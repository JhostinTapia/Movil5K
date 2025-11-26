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
    this.activa = true,
    this.enCurso = false,
    this.fechaInicio,
    this.fechaFin,
  });

  factory Competencia.fromJson(Map<String, dynamic> json) {
    return Competencia(
      id: json['id'],
      nombre: json['name'],
      fechaHora: DateTime.parse(json['datetime']),
      categoria: json['category'],
      activa: json['is_active'] ?? true,
      enCurso: json['is_running'] ?? false,
      fechaInicio: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      fechaFin: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nombre,
      'datetime': fechaHora.toIso8601String(),
      'category': categoria,
      'is_active': activa,
      'is_running': enCurso,
      'started_at': fechaInicio?.toIso8601String(),
      'finished_at': fechaFin?.toIso8601String(),
    };
  }

  String get categoriaDisplay {
    return categoria == 'estudiantes'
        ? 'Estudiantes por Equipos'
        : 'Interfacultades por Equipos';
  }

  // Verifica si la competencia ya comenzó
  bool get haComenzado {
    return DateTime.now().isAfter(fechaHora);
  }

  // Verifica si la competencia está en progreso
  bool get estaEnProgreso {
    return enCurso && haComenzado;
  }

  // Verifica si la competencia está por comenzar
  bool get estaPorComenzar {
    return !haComenzado && activa;
  }

  // Tiempo faltante para que comience
  Duration get tiempoRestante {
    if (haComenzado) return Duration.zero;
    return fechaHora.difference(DateTime.now());
  }

  // Estado de la competencia
  String get estadoActual {
    if (fechaFin != null) return 'FINALIZADA';
    if (estaEnProgreso) return 'EN CURSO';
    if (estaPorComenzar) return 'PROGRAMADA';
    return 'INACTIVA';
  }

  /// Crea una copia de la competencia con valores actualizados
  Competencia copyWith({
    int? id,
    String? nombre,
    DateTime? fechaHora,
    String? categoria,
    bool? activa,
    bool? enCurso,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    return Competencia(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fechaHora: fechaHora ?? this.fechaHora,
      categoria: categoria ?? this.categoria,
      activa: activa ?? this.activa,
      enCurso: enCurso ?? this.enCurso,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
    );
  }
}
