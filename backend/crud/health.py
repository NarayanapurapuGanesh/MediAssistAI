from sqlalchemy.orm import Session
from models.health import HealthMeasurement
from schemas.health import HealthMeasurementCreate
from typing import List

def get_health_measurements_by_user(db: Session, user_id: int, skip: int = 0, limit: int = 100) -> List[HealthMeasurement]:
    return db.query(HealthMeasurement).filter(HealthMeasurement.user_id == user_id).order_by(HealthMeasurement.recorded_at.desc()).offset(skip).limit(limit).all()

def create_health_measurement(db: Session, measurement: HealthMeasurementCreate, user_id: int) -> HealthMeasurement:
    db_measurement = HealthMeasurement(
        user_id=user_id,
        type=measurement.type,
        value=measurement.value,
        secondary_value=measurement.secondary_value,
        unit=measurement.unit,
        source=measurement.source
    )
    db.add(db_measurement)
    db.commit()
    db.refresh(db_measurement)
    return db_measurement
