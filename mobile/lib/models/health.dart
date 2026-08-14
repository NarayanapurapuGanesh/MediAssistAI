class HealthMeasurement {
  final int id;
  final String type;
  final double value;
  final double? secondaryValue;
  final String unit;
  final String recordedAt;

  HealthMeasurement({
    required this.id,
    required this.type,
    required this.value,
    this.secondaryValue,
    required this.unit,
    required this.recordedAt,
  });

  factory HealthMeasurement.fromJson(Map<String, dynamic> json) {
    return HealthMeasurement(
      id: json['id'],
      type: json['type'],
      value: (json['value'] as num).toDouble(),
      secondaryValue: json['secondary_value'] != null ? (json['secondary_value'] as num).toDouble() : null,
      unit: json['unit'],
      recordedAt: json['recorded_at'],
    );
  }
}

class AIAlert {
  final int id;
  final String alertType;
  final String message;
  final String severity;

  AIAlert({
    required this.id,
    required this.alertType,
    required this.message,
    required this.severity,
  });

  factory AIAlert.fromJson(Map<String, dynamic> json) {
    return AIAlert(
      id: json['id'],
      alertType: json['alert_type'],
      message: json['message'],
      severity: json['severity'],
    );
  }
}
