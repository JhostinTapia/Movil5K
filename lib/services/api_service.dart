import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
    : _client = client ?? _buildClient(),
      _storageService = storageService ?? StorageService();

  /// Construye un cliente HTTP con keep-alive y más conexiones por host (solo móvil).
  static http.Client _buildClient() {
    if (kIsWeb) return http.Client();
    final ioClient = HttpClient()
      ..idleTimeout = const Duration(seconds: 15)
      ..maxConnectionsPerHost = 12
      ..connectionTimeout = ApiConfig.connectionTimeout;
    return IOClient(ioClient);
  }

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
    bool isRetry = false,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}$endpoint',
      ).replace(queryParameters: queryParameters);

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _sendWithRetry(() => _client.get(uri, headers: requestHeaders));
      return _handleResponse(response);
    } catch (e) {
      final error = _handleError(e);
      
      // Si es error 401 y no es un reintento, intentar refrescar token
      if (!isRetry && requiresAuth && _isTokenExpiredError(error)) {
        return await _retryWithRefreshedToken(() => get(
          endpoint,
          headers: headers,
          queryParameters: queryParameters,
          requiresAuth: requiresAuth,
          isRetry: true,
        ));
      }
      
      throw error;
    }
  }

  /// Realiza una petición POST
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool isRetry = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _sendWithRetry(() => _client.post(
        uri,
        headers: requestHeaders,
        body: body != null ? json.encode(body) : null,
      ));
      return _handleResponse(response);
    } catch (e) {
      final error = _handleError(e);
      
      // Si es error 401 y no es un reintento, intentar refrescar token
      if (!isRetry && requiresAuth && _isTokenExpiredError(error)) {
        return await _retryWithRefreshedToken(() => post(
          endpoint,
          headers: headers,
          body: body,
          requiresAuth: requiresAuth,
          isRetry: true,
        ));
      }
      
      throw error;
    }
  }

  /// Realiza una petición PUT
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool isRetry = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _sendWithRetry(() => _client.put(
        uri,
        headers: requestHeaders,
        body: body != null ? json.encode(body) : null,
      ));
      return _handleResponse(response);
    } catch (e) {
      final error = _handleError(e);
      
      // Si es error 401 y no es un reintento, intentar refrescar token
      if (!isRetry && requiresAuth && _isTokenExpiredError(error)) {
        return await _retryWithRefreshedToken(() => put(
          endpoint,
          headers: headers,
          body: body,
          requiresAuth: requiresAuth,
          isRetry: true,
        ));
      }
      
      throw error;
    }
  }

  /// Realiza una petición DELETE
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
    bool requiresAuth = true,
    bool isRetry = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      final requestHeaders = requiresAuth
          ? await _getAuthHeaders(extraHeaders: headers)
          : headers ?? ApiConfig.defaultHeaders;

      final response = await _sendWithRetry(() => _client.delete(uri, headers: requestHeaders));
      return _handleResponse(response);
    } catch (e) {
      final error = _handleError(e);
      
      // Si es error 401 y no es un reintento, intentar refrescar token
      if (!isRetry && requiresAuth && _isTokenExpiredError(error)) {
        return await _retryWithRefreshedToken(() => delete(
          endpoint,
          headers: headers,
          requiresAuth: requiresAuth,
          isRetry: true,
        ));
      }
      
      throw error;
    }
  }

  // -------- Resiliencia y backoff --------

  Future<http.Response> _sendWithRetry(Future<http.Response> Function() send) async {
    const maxRetries = 2; // total 3 intentos
    int attempt = 0;
    while (true) {
      try {
        final resp = await send().timeout(ApiConfig.receiveTimeout);
        if (_isRetriableStatus(resp.statusCode) && attempt < maxRetries) {
          await _delayBackoff(attempt);
          attempt++;
          continue;
        }
        return resp;
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
        await _delayBackoff(attempt);
        attempt++;
      } on SocketException {
        if (attempt >= maxRetries) rethrow;
        await _delayBackoff(attempt);
        attempt++;
      }
    }
  }

  bool _isRetriableStatus(int code) => code == 429 || code == 502 || code == 503 || code == 504;

  Future<void> _delayBackoff(int attempt) async {
    final base = pow(2, attempt).toInt();
    final jitterMs = Random().nextInt(200);
    await Future.delayed(Duration(milliseconds: 400 * base + jitterMs));
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

  /// Verifica si una petición falló por token expirado (401)
  bool _isTokenExpiredError(ApiException e) {
    return e.statusCode == 401 && 
           (e.message.toLowerCase().contains('token') || 
            e.message.toLowerCase().contains('unauthorized'));
  }

  /// Intenta refrescar el token y reintentar la petición
  Future<Map<String, dynamic>> _retryWithRefreshedToken(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      // Obtener refresh token
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) {
        throw ApiException('No hay refresh token disponible', statusCode: 401);
      }

      // Refrescar el access token
      final refreshResponse = await post(
        '/api/token/refresh/',
        body: {'refresh': refreshToken},
        requiresAuth: false,
      );

      // Guardar nuevo access token
      await _storageService.saveAccessToken(refreshResponse['access']);

      // Reintentar la petición original
      return await request();
    } catch (e) {
      // Si falla el refresh, propagar el error
      throw _handleError(e);
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
    final response = await post(
      '/api/login/',
      body: {'username': username, 'password': password},
      requiresAuth: false,
    );
    
    // DEBUG: Ver qué viene del servidor
    print('🔍 Response del servidor:');
    print('   access type: ${response['access'].runtimeType}');
    print('   access length: ${(response['access'] as String).length}');
    print('   access value: "${response['access']}"');
    print('   Tiene #: ${(response['access'] as String).contains('#')}');
    
    // IMPORTANTE: Limpiar tokens INMEDIATAMENTE después de recibirlos del servidor
    // El servidor Django a veces envía tokens con caracteres extra (#, espacios, etc.)
    if (response.containsKey('access')) {
      final originalAccess = response['access'] as String;
      final cleanAccess = originalAccess
          .trim()
          .replaceAll(RegExp(r'[#\n\r\t]'), '');
      response['access'] = cleanAccess;
      
      if (originalAccess != cleanAccess) {
        print('⚠️ Token access tenía caracteres inválidos!');
        print('   Original length: ${originalAccess.length}');
        print('   Clean length: ${cleanAccess.length}');
      } else {
        print('✅ Token access estaba limpio');
      }
    }
    
    if (response.containsKey('refresh')) {
      final originalRefresh = response['refresh'] as String;
      final cleanRefresh = originalRefresh
          .trim()
          .replaceAll(RegExp(r'[#\n\r\t]'), '');
      response['refresh'] = cleanRefresh;
      
      if (originalRefresh != cleanRefresh) {
        print('⚠️ Token refresh tenía caracteres inválidos!');
      }
    }
    
    return response;
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
    if (activa != null) params['is_active'] = activa.toString();
    if (enCurso != null) params['is_running'] = enCurso.toString();

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

  /// Obtener equipos (filtrados automáticamente por el juez autenticado)
  Future<List<dynamic>> getEquipos({int? competenciaId}) async {
    final params = <String, String>{};
    if (competenciaId != null)
      params['competition_id'] = competenciaId.toString();

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

  // ==================== REGISTROS DE TIEMPO ====================

  /// Enviar registros de tiempo por HTTP (más confiable que WebSocket)
  /// 
  /// Este método envía los 15 tiempos de un equipo de manera atómica.
  /// Returns: {"exito": true, "mensaje": "...", "registros": [...]}
  Future<Map<String, dynamic>> enviarRegistros({
    required int equipoId,
    required List<Map<String, dynamic>> registros,
  }) async {
    return await post(
      '/api/equipos/$equipoId/registros/',
      body: {'registros': registros},
      requiresAuth: true,
    );
  }

  // NOTA: La app móvil es la FUENTE DE VERDAD para registros.
  // No se consulta ni descarga registros del servidor.
  // Solo se envían registros AL servidor.

  /// Liberar recursos
  void dispose() {
    _client.close();
  }
}
