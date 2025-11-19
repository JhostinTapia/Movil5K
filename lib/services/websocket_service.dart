import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../config/api_config.dart';

/// Tipos de mensajes WebSocket
enum WebSocketMessageType {
  carreraIniciada,
  carreraDetenida,
  competenciaIniciada,
  competenciaDetenida,
  conexionEstablecida,
  tiempoRegistrado,
  tiemposRegistradosBatch,
  equipoAsignado,
  sincronizacionCompletada,
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
      case 'equipo.asignado':
        return WebSocketMessageType.equipoAsignado;
      case 'sincronizacion.completada':
        return WebSocketMessageType.sincronizacionCompletada;
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
  WebSocketChannel? _channel;
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
      _accessToken = accessToken;

  /// Stream de mensajes
  Stream<WebSocketMessage> get messages => _messageController.stream;

  /// Stream de estado
  Stream<WebSocketState> get state => _stateController.stream;

  /// Estado actual
  WebSocketState get currentState => _state;

  /// Está conectado
  bool get isConnected => _state == WebSocketState.connected;

  /// Conectar al WebSocket
  Future<void> connect() async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      return;
    }

    try {
      _updateState(WebSocketState.connecting);

      final wsUrl = ApiConfig.webSocketUrl(_juezId, _accessToken);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

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

      print('✅ WebSocket conectado (Juez: $_juezId)');
    } catch (e) {
      print('❌ Error conectando WebSocket: $e');
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
      print('📤 Enviando mensaje: $jsonMessage');
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

      print('📨 Mensaje recibido: ${message.type}');
      print('📨 Datos completos: $json');
    } catch (e) {
      print('❌ Error procesando mensaje: $e');
    }
  }

  /// Maneja errores
  void _handleError(error) {
    print('❌ Error en WebSocket: $error');
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
        send({'tipo': 'ping', 'timestamp': DateTime.now().toIso8601String()});
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
