import 'package:flutter/foundation.dart';

/// Configuración centralizada de la API
/// 
/// Para producción, cambia [_productionUrl] a tu dominio real.
/// La app detecta automáticamente si está en modo desarrollo o producción.
class ApiConfig {
  // ============================================================================
  // CONFIGURACIÓN DE PRODUCCIÓN - CAMBIA ESTO ANTES DE DESPLEGAR
  // ============================================================================
  
  /// URL del servidor en producción (dominio o IP pública)
  /// Ejemplos:
  ///   - 'https://api.midominio.com'
  ///   - 'http://server5k.example.com:8000'
  ///   - 'http://203.0.113.50:8000' (IP pública)
  static const String _productionUrl = 'http://TU_DOMINIO_O_IP:8000';
  
  /// URL del servidor en desarrollo (IP local de tu laptop)
  static const String _developmentUrl = 'http://192.168.0.190:8000';
  
  /// URL para emulador Android (10.0.2.2 = localhost del host)
  static const String _emulatorUrl = 'http://10.0.2.2:8000';
  
  /// URL para navegador web (localhost)
  static const String _webUrl = 'http://127.0.0.1:8000';
  
  // ============================================================================
  // SELECCIÓN DE ENTORNO
  // ============================================================================
  
  /// Cambiar a `true` para usar la URL de producción
  static const bool isProduction = false;
  
  /// Cambiar a `true` si estás probando en emulador Android
  static const bool isEmulator = false;

  // ============================================================================
  // URL BASE - NO MODIFICAR (se calcula automáticamente)
  // ============================================================================
  
  static String get baseUrl {
    if (kIsWeb) {
      return _webUrl;
    }
    
    if (isProduction) {
      return _productionUrl;
    }
    
    if (isEmulator) {
      return _emulatorUrl;
    }
    
    return _developmentUrl;
  }

  // Endpoints de autenticación
  static const String loginEndpoint = '/api/login/';
  static const String logoutEndpoint = '/api/logout/';
  static const String refreshTokenEndpoint = '/api/token/refresh/';
  static const String meEndpoint = '/api/me/';

  // Endpoints de recursos
  static const String competenciasEndpoint = '/api/competencias/';
  static const String equiposEndpoint = '/api/equipos/';

  // WebSocket
  static String get wsBaseUrl {
    final url = baseUrl;
    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    }
    return url.replaceFirst('http://', 'ws://');
  }

  static String webSocketUrl(int juezId, String token) {
    // Limpiar el token de caracteres extras AGRESIVAMENTE
    // Remover: espacios, saltos de línea, #, tabs, retornos de carro
    String cleanToken = token.trim();
    cleanToken = cleanToken.replaceAll(RegExp(r'[#\n\r\t\s]'), '');

    // IMPORTANTE: URL-encode el token para evitar problemas con caracteres especiales
    // El problema es que web_socket_channel o Uri.parse() puede agregar # al final
    // Uri.encodeComponent() codifica el token correctamente para URLs
    final encodedToken = Uri.encodeComponent(cleanToken);

    // Debug: verificar si el token tenía caracteres inválidos
    if (token != cleanToken) {
      debugPrint('⚠️ Token contenía caracteres inválidos!');
      debugPrint('   Original length: ${token.length}');
      debugPrint('   Clean length: ${cleanToken.length}');
      debugPrint('   Token original: "$token"');
      debugPrint('   Token limpio: "$cleanToken"');
    }

    final url = '$wsBaseUrl/ws/juez/$juezId/?token=$encodedToken';
    debugPrint('🔗 URL WebSocket generada: $url');
    return url;
  }

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Headers por defecto
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
  
  /// Muestra la configuración actual (para debug)
  static void printConfig() {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('📡 API Config:');
    debugPrint('   Base URL: $baseUrl');
    debugPrint('   WS URL: $wsBaseUrl');
    debugPrint('   Modo: ${isProduction ? "PRODUCCIÓN" : "DESARROLLO"}');
    debugPrint('   Emulador: $isEmulator');
    debugPrint('═══════════════════════════════════════════════');
  }
}
