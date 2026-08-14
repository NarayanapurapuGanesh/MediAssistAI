from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime

from db.base import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    age = Column(Integer)
    gender = Column(String)
    height = Column(Float)
    weight = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    medications = relationship("Medication", back_populates="user")
    health_measurements = relationship("HealthMeasurement", back_populates="user")
    ai_alerts = relationship("AIAlert", back_populates="user")
    routine = relationship("Routine", back_populates="user", uselist=False)
