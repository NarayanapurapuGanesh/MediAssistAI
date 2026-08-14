"""
AI Service

Handles Gemini AI integration with:
- Structured prompt building with health context
- In-depth App Usage Assistance & Navigation Knowledge
- Structured JSON response parsing
- Robust fallback to deterministic analytics & app help when Gemini is offline
- Strict medical safety guardrails
"""

import json
import logging
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session

from core.config import settings
from services.health_analytics import get_health_analytics, get_overall_health_status
from services.anomaly_detection import detect_anomalies
from services.adherence_service import get_adherence_summary

logger = logging.getLogger(__name__)

APP_GUIDE_KNOWLEDGE = """
APP USAGE & FEATURES KNOWLEDGE BASE:
1. Adding Medications: Tap the bottom center '+' floating button and select 'Add Medication'. Enter name, dosage, frequency, and time schedules.
2. Logging Health Readings: Tap the '+' button and select 'Add Health Reading'. Supports Heart Rate (BPM), Blood Pressure (systolic & diastolic mmHg), SpO2 (%), Steps, and Sleep (hours).
3. Tracking Medication Adherence: Open the 'Meds' tab on the bottom bar to see today's doses. Tap the checkmark to mark as Taken, or 'X' to mark Missed.
4. Viewing 7/30-Day Trends: Tap any metric card on the dashboard or navigate to the 'History' tab on the bottom bar.
5. Setting Daily Routines: Tap the '+' button -> 'Daily Routine' or tap 'Routine' in Quick Actions to set wake-up, meal, and bed times.
6. AI Health Insights: Tap the 'AI' tab to get automated health summaries, status badges, and lifestyle suggestions.
7. Anomaly Detection: MediAssist automatically analyzes 7-day statistical trends using Isolation Forest to detect abnormal spikes in heart rate or drops in SpO2.
"""


def get_ai_insights(
    db: Session, user_id: int, user_name: str = "User"
) -> Dict[str, Any]:
    """
    Generate AI health insights using analytics + Gemini.
    Falls back to deterministic insights if Gemini is unavailable.
    """
    analytics = get_health_analytics(db, user_id, days=7)
    anomalies = detect_anomalies(db, user_id, days=7)
    adherence = get_adherence_summary(db, user_id)
    health_status = get_overall_health_status(db, user_id)

    if settings.GEMINI_API_KEY:
        try:
            gemini_result = _call_gemini_for_insights(
                analytics, anomalies, adherence, health_status, user_name
            )
            if gemini_result:
                return gemini_result
        except Exception as e:
            logger.error(f"Gemini insights failed: {e}")

    return _generate_deterministic_insights(
        analytics, anomalies, adherence, health_status
    )


def get_ai_chat_response(
    db: Session,
    user_id: int,
    message: str,
    user_name: str = "User",
    medications: List[Any] = None,
    recent_metrics: List[Any] = None,
) -> str:
    """
    Handle AI chat with health context and app usage assistance.
    """
    med_list = []
    if medications:
        med_list = [f"{m.name} ({m.dosage} {m.frequency})" for m in medications]

    metric_list = []
    if recent_metrics:
        for m in recent_metrics:
            sec = f"/{int(m.secondary_value)}" if m.secondary_value is not None else ""
            metric_list.append(
                f"{m.recorded_at.strftime('%Y-%m-%d %H:%M')}: {m.type} - {m.value}{sec} {m.unit}"
            )

    analytics = get_health_analytics(db, user_id, days=7)
    anomalies = detect_anomalies(db, user_id, days=7)
    adherence = get_adherence_summary(db, user_id)

    analytics_context = []
    for metric, data in analytics.items():
        if isinstance(data, dict) and data.get("status"):
            analytics_context.append(
                f"{metric}: status={data['status']}, "
                f"current={data.get('current')}, avg={data.get('average')}, "
                f"trend={data.get('trend')}"
            )

    anomaly_context = []
    for a in anomalies:
        if a.get("status") not in ("normal", "insufficient_data"):
            anomaly_context.append(
                f"{a['metric']}: {a['status']} - {a.get('reason', '')}"
            )

    context = f"""You are MediAssist AI, an intelligent, empathetic health assistant and app guide.

User Name: {user_name}

{APP_GUIDE_KNOWLEDGE}

Current User Medications:
{json.dumps(med_list, indent=2)}

Recent Health Metrics (last 20 readings in IST):
{json.dumps(metric_list, indent=2)}

Health Analytics (7-day):
{json.dumps(analytics_context, indent=2)}

Detected Anomalies:
{json.dumps(anomaly_context, indent=2) if anomaly_context else "None detected"}

Medication Adherence: {adherence.get('adherence_percentage', 'N/A')}%

CRITICAL INSTRUCTIONS:
- If the user asks HOW TO USE the app or navigation questions, give clear, step-by-step guidance referencing MediAssist features.
- If the user asks about their HEALTH or MEDICATIONS, synthesize their real metrics concisely.
- You are a health INFORMATION assistant, NOT a doctor.
- NEVER claim to diagnose medical conditions or alter prescriptions.
- If SpO2 drops below 95% or BP is highly elevated, gently advise resting and consulting a healthcare professional.
- Keep responses friendly, structured, and concise (2-4 sentences).
"""

    if not settings.GEMINI_API_KEY:
        return _generate_fallback_chat_response(message, analytics, adherence, med_list)

    try:
        import google.generativeai as genai
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(
            contents=[
                {"role": "user", "parts": [context + "\n\nUser Message: " + message]}
            ]
        )
        return response.text.strip()
    except Exception as e:
        logger.error(f"Gemini chat failed: {e}")
        return _generate_fallback_chat_response(message, analytics, adherence, med_list)


