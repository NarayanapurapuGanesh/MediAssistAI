from sqlalchemy.orm import Session
from models.ai import AIAlert
from schemas.health import AIAlertCreate
from typing import List

def get_ai_alerts_by_user(db: Session, user_id: int) -> List[AIAlert]:
    return db.query(AIAlert).filter(AIAlert.user_id == user_id).order_by(AIAlert.created_at.desc()).all()

def create_ai_alert(db: Session, alert: AIAlertCreate, user_id: int) -> AIAlert:
    db_alert = AIAlert(
        user_id=user_id,
        alert_type=alert.alert_type,
        message=alert.message,
        severity=alert.severity
    )
    db.add(db_alert)
    db.commit()
    db.refresh(db_alert)
    return db_alert
