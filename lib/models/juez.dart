class Juez {
  final int id;
  final String nombre;
  final int competenciaId;
  final bool activo;

  Juez({
    required this.id,
    required this.nombre,
    required this.competenciaId,
    required this.activo,
  });

  factory Juez.fromJson(Map<String, dynamic> json) {
    return Juez(
      id: json['id'],
      nombre: json['nombre'],
      competenciaId: json['competencia'],
      activo: json['activo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'competencia': competenciaId,
      'activo': activo,
    };
  }
}
