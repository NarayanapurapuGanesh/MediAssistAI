from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime

from db.base import Base

class HealthMeasurement(Base):
    __tablename__ = "health_measurements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    type = Column(String)
    value = Column(Float)
    secondary_value = Column(Float, nullable=True)
    unit = Column(String)
    source = Column(String)
    recorded_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="health_measurements")
