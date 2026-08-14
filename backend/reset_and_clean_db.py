import os
import sys
from datetime import datetime, timedelta, date, timezone
import random

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from db.session import SessionLocal
from models.health import HealthMeasurement
from models.ai import AIAlert
from models.medication import Medication, MedicationSchedule, MedicationRecord
from models.routine import Routine
from models.user import User
from passlib.context import CryptContext

def clean_and_seed_pristine_database():
    db = SessionLocal()
    
    print("1. Cleaning up all old data from database...")
    db.query(AIAlert).delete()
    db.query(Routine).delete()
    db.query(MedicationRecord).delete()
    db.query(MedicationSchedule).delete()
    db.query(Medication).delete()
    db.query(HealthMeasurement).delete()
    
    # Delete all non-demo users
    db.query(User).filter(User.email != "demo@example.com").delete()
    
    # Ensure demo user exists with clean password
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    demo_user = db.query(User).filter(User.email == "demo@example.com").first()
    
    if not demo_user:
        demo_user = User(
            name="Demo User",
            email="demo@example.com",
            password_hash=pwd_context.hash("password123"),
            age=35,
            gender="Male",
            height=175.0,
            weight=70.0
        )
        db.add(demo_user)
        db.commit()
        db.refresh(demo_user)
        print("Created clean Demo User (demo@example.com / password123)")
    else:
        demo_user.password_hash = pwd_context.hash("password123")
        demo_user.name = "Demo User"
        demo_user.age = 35
        demo_user.gender = "Male"
        demo_user.height = 175.0
        demo_user.weight = 70.0
        db.commit()
        print("Reset Demo User credentials (demo@example.com / password123)")

    # 2. Seed 14 days of realistic health measurements (IST times)
    random.seed(42)
    base_date = datetime.now(timezone.utc) - timedelta(days=14)
    measurements = []
    
    # Heart rate
    for day in range(15):
        d = base_date + timedelta(days=day)
        base_hr = 72 if day < 11 else 82
        for reading in range(3):
            measurements.append(HealthMeasurement(
                user_id=demo_user.id,
                type="Heart Rate",
                value=round(base_hr + random.uniform(-4, 4), 1),
                unit="BPM",
                source="Smart Wearable",
                recorded_at=d + timedelta(hours=8 + (reading * 5))
            ))

    # SpO2
    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=demo_user.id,
            type="SpO2",
            value=round(98 + random.uniform(-1, 1), 1),
            unit="%",
            source="Smart Wearable",
            recorded_at=d + timedelta(hours=9)
        ))

    # Blood Pressure
    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=demo_user.id,
            type="Blood Pressure",
            value=round(120 + random.uniform(-4, 4), 0),
            secondary_value=round(80 + random.uniform(-3, 3), 0),
            unit="mmHg",
            source="Smart Wearable",
            recorded_at=d + timedelta(hours=10)
        ))

    # Steps
    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=demo_user.id,
            type="Steps",
            value=round(6800 + random.uniform(-1200, 2500), 0),
            unit="steps",
            source="Smart Wearable",
            recorded_at=d + timedelta(hours=20)
        ))

    # Sleep
    for day in range(15):
        d = base_date + timedelta(days=day)
        measurements.append(HealthMeasurement(
            user_id=demo_user.id,
            type="Sleep",
            value=round(7.5 + random.uniform(-0.8, 0.8), 1),
            unit="hours",
            source="Smart Wearable",
            recorded_at=d + timedelta(hours=7)
        ))

    db.bulk_save_objects(measurements)
    db.commit()

    # 3. Seed Routine
    routine = Routine(
        user_id=demo_user.id,
        wake_time="07:00",
        breakfast_time="08:30",
        lunch_time="13:00",
        dinner_time="20:00",
        sleep_time="23:00",
    )
    db.add(routine)
    db.commit()

    # 4. Seed Medications with IST schedules
    today = date.today()
    med1 = Medication(
        user_id=demo_user.id,
        name="Metformin",
        dosage="500mg",
        frequency="Twice daily",
        start_date=today - timedelta(days=30),
        end_date=today + timedelta(days=60),
    )
    med2 = Medication(
        user_id=demo_user.id,
        name="Atorvastatin",
        dosage="20mg",
        frequency="Once daily",
        start_date=today - timedelta(days=30),
        end_date=today + timedelta(days=60),
    )
    med3 = Medication(
        user_id=demo_user.id,
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

    scheds = [
        MedicationSchedule(medication_id=med1.id, scheduled_time="08:00:00"),
        MedicationSchedule(medication_id=med1.id, scheduled_time="20:00:00"),
        MedicationSchedule(medication_id=med2.id, scheduled_time="21:00:00"),
        MedicationSchedule(medication_id=med3.id, scheduled_time="09:00:00"),
    ]
    db.add_all(scheds)
    db.commit()

    # 7-day adherence history
    records = []
    for day_offset in range(7):
        rec_date = datetime.now(timezone.utc) - timedelta(days=day_offset)
        records.append(MedicationRecord(
            medication_id=med1.id, scheduled_time="08:00:00", status="Taken", taken_at=rec_date.replace(hour=8, minute=15)
        ))
        records.append(MedicationRecord(
            medication_id=med1.id, scheduled_time="20:00:00", status="Taken" if day_offset != 2 else "Missed", taken_at=rec_date.replace(hour=20, minute=5) if day_offset != 2 else None
        ))
        records.append(MedicationRecord(
            medication_id=med2.id, scheduled_time="21:00:00", status="Taken", taken_at=rec_date.replace(hour=21, minute=10)
        ))
        records.append(MedicationRecord(
            medication_id=med3.id, scheduled_time="09:00:00", status="Taken", taken_at=rec_date.replace(hour=9, minute=5)
        ))

    db.add_all(records)
    db.commit()

    # 5. Add a friendly welcome AI alert
    alert = AIAlert(
        user_id=demo_user.id,
        alert_type="Health Status",
        message="All baseline health metrics are synced and within normal ranges.",
        severity="info"
    )
    db.add(alert)
    db.commit()
    db.close()
    
    print("==================================================")
    print("PRISTINE DATABASE PURGE & RE-SEED COMPLETED!")
    print("Only user: demo@example.com")
    print("Password:  password123")
    print("==================================================")

if __name__ == "__main__":
    clean_and_seed_pristine_database()
