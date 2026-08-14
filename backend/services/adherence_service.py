"""
Medication Adherence Service

Calculates:
- Scheduled doses
- Completed (Taken) doses
- Missed doses
- Skipped doses
- Adherence percentage
- Today's medication status
"""

from datetime import datetime, date, timedelta
from typing import List, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import func

from models.medication import Medication, MedicationSchedule, MedicationRecord


def get_adherence_summary(
    db: Session, user_id: int
) -> Dict[str, Any]:
    """Calculate overall medication adherence for a user."""
    total_records = db.query(MedicationRecord).join(Medication).filter(
        Medication.user_id == user_id
    ).count()

    taken_records = db.query(MedicationRecord).join(Medication).filter(
        Medication.user_id == user_id,
        MedicationRecord.status == "Taken"
    ).count()

    missed_records = db.query(MedicationRecord).join(Medication).filter(
        Medication.user_id == user_id,
        MedicationRecord.status == "Missed"
    ).count()

    skipped_records = db.query(MedicationRecord).join(Medication).filter(
        Medication.user_id == user_id,
        MedicationRecord.status == "Skipped"
    ).count()

    adherence = 0.0
    if total_records > 0:
        adherence = round((taken_records / total_records) * 100, 1)

    return {
        "total_scheduled": total_records,
        "taken": taken_records,
        "missed": missed_records,
        "skipped": skipped_records,
        "adherence_percentage": adherence,
    }


def get_today_medication_status(
    db: Session, user_id: int
) -> Dict[str, Any]:
    """Get today's medication schedule and status."""
    today = date.today()
    medications = db.query(Medication).filter(
        Medication.user_id == user_id,
        Medication.start_date <= today,
        Medication.end_date >= today,
    ).all()

    today_medications = []
    for med in medications:
        schedules = db.query(MedicationSchedule).filter(
            MedicationSchedule.medication_id == med.id
        ).all()

        for schedule in schedules:
            # Check if there's a record for today
            today_start = datetime.combine(today, datetime.min.time())
            today_end = datetime.combine(today, datetime.max.time())

            record = db.query(MedicationRecord).filter(
                MedicationRecord.medication_id == med.id,
                MedicationRecord.scheduled_time == schedule.scheduled_time,
                MedicationRecord.taken_at >= today_start,
                MedicationRecord.taken_at <= today_end,
            ).first()

            status = "Pending"
            if record:
                status = record.status

            today_medications.append({
                "medication_id": med.id,
                "medication_name": med.name,
                "dosage": med.dosage,
                "scheduled_time": schedule.scheduled_time,
                "status": status,
            })

    # Sort by time
    today_medications.sort(key=lambda x: x["scheduled_time"])

    completed = sum(1 for m in today_medications if m["status"] == "Taken")
    total = len(today_medications)

    return {
        "date": today.isoformat(),
        "total_scheduled": total,
        "completed": completed,
        "pending": total - completed,
        "medications": today_medications,
    }


def record_medication_event(
    db: Session,
    medication_id: int,
    scheduled_time: str,
    status: str,
    user_id: int,
) -> Dict[str, Any]:
    """Record a medication taken/missed/skipped event."""
    # Verify medication belongs to user
    medication = db.query(Medication).filter(
        Medication.id == medication_id,
        Medication.user_id == user_id,
    ).first()

    if not medication:
        return {"success": False, "error": "Medication not found"}

    record = MedicationRecord(
        medication_id=medication_id,
        scheduled_time=scheduled_time,
        status=status,
        taken_at=datetime.utcnow() if status == "Taken" else None,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return {
        "success": True,
        "record_id": record.id,
        "medication_name": medication.name,
        "status": status,
    }
