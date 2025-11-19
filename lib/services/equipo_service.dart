import 'api_service.dart';
import '../config/api_config.dart';
import '../models/equipo.dart';

/// Servicio para gestionar equipos
class EquipoService {
  final ApiService _apiService;
  final String? _accessToken;

  EquipoService(this._apiService, this._accessToken);

  /// Obtener todos los equipos
  Future<List<Equipo>> getEquipos({int? competenciaId, int? juezId}) async {
    if (_accessToken == null) {
      throw ApiException('No autenticado');
    }

    final queryParams = <String, String>{};
    if (competenciaId != null) {
      queryParams['competencia_id'] = competenciaId.toString();
    }
    if (juezId != null) {
      queryParams['juez_id'] = juezId.toString();
    }

    final response = await _apiService.get(
      ApiConfig.equiposEndpoint,
      headers: ApiConfig.authHeaders(_accessToken),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    // La respuesta puede ser un array o un objeto con 'results'
    final List<dynamic> data = response is List
        ? (response as List)
        : ((response as Map<String, dynamic>)['results'] ?? []) as List;

    return data.map((json) => Equipo.fromJson(json)).toList();
  }

  /// Obtener un equipo específico
  Future<Equipo> getEquipo(int id) async {
    if (_accessToken == null) {
      throw ApiException('No autenticado');
    }

    final response = await _apiService.get(
      '${ApiConfig.equiposEndpoint}$id/',
      headers: ApiConfig.authHeaders(_accessToken),
    );

    return Equipo.fromJson(response);
  }

  /// Obtener equipos asignados al juez autenticado
  Future<List<Equipo>> getEquiposAsignados(int juezId) async {
    return getEquipos(juezId: juezId);
  }
}
