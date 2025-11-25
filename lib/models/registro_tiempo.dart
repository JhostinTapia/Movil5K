import 'package:uuid/uuid.dart';

/// Modelo de Registro de Tiempo según el backend actualizado
class RegistroTiempo {
  final String idRegistro; // UUID
  final int equipoId;
  final int tiempo; // Milisegundos totales
  final DateTime timestamp;

  // Campos desglosados
  final int horas;
  final int minutos;
  final int segundos;
  final int milisegundos;

  // Estado de sincronización
  bool sincronizado;

  // Indica si es un registro de penalización
  final bool penalizado;

  RegistroTiempo({
    String? idRegistro,
    required this.equipoId,
    required this.tiempo,
    required this.timestamp,
    this.horas = 0,
    this.minutos = 0,
    this.segundos = 0,
    this.milisegundos = 0,
    this.sincronizado = false,
    this.penalizado = false,
  }) : idRegistro = idRegistro ?? const Uuid().v4();

  /// Constructor desde milisegundos totales (calcula los componentes)
  factory RegistroTiempo.fromTiempoTotal({
    String? idRegistro,
    required int equipoId,
    required int tiempoMs,
    required DateTime timestamp,
    bool sincronizado = false,
    bool penalizado = false,
  }) {
    final ms = tiempoMs % 1000;
    final totalSeconds = tiempoMs ~/ 1000;
    final s = totalSeconds % 60;
    final totalMinutes = totalSeconds ~/ 60;
    final m = totalMinutes % 60;
    final h = totalMinutes ~/ 60;

    return RegistroTiempo(
      idRegistro: idRegistro,
      equipoId: equipoId,
      tiempo: tiempoMs,
      timestamp: timestamp,
      horas: h,
      minutos: m,
      segundos: s,
      milisegundos: ms,
      sincronizado: sincronizado,
      penalizado: penalizado,
    );
  }

  factory RegistroTiempo.fromJson(Map<String, dynamic> json) {
    return RegistroTiempo(
      idRegistro: json['record_id'] as String?,
      equipoId: json['team'] as int,
      tiempo: json['time'] as int,
      timestamp: DateTime.parse(json['created_at'] as String),
      horas: json['hours'] as int? ?? 0,
      minutos: json['minutes'] as int? ?? 0,
      segundos: json['seconds'] as int? ?? 0,
      milisegundos: json['milliseconds'] as int? ?? 0,
      sincronizado: json['sincronizado'] as bool? ?? false,
      penalizado: json['penalizado'] as bool? ?? false,
    );
  }

  /// Para enviar al servidor (WebSocket)
  Map<String, dynamic> toJson() {
    return {
      'record_id': idRegistro,
      'team': equipoId,
      'time': tiempo,
      'hours': horas,
      'minutes': minutos,
      'seconds': segundos,
      'milliseconds': milisegundos,
      'created_at': timestamp.toIso8601String(),
    };
  }

  /// Para la base de datos local
  Map<String, dynamic> toDbMap() {
    return {
      'id_registro': idRegistro,
      'equipo_id': equipoId,
      'tiempo': tiempo,
      'timestamp': timestamp.toIso8601String(),
      'horas': horas,
      'minutos': minutos,
      'segundos': segundos,
      'milisegundos': milisegundos,
      'sincronizado': sincronizado ? 1 : 0,
      'penalizado': penalizado ? 1 : 0,
    };
  }

  factory RegistroTiempo.fromDbMap(Map<String, dynamic> map) {
    return RegistroTiempo(
      idRegistro: map['id_registro'] as String,
      equipoId: map['equipo_id'] as int,
      tiempo: map['tiempo'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      horas: map['horas'] as int? ?? 0,
      minutos: map['minutos'] as int? ?? 0,
      segundos: map['segundos'] as int? ?? 0,
      milisegundos: map['milisegundos'] as int? ?? 0,
      sincronizado: (map['sincronizado'] as int) == 1,
      penalizado: (map['penalizado'] as int? ?? 0) == 1,
    );
  }

  String get tiempoFormateado {
    final m = minutos.toString().padLeft(2, '0');
    final s = segundos.toString().padLeft(2, '0');
    final cs = (milisegundos ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  RegistroTiempo copyWith({
    String? idRegistro,
    int? equipoId,
    int? tiempo,
    DateTime? timestamp,
    int? horas,
    int? minutos,
    int? segundos,
    int? milisegundos,
    bool? sincronizado,
    bool? penalizado,
  }) {
    return RegistroTiempo(
      idRegistro: idRegistro ?? this.idRegistro,
      equipoId: equipoId ?? this.equipoId,
      tiempo: tiempo ?? this.tiempo,
      timestamp: timestamp ?? this.timestamp,
      horas: horas ?? this.horas,
      minutos: minutos ?? this.minutos,
      segundos: segundos ?? this.segundos,
      milisegundos: milisegundos ?? this.milisegundos,
      sincronizado: sincronizado ?? this.sincronizado,
      penalizado: penalizado ?? this.penalizado,
    );
  }
}
