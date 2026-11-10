from sqlalchemy import Column, Integer, String, Float, Boolean, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base

class Pharmacy(Base):
    __tablename__ = "pharmacies"

    id = Column(Integer, primary_key=True, index=True)
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    name = Column(String(150), nullable=False, index=True)
    area = Column(String(100), nullable=True, default="")
    address = Column(String(255), nullable=False)
    city = Column(String(100), default="", nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    phone = Column(String(50), nullable=True)
    opening_hours = Column(String(100), default="9:00 AM – 11:00 PM")
    is_open = Column(Boolean, default=True)
    description = Column(Text, nullable=True)
    is_demo = Column(Boolean, default=False)
    rating = Column(Float, default=4.8)

    owner = relationship("User", back_populates="pharmacies")
    stocks = relationship("Stock", back_populates="pharmacy", cascade="all, delete-orphan")
    inventory_items = relationship("PharmacyInventory", back_populates="pharmacy", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="pharmacy")
    orders = relationship("Order", back_populates="pharmacy")
