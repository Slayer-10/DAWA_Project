import json
import datetime
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.pharmacy import Pharmacy
from app.models.stock import Stock
from app.models.order import Order, OrderStatusHistory
from app.auth import require_role

router = APIRouter(prefix="/admin", tags=["Pharmacy Admin"])

class StockCreate(BaseModel):
    medicine_name: str = Field(..., min_length=1)
    strength: Optional[str] = None
    form: Optional[str] = None
    price: float = Field(..., ge=0.0)
    quantity: int = Field(..., ge=0)

class StockUpdate(BaseModel):
    medicine_name: Optional[str] = None
    strength: Optional[str] = None
    form: Optional[str] = None
    price: Optional[float] = Field(None, ge=0.0)
    quantity: Optional[int] = Field(None, ge=0)

class OrderStatusUpdate(BaseModel):
    status: str
    reason: Optional[str] = None
    notes: Optional[str] = None

class PharmacyProfileUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    opening_hours: Optional[str] = None
    is_open: Optional[bool] = None

def get_admin_pharmacy(current_user: User, db: Session) -> Pharmacy:
    pharmacy = db.query(Pharmacy).filter(Pharmacy.owner_user_id == current_user.id).first()
    if not pharmacy:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No pharmacy registered under this admin account"
        )
    return pharmacy

def format_stock(s: Stock) -> dict:
    return {
        "id": s.id,
        "pharmacy_id": s.pharmacy_id,
        "medicine_name": s.medicine_name,
        "strength": s.strength,
        "form": s.form,
        "price": s.price,
        "quantity": s.quantity,
        "updated_at": s.updated_at.isoformat() if s.updated_at else None
    }

def format_order(o: Order) -> dict:
    items_parsed = []
    if o.items:
        try:
            items_parsed = json.loads(o.items)
        except Exception:
            items_parsed = [{"raw": o.items}]
    patient_name = "Patient"
    patient_phone = None
    if o.user:
        patient_name = o.user.name
        patient_phone = o.user.phone
    elif o.patient:
        patient_name = o.patient.name
        patient_phone = o.patient.phone

    return {
        "id": o.id,
        "order_number": o.order_number,
        "patient_id": o.patient_id,
        "patient_name": patient_name,
        "patient_phone": patient_phone,
        "user_id": o.user_id,
        "pharmacy_id": o.pharmacy_id,
        "items": items_parsed,
        "prescription_ref": o.prescription_ref,
        "status": o.status,
        "total": o.total_amount,
        "total_amount": o.total_amount,
        "delivery_address": o.delivery_address,
        "fulfillment_type": o.fulfillment_type,
        "rejection_reason": o.rejection_reason,
        "pharmacist_notes": o.pharmacist_notes,
        "created_at": o.created_at.isoformat() if o.created_at else None,
        "updated_at": o.updated_at.isoformat() if o.updated_at else None
    }

# --- Stock Endpoints ---

