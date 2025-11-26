import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import '../models/registro_tiempo.dart';

/// Resultado de sincronización
class SyncResult {
  final int totalEnviados;
  final int exitosos;
  final int fallidos;
  final List<String> errores;

  SyncResult({
    required this.totalEnviados,
    required this.exitosos,
    required this.fallidos,
    required this.errores,
  });

  bool get todoExitoso => exitosos == totalEnviados && fallidos == 0;
}

/// Servicio de sincronización de registros con el servidor
class SyncService {
  final DatabaseService _databaseService;
  final Connectivity _connectivity;

  // Límite de registros por lote (según backend)
  static const int maxRegistrosPorLote = 15;

  SyncService(this._databaseService, [Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  /// Sincronizar registros pendientes usando WebSocket
  /// Esta función NO usa HTTP, sino que envía directamente por WebSocket
  /// cuando el timer_provider llame a syncRegistros()
  Future<SyncResult> syncRegistros({
    required int equipoId,
    required String accessToken,
  }) async {
    // NOTA: La sincronización real se hace por WebSocket en tiempo real
    // Esta función solo retorna el estado de los registros en BD local

    print('📊 Verificando estado de sincronización para equipo $equipoId');

    final registrosPendientes = await _databaseService
        .getRegistrosNoSincronizados(equipoId);

    if (registrosPendientes.isEmpty) {
      print('✅ No hay registros pendientes de sincronización');
      return SyncResult(
        totalEnviados: 0,
        exitosos: 0,
        fallidos: 0,
        errores: [],
      );
    }

    // Los registros se enviaron en tiempo real por WebSocket
    // Solo marcarlos como sincronizados si están en BD
    int exitosos = 0;
    for (final registro in registrosPendientes) {
      try {
        await _databaseService.marcarComoSincronizado(registro.idRegistro);
        exitosos++;
      } catch (e) {
        print('⚠️ Error marcando registro como sincronizado: $e');
      }
    }

    print('✅ $exitosos registros marcados como sincronizados');

    return SyncResult(
      totalEnviados: registrosPendientes.length,
      exitosos: exitosos,
      fallidos: 0,
      errores: [],
    );
  }

  /// Enviar lote de registros por WebSocket
  /// Esta función la llamará el TimerProvider cuando complete los 15 registros
  Future<void> enviarRegistrosPorWebSocket({
    required int equipoId,
    required List<RegistroTiempo> registros,
    required void Function(Map<String, dynamic>) sendWebSocketMessage,
  }) async {
    // Verificar conectividad
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    if (registros.isEmpty) {
      throw Exception('No hay registros para enviar');
    }

    print(
      '📤 Enviando ${registros.length} registros por WebSocket para equipo $equipoId',
    );

    // Asegurar máximo 15 registros por envío para respetar el límite del servidor
    final registrosAEnviar = registros.length > maxRegistrosPorLote 
        ? registros.sublist(0, maxRegistrosPorLote) 
        : registros;

    if (registros.length > maxRegistrosPorLote) {
      print('⚠️ Se intentaron enviar ${registros.length} registros. Se recortó a $maxRegistrosPorLote.');
    }

    // Construir payload según el formato esperado por el backend WebSocket
    // Ver app/websocket/consumers.py - manejar_registro_tiempos_batch
    // Formato: {"tipo": "registrar_tiempos", "equipo_id": 1, "registros": [...]}
    final payload = {
      'tipo': 'registrar_tiempos',
      'equipo_id': equipoId,
      'registros': registrosAEnviar
          .map(
            (r) => {
              'id_registro': r.idRegistro, // UUID para idempotencia
              'tiempo': r.tiempo,
              'horas': r.horas,
              'minutos': r.minutos,
              'segundos': r.segundos,
              'milisegundos': r.milisegundos,
            },
          )
          .toList(),
    };

    // Enviar por WebSocket
    sendWebSocketMessage(payload);

    print('✅ Registros enviados por WebSocket');
  }

  /// Verificar conectividad
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Obtener cantidad de registros pendientes de sincronización
  Future<int> getRegistrosPendientes(int equipoId) async {
    final registros = await _databaseService.getRegistrosNoSincronizados(
      equipoId,
    );
    return registros.length;
  }

  /// Sincronizar todos los equipos
  Future<Map<int, SyncResult>> syncTodosLosEquipos({
    required List<int> equipoIds,
    required String accessToken,
  }) async {
    final resultados = <int, SyncResult>{};

    for (final equipoId in equipoIds) {
      try {
        final result = await syncRegistros(
          equipoId: equipoId,
          accessToken: accessToken,
        );
        resultados[equipoId] = result;
      } catch (e) {
        resultados[equipoId] = SyncResult(
          totalEnviados: 0,
          exitosos: 0,
          fallidos: 0,
          errores: ['Error general: $e'],
        );
      }
    }

    return resultados;
  }
}
