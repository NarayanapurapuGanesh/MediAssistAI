from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class HealthMeasurementBase(BaseModel):
    type: str # Heart Rate, SpO2, Blood Pressure, Steps, Sleep
    value: float
    secondary_value: Optional[float] = None
    unit: str
    source: str

class HealthMeasurementCreate(HealthMeasurementBase):
    pass

class HealthMeasurement(HealthMeasurementBase):
    id: int
    user_id: int
    recorded_at: datetime

    class Config:
        from_attributes = True

class AIAlertBase(BaseModel):
    alert_type: str
    message: str
    severity: str

class AIAlertCreate(AIAlertBase):
    pass

class AIAlert(AIAlertBase):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True