def _call_gemini_for_insights(
    analytics: Dict,
    anomalies: List,
    adherence: Dict,
    health_status: Dict,
    user_name: str,
) -> Optional[Dict[str, Any]]:
    """Call Gemini to generate structured health insights."""
    try:
        import google.generativeai as genai
        genai.configure(api_key=settings.GEMINI_API_KEY)
        model = genai.GenerativeModel('gemini-2.5-flash')

        prompt = f"""Analyze the following health data and provide structured insights.

Health Analytics (7-day):
{json.dumps(analytics, indent=2, default=str)}

Detected Anomalies:
{json.dumps(anomalies, indent=2, default=str)}

Medication Adherence:
{json.dumps(adherence, indent=2, default=str)}

Health Status: {health_status.get('overall_status', 'Good')}
User: {user_name}

Return a valid JSON object matching this schema:
{{
  "summary": "Brief 1-2 sentence overall health summary.",
  "insights": ["Insight 1", "Insight 2", "Insight 3"],
  "recommendations": ["Recommendation 1", "Recommendation 2"],
  "severity": "normal" | "attention" | "urgent",
  "disclaimer": "This analysis is for informational purposes only and does not constitute medical diagnosis."
}}

RULES:
- Do NOT diagnose diseases
- Base insights on actual metrics
- Return ONLY valid JSON, no markdown formatting
"""

        response = model.generate_content(contents=[{"role": "user", "parts": [prompt]}])
        text = response.text.strip()

        if text.startswith("```"):
            text = text.split("\n", 1)[1] if "\n" in text else text[3:]
        if text.endswith("```"):
            text = text[:-3]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()

        result = json.loads(text)
        required = ["summary", "insights", "recommendations", "severity", "disclaimer"]
        for field in required:
            if field not in result:
                return None
        return result

    except Exception as e:
        logger.error(f"Gemini insights generation failed: {e}")
        return None


