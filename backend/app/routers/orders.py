import json
import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.order import Order, OrderStatusHistory
from app.models.invoice import Invoice
from app.models.pharmacy import Pharmacy
from app.models.user import User
from app.schemas.order import OrderCreateRequest, OrderResponse, PatientOrderCreateRequest
from app.routers.invoices import _format_invoice_response
from app.core.config import settings
from app.auth import get_current_user, require_role

router = APIRouter(prefix="/orders", tags=["Orders & Patient Tracking"])

def _generate_order_number(db: Session) -> str:
    count = db.query(Order).count() + 1
    year = datetime.datetime.utcnow().year
    return f"DAWA-{year}-{count:04d}"

@router.post("", response_model=OrderResponse)
@router.post("/", response_model=OrderResponse)
def create_patient_order(
    req: PatientOrderCreateRequest,
    current_user: User = Depends(require_role("patient")),
    db: Session = Depends(get_db)
):
    pharmacy = db.query(Pharmacy).filter(Pharmacy.id == req.pharmacy_id).first()
    if not pharmacy:
        raise HTTPException(status_code=404, detail="Pharmacy not found")

    is_delivery = (req.fulfillment_type or "").lower() == "delivery"
    delivery_fee = settings.DEFAULT_DELIVERY_FEE if is_delivery else 0.0

    subtotal = 0.0
    for itm in req.items:
        price = float(itm.get("price", 0.0))
        qty = int(itm.get("quantity", 1))
        subtotal += price * qty

    total_amount = round(subtotal + delivery_fee, 2)
    order_number = _generate_order_number(db)

    order = Order(
        order_number=order_number,
        patient_id=current_user.id,
        user_id=current_user.id,
        pharmacy_id=req.pharmacy_id,
        fulfillment_type="delivery" if is_delivery else "pickup",
        delivery_address=req.delivery_address,
        delivery_latitude=req.delivery_latitude,
        delivery_longitude=req.delivery_longitude,
        delivery_fee=delivery_fee,
        total_amount=total_amount,
        items=json.dumps(req.items),
        prescription_ref=req.prescription_ref,
        status="pending",
        payment_method=req.payment_method or "Pay at Pickup / Cash on Delivery"
    )
    db.add(order)
    db.flush()

    hist = OrderStatusHistory(
        order_id=order.id,
        status="pending",
        notes=f"Order placed by patient {current_user.name} ({current_user.email})",
        changed_by="Patient"
    )
    db.add(hist)
    db.commit()
    db.refresh(order)
    return _format_order_response(order)

@router.get("/mine", response_model=List[OrderResponse])
def get_my_orders(
    current_user: User = Depends(require_role("patient")),
    db: Session = Depends(get_db)
):
    orders = db.query(Order).filter(
        (Order.user_id == current_user.id) | (Order.patient_id == current_user.id)
    ).order_by(Order.created_at.desc()).all()
    return [_format_order_response(o) for o in orders]

