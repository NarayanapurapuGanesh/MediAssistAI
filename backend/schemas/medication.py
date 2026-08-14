from pydantic import BaseModel
from typing import Optional, List
from datetime import date, datetime

class MedicationScheduleBase(BaseModel):
    scheduled_time: str

class MedicationScheduleCreate(MedicationScheduleBase):
    pass

class MedicationSchedule(MedicationScheduleBase):
    id: int
    medication_id: int

    class Config:
        from_attributes = True

class MedicationBase(BaseModel):
    name: str
    dosage: str
    frequency: str
    start_date: date
    end_date: date

class MedicationCreate(MedicationBase):
    schedules: List[str]

class MedicationUpdate(MedicationBase):
    name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    schedules: Optional[List[str]] = None

class Medication(MedicationBase):
    id: int
    user_id: int
    created_at: datetime
    schedules: List[MedicationSchedule] = []

    class Config:
        from_attributes = True

class MedicationRecordBase(BaseModel):
    scheduled_time: str
    status: str # "Taken", "Skipped", "Snooze"

class MedicationRecordCreate(MedicationRecordBase):
    medication_id: int
    taken_at: Optional[datetime] = None

class MedicationRecord(MedicationRecordBase):
    id: int
    medication_id: int
    taken_at: Optional[datetime] = None

    class Config:
        from_attributes = True
