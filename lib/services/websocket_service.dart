import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/api_config.dart';

/// Tipos de mensajes WebSocket
/// 
/// NOTA: Los registros ahora se envían por HTTP POST.
/// El WebSocket solo recibe notificaciones del servidor.
enum WebSocketMessageType {
  carreraIniciada,
  carreraDetenida,
  competenciaIniciada,
  competenciaDetenida,
  conexionEstablecida,
  tiempoRegistrado,
  tiemposRegistradosBatch,
  registrosActualizados, 
  equipoAsignado,
  sincronizacionCompletada,
  pong,
  error,
  unknown,
}

/// Mensaje de WebSocket
class WebSocketMessage {
  final WebSocketMessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    // El backend puede enviar 'type' o 'tipo'
    final typeStr = json['type'] as String? ?? json['tipo'] as String?;
    final type = _parseMessageType(typeStr);

    // Los datos pueden estar en 'data' o directamente en el JSON
    final data =
        json['data'] as Map<String, dynamic>? ?? Map<String, dynamic>.from(json)
          ..remove('type')
          ..remove('tipo');

    return WebSocketMessage(type: type, data: data);
  }

  static WebSocketMessageType _parseMessageType(String? typeStr) {
    switch (typeStr) {
      case 'carrera.iniciada':
        return WebSocketMessageType.carreraIniciada;
      case 'carrera.detenida':
        return WebSocketMessageType.carreraDetenida;
      case 'competencia_iniciada':
        return WebSocketMessageType.competenciaIniciada;
      case 'competencia_detenida':
        return WebSocketMessageType.competenciaDetenida;
      case 'conexion_establecida':
        return WebSocketMessageType.conexionEstablecida;
      case 'tiempo_registrado':
        return WebSocketMessageType.tiempoRegistrado;
      case 'tiempos_registrados_batch':
        return WebSocketMessageType.tiemposRegistradosBatch;
      case 'registros_actualizados':
        return WebSocketMessageType.registrosActualizados;
      case 'equipo.asignado':
        return WebSocketMessageType.equipoAsignado;
      case 'sincronizacion.completada':
        return WebSocketMessageType.sincronizacionCompletada;
      case 'pong':
        return WebSocketMessageType.pong;
      case 'error':
        return WebSocketMessageType.error;
      default:
        return WebSocketMessageType.unknown;
    }
  }
}

/// Estado de conexión WebSocket
enum WebSocketState { disconnected, connecting, connected, reconnecting, error }

