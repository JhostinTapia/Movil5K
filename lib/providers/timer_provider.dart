import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/registro_tiempo.dart';
import '../models/equipo.dart';
import '../models/competencia.dart';
import '../services/database_service.dart';

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Timer? _checkTimer;
  final List<RegistroTiempo> _registros = [];
  Equipo? _equipoActual;
  Competencia? _competenciaActual;
  bool _isCompleted = false;
  final DatabaseService _dbService = DatabaseService();

  // Configuración
  static const int maxParticipantes = 15;

  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  List<RegistroTiempo> get registros => List.unmodifiable(_registros);
  bool get isRunning => _stopwatch.isRunning;
  bool get isCompleted => _isCompleted;
  Equipo? get equipoActual => _equipoActual;
  Competencia? get competenciaActual => _competenciaActual;
  int get participantesRegistrados => _registros.length;
  bool get canAddMore => _registros.length < maxParticipantes;

  String get tiempoFormateado {
    int milliseconds = _stopwatch.elapsedMilliseconds;
    int minutes = milliseconds ~/ 60000;
    int seconds = (milliseconds % 60000) ~/ 1000;
    int ms = (milliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  // Estado de la competencia
  String get estadoCompetencia {
    if (_competenciaActual == null) return 'SIN COMPETENCIA';
    if (_isCompleted) return 'COMPLETADO';
    if (_competenciaActual!.estaEnProgreso) return 'EN CURSO';
    if (_competenciaActual!.estaPorComenzar) return 'POR INICIAR';
    return 'INACTIVA';
  }

  // Verifica si puede marcar tiempo (competencia debe estar en curso)
  bool get puedeMarcarTiempo {
    return _stopwatch.isRunning && canAddMore;
  }

  void setEquipo(Equipo equipo) {
    _equipoActual = equipo;
    _cargarRegistrosGuardados();
    notifyListeners();
  }

  void setCompetencia(Competencia competencia) {
    _competenciaActual = competencia;
    _iniciarMonitoreoCompetencia();
    notifyListeners();
  }

  // Monitorea la hora de inicio de la competencia
  void _iniciarMonitoreoCompetencia() {
    _checkTimer?.cancel();
    // Comentado para desarrollo - descomentar en producción
    /*
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_competenciaActual != null) {
        // Si la competencia debe comenzar, iniciar automáticamente
        if (_competenciaActual!.haComenzado &&
            !_stopwatch.isRunning &&
            !_isCompleted) {
          _iniciarAutomaticamente();
        }
        notifyListeners();
      }
    });
    */
  }

  void start() {
    if (!_stopwatch.isRunning && !_isCompleted) {
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        notifyListeners();
      });
      notifyListeners();
    }
  }

  void pause() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
      notifyListeners();
    }
  }

  void _iniciarAutomaticamente() {
    if (!_stopwatch.isRunning && !_isCompleted) {
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        notifyListeners();
      });
      notifyListeners();
    }
  }

  Future<void> _cargarRegistrosGuardados() async {
    if (_equipoActual == null) return;

    try {
      final registrosDb =
          await _dbService.getRegistrosByEquipo(_equipoActual!.id);

      _registros.clear();
      for (var regData in registrosDb) {
        _registros.add(RegistroTiempo(
          idRegistro: regData['id_registro'],
          equipoId: regData['equipo_id'],
          tiempo: regData['tiempo'],
          timestamp: DateTime.parse(regData['timestamp']),
        ));
      }

      if (_registros.length >= maxParticipantes) {
        _isCompleted = true;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando registros: $e');
    }
  }

  Future<void> marcarTiempo() async {
    if (puedeMarcarTiempo && _equipoActual != null) {
      final tiempo = _stopwatch.elapsedMilliseconds;
      final registro = RegistroTiempo(
        idRegistro: const Uuid().v4(),
        equipoId: _equipoActual!.id,
        tiempo: tiempo,
        timestamp: DateTime.now(),
      );

      _registros.add(registro);

      // Guardar en base de datos
      try {
        await _dbService.insertRegistroTiempo(
          registro,
          _equipoActual!.id,
          _equipoActual!.nombre,
          _equipoActual!.dorsal,
          _equipoActual!.juezAsignado,
        );
      } catch (e) {
        debugPrint('Error guardando registro: $e');
      }

      // Si llegamos al máximo de participantes, detener automáticamente
      if (_registros.length >= maxParticipantes) {
        _stopwatch.stop();
        _timer?.cancel();
        _isCompleted = true;
      }

      notifyListeners();
    }
  }

  Future<void> eliminarRegistro(String idRegistro) async {
    _registros.removeWhere((r) => r.idRegistro == idRegistro);

    // Eliminar de base de datos
    try {
      await _dbService.deleteRegistro(idRegistro);
    } catch (e) {
      debugPrint('Error eliminando registro: $e');
    }

    if (_isCompleted && _registros.length < maxParticipantes) {
      _isCompleted = false;
    }
    notifyListeners();
  }

  // Obtener registros no sincronizados para enviar al servidor
  Future<List<Map<String, dynamic>>> getRegistrosNoSincronizados() async {
    try {
      return await _dbService.getRegistrosNoSincronizados();
    } catch (e) {
      debugPrint('Error obteniendo registros no sincronizados: $e');
      return [];
    }
  }

  // Marcar registros como sincronizados después de enviarlos
  Future<void> marcarComoSincronizado(String idRegistro) async {
    try {
      await _dbService.marcarComoSincronizado(idRegistro);
    } catch (e) {
      debugPrint('Error marcando como sincronizado: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }
}

