class Medication {
  final int id;
  final String name;
  final String dosage;
  final String frequency;
  final String startDate;
  final String endDate;
  final List<String> schedules;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.schedules,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      schedules: (json['schedules'] as List)
          .map((s) => s['scheduled_time'].toString())
          .toList(),
    );
  }
}
