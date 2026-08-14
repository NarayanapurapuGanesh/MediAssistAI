"""
Health Analytics Service

Provides deterministic health data analysis including:
- Daily averages, min, max
- Baseline calculation (rolling 7-day average)
- Trend direction analysis
- Change percentage
- Data completeness metrics
- Health status determination

This module does NOT diagnose medical conditions.
It uses configurable thresholds for informational status only.
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import func

from models.health import HealthMeasurement


# Configurable reference thresholds (informational only, not diagnostic)
REFERENCE_THRESHOLDS = {
    "Heart Rate": {
        "unit": "BPM",
        "normal_range": (60, 100),
        "attention_range": (50, 110),
        "description": "Resting heart rate"
    },
    "SpO2": {
        "unit": "%",
        "normal_range": (95, 100),
        "attention_range": (90, 100),
        "description": "Blood oxygen saturation"
    },
    "Blood Pressure": {
        "unit": "mmHg",
        "normal_range": (90, 140),  # Systolic
        "attention_range": (80, 160),
        "secondary_normal": (60, 90),  # Diastolic
        "secondary_attention": (50, 100),
        "description": "Systolic/Diastolic blood pressure"
    },
    "Steps": {
        "unit": "steps",
        "normal_range": (3000, 20000),
        "attention_range": (500, 30000),
        "description": "Daily step count"
    },
    "Sleep": {
        "unit": "hours",
        "normal_range": (6, 9),
        "attention_range": (4, 11),
        "description": "Sleep duration"
    }
}


def get_health_analytics(
    db: Session, user_id: int, days: int = 7
) -> Dict[str, Any]:
    """
    Calculate comprehensive health analytics for a user.
    Returns analytics per metric type.
    """
    cutoff = datetime.utcnow() - timedelta(days=days)

    measurements = db.query(HealthMeasurement).filter(
        HealthMeasurement.user_id == user_id,
        HealthMeasurement.recorded_at >= cutoff
    ).order_by(HealthMeasurement.recorded_at.asc()).all()

    # Group by type
    grouped: Dict[str, List[HealthMeasurement]] = {}
    for m in measurements:
        if m.type not in grouped:
            grouped[m.type] = []
        grouped[m.type].append(m)

    analytics = {}
    for metric_type, readings in grouped.items():
        analytics[metric_type] = _analyze_metric(metric_type, readings, days)

    return analytics


def _analyze_metric(
    metric_type: str, readings: List[HealthMeasurement], period_days: int
) -> Dict[str, Any]:
    """Analyze a single metric type."""
    if not readings:
        return {
            "status": "insufficient_data",
            "message": "No data available for this period.",
            "data_points": 0
        }

    values = [r.value for r in readings]
    latest = readings[-1]

    # Basic statistics
    avg_val = round(sum(values) / len(values), 1)
    min_val = round(min(values), 1)
    max_val = round(max(values), 1)

    # Trend direction
    trend = _calculate_trend(values)

    # Baseline (first half average vs second half)
    mid = len(values) // 2
    if mid > 0:
        first_half_avg = sum(values[:mid]) / mid
        second_half_avg = sum(values[mid:]) / (len(values) - mid)
        change_pct = round(
            ((second_half_avg - first_half_avg) / first_half_avg) * 100, 1
        ) if first_half_avg != 0 else 0.0
    else:
        first_half_avg = avg_val
        second_half_avg = avg_val
        change_pct = 0.0

    # Status based on thresholds
    status = _determine_status(metric_type, latest.value, avg_val)

    # Daily breakdown
    daily_data = _calculate_daily_averages(readings)

    result = {
        "metric": metric_type,
        "status": status,
        "current": round(latest.value, 1),
        "average": avg_val,
        "min": min_val,
        "max": max_val,
        "trend": trend,
        "change_percent": change_pct,
        "baseline": round(first_half_avg, 1),
        "data_points": len(values),
        "period_days": period_days,
        "unit": latest.unit,
        "last_updated": latest.recorded_at.isoformat(),
        "daily_data": daily_data,
    }

    # Add secondary value info for BP
    if metric_type == "Blood Pressure":
        secondary_values = [
            r.secondary_value for r in readings
            if r.secondary_value is not None
        ]
        if secondary_values:
            result["secondary_current"] = round(latest.secondary_value or 0, 1)
            result["secondary_average"] = round(
                sum(secondary_values) / len(secondary_values), 1
            )

    return result


def _calculate_trend(values: List[float]) -> str:
    """Calculate trend direction from a list of values."""
    if len(values) < 3:
        return "stable"

    # Use simple linear regression direction
    n = len(values)
    x_mean = (n - 1) / 2
    y_mean = sum(values) / n

    numerator = sum((i - x_mean) * (v - y_mean) for i, v in enumerate(values))
    denominator = sum((i - x_mean) ** 2 for i in range(n))

    if denominator == 0:
        return "stable"

    slope = numerator / denominator
    # Normalize slope relative to mean
    relative_slope = (slope / y_mean * 100) if y_mean != 0 else 0

    if relative_slope > 1.5:
        return "increasing"
    elif relative_slope < -1.5:
        return "decreasing"
    else:
        return "stable"


def _determine_status(
    metric_type: str, current_value: float, avg_value: float
) -> str:
    """
    Determine health status for a metric.
    Uses configurable thresholds — informational only, NOT diagnostic.
    """
    thresholds = REFERENCE_THRESHOLDS.get(metric_type)
    if not thresholds:
        return "normal"

    normal_low, normal_high = thresholds["normal_range"]
    attention_low, attention_high = thresholds["attention_range"]

    if normal_low <= current_value <= normal_high:
        return "normal"
    elif attention_low <= current_value <= attention_high:
        return "attention"
    else:
        return "abnormal"


def _calculate_daily_averages(
    readings: List[HealthMeasurement],
) -> List[Dict[str, Any]]:
    """Group readings by date and calculate daily averages."""
    daily: Dict[str, List[float]] = {}
    for r in readings:
        date_str = r.recorded_at.strftime("%Y-%m-%d")
        if date_str not in daily:
            daily[date_str] = []
        daily[date_str].append(r.value)

    result = []
    for date_str in sorted(daily.keys()):
        values = daily[date_str]
        result.append({
            "date": date_str,
            "average": round(sum(values) / len(values), 1),
            "min": round(min(values), 1),
            "max": round(max(values), 1),
            "readings": len(values)
        })
    return result


def get_overall_health_status(
    db: Session, user_id: int
) -> Dict[str, Any]:
    """
    Calculate an overall health status summary.
    Returns status as Good/Attention/Concern based on individual metrics.
    """
    analytics = get_health_analytics(db, user_id, days=7)

    statuses = []
    attention_metrics = []
    abnormal_metrics = []

    for metric_type, data in analytics.items():
        status = data.get("status", "normal")
        statuses.append(status)
        if status == "attention":
            attention_metrics.append(metric_type)
        elif status == "abnormal":
            abnormal_metrics.append(metric_type)

    if abnormal_metrics:
        overall = "Needs Attention"
    elif attention_metrics:
        overall = "Fair"
    elif statuses:
        overall = "Good"
    else:
        overall = "No Data"

    return {
        "overall_status": overall,
        "attention_metrics": attention_metrics,
        "abnormal_metrics": abnormal_metrics,
        "metrics_analyzed": len(statuses),
    }
