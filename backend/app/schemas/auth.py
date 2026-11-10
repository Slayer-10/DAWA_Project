from typing import Optional, Dict, Any
from pydantic import BaseModel, EmailStr, Field

class PharmacyRegisterData(BaseModel):
    name: str
    address: str
    lat: float
    lng: float
    phone: Optional[str] = None
    opening_hours: Optional[str] = "9:00 AM – 11:00 PM"

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1)
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=8)
    role: str = Field(..., pattern="^(patient|pharmacy_admin)$")
    phone: Optional[str] = None
    pharmacy: Optional[PharmacyRegisterData] = None

class LoginRequest(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: str
    phone: Optional[str] = None
    created_at: Optional[str] = None

class PharmacySummary(BaseModel):
    id: int
    name: str
    address: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    phone: Optional[str] = None
    opening_hours: Optional[str] = None
    is_open: bool = True

class AuthResponse(BaseModel):
    token: str
    user: Dict[str, Any]
    pharmacy: Optional[Dict[str, Any]] = None

