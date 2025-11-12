class RegistroTiempo {
  final String idRegistro;
  final int equipoId;
  final int tiempo; // Tiempo en milisegundos
  final DateTime timestamp;

  RegistroTiempo({
    required this.idRegistro,
    required this.equipoId,
    required this.tiempo,
    required this.timestamp,
  });

  factory RegistroTiempo.fromJson(Map<String, dynamic> json) {
    return RegistroTiempo(
      idRegistro: json['id_registro'],
      equipoId: json['equipo'],
      tiempo: json['tiempo'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_registro': idRegistro,
      'equipo': equipoId,
      'tiempo': tiempo,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Formato de tiempo legible: mm:ss.SSS
  String get tiempoFormateado {
    int minutes = tiempo ~/ 60000;
    int seconds = (tiempo % 60000) ~/ 1000;
    int milliseconds = tiempo % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(3, '0')}';
  }
}