/// Servicio de WebSocket para comunicación en tiempo real
class WebSocketService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final int _juezId;
  final String _accessToken;

  // Controladores de streams
  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _stateController = StreamController<WebSocketState>.broadcast();

  // Estado
  WebSocketState _state = WebSocketState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  WebSocketService({required int juezId, required String accessToken})
    : _juezId = juezId,
      _accessToken = accessToken.trim().replaceAll(RegExp(r'[#\n\r\t\s]'), '');

  /// Stream de mensajes
  Stream<WebSocketMessage> get messages => _messageController.stream;

  /// Stream de estado
  Stream<WebSocketState> get state => _stateController.stream;

  /// Estado actual
  WebSocketState get currentState => _state;

  /// Está conectado
  bool get isConnected => _state == WebSocketState.connected;

  /// Construir URI correctamente
  Uri _buildWebSocketUri() {
    // Limpiar token (ya está limpio desde el constructor, pero por seguridad)
    final cleanToken = _accessToken.trim().replaceAll(RegExp(r'[#\n\r\t\s]'), '');
    
    // Construir URI usando el constructor Uri() para evitar problemas
    final wsBaseUrl = ApiConfig.wsBaseUrl.replaceFirst('ws://', '');
    final parts = wsBaseUrl.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.parse(parts[1]) : 8000;
    
    return Uri(
      scheme: 'ws',
      host: host,
      port: port,
      path: '/ws/juez/$_juezId/',
      queryParameters: {
        'token': cleanToken,
      },
    );
  }

  /// Conectar al WebSocket
  Future<void> connect() async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      return;
    }

    try {
      _updateState(WebSocketState.connecting);

      // Construir URI correctamente
      final uri = _buildWebSocketUri();
      
      print('═══════════════════════════════════════');
      print('🔌 CONECTANDO WEBSOCKET');
      print('═══════════════════════════════════════');
      print('Scheme: ${uri.scheme}');
      print('Host: ${uri.host}');
      print('Port: ${uri.port}');
      print('Path: ${uri.path}');
      print('Query: ${uri.query}');
      print('Fragment: "${uri.fragment}" (debe estar vacío)');
      print('URI completo: $uri');
      print('═══════════════════════════════════════');
      
      // Verificaciones de seguridad
      if (uri.scheme != 'ws') {
        throw Exception('❌ Scheme incorrecto: ${uri.scheme} (debe ser ws)');
      }
      
      if (uri.fragment.isNotEmpty) {
        throw Exception('❌ URI tiene fragment (#): ${uri.fragment}');
      }
      
      if (uri.query.contains('#')) {
        throw Exception('❌ Query contiene #: ${uri.query}');
      }
      
      // ✅ USAR WebSocket.connect directamente y envolver en IOWebSocketChannel
      print('🔄 Conectando usando WebSocket.connect...');
      final webSocket = await WebSocket.connect(
        uri.toString(),
        headers: {
          'Connection': 'Upgrade',
          'Upgrade': 'websocket',
        },
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('⏱️ Timeout conectando al WebSocket');
        },
      );
      
      _channel = IOWebSocketChannel(webSocket);

      // Escuchar mensajes
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;

      // Iniciar heartbeat
      _startHeartbeat();

      print('✅ WebSocket conectado exitosamente (Juez: $_juezId)');
    } catch (e, stackTrace) {
      print('❌ Error conectando WebSocket: $e');
      print('🔍 Detalles del error: ${e.runtimeType}');
      
      // Si es un WebSocketException, mostrar más detalles
      if (e is WebSocketException) {
        print('📋 WebSocketException - Mensaje: ${e.message}');
        
        // Verificar si es un error 403
        if (e.message != null && e.message!.contains('403')) {
          print('🚫 Error 403 Forbidden - El servidor Django rechazó la conexión');
          print('   Posibles causas:');
          print('   1. Token inválido o expirado');
          print('   2. Token no enviado correctamente');
          print('   3. Middleware de autenticación rechazando');
          print('   4. CORS o configuración de ALLOWED_HOSTS');
          print('💡 Revisa los logs del servidor Django para más información');
        }
      }
      
      print('📚 Stack trace: $stackTrace');
      _updateState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Desconectar del WebSocket
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    await _subscription?.cancel();
    await _channel?.sink.close(status.normalClosure);

    _channel = null;
    _subscription = null;

    _updateState(WebSocketState.disconnected);
    print('🔌 WebSocket desconectado');
  }

  /// Enviar mensaje
  void send(Map<String, dynamic> message) {
    if (!isConnected) {
      print('⚠️ No se puede enviar mensaje: WebSocket no conectado');
      return;
    }

    try {
      final jsonMessage = json.encode(message);
      // Solo loguear mensajes importantes (no ping)
      if (message['tipo'] != 'ping') {
        print('📤 Enviando mensaje: $jsonMessage');
      }
      _channel?.sink.add(jsonMessage);
    } catch (e) {
      print('❌ Error enviando mensaje: $e');
    }
  }

  /// Maneja mensajes recibidos
  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(json);

      _messageController.add(message);

      // Solo loguear mensajes importantes (no pong)
      if (message.type != WebSocketMessageType.pong) {
        print('📨 Mensaje recibido: ${message.type}');
        print('📨 Datos completos: $json');
      }
    } catch (e) {
      print('❌ Error procesando mensaje: $e');
    }
  }

  /// Maneja errores
  void _handleError(error) {
    print('❌ Error en WebSocket: $error');
    print('🔍 Tipo de error: ${error.runtimeType}');
    
    // Parsear mensaje de error del servidor para mostrar al usuario
    String errorMessage = 'Error de conexión con el servidor';
    
    final errorStr = error.toString().toLowerCase();
    
    // Detectar errores específicos
    if (errorStr.contains('no tienes equipos asignados')) {
      errorMessage = 'No tienes equipos asignados. Contacta al administrador.';
    } else if (errorStr.contains('no tienes competencias activas') || 
               errorStr.contains('competencia no está activa')) {
      errorMessage = 'Tu competencia no está activa. Contacta al administrador.';
    } else if (errorStr.contains('not upgraded to websocket')) {
      errorMessage = 'Error de autenticación. Intenta cerrar sesión y volver a entrar.';
    } else if (errorStr.contains('token inválido') || errorStr.contains('token invalido')) {
      errorMessage = 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';
    } else if (errorStr.contains('connection refused') || errorStr.contains('failed to connect')) {
      errorMessage = 'No se puede conectar al servidor. Verifica tu conexión a internet.';
    }
    
    // Emitir mensaje de error para que la UI lo capture
    _messageController.add(WebSocketMessage(
      type: WebSocketMessageType.error,
      data: {
        'mensaje': errorMessage,
        'error_tecnico': error.toString(),
      },
    ));
    
    _updateState(WebSocketState.error);
    _scheduleReconnect();
  }

  /// Maneja desconexión
  void _handleDisconnect() {
    print('🔌 WebSocket desconectado');
    _updateState(WebSocketState.disconnected);
    _scheduleReconnect();
  }

  /// Programa reconexión
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Máximo de intentos de reconexión alcanzado');
      _updateState(WebSocketState.error);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      print('🔄 Reintentando conexión (Intento $_reconnectAttempts)...');
      _updateState(WebSocketState.reconnecting);
      connect();
    });
  }

  /// Inicia heartbeat para mantener conexión viva
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (isConnected) {
        send({'tipo': 'ping'});
        print('Heartbeat enviado');
      }
    });
  }

  /// Actualiza el estado y notifica
  void _updateState(WebSocketState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Liberar recursos
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
