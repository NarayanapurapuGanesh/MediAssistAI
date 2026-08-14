"""
Anomaly Detection Service

Combines multiple detection methods:
1. Configurable medical-reference thresholds
2. User-specific baseline deviation
3. Trend analysis (rolling averages)
4. Repeated abnormal readings detection

Does NOT diagnose diseases. Produces status levels:
- NORMAL
- ATTENTION
- ABNORMAL
- INSUFFICIENT_DATA
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from models.health import HealthMeasurement
from services.health_analytics import (
    REFERENCE_THRESHOLDS,
    _calculate_trend,
)


def detect_anomalies(
    db: Session, user_id: int, days: int = 7
) -> List[Dict[str, Any]]:
    """
    Run anomaly detection across all metric types for a user.
    Returns a list of anomaly reports.
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

    anomalies = []
    for metric_type, readings in grouped.items():
        report = _analyze_metric_anomalies(db, user_id, metric_type, readings)
        if report:
            anomalies.append(report)

    return anomalies


def _analyze_metric_anomalies(
    db: Session,
    user_id: int,
    metric_type: str,
    readings: List[HealthMeasurement],
) -> Optional[Dict[str, Any]]:
    """
    Analyze a single metric for anomalies using multiple methods.
    """
    if len(readings) < 5:
        return {
            "metric": metric_type,
            "status": "insufficient_data",
            "reason": "Not enough data points for reliable analysis.",
            "data_points": len(readings),
        }

    values = [r.value for r in readings]
    latest_value = values[-1]

    # 1. Threshold-based detection
    threshold_status = _check_thresholds(metric_type, latest_value)

    # 2. Baseline deviation detection
    baseline_status = _check_baseline_deviation(values)

    # 3. Trend analysis
    trend = _calculate_trend(values)

    # 4. Repeated abnormal readings
    repeated_status = _check_repeated_abnormals(metric_type, values[-5:])

    # Combine results — worst status wins
    combined_status = _combine_statuses(
        threshold_status, baseline_status, repeated_status
    )

    # Only return if something noteworthy
    if combined_status == "normal":
        return {
            "metric": metric_type,
            "status": "normal",
            "baseline": round(sum(values[:-3]) / max(len(values) - 3, 1), 1),
            "current": round(latest_value, 1),
            "trend": trend,
            "reason": "All readings are within expected range.",
            "data_points": len(values),
        }

    # Build reason
    reasons = []
    if threshold_status != "normal":
        reasons.append("Recent reading is outside typical reference range.")
    if baseline_status != "normal":
        baseline_avg = sum(values[:-3]) / max(len(values) - 3, 1)
        deviation = abs(latest_value - baseline_avg) / baseline_avg * 100 if baseline_avg else 0
        reasons.append(
            f"Value deviates {deviation:.0f}% from personal baseline."
        )
    if repeated_status != "normal":
        reasons.append("Multiple recent readings show unusual values.")
    if trend in ("increasing", "decreasing"):
        reasons.append(f"Values show a {trend} trend.")

    return {
        "metric": metric_type,
        "status": combined_status,
        "baseline": round(sum(values[:-3]) / max(len(values) - 3, 1), 1),
        "current": round(latest_value, 1),
        "trend": trend,
        "reason": " ".join(reasons),
        "data_points": len(values),
    }


def _check_thresholds(metric_type: str, value: float) -> str:
    """Check value against configurable reference thresholds."""
    thresholds = REFERENCE_THRESHOLDS.get(metric_type)
    if not thresholds:
        return "normal"

    normal_low, normal_high = thresholds["normal_range"]
    attention_low, attention_high = thresholds["attention_range"]

    if normal_low <= value <= normal_high:
        return "normal"
    elif attention_low <= value <= attention_high:
        return "attention"
    else:
        return "abnormal"


def _check_baseline_deviation(values: List[float]) -> str:
    """
    Compare latest values against the user's personal baseline.
    Baseline = average of earlier readings (excluding last 3).
    """
    if len(values) < 6:
        return "normal"

    baseline_values = values[:-3]
    baseline_avg = sum(baseline_values) / len(baseline_values)

    if baseline_avg == 0:
        return "normal"

    recent_avg = sum(values[-3:]) / 3
    deviation_pct = abs(recent_avg - baseline_avg) / baseline_avg * 100

    if deviation_pct > 25:
        return "abnormal"
    elif deviation_pct > 15:
        return "attention"
    else:
        return "normal"


def _check_repeated_abnormals(metric_type: str, recent_values: List[float]) -> str:
    """Check if multiple recent values are outside normal range."""
    thresholds = REFERENCE_THRESHOLDS.get(metric_type)
    if not thresholds:
        return "normal"

    normal_low, normal_high = thresholds["normal_range"]
    abnormal_count = sum(
        1 for v in recent_values
        if v < normal_low or v > normal_high
    )

    if abnormal_count >= 4:
        return "abnormal"
    elif abnormal_count >= 2:
        return "attention"
    else:
        return "normal"


def _combine_statuses(*statuses: str) -> str:
    """Return the most severe status."""
    if "abnormal" in statuses:
        return "abnormal"
    if "attention" in statuses:
        return "attention"
    return "normal"
