from sqlalchemy.orm import Session
from models.routine import Routine
from schemas.routine import RoutineCreate, RoutineUpdate
from typing import Optional


def get_routine_by_user(db: Session, user_id: int) -> Optional[Routine]:
    return db.query(Routine).filter(Routine.user_id == user_id).first()


def create_routine(db: Session, routine: RoutineCreate, user_id: int) -> Routine:
    db_routine = Routine(
        user_id=user_id,
        wake_time=routine.wake_time,
        breakfast_time=routine.breakfast_time,
        lunch_time=routine.lunch_time,
        dinner_time=routine.dinner_time,
        sleep_time=routine.sleep_time,
    )
    db.add(db_routine)
    db.commit()
    db.refresh(db_routine)
    return db_routine


def update_routine(db: Session, db_routine: Routine, routine_in: RoutineUpdate) -> Routine:
    update_data = routine_in.dict(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None:
            setattr(db_routine, field, value)
    db.commit()
    db.refresh(db_routine)
    return db_routine


def upsert_routine(db: Session, routine: RoutineCreate, user_id: int) -> Routine:
    """Create or update the user's routine."""
    existing = get_routine_by_user(db, user_id)
    if existing:
        return update_routine(db, existing, RoutineUpdate(**routine.dict()))
    return create_routine(db, routine, user_id)
