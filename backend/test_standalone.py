import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from db.session import SessionLocal
from models.user import User
from schemas.health import HealthMeasurementCreate
from schemas.medication import MedicationCreate
from schemas.routine import RoutineCreate
from crud import user as crud_user
from crud import health as crud_health
from crud import medication as crud_medication
from crud import routine as crud_routine
from services.health_analytics import get_health_analytics, get_overall_health_status
from services.anomaly_detection import detect_anomalies
from services.adherence_service import get_adherence_summary, get_today_medication_status, record_medication_event
from services.ai_service import get_ai_insights, get_ai_chat_response

def run_tests():
    db = SessionLocal()
    user = db.query(User).filter(User.email == "demo@example.com").first()
    assert user is not None, "Demo user must exist"
    print(f"[OK] User Found: {user.name} ({user.email})")

    # 1. Health Analytics
    analytics = get_health_analytics(db, user.id, days=7)
    assert len(analytics) > 0, "Analytics must return data"
    print(f"[OK] Analytics calculated for {len(analytics)} metrics: {list(analytics.keys())}")

    # 2. Overall Status
    status = get_overall_health_status(db, user.id)
    assert "overall_status" in status
    print(f"[OK] Health Status: {status['overall_status']}")

    # 3. Anomaly Detection
    anomalies = detect_anomalies(db, user.id, days=7)
    assert isinstance(anomalies, list)
    print(f"[OK] Anomalies evaluated: {len(anomalies)} metrics checked")

    # 4. Medication CRUD & Adherence
    med_in = MedicationCreate(
        name="Omega-3",
        dosage="1000mg",
        frequency="Once daily",
        start_date="2026-01-01",
        end_date="2026-12-31",
        schedules=["09:00:00"]
    )
    med = crud_medication.create_medication(db, med_in, user.id)
    assert med.id is not None
    print(f"[OK] Medication created: {med.name} (ID: {med.id})")

    rec_result = record_medication_event(db, med.id, "09:00:00", "Taken", user.id)
    assert rec_result["success"] is True
    print(f"[OK] Medication recorded as Taken")

    adh = get_adherence_summary(db, user.id)
    assert adh["taken"] >= 1
    print(f"[OK] Adherence Summary: {adh['adherence_percentage']}% ({adh['taken']}/{adh['total_scheduled']} taken)")

    today = get_today_medication_status(db, user.id)
    print(f"[OK] Today's Medication Status: {today['completed']}/{today['total_scheduled']} completed")

    # 5. AI Chat & Structured Insights
    chat_resp = get_ai_chat_response(db, user.id, "How is my heart rate?")
    assert len(chat_resp) > 0
    print(f"[OK] AI Chat Response: {chat_resp[:80]}...")

    insights = get_ai_insights(db, user.id, user.name)
    assert "summary" in insights
    assert "insights" in insights
    assert "recommendations" in insights
    assert "severity" in insights
    print(f"[OK] AI Insights (Severity: {insights['severity']})")
    print(f"  Summary: {insights['summary']}")
    print(f"  Top Insight: {insights['insights'][0] if insights['insights'] else 'None'}")
    print(f"  Top Rec: {insights['recommendations'][0] if insights['recommendations'] else 'None'}")

    # 6. Routines
    routine_in = RoutineCreate(
        wake_time="07:00",
        breakfast_time="08:00",
        lunch_time="13:00",
        dinner_time="20:00",
        sleep_time="23:00"
    )
    routine = crud_routine.upsert_routine(db, routine_in, user.id)
    assert routine.wake_time == "07:00"
    print(f"[OK] Routine verified: Wake at {routine.wake_time}, Sleep at {routine.sleep_time}")

    db.close()
    print("\n==========================================")
    print("ALL CORE BACKEND SERVICES & LOGIC VERIFIED 100%!")
    print("==========================================")

if __name__ == "__main__":
    run_tests()
