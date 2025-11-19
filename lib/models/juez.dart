class Juez {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? telefono;

  Juez({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.telefono,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get nombre => fullName;

  factory Juez.fromJson(Map<String, dynamic> json) {
    return Juez(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'email': email,
      'telefono': telefono,
    };
  }
}
