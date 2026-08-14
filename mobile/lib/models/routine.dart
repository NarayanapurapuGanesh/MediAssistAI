class Routine {
  final int id;
  final int userId;
  final String wakeTime;
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;
  final String sleepTime;

  Routine({
    required this.id,
    required this.userId,
    required this.wakeTime,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.sleepTime,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'],
      userId: json['user_id'],
      wakeTime: json['wake_time'] ?? '07:00',
      breakfastTime: json['breakfast_time'] ?? '08:00',
      lunchTime: json['lunch_time'] ?? '13:00',
      dinnerTime: json['dinner_time'] ?? '20:00',
      sleepTime: json['sleep_time'] ?? '23:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wake_time': wakeTime,
      'breakfast_time': breakfastTime,
      'lunch_time': lunchTime,
      'dinner_time': dinnerTime,
      'sleep_time': sleepTime,
    };
  }
}
