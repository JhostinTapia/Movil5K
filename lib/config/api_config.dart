import 'package:flutter/foundation.dart';

/// Configuración centralizada de la API
class ApiConfig {
  // URL base del servidor - Automático según plataforma
  static const String baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000' // Para navegador web
      : 'http://192.168.0.108:8000'; // Para móvil (IP WiFi de tu laptop)
      // : 'http://10.20.142:8000'; // Para móvil (IP WiFi de tu laptop)

  // static const String baseUrl = 'http://10.0.2.2:8000'; // Para emulador Android
  // static const String baseUrl = 'http://192.168.x.x:8000'; // Para otro dispositivo físico

  // Endpoints de autenticación
  static const String loginEndpoint = '/api/login/';
  static const String logoutEndpoint = '/api/logout/';
  static const String refreshTokenEndpoint = '/api/token/refresh/';
  static const String meEndpoint = '/api/me/';

  // Endpoints de recursos
  static const String competenciasEndpoint = '/api/competencias/';
  static const String equiposEndpoint = '/api/equipos/';

  // WebSocket
  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');
  static String webSocketUrl(int juezId, String token) {
    return '$wsBaseUrl/ws/juez/$juezId/?token=$token';
  }

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers por defecto
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
}