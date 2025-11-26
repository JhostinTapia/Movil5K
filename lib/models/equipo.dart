class Equipo {
  final int id;
  final String nombre;
  final int dorsal;
  final int competenciaId;
  final String competenciaNombre;
  final String? juezUsername;

  Equipo({
    required this.id,
    required this.nombre,
    required this.dorsal,
    required this.competenciaId,
    required this.competenciaNombre,
    this.juezUsername,
  });

  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'],
      nombre: json['name'],
      dorsal: json['number'],
      competenciaId: json['competition_id'],
      competenciaNombre: json['competition_name'],
      juezUsername: json['judge_username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nombre,
      'number': dorsal,
      'competition_id': competenciaId,
      'competition_name': competenciaNombre,
      'judge_username': juezUsername,
    };
  }
}
