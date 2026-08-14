from sqlalchemy.orm import Session
from models.medication import Medication, MedicationSchedule
from schemas.medication import MedicationCreate, MedicationUpdate
from typing import List, Optional

def get_medications_by_user(db: Session, user_id: int) -> List[Medication]:
    return db.query(Medication).filter(Medication.user_id == user_id).all()

def create_medication(db: Session, medication: MedicationCreate, user_id: int) -> Medication:
    db_medication = Medication(
        name=medication.name,
        dosage=medication.dosage,
        frequency=medication.frequency,
        start_date=medication.start_date,
        end_date=medication.end_date,
        user_id=user_id
    )
    db.add(db_medication)
    db.commit()
    db.refresh(db_medication)

    for schedule_time in medication.schedules:
        db_schedule = MedicationSchedule(
            medication_id=db_medication.id,
            scheduled_time=schedule_time
        )
        db.add(db_schedule)
    db.commit()
    db.refresh(db_medication)

    return db_medication

def get_medication(db: Session, id: int) -> Optional[Medication]:
    return db.query(Medication).filter(Medication.id == id).first()

def update_medication(db: Session, db_medication: Medication, medication_in: MedicationUpdate) -> Medication:
    if medication_in.name is not None:
        db_medication.name = medication_in.name
    if medication_in.dosage is not None:
        db_medication.dosage = medication_in.dosage
    if medication_in.frequency is not None:
        db_medication.frequency = medication_in.frequency
    if medication_in.start_date is not None:
        db_medication.start_date = medication_in.start_date
    if medication_in.end_date is not None:
        db_medication.end_date = medication_in.end_date
    
    if medication_in.schedules is not None:
        # Delete old schedules
        db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == db_medication.id).delete()
        # Add new schedules
        for schedule_time in medication_in.schedules:
            db_schedule = MedicationSchedule(
                medication_id=db_medication.id,
                scheduled_time=schedule_time
            )
            db.add(db_schedule)
            
    db.commit()
    db.refresh(db_medication)
    return db_medication

def delete_medication(db: Session, id: int) -> Medication:
    obj = db.query(Medication).get(id)
    if obj:
        db.delete(obj)
        db.commit()
    return obj
