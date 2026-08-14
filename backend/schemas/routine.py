from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class RoutineBase(BaseModel):
    wake_time: str = "07:00"
    breakfast_time: str = "08:00"
    lunch_time: str = "13:00"
    dinner_time: str = "20:00"
    sleep_time: str = "23:00"


class RoutineCreate(RoutineBase):
    pass


class RoutineUpdate(RoutineBase):
    wake_time: Optional[str] = None
    breakfast_time: Optional[str] = None
    lunch_time: Optional[str] = None
    dinner_time: Optional[str] = None
    sleep_time: Optional[str] = None


class Routine(RoutineBase):
    id: int
    user_id: int

    class Config:
        from_attributes = True