@router.patch("/{order_id}/cancel", response_model=OrderResponse)
def cancel_order(
    order_id: int,
    current_user: User = Depends(require_role("patient")),
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(
        Order.id == order_id,
        (Order.user_id == current_user.id) | (Order.patient_id == current_user.id)
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    cur_status = (order.status or "").lower()
    if cur_status not in ["pending", "order placed", "awaiting pharmacist verification"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Only pending orders can be cancelled (current status: '{order.status}')"
        )

    order.status = "cancelled"
    order.updated_at = datetime.datetime.utcnow()

    hist = OrderStatusHistory(
        order_id=order.id,
        status="cancelled",
        notes="Order cancelled by patient",
        changed_by="Patient"
    )
    db.add(hist)
    db.commit()
    db.refresh(order)
    return _format_order_response(order)


@router.post("/create", response_model=OrderResponse)
def create_order(req: OrderCreateRequest, db: Session = Depends(get_db)):
    """
    Creates an order once the patient approves the invoice and selects
    fulfillment (Pickup or Home Delivery).
    """
    invoice = db.query(Invoice).filter(Invoice.id == req.invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    is_delivery = req.fulfillment_type.lower() == "delivery"
    delivery_fee = settings.DEFAULT_DELIVERY_FEE if is_delivery else 0.0
    total_amount = round(invoice.subtotal + delivery_fee, 2)

    # Update invoice delivery fee and total
    invoice.delivery_fee = delivery_fee
    invoice.total_amount = total_amount
    invoice.status = "APPROVED"

    order_number = _generate_order_number(db)
    
    order = Order(
        order_number=order_number,
        patient_id=req.patient_id or invoice.patient_id or 1,
        pharmacy_id=invoice.pharmacy_id,
        invoice_id=invoice.id,
        prescription_id=invoice.prescription_id,
        fulfillment_type="delivery" if is_delivery else "pickup",
        delivery_address=req.delivery_address or ("Home Delivery" if is_delivery else None),
        delivery_latitude=req.delivery_latitude,
        delivery_longitude=req.delivery_longitude,
        delivery_fee=delivery_fee,
        total_amount=total_amount,
        status="Order Placed",
        payment_method=req.payment_method or "Pay at Pickup / Cash on Delivery",
        items=json.dumps([
            {"name": it.medicine.brand_name if it.medicine else "Medicine", "quantity": it.quantity, "price": it.unit_price}
            for it in invoice.items
        ]) if invoice.items else None,
    )
    db.add(order)
    db.flush()

    # Add initial history logs
    hist1 = OrderStatusHistory(
        order_id=order.id,
        status="Order Placed",
        notes=f"Order submitted by patient. Fulfillment: {order.fulfillment_type.capitalize()}.",
        changed_by="Patient",
    )
    hist2 = OrderStatusHistory(
        order_id=order.id,
        status="Awaiting Pharmacist Verification",
        notes="Prescription routed to licensed pharmacist for clinical review.",
        changed_by="System",
    )
    db.add(hist1)
    db.add(hist2)

    order.status = "Awaiting Pharmacist Verification"
    db.commit()
    db.refresh(order)

    return _format_order_response(order)

@router.get("", response_model=List[OrderResponse])
def get_patient_orders(db: Session = Depends(get_db)):
    """Get all orders with full status timeline history."""
    orders = db.query(Order).order_by(Order.created_at.desc()).all()
    return [_format_order_response(o) for o in orders]

@router.get("/{order_id}", response_model=OrderResponse)
def get_order_by_id(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return _format_order_response(order)

def _format_order_response(order: Order) -> OrderResponse:
    items_parsed = None
    if order.items:
        try:
            items_parsed = json.loads(order.items)
        except Exception:
            items_parsed = [{"raw": order.items}]
    return OrderResponse(
        id=order.id,
        order_number=order.order_number,
        patient_id=order.patient_id,
        user_id=order.user_id,
        pharmacy_id=order.pharmacy_id,
        pharmacy_name=order.pharmacy.name if order.pharmacy else "DAWA Pharmacy",
        pharmacy_address=order.pharmacy.address if order.pharmacy else "",
        invoice_id=order.invoice_id,
        prescription_id=order.prescription_id,
        prescription_ref=order.prescription_ref,
        fulfillment_type=order.fulfillment_type or "pickup",
        delivery_address=order.delivery_address,
        delivery_fee=order.delivery_fee or 0.0,
        total_amount=order.total_amount,
        total=order.total_amount,
        status=order.status,
        items=items_parsed,
        payment_method=order.payment_method or "Pay at Pickup / Cash on Delivery",
        rejection_reason=order.rejection_reason,
        pharmacist_notes=order.pharmacist_notes,
        created_at=order.created_at,
        updated_at=order.updated_at,
        history=[
            {
                "id": h.id,
                "status": h.status,
                "notes": h.notes,
                "changed_by": h.changed_by,
                "timestamp": h.timestamp,
            }
            for h in order.history
        ],
        invoice=_format_invoice_response(order.invoice) if order.invoice else None
    )