@router.get("/stock")
def get_stocks(
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    stocks = db.query(Stock).filter(Stock.pharmacy_id == pharmacy.id).all()
    return [format_stock(s) for s in stocks]

@router.post("/stock")
def create_stock(
    req: StockCreate,
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    stock = Stock(
        pharmacy_id=pharmacy.id,
        medicine_name=req.medicine_name.strip(),
        strength=req.strength.strip() if req.strength else None,
        form=req.form.strip() if req.form else None,
        price=req.price,
        quantity=req.quantity
    )
    db.add(stock)
    db.commit()
    db.refresh(stock)
    return format_stock(stock)

@router.put("/stock/{stock_id}")
def update_stock(
    stock_id: int,
    req: StockUpdate,
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    stock = db.query(Stock).filter(Stock.id == stock_id, Stock.pharmacy_id == pharmacy.id).first()
    if not stock:
        raise HTTPException(status_code=404, detail="Stock item not found")

    if req.medicine_name is not None:
        stock.medicine_name = req.medicine_name.strip()
    if req.strength is not None:
        stock.strength = req.strength.strip() if req.strength else None
    if req.form is not None:
        stock.form = req.form.strip() if req.form else None
    if req.price is not None:
        stock.price = req.price
    if req.quantity is not None:
        stock.quantity = req.quantity
    
    stock.updated_at = datetime.datetime.utcnow()
    db.commit()
    db.refresh(stock)
    return format_stock(stock)

@router.delete("/stock/{stock_id}")
def delete_stock(
    stock_id: int,
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    stock = db.query(Stock).filter(Stock.id == stock_id, Stock.pharmacy_id == pharmacy.id).first()
    if not stock:
        raise HTTPException(status_code=404, detail="Stock item not found")
    db.delete(stock)
    db.commit()
    return {"success": True, "deleted_id": stock_id}

# --- Orders Endpoints ---

@router.get("/orders")
def get_admin_orders(
    status: Optional[str] = Query(None),
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    query = db.query(Order).filter(Order.pharmacy_id == pharmacy.id)
    if status:
        query = query.filter(Order.status.ilike(status))
    orders = query.order_by(Order.created_at.desc()).all()
    return [format_order(o) for o in orders]

ALLOWED_STATUS_TRANSITIONS = {
    "pending": {"accepted", "rejected", "cancelled"},
    "accepted": {"ready", "cancelled"},
    "ready": {"completed", "cancelled"},
    "rejected": set(),
    "completed": set(),
    "cancelled": set()
}

@router.patch("/orders/{order_id}/status")
def update_order_status(
    order_id: int,
    req: OrderStatusUpdate,
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    order = db.query(Order).filter(Order.id == order_id, Order.pharmacy_id == pharmacy.id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    current_st = (order.status or "pending").lower()
    target_st = req.status.lower()

    allowed = ALLOWED_STATUS_TRANSITIONS.get(current_st, {"accepted", "rejected", "ready", "completed", "cancelled"})
    if target_st not in allowed and target_st != current_st:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot transition order from '{order.status}' to '{req.status}'. Allowed: {list(allowed)}"
        )

    order.status = target_st
    if req.reason:
        order.rejection_reason = req.reason
    if req.notes:
        order.pharmacist_notes = req.notes
    order.updated_at = datetime.datetime.utcnow()

    # Record history
    history = OrderStatusHistory(
        order_id=order.id,
        status=target_st,
        notes=req.notes or req.reason,
        changed_by="Pharmacist"
    )
    db.add(history)
    db.commit()
    db.refresh(order)
    return format_order(order)

# --- Pharmacy Profile Endpoint ---

@router.put("/pharmacy")
def update_pharmacy_profile(
    req: PharmacyProfileUpdate,
    current_user: User = Depends(require_role("pharmacy_admin")),
    db: Session = Depends(get_db)
):
    pharmacy = get_admin_pharmacy(current_user, db)
    if req.name is not None:
        pharmacy.name = req.name.strip()
    if req.address is not None:
        pharmacy.address = req.address.strip()
    if req.lat is not None:
        pharmacy.lat = req.lat
        pharmacy.latitude = req.lat
    if req.lng is not None:
        pharmacy.lng = req.lng
        pharmacy.longitude = req.lng
    if req.phone is not None:
        pharmacy.phone = req.phone.strip()
    if req.opening_hours is not None:
        pharmacy.opening_hours = req.opening_hours.strip()
    if req.is_open is not None:
        pharmacy.is_open = req.is_open

    db.commit()
    db.refresh(pharmacy)
    return {
        "id": pharmacy.id,
        "name": pharmacy.name,
        "address": pharmacy.address,
        "lat": pharmacy.lat,
        "lng": pharmacy.lng,
        "phone": pharmacy.phone,
        "opening_hours": pharmacy.opening_hours,
        "is_open": pharmacy.is_open
    }

