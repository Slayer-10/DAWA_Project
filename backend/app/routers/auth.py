from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.pharmacy import Pharmacy
from app.schemas.auth import RegisterRequest, LoginRequest, AuthResponse
from app.auth import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

def format_user(user: User) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "phone": user.phone,
        "created_at": user.created_at.isoformat() if user.created_at else None
    }

def format_pharmacy(pharmacy: Pharmacy) -> dict:
    if not pharmacy:
        return None
    return {
        "id": pharmacy.id,
        "name": pharmacy.name,
        "address": pharmacy.address,
        "lat": pharmacy.lat if pharmacy.lat is not None else pharmacy.latitude,
        "lng": pharmacy.lng if pharmacy.lng is not None else pharmacy.longitude,
        "phone": pharmacy.phone,
        "opening_hours": pharmacy.opening_hours,
        "is_open": bool(pharmacy.is_open) if pharmacy.is_open is not None else True
    }

@router.post("/register", response_model=AuthResponse)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    clean_email = req.email.strip().lower()
    
    if len(req.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters"
        )
    
    existing = db.query(User).filter(User.email == clean_email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    if req.role == "pharmacy_admin" and not req.pharmacy:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Pharmacy details are required for pharmacy_admin registration"
        )

    user = User(
        name=req.name.strip(),
        email=clean_email,
        password_hash=hash_password(req.password),
        role=req.role,
        phone=req.phone.strip() if req.phone else None
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    pharmacy_obj = None
    if req.role == "pharmacy_admin" and req.pharmacy:
        pharmacy_obj = Pharmacy(
            owner_user_id=user.id,
            name=req.pharmacy.name.strip(),
            address=req.pharmacy.address.strip(),
            lat=req.pharmacy.lat,
            lng=req.pharmacy.lng,
            latitude=req.pharmacy.lat,
            longitude=req.pharmacy.lng,
            phone=req.pharmacy.phone.strip() if req.pharmacy.phone else user.phone,
            opening_hours=req.pharmacy.opening_hours or "9:00 AM – 11:00 PM",
            is_open=True,
            is_demo=False
        )
        db.add(pharmacy_obj)
        db.commit()
        db.refresh(pharmacy_obj)

    token = create_access_token(user.id, user.role)
    return {
        "token": token,
        "user": format_user(user),
        "pharmacy": format_pharmacy(pharmacy_obj)
    }

@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    clean_email = req.email.strip().lower()
    user = db.query(User).filter(User.email == clean_email).first()
    
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    pharmacy_obj = None
    if user.role == "pharmacy_admin":
        pharmacy_obj = db.query(Pharmacy).filter(Pharmacy.owner_user_id == user.id).first()

    token = create_access_token(user.id, user.role)
    return {
        "token": token,
        "user": format_user(user),
        "pharmacy": format_pharmacy(pharmacy_obj)
    }

@router.get("/me")
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    pharmacy_obj = None
    if current_user.role == "pharmacy_admin":
        pharmacy_obj = db.query(Pharmacy).filter(Pharmacy.owner_user_id == current_user.id).first()

    return {
        "user": format_user(current_user),
        "pharmacy": format_pharmacy(pharmacy_obj)
    }

