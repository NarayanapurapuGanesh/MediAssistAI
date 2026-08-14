from datetime import datetime, timedelta
from typing import Any, List, Dict, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from api import deps
from crud import health as crud_health
from crud import ai as crud_ai
from schemas.health import HealthMeasurement, HealthMeasurementCreate, AIAlert, AIAlertCreate
from models.user import User as UserModel
from models.health import HealthMeasurement as HealthModel
from models.medication import MedicationRecord, Medication
from services.health_analytics import get_health_analytics, get_overall_health_status
from services.anomaly_detection import detect_anomalies
from services.adherence_service import get_adherence_summary

router = APIRouter()


def _serialize_measurement(m: HealthModel) -> Dict[str, Any]:
    """Helper to convert SQLAlchemy model instance into JSON-serializable dict."""
    return {
        "id": m.id,
        "type": m.type,
        "value": m.value,
        "secondary_value": m.secondary_value,
        "unit": m.unit,
        "source": m.source,
        "recorded_at": m.recorded_at.isoformat() if m.recorded_at else None,
        "user_id": m.user_id,
    }


@router.get("/", response_model=List[HealthMeasurement])
def read_health_measurements(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
    skip: int = 0,
    limit: int = 100
) -> Any:
    return crud_health.get_health_measurements_by_user(
        db=db, user_id=current_user.id, skip=skip, limit=limit
    )


@router.post("/", response_model=HealthMeasurement)
def create_health_measurement(
    *,
    db: Session = Depends(deps.get_db),
    measurement_in: HealthMeasurementCreate,
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    # 1. Save measurement
    measurement = crud_health.create_health_measurement(
        db=db, measurement=measurement_in, user_id=current_user.id
    )

    # 2. Run anomaly detection
    anomalies = detect_anomalies(db, current_user.id, days=7)
    for anomaly in anomalies:
        if (anomaly.get("metric") == measurement_in.type and
                anomaly.get("status") in ("attention", "abnormal")):
            alert_in = AIAlertCreate(
                alert_type="Health Anomaly",
                message=anomaly.get("reason", f"Unusual trend detected in {measurement_in.type}."),
                severity="warning" if anomaly["status"] == "attention" else "critical"
            )
            crud_ai.create_ai_alert(db, alert=alert_in, user_id=current_user.id)
            break

    return measurement


@router.post("/readings", response_model=Dict[str, Any])
def create_batch_readings(
    *,
    db: Session = Depends(deps.get_db),
    readings: List[HealthMeasurementCreate],
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    """Submit multiple health readings at once."""
    created = []
    for reading in readings:
        m = crud_health.create_health_measurement(
            db=db, measurement=reading, user_id=current_user.id
        )
        created.append(m.id)
    return {"created": len(created), "ids": created}


@router.get("/latest", response_model=Dict[str, Any])
def get_latest_health_measurements(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user)
) -> Any:
    """Get the most recent reading for each metric type."""
    subquery = db.query(
        HealthModel.type,
        func.max(HealthModel.recorded_at).label('max_date')
    ).filter(
        HealthModel.user_id == current_user.id
    ).group_by(HealthModel.type).subquery()

    latest_records = db.query(HealthModel).join(
        subquery,
        (HealthModel.type == subquery.c.type) &
        (HealthModel.recorded_at == subquery.c.max_date)
    ).filter(HealthModel.user_id == current_user.id).all()

    return {r.type: _serialize_measurement(r) for r in latest_records}


@router.get("/summary", response_model=Dict[str, Any])
def get_health_summary(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user)
) -> Any:
    """Get an overall summary for the dashboard."""
    latest = get_latest_health_measurements(db=db, current_user=current_user)

    # Calculate adherence using the service
    adherence_data = get_adherence_summary(db, current_user.id)
    adherence = adherence_data["adherence_percentage"]

    # Calculate overall health status
    health_status = get_overall_health_status(db, current_user.id)

    last_updated = None
    if latest:
        dates = []
        for val in latest.values():
            if isinstance(val, dict) and val.get("recorded_at"):
                dates.append(val["recorded_at"])
            elif hasattr(val, 'recorded_at') and val.recorded_at:
                dates.append(val.recorded_at.isoformat())
        if dates:
            last_updated = max(dates)

    return {
        "status": health_status["overall_status"],
        "last_updated": last_updated,
        "metrics": latest,
        "adherence": adherence,
        "attention_metrics": health_status.get("attention_metrics", []),
        "abnormal_metrics": health_status.get("abnormal_metrics", []),
    }


@router.get("/trends", response_model=Dict[str, Any])
def get_health_trends(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
    days: int = 7
) -> Any:
    """Get health trends with analytics."""
    cutoff = datetime.utcnow() - timedelta(days=days)

    measurements = db.query(HealthModel).filter(
        HealthModel.user_id == current_user.id,
        HealthModel.recorded_at >= cutoff
    ).order_by(HealthModel.recorded_at.asc()).all()

    trends = {}
    for m in measurements:
        date_str = m.recorded_at.strftime("%Y-%m-%d")
        if m.type not in trends:
            trends[m.type] = {}
        if date_str not in trends[m.type]:
            trends[m.type][date_str] = []
        trends[m.type][date_str].append(m.value)

    formatted_trends = {}
    for m_type, dates in trends.items():
        formatted_trends[m_type] = []
        for date_str, values in dates.items():
            avg = sum(values) / len(values)
            formatted_trends[m_type].append({
                "date": date_str,
                "value": round(avg, 1)
            })

    return {"trends": formatted_trends}


@router.get("/analytics", response_model=Dict[str, Any])
def get_health_analytics_endpoint(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
    days: int = Query(default=7, ge=1, le=90),
) -> Any:
    """Get comprehensive health analytics with baselines and trends."""
    analytics = get_health_analytics(db, current_user.id, days=days)
    anomalies = detect_anomalies(db, current_user.id, days=days)

    return {
        "analytics": analytics,
        "anomalies": anomalies,
        "period_days": days,
    }


@router.get("/history", response_model=List[HealthMeasurement])
def get_health_history(
    type: Optional[str] = None,
    days: Optional[int] = None,
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
    limit: int = 100
) -> Any:
    """Get history, optionally filtered by type and time range."""
    query = db.query(HealthModel).filter(
        HealthModel.user_id == current_user.id
    )
    if type:
        query = query.filter(HealthModel.type == type)
    if days:
        cutoff = datetime.utcnow() - timedelta(days=days)
        query = query.filter(HealthModel.recorded_at >= cutoff)
    return query.order_by(HealthModel.recorded_at.desc()).limit(limit).all()


@router.get("/alerts", response_model=List[AIAlert])
def read_ai_alerts(
    db: Session = Depends(deps.get_db),
    current_user: UserModel = Depends(deps.get_current_user),
) -> Any:
    return crud_ai.get_ai_alerts_by_user(db=db, user_id=current_user.id)
