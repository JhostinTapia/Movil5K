class Equipo {
  final int id;
  final String nombre;
  final int dorsal;
  final int juezAsignado;

  Equipo({
    required this.id,
    required this.nombre,
    required this.dorsal,
    required this.juezAsignado,
  });

  factory Equipo.fromJson(Map<String, dynamic> json) {
    return Equipo(
      id: json['id'],
      nombre: json['nombre'],
      dorsal: json['dorsal'],
      juezAsignado: json['juez_asignado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'dorsal': dorsal,
      'juez_asignado': juezAsignado,
    };
  }
}
