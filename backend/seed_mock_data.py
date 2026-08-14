import os
import sys
from datetime import datetime, timedelta, date
import random

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from db.session import SessionLocal
from models.health import HealthMeasurement
from models.medication import Medication, MedicationSchedule, MedicationRecord
from models.user import User

def seed_data(email: str = "demo@example.com"):
    db = SessionLocal()
    user = db.query(User).filter(User.email == email).first()
    
    if not user:
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        user = User(
            name="Demo User",
            email=email,
            password_hash=pwd_context.hash("password123"),
            age=35,
            gender="Male",
            height=175.0,
            weight=70.0
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"Created dummy user: {user.email}")
    else:
        print(f"Using existing user: {user.email}")
        db.query(HealthMeasurement).filter(HealthMeasurement.user_id == user.id).delete()
        db.query(MedicationRecord).filter(
            MedicationRecord.medication_id.in_(
                db.query(Medication.id).filter(Medication.user_id == user.id)
            )
        ).delete(synchronize_session=False)
        db.query(MedicationSchedule).filter(
            MedicationSchedule.medication_id.in_(
                db.query(Medication.id).filter(Medication.user_id == user.id)
            )
        ).delete(synchronize_session=False)
        db.query(Medication).filter(Medication.user_id == user.id).delete()
        db.commit()

    # 1. Seed Health Measurements (14 days)
    random.seed(42)
    base_date = datetime.utcnow() - timedelta(days=14)
    measurements = []
    
    for day in range(15):
        d = base_date + timedelta(days=day)
        base_hr = 72 if day < 11 else 84
        for reading in range(3):
            hr_val = base_hr + random.uniform(-4, 4)
            measurements.append(HealthMeasurement(
                user_id=user.id,
                type="Heart Rate",
                value=round(hr_val, 1),
                unit="BPM",
                source="Mock Wearable",
                recorded_at=d + timedelta(hours=8 + (reading * 5))
            ))

    for day in range(15):
        d = base_date + timedelta(days=day)
        spo2_val = 98 + random.uniform(-1, 1)
        measurements.append(HealthMeasurement(
            user_id=user.id,
            type="SpO2",
            value=round(spo2_val, 1),
            unit="%",
            source="Mock Wearable",
            recorded_at=d + timedelta(hours=9)
        ))

    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=user.id,
            type="Blood Pressure",
            value=round(120 + random.uniform(-4, 4), 0),
            secondary_value=round(80 + random.uniform(-3, 3), 0),
            unit="mmHg",
            source="Mock Wearable",
            recorded_at=d + timedelta(hours=10)
        ))

    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=user.id,
            type="Steps",
            value=round(6500 + random.uniform(-1000, 2500), 0),
            unit="steps",
            source="Mock Wearable",
            recorded_at=d + timedelta(hours=20)
        ))

    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=user.id,
            type="Sleep",
            value=round(7.4 + random.uniform(-0.8, 0.8), 1),
            unit="hours",
            source="Mock Wearable",
            recorded_at=d + timedelta(hours=7)
        ))

    db.bulk_save_objects(measurements)
    db.commit()

    # 2. Seed Realistic Medications with IST times
    today = date.today()
    med1 = Medication(
        user_id=user.id,
        name="Metformin",
        dosage="500mg",
        frequency="Twice daily",
        start_date=today - timedelta(days=30),
        end_date=today + timedelta(days=60),
    )
    med2 = Medication(
        user_id=user.id,
        name="Atorvastatin",
        dosage="20mg",
        frequency="Once daily",
        start_date=today - timedelta(days=30),
        end_date=today + timedelta(days=60),
    )
    med3 = Medication(
        user_id=user.id,
        name="Vitamin D3",
        dosage="1000IU",
        frequency="Once daily",
        start_date=today - timedelta(days=15),
        end_date=today + timedelta(days=45),
    )
    db.add_all([med1, med2, med3])
    db.commit()
    db.refresh(med1)
    db.refresh(med2)
    db.refresh(med3)

    # Add schedules: Metformin (08:00 AM, 08:00 PM IST), Atorvastatin (09:00 PM IST), Vitamin D3 (09:00 AM IST)
    scheds = [
        MedicationSchedule(medication_id=med1.id, scheduled_time="08:00:00"),
        MedicationSchedule(medication_id=med1.id, scheduled_time="20:00:00"),
        MedicationSchedule(medication_id=med2.id, scheduled_time="21:00:00"),
        MedicationSchedule(medication_id=med3.id, scheduled_time="09:00:00"),
    ]
    db.add_all(scheds)
    db.commit()

    # Add adherence records for past 7 days
    records = []
    for day_offset in range(7):
        rec_date = datetime.utcnow() - timedelta(days=day_offset)
        # Metformin Morning
        records.append(MedicationRecord(
            medication_id=med1.id,
            scheduled_time="08:00:00",
            status="Taken",
            taken_at=rec_date.replace(hour=8, minute=15)
        ))
        # Metformin Evening
        records.append(MedicationRecord(
            medication_id=med1.id,
            scheduled_time="20:00:00",
            status="Taken" if day_offset != 2 else "Missed",
            taken_at=rec_date.replace(hour=20, minute=5) if day_offset != 2 else None
        ))
        # Atorvastatin
        records.append(MedicationRecord(
            medication_id=med2.id,
            scheduled_time="21:00:00",
            status="Taken",
            taken_at=rec_date.replace(hour=21, minute=10)
        ))
        # Vitamin D3
        records.append(MedicationRecord(
            medication_id=med3.id,
            scheduled_time="09:00:00",
            status="Taken",
            taken_at=rec_date.replace(hour=9, minute=5)
        ))

    db.add_all(records)
    db.commit()
    db.close()
    
    print(f"Successfully seeded 14 days of health metrics & IST medications for {email}.")

if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "demo@example.com"
    seed_data(email)
