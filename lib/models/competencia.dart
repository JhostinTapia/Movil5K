class Competencia {
  final int id;
  final String nombre;
  final DateTime fechaHora;
  final String categoria;
  final bool activa;
  final bool enCurso;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  Competencia({
    required this.id,
    required this.nombre,
    required this.fechaHora,
    required this.categoria,
    required this.activa,
    required this.enCurso,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Competencia.fromJson(Map<String, dynamic> json) {
    return Competencia(
      id: json['id'],
      nombre: json['nombre'],
      fechaHora: DateTime.parse(json['fecha_hora']),
      categoria: json['categoria'],
      activa: json['activa'],
      enCurso: json['en_curso'],
      fechaInicio: json['fecha_inicio'] != null
          ? DateTime.parse(json['fecha_inicio'])
          : null,
      fechaFin: json['fecha_fin'] != null
          ? DateTime.parse(json['fecha_fin'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'fecha_hora': fechaHora.toIso8601String(),
      'categoria': categoria,
      'activa': activa,
      'en_curso': enCurso,
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
    };
  }

  String get categoriaDisplay {
    return categoria == 'estudiantes'
        ? 'Estudiantes por Equipos'
        : 'Interfacultades por Equipos';
  }
}
