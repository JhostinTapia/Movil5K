import 'package:flutter/foundation.dart';
import '../models/juez.dart';
import '../models/competencia.dart';
import '../models/equipo.dart';
import '../models/registro_tiempo.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/storage_service.dart';

/// Repositorio principal que coordina todos los servicios de la aplicación
/// Implementa el patrón Repository para centralizar el acceso a datos
class AppRepository {
  final ApiService _apiService;
  WebSocketService? _webSocketService;
  final DatabaseService _databaseService;
  final SyncService _syncService;
  final StorageService _storageService;

  AppRepository({
    ApiService? apiService,
    DatabaseService? databaseService,
    SyncService? syncService,
    StorageService? storageService,
  }) : _apiService = apiService ?? ApiService(),
       _databaseService = databaseService ?? DatabaseService(),
       _syncService =
           syncService ?? SyncService(databaseService ?? DatabaseService()),
       _storageService = storageService ?? StorageService();

  // ==================== AUTENTICACIÓN ====================

  /// Inicia sesión con username y password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // 1. Autenticar con el API
      final loginResponse = await _apiService.login(username, password);

      // 2. Guardar tokens
      await _storageService.saveTokens(
        loginResponse['access'],
        loginResponse['refresh'],
      );

      // 3. Obtener información del juez
      final juezData = await _apiService.getMe();
      final juez = Juez.fromJson(juezData);

      // 4. Guardar datos del juez
      await _storageService.saveJuez(juez);

      // 5. Obtener competencias del juez
      final competencias = await getCompetencias();

