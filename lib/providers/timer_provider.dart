import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/registro_tiempo.dart';
import '../models/equipo.dart';

class TimerProvider extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<RegistroTiempo> _registros = [];
  Equipo? _equipoActual;
  bool _isCompleted = false;

  // Configuración
  static const int maxParticipantes = 15;

  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  List<RegistroTiempo> get registros => List.unmodifiable(_registros);
  bool get isRunning => _stopwatch.isRunning;
  bool get isCompleted => _isCompleted;
  Equipo? get equipoActual => _equipoActual;
  int get participantesRegistrados => _registros.length;
  bool get canAddMore => _registros.length < maxParticipantes;

  String get tiempoFormateado {
    int milliseconds = _stopwatch.elapsedMilliseconds;
    int minutes = milliseconds ~/ 60000;
    int seconds = (milliseconds % 60000) ~/ 1000;
    int ms = (milliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  void setEquipo(Equipo equipo) {
    _equipoActual = equipo;
    notifyListeners();
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

  void marcarTiempo() {
    if (_stopwatch.isRunning && _equipoActual != null && canAddMore) {
      final tiempo = _stopwatch.elapsedMilliseconds;
      final registro = RegistroTiempo(
        idRegistro: const Uuid().v4(),
        equipoId: _equipoActual!.id,
        tiempo: tiempo,
        timestamp: DateTime.now(),
      );

      _registros.add(registro);

      // Si llegamos al máximo de participantes, detener automáticamente
      if (_registros.length >= maxParticipantes) {
        _stopwatch.stop();
        _timer?.cancel();
        _isCompleted = true;
      }

      notifyListeners();
    }
  }

  void reset() {
    _stopwatch.reset();
    _timer?.cancel();
    _registros.clear();
    _isCompleted = false;
    notifyListeners();
  }

  void eliminarRegistro(String idRegistro) {
    _registros.removeWhere((r) => r.idRegistro == idRegistro);
    if (_isCompleted && _registros.length < maxParticipantes) {
      _isCompleted = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
