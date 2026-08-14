from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from api import deps
from crud import medication as crud_medication
from schemas.medication import Medication, MedicationCreate, MedicationUpdate
from models.user import User as UserModel
from services.adherence_service import (
    get_adherence_summary,
    get_today_medication_status,
    record_medication_event,
)

router = APIRouter()


class MedicationEventRequest(BaseModel):
    medication_id: int
    scheduled_time: str
    status: str  # "Taken", "Missed", "Skipped"


@router.get("/", response_model=List[Medication])
def read_medications(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Retrieve medications."""
    medications = crud_medication.get_medications_by_user(
        db=db, user_id=current_user.id
    )
    return medications


@router.post("/", response_model=Medication)
def create_medication(
    *,
    db: Session = Depends(deps.get_db),
    medication_in: MedicationCreate,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Create new medication."""
    medication = crud_medication.create_medication(
        db=db, medication=medication_in, user_id=current_user.id
    )
    return medication


@router.put("/{medication_id}", response_model=Medication)
def update_medication(
    *,
    db: Session = Depends(deps.get_db),
    medication_id: int,
    medication_in: MedicationUpdate,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Update a medication."""
    medication = crud_medication.get_medication(db=db, id=medication_id)
    if not medication:
        raise HTTPException(status_code=404, detail="Medication not found")
    if medication.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    medication = crud_medication.update_medication(
        db=db, db_medication=medication, medication_in=medication_in
    )
    return medication


@router.delete("/{medication_id}", response_model=Medication)
def delete_medication(
    *,
    db: Session = Depends(deps.get_db),
    medication_id: int,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Delete a medication."""
    medication = crud_medication.get_medication(db=db, id=medication_id)
    if not medication:
        raise HTTPException(status_code=404, detail="Medication not found")
    if medication.user_id != current_user.id:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    medication = crud_medication.delete_medication(db=db, id=medication_id)
    return medication


@router.get("/adherence")
def get_medication_adherence(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Get medication adherence summary."""
    return get_adherence_summary(db, current_user.id)


@router.get("/today")
def get_today_medications(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Get today's medication schedule and status."""
    return get_today_medication_status(db, current_user.id)


@router.post("/record")
def record_medication(
    *,
    db: Session = Depends(deps.get_db),
    event: MedicationEventRequest,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Record a medication taken/missed/skipped event."""
    if event.status not in ("Taken", "Missed", "Skipped"):
        raise HTTPException(
            status_code=400,
            detail="Status must be 'Taken', 'Missed', or 'Skipped'"
        )
    result = record_medication_event(
        db=db,
        medication_id=event.medication_id,
        scheduled_time=event.scheduled_time,
        status=event.status,
        user_id=current_user.id,
    )
    if not result.get("success"):
        raise HTTPException(status_code=404, detail=result.get("error"))
    return result
