from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel
from app.schemas.invoice import InvoiceResponse

class OrderStatusHistoryResponse(BaseModel):
    id: int
    status: str
    notes: Optional[str]
    changed_by: str
    timestamp: datetime

    class Config:
        from_attributes = True

class PatientOrderCreateRequest(BaseModel):
    pharmacy_id: int
    items: List[Dict[str, Any]]
    prescription_ref: Optional[str] = None
    fulfillment_type: Optional[str] = "pickup"
    delivery_address: Optional[str] = None
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    payment_method: Optional[str] = "Pay at Pickup / Cash on Delivery"

class OrderCreateRequest(BaseModel):
    invoice_id: int
    patient_id: Optional[int] = 1
    fulfillment_type: str = "pickup"  # "pickup" or "delivery"
    delivery_address: Optional[str] = None
    delivery_latitude: Optional[float] = None
    delivery_longitude: Optional[float] = None
    payment_method: Optional[str] = "Pay at Pickup / Cash on Delivery"

class OrderStatusUpdateRequest(BaseModel):
    status: str
    notes: Optional[str] = None
    changed_by: Optional[str] = "Pharmacist"
    admin_key: Optional[str] = None

class OrderResponse(BaseModel):
    id: int
    order_number: str
    patient_id: Optional[int] = None
    user_id: Optional[int] = None
    pharmacy_id: int
    pharmacy_name: str
    pharmacy_address: str
    invoice_id: Optional[int] = None
    prescription_id: Optional[int] = None
    prescription_ref: Optional[str] = None
    fulfillment_type: str
    delivery_address: Optional[str] = None
    delivery_fee: float = 0.0
    total_amount: float
    total: Optional[float] = None
    status: str
    items: Optional[List[Dict[str, Any]]] = None
    payment_method: str
    rejection_reason: Optional[str] = None
    pharmacist_notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    history: List[OrderStatusHistoryResponse] = []
    invoice: Optional[InvoiceResponse] = None

    class Config:
        from_attributes = True

