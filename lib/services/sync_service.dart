import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
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
/// 
/// ARQUITECTURA:
/// - Los registros se envían por HTTP POST (más confiable)
/// - El WebSocket solo se usa para recibir notificaciones
class SyncService {
  final DatabaseService _databaseService;
  final Connectivity _connectivity;
  final ApiService _apiService;

  // Límite de registros por lote (según backend)
  static const int maxRegistrosPorLote = 15;

  SyncService(this._databaseService, [Connectivity? connectivity, ApiService? apiService])
    : _connectivity = connectivity ?? Connectivity(),
      _apiService = apiService ?? ApiService();

  /// Sincronizar registros pendientes usando HTTP POST
  /// 
  /// Esta función envía los registros al servidor usando HTTP
  /// que es más confiable que WebSocket para operaciones CRUD.
  Future<SyncResult> syncRegistros({
    required int equipoId,
    required String accessToken,
  }) async {
    print('📊 Sincronizando registros para equipo $equipoId via HTTP');

    // Verificar conectividad
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      return SyncResult(
        totalEnviados: 0,
        exitosos: 0,
        fallidos: 0,
        errores: ['No hay conexión a internet'],
      );
    }

    // Obtener registros pendientes
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

    // Verificar que tengamos exactamente 15 registros
    if (registrosPendientes.length != maxRegistrosPorLote) {
      print('⚠️ Se esperan $maxRegistrosPorLote registros, hay ${registrosPendientes.length}');
      return SyncResult(
        totalEnviados: 0,
        exitosos: 0,
        fallidos: registrosPendientes.length,
        errores: ['Se requieren exactamente $maxRegistrosPorLote registros para sincronizar'],
      );
    }

    try {
      // Preparar payload para HTTP
      final registrosPayload = registrosPendientes.map((r) => {
        'id_registro': r.idRegistro,
        'tiempo': r.tiempo,
        'horas': r.horas,
        'minutos': r.minutos,
        'segundos': r.segundos,
        'milisegundos': r.milisegundos,
      }).toList();

      print('📤 Enviando ${registrosPayload.length} registros por HTTP...');

      // Enviar por HTTP
      final response = await _apiService.enviarRegistros(
        equipoId: equipoId,
        registros: registrosPayload,
      );

      if (response['exito'] == true) {
        // Marcar todos como sincronizados
        int exitosos = 0;
        for (final registro in registrosPendientes) {
          try {
            await _databaseService.marcarComoSincronizado(registro.idRegistro);
            exitosos++;
          } catch (e) {
            print('⚠️ Error marcando registro como sincronizado: $e');
          }
        }

        print('✅ ${response['total_guardados']} registros sincronizados exitosamente');

        return SyncResult(
          totalEnviados: registrosPendientes.length,
          exitosos: exitosos,
          fallidos: 0,
          errores: [],
        );
      } else {
        final errorMsg = response['error'] ?? 'Error desconocido';
        print('❌ Error del servidor: $errorMsg');
        
        return SyncResult(
          totalEnviados: registrosPendientes.length,
          exitosos: 0,
          fallidos: registrosPendientes.length,
          errores: [errorMsg],
        );
      }
    } catch (e) {
      print('❌ Error sincronizando: $e');
      return SyncResult(
        totalEnviados: registrosPendientes.length,
        exitosos: 0,
        fallidos: registrosPendientes.length,
        errores: ['Error de red: $e'],
      );
    }
  }

  /// Enviar registros por HTTP (método directo)
  /// 
  /// Este método reemplaza al antiguo enviarRegistrosPorWebSocket.
  /// Usa HTTP POST que es más confiable para envío de datos.
  Future<SyncResult> enviarRegistrosPorHttp({
    required int equipoId,
    required List<RegistroTiempo> registros,
  }) async {
    // Verificar conectividad
    final hasConnection = await _checkConnectivity();
    if (!hasConnection) {
      throw Exception('No hay conexión a internet');
    }

    if (registros.isEmpty) {
      throw Exception('No hay registros para enviar');
    }

    print('📤 Enviando ${registros.length} registros por HTTP para equipo $equipoId');

    // Asegurar máximo 15 registros
    final registrosAEnviar = registros.length > maxRegistrosPorLote 
        ? registros.sublist(0, maxRegistrosPorLote) 
        : registros;

    if (registros.length > maxRegistrosPorLote) {
      print('⚠️ Se intentaron enviar ${registros.length} registros. Se recortó a $maxRegistrosPorLote.');
    }

    // Preparar payload
    final registrosPayload = registrosAEnviar.map((r) => {
      'id_registro': r.idRegistro,
      'tiempo': r.tiempo,
      'horas': r.horas,
      'minutos': r.minutos,
      'segundos': r.segundos,
      'milisegundos': r.milisegundos,
    }).toList();

    try {
      final response = await _apiService.enviarRegistros(
        equipoId: equipoId,
        registros: registrosPayload,
      );

      if (response['exito'] == true) {
        // Marcar como sincronizados
        for (final registro in registrosAEnviar) {
          await _databaseService.marcarComoSincronizado(registro.idRegistro);
        }

        print('✅ Registros enviados y sincronizados exitosamente');

        return SyncResult(
          totalEnviados: registrosAEnviar.length,
          exitosos: response['total_guardados'] ?? registrosAEnviar.length,
          fallidos: 0,
          errores: [],
        );
      } else {
        throw Exception(response['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      print('❌ Error enviando registros: $e');
      rethrow;
    }
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
