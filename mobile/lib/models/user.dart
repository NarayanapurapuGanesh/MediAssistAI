class User {
  final int id;
  final String email;
  final String? name;
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;

  User({
    required this.id,
    required this.email,
    this.name,
    this.age,
    this.gender,
    this.height,
    this.weight,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      height: json['height'] != null ? (json['height'] as num).toDouble() : null,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    );
  }
}
