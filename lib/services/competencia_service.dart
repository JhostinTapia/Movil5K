import 'api_service.dart';
import '../config/api_config.dart';
import '../models/competencia.dart';

/// Servicio para gestionar competencias
class CompetenciaService {
  final ApiService _apiService;
  final String? _accessToken;

  CompetenciaService(this._apiService, this._accessToken);

  /// Obtener todas las competencias
  Future<List<Competencia>> getCompetencias({
    bool? activa,
    bool? enCurso,
  }) async {
    if (_accessToken == null) {
      throw ApiException('No autenticado');
    }

    final queryParams = <String, String>{};
    if (activa != null) queryParams['activa'] = activa.toString();
    if (enCurso != null) queryParams['en_curso'] = enCurso.toString();

    final response = await _apiService.get(
      ApiConfig.competenciasEndpoint,
      headers: ApiConfig.authHeaders(_accessToken),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    // La respuesta puede ser un array o un objeto con 'results'
    final List<dynamic> data = response is List
        ? (response as List)
        : ((response as Map<String, dynamic>)['results'] ?? []) as List;

    return data.map((json) => Competencia.fromJson(json)).toList();
  }

  /// Obtener una competencia específica
  Future<Competencia> getCompetencia(int id) async {
    if (_accessToken == null) {
      throw ApiException('No autenticado');
    }

    final response = await _apiService.get(
      '${ApiConfig.competenciasEndpoint}$id/',
      headers: ApiConfig.authHeaders(_accessToken),
    );

    return Competencia.fromJson(response);
  }

  /// Obtener competencia activa y en curso
  Future<Competencia?> getCompetenciaActiva() async {
    try {
      final competencias = await getCompetencias(activa: true, enCurso: true);

      return competencias.isNotEmpty ? competencias.first : null;
    } catch (e) {
      return null;
    }
  }
}
