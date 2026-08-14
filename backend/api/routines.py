from typing import Any
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api import deps
from crud import routine as crud_routine
from schemas.routine import Routine, RoutineCreate
from models.user import User as UserModel

router = APIRouter()


@router.get("/", response_model=Routine)
def get_routine(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Get the current user's daily routine."""
    routine = crud_routine.get_routine_by_user(db=db, user_id=current_user.id)
    if not routine:
        # Return default routine
        routine = crud_routine.create_routine(
            db=db,
            routine=RoutineCreate(),
            user_id=current_user.id,
        )
    return routine


@router.post("/", response_model=Routine)
def create_or_update_routine(
    *,
    db: Session = Depends(deps.get_db),
    routine_in: RoutineCreate,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Create or update the user's daily routine."""
    routine = crud_routine.upsert_routine(
        db=db, routine=routine_in, user_id=current_user.id
    )
    return routine