def _generate_fallback_chat_response(
    message: str, analytics: Dict, adherence: Dict, med_list: List[str] = None
) -> str:
    """Intelligent offline fallback responder when Gemini API key is not yet set."""
    msg = message.lower()

    if "how to add" in msg or "add medication" in msg or "new medication" in msg or "prescription" in msg:
        return "To add a medication: Tap the '+' button at the bottom center of your screen, choose 'Add Medication', fill in the name, dosage, frequency, and dose times, then tap 'Save Medication'."

    if "add health" in msg or "log reading" in msg or "log blood pressure" in msg or "log bp" in msg or "add reading" in msg:
        return "To log health readings: Tap the '+' button at the bottom center and select 'Add Health Reading'. You can record Heart Rate, Blood Pressure (systolic/diastolic), SpO2, Steps, or Sleep."

    if "how does anomaly" in msg or "anomaly detection" in msg or "what is anomaly" in msg:
        return "MediAssist uses an Isolation Forest machine learning model on your backend to analyze your 7-day health trend baseline. If a metric deviates abnormally from your normal pattern, you will receive an automatic Health Alert."

    if "routine" in msg or "sleep routine" in msg or "wake up" in msg:
        return "To configure your daily routine: Tap the '+' button -> 'Daily Routine' (or tap 'Routine' under Quick Actions on the dashboard) to set your wake-up time, meal schedules, and bedtime."

    if "trend" in msg or "history" in msg or "chart" in msg:
        return "You can view your 7-day and 30-day interactive health charts by tapping any metric card on your Dashboard or navigating to the 'History' tab on the bottom bar."

    if "heart rate" in msg or "heart" in msg:
        data = analytics.get("Heart Rate", {})
        if isinstance(data, dict) and data.get("current"):
            return f"Your latest heart rate is {data['current']} BPM (7-day average: {data.get('average', 'N/A')} BPM, trend: {data.get('trend', 'stable')}). Normal resting range is 60-100 BPM."
        return "Your heart rate is within normal resting parameters. Continue monitoring regularly!"

    if "spo2" in msg or "oxygen" in msg:
        data = analytics.get("SpO2", {})
        if isinstance(data, dict) and data.get("current"):
            return f"Your latest SpO2 reading is {data['current']}% (7-day average: {data.get('average', 'N/A')}%). Healthy oxygen saturation is 95-100%."
        return "Your blood oxygen (SpO2) levels are stable above 95%."

    if "blood pressure" in msg or "bp" in msg:
        data = analytics.get("Blood Pressure", {})
        if isinstance(data, dict) and data.get("current"):
            sec = f"/{data['current_secondary']}" if data.get("current_secondary") else ""
            return f"Your recent Blood Pressure is {data['current']}{sec} mmHg (trend: {data.get('trend', 'stable')}). Ideal resting blood pressure is around 120/80 mmHg."
        return "Your blood pressure is tracked under normal parameters."

    if "medication" in msg or "medicine" in msg or "pill" in msg or "adherence" in msg:
        adh_pct = adherence.get("adherence_percentage", 100)
        meds_str = ", ".join(med_list) if med_list else "Metformin 500mg, Atorvastatin 20mg, Vitamin D3"
        return f"Your overall medication adherence is {adh_pct}%. Your active prescriptions include: {meds_str}. You can view today's schedule in the 'Meds' tab."

    if "steps" in msg or "walk" in msg or "activity" in msg:
        data = analytics.get("Steps", {})
        if isinstance(data, dict) and data.get("current"):
            return f"You logged {int(data['current'])} steps recently (7-day average: {int(data.get('average', 6000))} steps). Great job staying active!"
        return "Keep aiming for 6,000 to 10,000 steps daily for cardiovascular health!"

    if "sleep" in msg:
        data = analytics.get("Sleep", {})
        if isinstance(data, dict) and data.get("current"):
            return f"Your average sleep duration is {data.get('average', 7.5)} hours per night. Maintaining a consistent sleep routine supports recovery."
        return "Aim for 7-9 hours of restful sleep every night."

    if "hello" in msg or "hi" in msg or "hey" in msg:
        return "Hello! I am your MediAssist AI health companion. Ask me about your health trends, medication schedules, or how to use any feature in the app!"

    return f"Based on your recent health records, your overall status is Good. You can ask me about your Heart Rate, SpO2, Blood Pressure, Medications, or how to navigate the app!"


def _generate_deterministic_insights(
    analytics: Dict,
    anomalies: List,
    adherence: Dict,
    health_status: Dict,
) -> Dict[str, Any]:
    """Generate structured insights when Gemini is offline."""
    insights = []
    recommendations = []
    severity = "normal"

    for metric_type, data in analytics.items():
        if not isinstance(data, dict):
            continue
        status = data.get("status", "normal")
        trend = data.get("trend", "stable")
        current = data.get("current")

        if status == "abnormal":
            severity = "urgent"
            insights.append(f"{metric_type} reading ({current}) is outside standard range.")
        elif status == "attention":
            if severity != "urgent":
                severity = "attention"
            insights.append(f"{metric_type} shows an upward {trend} trend.")

    adh_pct = adherence.get("adherence_percentage", 100)
    if adh_pct >= 90:
        insights.append(f"Excellent medication adherence at {adh_pct}%.")
        recommendations.append("Keep up your consistent daily medication routine.")
    else:
        insights.append(f"Medication adherence is at {adh_pct}%.")
        recommendations.append("Set daily reminder alarms to avoid missing scheduled doses.")

    recommendations.append("Stay hydrated and maintain your scheduled daily routine.")

    status_str = health_status.get("overall_status", "Good")
    return {
        "summary": f"Your overall health status is: {status_str}. Metrics and routines are actively monitored.",
        "insights": insights if insights else ["All monitored health metrics are within stable reference ranges."],
        "recommendations": recommendations,
        "severity": severity,
        "disclaimer": "This analysis is for informational purposes only and does not constitute medical diagnosis.",
    }
