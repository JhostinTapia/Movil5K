class Equipo {
  final int id;
  final String nombre;
  final int dorsal;
  final String categoria;
  final String? categoriaDisplay;
  final int competenciaId;
  final String competenciaNombre;
  final String? juezUsername;

  Equipo({
    required this.id,
    required this.nombre,
    required this.dorsal,
    required this.categoria,
    this.categoriaDisplay,
    required this.competenciaId,
    required this.competenciaNombre,
    this.juezUsername,
  });

  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'],
      nombre: json['name'],
      dorsal: json['number'],
      categoria: json['category'] ?? 'estudiantes',
      categoriaDisplay: json['category_display'],
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
      'category': categoria,
      'category_display': categoriaDisplay,
      'competition_id': competenciaId,
      'competition_name': competenciaNombre,
      'judge_username': juezUsername,
    };
  }

  String get categoriaTexto {
    return categoriaDisplay ?? (categoria == 'estudiantes'
        ? 'Estudiantes por Equipos'
        : 'Interfacultades por Equipos');
  }
}
