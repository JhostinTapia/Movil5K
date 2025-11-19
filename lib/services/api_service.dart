import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Servicio base para comunicación con la API
class ApiService {
  final http.Client _client;
  final StorageService _storageService;

  ApiService({http.Client? client, StorageService? storageService})
    : _client = client ?? http.Client(),
      _storageService = storageService ?? StorageService();

  /// Obtiene headers autenticados con el token JWT
  Future<Map<String, String>> _getAuthHeaders({
    Map<String, String>? extraHeaders,
  }) async {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);

    // Intentar obtener el token de acceso
    final accessToken = await _storageService.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    // Agregar headers adicionales
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Realiza una petición GET
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}$endpoint',
      ).replace(queryParameters: queryParameters);

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _client
          .get(uri, headers: requestHeaders)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Realiza una petición POST
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _client
          .post(
            uri,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Realiza una petición PUT
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _client
          .put(
            uri,
            headers: requestHeaders,
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Realiza una petición DELETE
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _client
          .delete(uri, headers: requestHeaders)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Maneja la respuesta HTTP
  Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Manejar respuestas vacías
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return {};
      }
      throw ApiException('Error del servidor', statusCode: statusCode);
    }

    try {
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (statusCode >= 200 && statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'data': data};
      }

      // Manejar errores
      final errorMessage = data is Map
          ? (data['error'] ??
                data['detail'] ??
                data['message'] ??
                'Error desconocido')
          : 'Error desconocido';

      throw ApiException(
        errorMessage.toString(),
        statusCode: statusCode,
        data: data,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        'Error al procesar respuesta',
        statusCode: statusCode,
        data: response.body,
      );
    }
  }

  /// Maneja errores de red y excepciones
  ApiException _handleError(dynamic error) {
    if (error is ApiException) return error;

    if (error.toString().contains('SocketException')) {
      return ApiException('No hay conexión a internet');
    }

    if (error.toString().contains('TimeoutException')) {
      return ApiException('Tiempo de espera agotado');
    }

    return ApiException('Error: ${error.toString()}');
  }

  /// Login de juez (no requiere autenticación)
  Future<Map<String, dynamic>> login(String username, String password) async {
    return await post(
      '/api/login/',
      body: {'username': username, 'password': password},
      requiresAuth: false,
    );
  }

  /// Logout (requiere autenticación)
  Future<Map<String, dynamic>> logout(String refreshToken) async {
    return await post(
      '/api/logout/',
      body: {'refresh': refreshToken},
      requiresAuth: true,
    );
  }

  /// Obtener información del juez autenticado (requiere autenticación)
  Future<Map<String, dynamic>> getMe() async {
    return await get('/api/me/', requiresAuth: true);
  }

  /// Refrescar token (no requiere autenticación JWT, usa refresh token)
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    return await post(
      '/api/token/refresh/',
      body: {'refresh': refreshToken},
      requiresAuth: false,
    );
  }

  /// Obtener competencias
  Future<List<dynamic>> getCompetencias({bool? activa, bool? enCurso}) async {
    final params = <String, String>{};
    if (activa != null) params['activa'] = activa.toString();
    if (enCurso != null) params['en_curso'] = enCurso.toString();

    final response = await get(
      '/api/competencias/',
      queryParameters: params.isNotEmpty ? params : null,
    );

    // El backend devuelve una lista directamente, pero _handleResponse la envuelve en {'data': [...]}
    if (response['data'] is List) {
      return response['data'] as List<dynamic>;
    }
    // Fallback para respuestas con paginación
    return response['results'] as List<dynamic>? ?? [];
  }

  /// Obtener una competencia
  Future<Map<String, dynamic>> getCompetencia(int id) async {
    return await get('/api/competencias/$id/');
  }

  /// Obtener equipos
  Future<List<dynamic>> getEquipos({int? competenciaId, int? juezId}) async {
    final params = <String, String>{};
    if (competenciaId != null)
      params['competencia_id'] = competenciaId.toString();
    if (juezId != null) params['juez_id'] = juezId.toString();

    final response = await get(
      '/api/equipos/',
      queryParameters: params.isNotEmpty ? params : null,
    );

    // El backend devuelve una lista directamente, pero _handleResponse la envuelve en {'data': [...]}
    if (response['data'] is List) {
      return response['data'] as List<dynamic>;
    }
    // Fallback para respuestas con paginación
    return response['results'] as List<dynamic>? ?? [];
  }

  /// Obtener un equipo
  Future<Map<String, dynamic>> getEquipo(int id) async {
    return await get('/api/equipos/$id/');
  }

  /// Liberar recursos
  void dispose() {
    _client.close();
  }
}