      return {'juez': juez, 'competencias': competencias};
    } catch (e) {
      debugPrint('Error en login: $e');
      rethrow;
    }
  }

  /// Cierra sesión y limpia datos locales
  Future<void> logout() async {
    try {
      // 1. Cerrar WebSocket si está conectado
      await disconnectWebSocket();

      // 2. Intentar cerrar sesión en el servidor
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        try {
          await _apiService.logout(refreshToken);
        } catch (e) {
          debugPrint('Error al cerrar sesión en servidor: $e');
        }
      }

      // 3. Limpiar storage local
      await _storageService.clearAll();

      // 4. Limpiar base de datos (opcional)
      // await _databaseService.clearAll();
    } catch (e) {
      debugPrint('Error en logout: $e');
      rethrow;
    }
  }

  /// Verifica si hay una sesión guardada
  Future<bool> hasSession() async {
    final accessToken = await _storageService.getAccessToken();
    return accessToken != null;
  }

  /// Intenta restaurar la sesión guardada
  Future<Juez?> restoreSession() async {
    try {
      final juez = await _storageService.getJuez();
      if (juez != null) {
        // Verificar que el token siga siendo válido
        try {
          await _apiService.getMe();
          return juez;
        } catch (e) {
          // Token expirado, intentar refrescar
          final refreshToken = await _storageService.getRefreshToken();
          if (refreshToken != null) {
            await refreshAccessToken();
            return juez;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error restaurando sesión: $e');
      return null;
    }
  }

  /// Refresca el access token usando el refresh token
  Future<void> refreshAccessToken() async {
    final refreshToken = await _storageService.getRefreshToken();
    if (refreshToken == null) {
      throw Exception('No hay refresh token disponible');
    }

    final response = await _apiService.refreshToken(refreshToken);
    await _storageService.saveAccessToken(response['access']);
  }

  // ==================== COMPETENCIAS ====================

  /// Obtiene todas las competencias
  Future<List<Competencia>> getCompetencias({
    bool? activa,
    bool? enCurso,
  }) async {
    try {
      final data = await _apiService.getCompetencias(
        activa: activa,
        enCurso: enCurso,
      );
      return data.map((json) => Competencia.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error obteniendo competencias: $e');
      rethrow;
    }
  }

  /// Obtiene una competencia por ID
  Future<Competencia> getCompetencia(int id) async {
    try {
      final data = await _apiService.getCompetencia(id);
      return Competencia.fromJson(data);
    } catch (e) {
      debugPrint('Error obteniendo competencia: $e');
      rethrow;
    }
  }

  // ==================== EQUIPOS ====================

  /// Obtiene todos los equipos (filtrados automáticamente por el juez autenticado en el servidor)
  Future<List<Equipo>> getEquipos({int? competenciaId}) async {
    try {
      final data = await _apiService.getEquipos(
        competenciaId: competenciaId,
      );
      return data.map((json) => Equipo.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error obteniendo equipos: $e');
      rethrow;
    }
  }

  /// Obtiene un equipo por ID
  Future<Equipo> getEquipo(int id) async {
    try {
      final data = await _apiService.getEquipo(id);
      return Equipo.fromJson(data);
    } catch (e) {
      debugPrint('Error obteniendo equipo: $e');
      rethrow;
    }
  }

  // ==================== REGISTROS DE TIEMPO ====================

  static const int maxRegistrosPorEquipo = 15;

  /// Guarda un registro de tiempo localmente
  /// VALIDACIÓN: No permite guardar más de 15 registros por equipo
  Future<bool> saveRegistroTiempo(
    RegistroTiempo registro,
    Equipo equipo,
  ) async {
    try {
      // VALIDACIÓN CRÍTICA: Verificar límite ANTES de guardar
      final registrosActuales = await _databaseService.contarRegistrosEquipo(equipo.id);
      
      if (registrosActuales >= maxRegistrosPorEquipo) {
        debugPrint('❌ LÍMITE ALCANZADO: Ya hay $registrosActuales registros para equipo ${equipo.id}');
        debugPrint('   No se puede guardar más. Máximo permitido: $maxRegistrosPorEquipo');
        return false; // No guardar, ya está lleno
      }
      
      await _databaseService.insertRegistroTiempo(registro);
      debugPrint('✅ Registro guardado: ${registrosActuales + 1}/$maxRegistrosPorEquipo');
      return true;
    } catch (e) {
      debugPrint('Error guardando registro: $e');
      return false;
    }
  }

  /// Obtiene registros de tiempo por equipo
  Future<List<RegistroTiempo>> getRegistrosByEquipo(int equipoId) async {
    try {
      final data = await _databaseService.getRegistrosByEquipo(equipoId);
      return data.map((json) => RegistroTiempo.fromDbMap(json)).toList();
    } catch (e) {
      debugPrint('Error obteniendo registros: $e');
      rethrow;
    }
  }

  /// Elimina un registro de tiempo
  Future<void> deleteRegistro(String idRegistro) async {
    try {
      await _databaseService.deleteRegistro(idRegistro);
    } catch (e) {
      debugPrint('Error eliminando registro: $e');
      rethrow;
    }
  }

  /// Marca un registro como sincronizado en BD local
  Future<void> marcarComoSincronizado(String idRegistro) async {
    try {
      await _databaseService.marcarComoSincronizado(idRegistro);
    } catch (e) {
      debugPrint('Error marcando registro como sincronizado: $e');
      rethrow;
    }
  }

  /// Verifica si un equipo ya tiene registros sincronizados
  Future<bool> equipoTieneRegistrosSincronizados(int equipoId) async {
    try {
      return await _databaseService.equipoTieneRegistrosSincronizados(equipoId);
    } catch (e) {
      debugPrint('Error verificando registros sincronizados: $e');
      return false;
    }
  }

  /// Cuenta la cantidad de registros que tiene un equipo
  Future<int> contarRegistrosEquipo(int equipoId) async {
    try {
      return await _databaseService.contarRegistrosEquipo(equipoId);
    } catch (e) {
      debugPrint('Error contando registros del equipo: $e');
      return 0;
    }
  }

  // ==================== SINCRONIZACIÓN ====================

  /// Sincroniza los registros pendientes con el servidor usando HTTP
  Future<Map<String, dynamic>> syncRegistros({required int equipoId}) async {
    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No hay token de acceso');
      }

      final result = await _syncService.syncRegistros(
        equipoId: equipoId,
        accessToken: accessToken,
      );

      return {
        'success': result.todoExitoso,
        'total': result.totalEnviados,
        'exitosos': result.exitosos,
        'fallidos': result.fallidos,
        'errores': result.errores,
      };
    } catch (e) {
      debugPrint('Error sincronizando registros: $e');
      rethrow;
    }
  }

  /// Enviar registros por HTTP directamente
  /// 
  /// Este método envía los registros al servidor usando HTTP POST
  /// que es más confiable que WebSocket para envío de datos.
  Future<Map<String, dynamic>> enviarRegistrosPorHttp({
    required int equipoId,
    required List<RegistroTiempo> registros,
  }) async {
    try {
      final result = await _syncService.enviarRegistrosPorHttp(
        equipoId: equipoId,
        registros: registros,
      );

      return {
        'success': result.todoExitoso,
        'total': result.totalEnviados,
        'exitosos': result.exitosos,
        'fallidos': result.fallidos,
        'errores': result.errores,
      };
    } catch (e) {
      debugPrint('Error enviando registros por HTTP: $e');
      rethrow;
    }
  }

  /// Verificar estado de registros en el servidor
  Future<Map<String, dynamic>> getEstadoRegistrosServidor(int equipoId) async {
    try {
      return await _apiService.getEstadoRegistros(equipoId);
    } catch (e) {
      debugPrint('Error obteniendo estado de registros del servidor: $e');
      rethrow;
    }
  }

  /// Sincroniza registros desde el servidor a la BD local
  /// Retorna true si había registros en el servidor
  Future<bool> sincronizarRegistrosDesdeServidor(int equipoId) async {
    try {
      final estado = await _apiService.getEstadoRegistros(equipoId);
      final registrosServidor = estado['registros'] as List<dynamic>? ?? [];
      
      if (registrosServidor.isEmpty) {
        // IMPORTANTE: Si el servidor dice que NO hay registros,
        // limpiar cualquier dato residual en la BD local
        // Esto asegura consistencia servidor <-> cliente
        final registrosLocales = await _databaseService.contarRegistrosEquipo(equipoId);
        if (registrosLocales > 0) {
          debugPrint('🧹 Servidor vacío pero BD local tiene $registrosLocales registros');
          debugPrint('   Limpiando registros locales del equipo $equipoId...');
          await _databaseService.eliminarRegistrosEquipo(equipoId);
          debugPrint('   ✅ Registros locales eliminados');
        }
        return false;
      }
      
      debugPrint('📥 Sincronizando ${registrosServidor.length} registros desde servidor');
      
      // Guardar cada registro en la BD local (marcado como sincronizado)
      for (final regData in registrosServidor) {
        final registro = RegistroTiempo(
          idRegistro: regData['id_registro'] ?? '',
          equipoId: equipoId,
          tiempo: regData['tiempo'] ?? 0,
          horas: regData['horas'] ?? 0,
          minutos: regData['minutos'] ?? 0,
          segundos: regData['segundos'] ?? 0,
          milisegundos: regData['milisegundos'] ?? 0,
          timestamp: DateTime.now(),
          sincronizado: true, // Ya está en el servidor
        );
        
        try {
          await _databaseService.insertRegistroTiempo(registro);
        } catch (e) {
          // Si ya existe, ignorar (idempotencia)
          debugPrint('   Registro ${registro.idRegistro} ya existe localmente');
        }
      }
      
      debugPrint('✅ Registros sincronizados desde servidor: ${registrosServidor.length}');
      return true;
    } catch (e) {
      debugPrint('Error sincronizando desde servidor: $e');
      return false;
    }
  }

  /// Obtiene el estado de sincronización de un equipo
  Future<Map<String, dynamic>> getSyncStatus({required int equipoId}) async {
    try {
      final pendientes = await _syncService.getRegistrosPendientes(equipoId);
      return {'pendientes': pendientes};
    } catch (e) {
      debugPrint('Error obteniendo estado de sincronización: $e');
      rethrow;
    }
  }

  /// Obtiene todos los registros pendientes (para todos los equipos)
  Future<int> getTotalRegistrosPendientes() async {
    try {
      final stats = await _databaseService.obtenerEstadisticas();
      return stats['pendientes'] ?? 0;
    } catch (e) {
      debugPrint('Error obteniendo total de registros pendientes: $e');
      return 0;
    }
  }

  // ==================== WEBSOCKET ====================

  /// Conecta al WebSocket para recibir notificaciones
  Future<void> connectWebSocket(int juezId) async {
    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken == null) {
        throw Exception('No hay token de acceso');
      }

      _webSocketService = WebSocketService(
        juezId: juezId,
        accessToken: accessToken,
      );

      await _webSocketService!.connect();
    } catch (e) {
      debugPrint('Error conectando WebSocket: $e');
      rethrow;
    }
  }

  /// Desconecta el WebSocket
  Future<void> disconnectWebSocket() async {
    await _webSocketService?.disconnect();
    _webSocketService = null;
  }

  /// Reconecta el WebSocket (desconecta y vuelve a conectar)
  Future<void> reconnectWebSocket(int juezId) async {
    await disconnectWebSocket();
    await connectWebSocket(juezId);
  }

  /// Stream de mensajes del WebSocket
  Stream<WebSocketMessage>? get webSocketMessages =>
      _webSocketService?.messages;

  /// Estado de conexión del WebSocket
  bool get isWebSocketConnected {
    return _webSocketService?.isConnected ?? false;
  }

  /// Enviar mensaje por WebSocket
  void sendWebSocketMessage(Map<String, dynamic> message) {
    if (_webSocketService == null || !isWebSocketConnected) {
      debugPrint('❌ WebSocket no disponible para enviar');
      throw Exception('WebSocket no conectado');
    }
    _webSocketService!.send(message);
  }

  // ==================== LIMPIEZA ====================

  /// Libera recursos
  void dispose() {
    _webSocketService?.dispose();
    _apiService.dispose();
  }
}
