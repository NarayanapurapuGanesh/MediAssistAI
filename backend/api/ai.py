from fastapi import APIRouter, Depends
from typing import Any
from sqlalchemy.orm import Session
from api import deps
from pydantic import BaseModel
from crud import health as crud_health
from crud import medication as crud_med
from services.ai_service import get_ai_insights, get_ai_chat_response

router = APIRouter()


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    response: str


@router.post("/chat", response_model=ChatResponse)
def ai_chat(
    *,
    db: Session = Depends(deps.get_db),
    request: ChatRequest,
    current_user=Depends(deps.get_current_user),
) -> Any:
    """Chat with AI health assistant using real application context."""
    meds = crud_med.get_medications_by_user(db=db, user_id=current_user.id)
    metrics = crud_health.get_health_measurements_by_user(
        db=db, user_id=current_user.id, limit=20
    )

    response_text = get_ai_chat_response(
        db=db,
        user_id=current_user.id,
        message=request.message,
        user_name=current_user.name or "User",
        medications=meds,
        recent_metrics=metrics,
    )
    return ChatResponse(response=response_text)


@router.post("/insights")
def get_insights(
    *,
    db: Session = Depends(deps.get_db),
    current_user=Depends(deps.get_current_user),
) -> Any:
    """
    Get structured AI health insights.
    Returns: summary, insights list, recommendations, severity, disclaimer.
    Falls back to deterministic analytics if Gemini is unavailable.
    """
    return get_ai_insights(
        db=db,
        user_id=current_user.id,
        user_name=current_user.name or "User",
    )
