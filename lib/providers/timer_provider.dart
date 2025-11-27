import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/registro_tiempo.dart';
import '../models/equipo.dart';
import '../models/competencia.dart';
import '../repositories/app_repository.dart';
import '../services/websocket_service.dart';

/// Provider que maneja el cronómetro y los registros de tiempo
class TimerProvider extends ChangeNotifier {
  AppRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Timer? _checkTimer;
  Timer? _autoSyncTimer;
  final List<RegistroTiempo> _registros = [];
  Equipo? _equipoActual;
  Competencia? _competenciaActual;
  bool _isCompleted = false;
  bool _isSyncing = false;
  bool _datosEnviados = false;
  int _registrosPendientes = 0;
  StreamSubscription? _webSocketSubscription;
  
  // Sincronización con servidor
  DateTime? _serverStartedAt; // Timestamp de inicio desde el servidor
  DateTime? _serverFinishedAt; // Timestamp de finalización desde el servidor
  
  int _tiempoInicioOffset =
      0; // Offset para sincronizar con hora real de inicio
  Completer<Map<String, dynamic>>?
  _envioCompleter; // Para esperar respuesta del WebSocket

  TimerProvider({AppRepository? repository})
    : _repository = repository ?? AppRepository();

  /// Establece el repository compartido (llamado desde main.dart)
  void setRepository(AppRepository repository) {
    debugPrint('🔄 TimerProvider: Estableciendo repository compartido');
    _repository = repository;
  }

  // Configuración
  static const int maxParticipantes = 15;
  static const Duration autoSyncInterval = Duration(minutes: 5);

  // Getters
  int get elapsedMilliseconds {
    // Si tenemos el timestamp del servidor, calcular basándose en él
    if (_serverStartedAt != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_serverStartedAt!);
      return elapsed.inMilliseconds;
    }
    // Fallback al stopwatch local (para compatibilidad)
    return _stopwatch.elapsedMilliseconds + _tiempoInicioOffset;
  }
  List<RegistroTiempo> get registros => List.unmodifiable(_registros);
  bool get isRunning => _stopwatch.isRunning;
  bool get isCompleted => _isCompleted;
  bool get isSyncing => _isSyncing;
  Equipo? get equipoActual => _equipoActual;
  Competencia? get competenciaActual => _competenciaActual;
  int get participantesRegistrados => _registros.length;
  int get registrosPendientes => _registrosPendientes;
  bool get canAddMore => _registros.length < maxParticipantes;
  bool get hasPendingSync => _registrosPendientes > 0;
  bool get isWebSocketConnected => _repository.isWebSocketConnected;
  bool get datosEnviados => _datosEnviados;

  // Getters individuales para componentes de tiempo
  int get horas => elapsedMilliseconds ~/ 3600000;
  int get minutos => (elapsedMilliseconds % 3600000) ~/ 60000;
  int get segundos => (elapsedMilliseconds % 60000) ~/ 1000;
  int get milisegundos => elapsedMilliseconds % 1000;

  String get tiempoFormateado {
    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  // Estado de la competencia
  String get estadoCompetencia {
    if (_competenciaActual == null) return 'SIN COMPETENCIA';
    if (_isCompleted) return 'COMPLETADO';
    if (_competenciaActual!.estaEnProgreso) return 'EN CURSO';
    if (_competenciaActual!.estaPorComenzar) return 'PROGRAMADA';
    return 'INACTIVA';
  }

  // Verifica si puede marcar tiempo (competencia debe estar en curso y datos NO enviados)
  bool get puedeMarcarTiempo {
    return _stopwatch.isRunning && canAddMore && !_datosEnviados;
  }

  // Obtiene el tiempo restante hasta el inicio de la competencia
  Duration? get tiempoHastaInicio {
    if (_competenciaActual == null) return null;
    return _competenciaActual!.tiempoRestante;
  }

  // Verifica si la competencia está por comenzar en los próximos minutos
  bool get competenciaPorComenzar {
    if (_competenciaActual == null) return false;
    final restante = tiempoHastaInicio;
    return restante != null &&
        restante.inSeconds > 0 &&
        restante.inMinutes < 30;
  }

  // Formatea el tiempo restante
  String get tiempoRestanteFormateado {
    final restante = tiempoHastaInicio;
    if (restante == null || restante.inSeconds <= 0) return '00:00:00';

    final horas = restante.inHours;
    final minutos = restante.inMinutes.remainder(60);
    final segundos = restante.inSeconds.remainder(60);

    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  /// Establece el equipo actual y carga sus registros
  Future<void> setEquipo(Equipo equipo) async {
    debugPrint('👥 Estableciendo equipo: ${equipo.nombre} (ID: ${equipo.id})');
    _equipoActual = equipo;

    // Verificar si el equipo ya tiene registros sincronizados
    final yaEnviado = await _repository.equipoTieneRegistrosSincronizados(equipo.id);
    _datosEnviados = yaEnviado;
    
    if (yaEnviado) {
      debugPrint('   ⚠️ Este equipo ya tiene registros sincronizados previamente');
    }

    // Cargar registros desde BD local para continuar donde se quedó
    await reloadRegistros();

    debugPrint('   - Registros cargados desde BD: ${_registros.length}');
    debugPrint('   - Datos enviados previamente: $_datosEnviados');

    // Solo marcar como completado si los datos fueron enviados
    // NO por tener 15 registros
    if (_datosEnviados) {
      _isCompleted = true;
      debugPrint('   ✅ Equipo marcado como completado (datos ya enviados)');
    } else if (_registros.length >= maxParticipantes) {
      debugPrint(
        '   ℹ️ Ya hay ${_registros.length} registros (máx: $maxParticipantes), pero aún no se han enviado',
      );
      _isCompleted = false; // Permitir continuar hasta que se envíen
    } else {
      _isCompleted = false;
    }

    notifyListeners();
  }

  /// Establece la competencia actual y configura el monitoreo
  Future<void> setCompetencia(Competencia competencia) async {
    debugPrint('🏁 ESTABLECIENDO COMPETENCIA:');
    debugPrint('   - ID: ${competencia.id}');
    debugPrint('   - Nombre: ${competencia.nombre}');
    debugPrint('   - En curso: ${competencia.enCurso}');
    debugPrint('   - Activa: ${competencia.activa}');
    debugPrint('   - Fecha inicio: ${competencia.fechaInicio}');
    
    _competenciaActual = competencia;

    // Si la competencia ya está en curso, sincronizar con el timestamp del servidor
    if (competencia.enCurso && competencia.fechaInicio != null) {
      _serverStartedAt = competencia.fechaInicio;
      debugPrint('✅ Sincronizando con timestamp del servidor: $_serverStartedAt');
    }

    // IMPORTANTE: El cronómetro SOLO se inicia si competencia.enCurso == true
    // enCurso corresponde al campo isRunning del servidor (NO isActive)
    // - isActive (activa): indica si la competencia existe (borrado lógico)
    // - isRunning (enCurso): indica si la competencia está en curso
    if (competencia.enCurso && !_stopwatch.isRunning && !_isCompleted) {
      debugPrint(
        '🚀 La competencia está EN CURSO (isRunning=true) - Iniciando cronómetro',
      );
      start();
    } else if (!competencia.enCurso) {
      debugPrint('⏸️ La competencia NO está en curso (isRunning=false) - Cronómetro en espera');
      debugPrint('   ⚠️ Esperando mensaje WebSocket de inicio...');
    }

    await _iniciarMonitoreoCompetencia();
    notifyListeners();
  }

  /// Conecta al WebSocket para recibir notificaciones
  Future<void> connectWebSocket(int juezId) async {
    try {
      debugPrint('🔌 CONECTANDO WEBSOCKET para juez $juezId');
      if (_competenciaActual != null) {
        debugPrint('   📊 Competencia cargada: ${_competenciaActual!.nombre} (ID: ${_competenciaActual!.id})');
        debugPrint('   📊 En curso: ${_competenciaActual!.enCurso}');
      } else {
        debugPrint('   ⚠️ No hay competencia cargada aún');
      }
      
      await _repository.connectWebSocket(juezId);

      // Escuchar mensajes del WebSocket
      _webSocketSubscription = _repository.webSocketMessages?.listen(
        (message) => _handleWebSocketMessage(message),
        onError: (error) => debugPrint('Error en WebSocket: $error'),
      );

      debugPrint('✅ WebSocket listener configurado para juez $juezId');
    } catch (e) {
      debugPrint('❌ Error conectando WebSocket: $e');
    }
  }

  /// Maneja los mensajes recibidos por WebSocket
  void _handleWebSocketMessage(dynamic message) {
    // El mensaje ya viene como WebSocketMessage desde el repository
    if (message is WebSocketMessage) {
      // Ignorar mensajes de pong (heartbeat)
      if (message.type == WebSocketMessageType.pong) {
        return;
      }
      
      debugPrint('📨 Mensaje WebSocket recibido en TimerProvider');
      debugPrint('📨 Tipo: ${message.type}');
      debugPrint('📨 Datos: ${message.data}');
      
      switch (message.type) {
        case WebSocketMessageType.competenciaIniciada:
        case WebSocketMessageType.carreraIniciada:
          debugPrint('🏁 COMPETENCIA INICIADA - Iniciando cronómetro');
          _handleCarreraIniciada(message.data);
          break;
          
        case WebSocketMessageType.competenciaDetenida:
        case WebSocketMessageType.carreraDetenida:
          debugPrint('🛑 COMPETENCIA DETENIDA - Pausando cronómetro');
          _handleCarreraDetenida(message.data);
          break;
          
        case WebSocketMessageType.conexionEstablecida:
          debugPrint('✅ Conexión WebSocket establecida');
          // Si la competencia viene en curso, iniciar cronómetro
          final competencia = message.data['competencia'] as Map<String, dynamic>?;
          if (competencia != null) {
            final enCurso = competencia['en_curso'] as bool?;
            if (enCurso == true && !_stopwatch.isRunning) {
              debugPrint('🏁 Competencia ya estaba en curso - Iniciando cronómetro');
              _handleCarreraIniciada(competencia);
            }
          }
          break;
          
        case WebSocketMessageType.pong:
          // Ignorar pong - es solo respuesta al heartbeat
          break;
          
        default:
          debugPrint('Tipo de mensaje: ${message.type}');
      }
    } else {
      debugPrint('⚠️ Mensaje no es WebSocketMessage: ${message.runtimeType}');
    }
  }

  /// Maneja el evento de carrera iniciada
  void _handleCarreraIniciada(Map<String, dynamic>? data) {
    debugPrint('🏁 PROCESANDO INICIO DE COMPETENCIA');
    debugPrint('   Datos recibidos: $data');
    debugPrint('   Cronómetro corriendo: ${_stopwatch.isRunning}');
    debugPrint('   Completado: $_isCompleted');
    debugPrint('   Competencia actual: $_competenciaActual');

    // Extraer timestamp del servidor
    final startedAtStr = data?['started_at'] as String?;
    if (startedAtStr != null) {
      try {
        _serverStartedAt = DateTime.parse(startedAtStr);
        debugPrint('✅ Timestamp del servidor recibido: $_serverStartedAt');
      } catch (e) {
        debugPrint('⚠️ Error al parsear started_at: $e');
      }
    }

    // RESETEAR estado completado para permitir reiniciar
    if (_isCompleted) {
      debugPrint('🔄 Reseteando estado completado para permitir inicio');
      _isCompleted = false;
      _registros.clear();
    }

    // Actualizar estado de competencia SIEMPRE (antes de verificar cronómetro)
    if (_competenciaActual != null) {
      _competenciaActual = _competenciaActual!.copyWith(
        enCurso: true,
        fechaInicio: _serverStartedAt ?? DateTime.now(),
      );
      debugPrint('✅ Estado de competencia actualizado: EN CURSO');
    } else {
      debugPrint('⚠️ No hay competencia actual cargada');
    }

    // Iniciar cronómetro automáticamente solo si NO está corriendo
    if (!_stopwatch.isRunning && !_isCompleted) {
      debugPrint('✅ INICIANDO CRONÓMETRO AUTOMÁTICAMENTE');
      start();
    } else {
      debugPrint('⚠️ Cronómetro ya está corriendo o completado');
    }
    
    // SIEMPRE notificar para disparar listeners (incluso si ya estaba corriendo)
    debugPrint('📢 Llamando notifyListeners() para propagar cambio...');
    notifyListeners();
    debugPrint('✅ notifyListeners() ejecutado');
  }

  /// Maneja el evento de carrera detenida
  void _handleCarreraDetenida(Map<String, dynamic>? data) {
    debugPrint('🛑 PROCESANDO DETENCIÓN DE COMPETENCIA');
    debugPrint('Datos recibidos: $data');
    debugPrint('Cronómetro corriendo: ${_stopwatch.isRunning}');

    // Extraer timestamp del servidor
    final finishedAtStr = data?['finished_at'] as String?;
    if (finishedAtStr != null) {
      try {
        _serverFinishedAt = DateTime.parse(finishedAtStr);
        debugPrint('✅ Timestamp de finalización del servidor recibido: $_serverFinishedAt');
      } catch (e) {
        debugPrint('⚠️ Error al parsear finished_at: $e');
      }
    }

    // Actualizar estado de competencia SIEMPRE (antes de verificar cronómetro)
    if (_competenciaActual != null) {
      _competenciaActual = _competenciaActual!.copyWith(
        enCurso: false,
        fechaFin: _serverFinishedAt ?? DateTime.now(),
      );
      debugPrint('✅ Estado de competencia actualizado: DETENIDA');
    } else {
      debugPrint('⚠️ No hay competencia actual cargada');
    }

    // Pausar cronómetro solo si está corriendo
    if (_stopwatch.isRunning) {
      debugPrint('⏸️ PAUSANDO CRONÓMETRO AUTOMÁTICAMENTE');
      pause();
    } else {
      debugPrint('⚠️ Cronómetro ya estaba pausado');
    }
    
    // SIEMPRE notificar para disparar listeners
    debugPrint('📢 Llamando notifyListeners() para propagar cambio...');
    notifyListeners();
    debugPrint('✅ notifyListeners() ejecutado');
  }

  /// Maneja la actualización de competencia
  void _handleCompetenciaActualizada(Map<String, dynamic>? data) {
    debugPrint('Competencia actualizada: $data');
    // Aquí podrías refrescar los datos de la competencia
  }

  /// Monitorea la hora de inicio de la competencia y sincronización automática
  Future<void> _iniciarMonitoreoCompetencia() async {
    _checkTimer?.cancel();
    _autoSyncTimer?.cancel();

    // Monitorear estado de la competencia cada 1 segundo para detectar inicio exacto
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_competenciaActual != null) {
        final ahora = DateTime.now();
        final horaInicio = _competenciaActual!.fechaHora;

        // Calcular diferencia en segundos (puede ser negativa si ya pasó)
        final diferenciaSegundos = horaInicio.difference(ahora).inSeconds;

        // Log cada 10 ticks para debugging
        if (timer.tick % 10 == 0) {
          debugPrint(
            '🕐 Monitoreo: Diferencia ${diferenciaSegundos}s | Corriendo: ${_stopwatch.isRunning} | Completado: $_isCompleted',
          );
        }

        // Si ya pasó la hora o es exactamente la hora (margen de 30 segundos hacia adelante)
        // y el cronómetro no está corriendo, iniciarlo
        if (!_stopwatch.isRunning && !_isCompleted) {
          if (diferenciaSegundos <= 0 && diferenciaSegundos >= -30) {
            debugPrint(
              '⏰ Hora de inicio alcanzada (diferencia: ${diferenciaSegundos}s) - Iniciando cronómetro automáticamente',
            );
            start();
          }
        }

        // Notificar cambios para actualizar la UI del countdown
        notifyListeners();

        // Refrescar competencia desde el servidor solo si WebSocket NO está conectado (fallback)
        // Cada 10 segundos como respaldo
        if (timer.tick % 10 == 0) {
          // Solo hacer polling si WebSocket está desconectado
          final isWebSocketConnected = _repository.isWebSocketConnected;
          
          if (!isWebSocketConnected) {
            debugPrint('Polling fallback: WebSocket desconectado, consultando API');
            try {
              final competencia = await _repository.getCompetencia(
                _competenciaActual!.id,
              );
              final anteriorEnCurso = _competenciaActual!.enCurso;
              _competenciaActual = competencia;

              // Si la competencia está en curso y el cronómetro no está corriendo, iniciarlo
              if (competencia.enCurso && !_stopwatch.isRunning && !_isCompleted) {
                if (!anteriorEnCurso) {
                  debugPrint(
                    'Competencia cambió a EN CURSO - Iniciando cronómetro',
                  );
                } else {
                  debugPrint(
                    'Competencia está EN CURSO pero cronómetro detenido - Iniciando',
                  );
                }
                start();
              }
            } catch (e) {
              debugPrint('Error refrescando competencia: $e');
            }
          } else {
            // WebSocket conectado, no hacer polling
            if (timer.tick == 10) {
              debugPrint('WebSocket activo: polling deshabilitado (usando actualizaciones en tiempo real)');
            }
          }
        }
      }
    });

    // Sincronización automática cada 5 minutos
    _autoSyncTimer = Timer.periodic(autoSyncInterval, (timer) {
      if (_registrosPendientes > 0) {
        syncRegistros();
      }
    });
  }

  void start() {
    if (!_stopwatch.isRunning && !_isCompleted) {
      debugPrint('▶️ Iniciando cronómetro...');
      debugPrint('   - Stopwatch corriendo antes: ${_stopwatch.isRunning}');
      debugPrint('   - Completado: $_isCompleted');

      // SINCRONIZAR con hora de inicio real de la competencia
      if (_competenciaActual != null && _competenciaActual!.enCurso) {
        final ahora = DateTime.now();
        final horaInicio = _competenciaActual!.fechaHora;

        if (ahora.isAfter(horaInicio)) {
          // La competencia ya empezó, calcular tiempo transcurrido
          final tiempoTranscurrido = ahora.difference(horaInicio);
          _tiempoInicioOffset = tiempoTranscurrido.inMilliseconds;

          debugPrint('⏰ Sincronizando cronómetro con hora de inicio real:');
          debugPrint('   - Hora inicio: $horaInicio');
          debugPrint('   - Hora actual: $ahora');
          debugPrint(
            '   - Tiempo transcurrido: ${_tiempoInicioOffset}ms (${(_tiempoInicioOffset / 1000 / 60).toStringAsFixed(2)} min)',
          );
        } else {
          _tiempoInicioOffset = 0;
        }
      } else {
        _tiempoInicioOffset = 0;
      }

      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        notifyListeners();
      });

      debugPrint('   - Stopwatch corriendo después: ${_stopwatch.isRunning}');
      debugPrint('   - Timer activo: ${_timer?.isActive}');
      debugPrint('   - Offset inicial: $_tiempoInicioOffset ms');

      notifyListeners();
    } else {
      debugPrint('⚠️ No se puede iniciar cronómetro:');
      debugPrint('   - Ya está corriendo: ${_stopwatch.isRunning}');
      debugPrint('   - Está completado: $_isCompleted');
    }
  }

  void pause() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
      notifyListeners();
    }
  }

  /// Carga los registros guardados para el equipo actual
  Future<void> _cargarRegistrosGuardados() async {
    if (_equipoActual == null) return;

    try {
      _registros.clear();
      debugPrint('🔍 Consultando registros del equipo ${_equipoActual!.id} en BD...');
      final registrosGuardados = await _repository.getRegistrosByEquipo(
        _equipoActual!.id,
      );
      debugPrint('   📊 Registros encontrados en BD: ${registrosGuardados.length}');
      _registros.addAll(registrosGuardados);

      debugPrint('📋 Registros cargados en memoria: ${_registros.length}');
      if (_registros.isNotEmpty) {
        debugPrint('   - Primer registro: ${_registros.first.tiempoFormateado}');
        debugPrint('   - Último registro: ${_registros.last.tiempoFormateado}');
      }

      // Solo marcar como completado si los datos ya fueron enviados
      // NO por tener 15 registros
      if (_datosEnviados) {
        _isCompleted = true;
        debugPrint('   ✅ Competencia completada para este equipo (datos enviados)');
        
        // Si ya completó, detener el cronómetro si está corriendo
        if (_stopwatch.isRunning) {
          _stopwatch.stop();
          _timer?.cancel();
          debugPrint('   ⏸️ Cronómetro detenido (datos ya enviados)');
        }
      } else if (_registros.length >= maxParticipantes) {
        debugPrint(
          '   ℹ️ Ya hay ${_registros.length} registros (máx: $maxParticipantes)',
        );
        debugPrint(
          '   ⏭️ Registros pendientes de enviar - cronómetro continúa',
        );
        _isCompleted = false; // NO completado hasta que se envíen
      } else {
        _isCompleted = false;
        debugPrint(
          '   📊 Registros pendientes: ${maxParticipantes - _registros.length}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando registros: $e');
    }
  }
  /// Actualiza el estado de sincronización
  Future<void> _updateSyncStatus() async {
    if (_equipoActual == null) return;

    try {
      final status = await _repository.getSyncStatus(
        equipoId: _equipoActual!.id,
      );
      _registrosPendientes = status['pendientes'] as int;
      notifyListeners();
    } catch (e) {
      debugPrint('Error actualizando estado de sincronización: $e');
    }
  }

  /// Marca un nuevo tiempo
  Future<void> marcarTiempo() async {
    debugPrint('🏁 marcarTiempo() llamado');
    debugPrint('   - puedeMarcarTiempo: $puedeMarcarTiempo');
    debugPrint('   - isRunning: ${_stopwatch.isRunning}');
    debugPrint('   - canAddMore: $canAddMore');
    debugPrint('   - equipoActual: ${_equipoActual?.nombre}');
    debugPrint('   - registros actuales: ${_registros.length}');

    if (puedeMarcarTiempo && _equipoActual != null) {
      // Usar el getter que calcula desde el timestamp del servidor
      final tiempo = elapsedMilliseconds;
      final registro = RegistroTiempo.fromTiempoTotal(
        idRegistro: const Uuid().v4(),
        equipoId: _equipoActual!.id,
        tiempoMs: tiempo,
        timestamp: DateTime.now(),
      );

      debugPrint('   ✅ Agregando registro: ${registro.idRegistro}');
      debugPrint('      - Tiempo: $tiempo ms (${registro.tiempoFormateado})');
      debugPrint('      - Equipo: ${_equipoActual!.nombre}');

      _registros.add(registro);
      debugPrint(
        '   - Total registros en memoria: ${_registros.length}/${maxParticipantes}',
      );

      // Notificar inmediatamente para actualizar la UI
      notifyListeners();

      // GUARDAR en base de datos local
      try {
        await _repository.saveRegistroTiempo(registro, _equipoActual!);
        debugPrint('   💾 Registro guardado en BD local');
      } catch (e) {
        debugPrint('   ⚠️ Error guardando en BD local: $e');
      }

      // Ya NO detenemos el cronómetro al alcanzar el máximo
      // Solo se detendrá cuando se envíen los datos
      if (_registros.length >= maxParticipantes) {
        debugPrint(
          '   🎯 Máximo de participantes alcanzado (${_registros.length}/$maxParticipantes)',
        );
        debugPrint(
          '   ℹ️ Cronómetro sigue corriendo. Presiona "Enviar Data" para finalizar.',
        );
      }

      notifyListeners();
    } else {
      debugPrint('   ⚠️ No se puede marcar tiempo:');
      debugPrint('      - puedeMarcarTiempo: $puedeMarcarTiempo');
      debugPrint('      - equipoActual null: ${_equipoActual == null}');
    }
  }

  /// Aplica penalización por jugadores faltantes
  /// Genera N registros de tiempo ficticios con el tiempo de penalización especificado
  Future<void> aplicarPenalizacion(
    int jugadoresFaltantes,
    int minutosPenalizacion,
  ) async {
    if (_equipoActual == null ||
        jugadoresFaltantes <= 0 ||
        minutosPenalizacion < 0) {
      debugPrint('⚠️ No se puede aplicar penalización: parámetros inválidos');
      return;
    }

    debugPrint('⚖️ Aplicando penalización...');
    debugPrint('   - Jugadores faltantes: $jugadoresFaltantes');
    debugPrint('   - Minutos por registro: $minutosPenalizacion');
    debugPrint(
      '   - Total registros a crear: $jugadoresFaltantes de $minutosPenalizacion min c/u',
    );

    final penalizacionMs =
        minutosPenalizacion * 60 * 1000; // Convertir minutos a ms

    // Crear N registros (uno por cada jugador faltante)
    for (int i = 0; i < jugadoresFaltantes; i++) {
      final registro = RegistroTiempo.fromTiempoTotal(
        idRegistro: const Uuid().v4(),
        equipoId: _equipoActual!.id,
        tiempoMs: penalizacionMs,
        timestamp: DateTime.now(),
        penalizado: true,
      );

      debugPrint('   ✅ Creando registro ${i + 1}/$jugadoresFaltantes');
      debugPrint('      - ID: ${registro.idRegistro}');
      debugPrint(
        '      - Tiempo: $penalizacionMs ms (${registro.tiempoFormateado})',
      );

      _registros.add(registro);

      // Guardar en BD local
      try {
        await _repository.saveRegistroTiempo(registro, _equipoActual!);
        debugPrint('      💾 Guardado en BD local');
      } catch (e) {
        debugPrint('      ⚠️ Error guardando: $e');
      }
    }

    debugPrint(
      '   ✅ Total registros después de penalización: ${_registros.length}/$maxParticipantes',
    );

    // Notificar cambio en UI
    notifyListeners();
  }

  /// Elimina un registro de tiempo
  Future<void> eliminarRegistro(String idRegistro) async {
    final index = _registros.indexWhere((r) => r.idRegistro == idRegistro);
    if (index == -1) return;

    final registroEliminado = _registros[index];
    _registros.removeAt(index);

    try {
      await _repository.deleteRegistro(idRegistro);
      await _updateSyncStatus();

      if (_isCompleted && _registros.length < maxParticipantes) {
        _isCompleted = false;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error eliminando registro: $e');
      // Revertir si falla
      _registros.insert(index, registroEliminado);
      notifyListeners();
    }
  }

  /// Envía los registros por WebSocket cuando el juez presiona "Enviar Data"
  /// Lee los registros desde la BD local y los envía
  Future<Map<String, dynamic>> enviarRegistrosPorWebSocket() async {
    debugPrint('🚀 enviarRegistrosPorWebSocket() INICIADO');
    debugPrint('   - _isSyncing: $_isSyncing');
    debugPrint('   - _equipoActual: ${_equipoActual?.nombre}');
    debugPrint('   - _datosEnviados: $_datosEnviados');

    if (_equipoActual == null) {
      debugPrint('⚠️ No hay equipo seleccionado');
      return {'success': false, 'message': 'No hay equipo seleccionado'};
    }

    // Verificar PRIMERO si ya se enviaron los datos en esta sesión
    if (_datosEnviados) {
      debugPrint('⚠️ Los datos ya fueron enviados en esta sesión');
      return {
        'success': false, 
        'message': 'Los datos de este equipo ya fueron enviados al servidor', 
        'yaEnviado': true
      };
    }

    // Verificar en BD si el equipo ya tiene datos sincronizados
    final yaEnviado = await _repository.equipoTieneRegistrosSincronizados(_equipoActual!.id);
    if (yaEnviado) {
      debugPrint('⚠️ Los datos ya fueron enviados anteriormente (verificado en BD)');
      _datosEnviados = true; // Actualizar flag local
      return {
        'success': false, 
        'message': 'Los datos de este equipo ya fueron enviados al servidor', 
        'yaEnviado': true
      };
    }

    if (_isSyncing) {
      debugPrint('⚠️ Envío ya en progreso');
      return {'success': false, 'message': 'Envío en progreso'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      // Verificar si WebSocket está conectado
      debugPrint('🔌 Verificando WebSocket...');
      debugPrint(
        '   - isWebSocketConnected: ${_repository.isWebSocketConnected}',
      );

      if (!_repository.isWebSocketConnected) {
        _isSyncing = false;
        notifyListeners();
        debugPrint('❌ WebSocket NO conectado');
        return {
          'success': false,
          'message': 'WebSocket no conectado. Verifica tu conexión.',
        };
      }

      // CARGAR registros desde BD local (no sincronizados)
      debugPrint('📋 Cargando registros desde BD local...');
      debugPrint('   - Equipo ID: ${_equipoActual!.id}');
      final registrosDB = await _repository.getRegistrosByEquipo(
        _equipoActual!.id,
      );

      if (registrosDB.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return {'success': false, 'message': 'No hay registros para enviar'};
      }

      debugPrint(
        '📤 Enviando ${registrosDB.length} registros por WebSocket...',
      );

      // Construir payload desde los registros de BD
      final payload = {
        'tipo': 'registrar_tiempos',
        'equipo_id': _equipoActual!.id,
        'registros': registrosDB
            .map(
              (r) => {
                'tiempo': r.tiempo,
                'horas': r.horas,
                'minutos': r.minutos,
                'segundos': r.segundos,
                'milisegundos': r.milisegundos,
              },
            )
            .toList(),
      };

      debugPrint('📦 Payload a enviar:');
      debugPrint('   - tipo: ${payload['tipo']}');
      debugPrint('   - equipo_id: ${payload['equipo_id']}');
      debugPrint(
        '   - registros count: ${(payload['registros'] as List).length}',
      );
      debugPrint(
        '   - primer registro: ${(payload['registros'] as List).first}',
      );

      // Crear completer para esperar respuesta
      _envioCompleter = Completer<Map<String, dynamic>>();

      // Escuchar mensajes WebSocket UNA VEZ para esta respuesta
      StreamSubscription? responseSubscription;
      responseSubscription = _repository.webSocketMessages?.listen((message) {
        debugPrint('📩 Mensaje recibido en envío: ${message.type}');

        if (message.type == WebSocketMessageType.tiemposRegistradosBatch) {
          final data = message.data;
          final totalGuardados = data['total_guardados'] as int? ?? 0;
          final totalFallidos = data['total_fallidos'] as int? ?? 0;

          debugPrint('✅ Respuesta del servidor:');
          debugPrint('   - Guardados: $totalGuardados');
          debugPrint('   - Fallidos: $totalFallidos');

          // Completar con resultado
          if (!_envioCompleter!.isCompleted) {
            _envioCompleter!.complete({
              'success': totalFallidos == 0,
              'message': totalFallidos == 0
                  ? 'Registros enviados exitosamente'
                  : 'Algunos registros fallaron',
              'total': totalGuardados,
              'fallidos': totalFallidos,
            });
          }

          // Cancelar suscripción
          responseSubscription?.cancel();
        }
      });

      // Enviar por WebSocket
      _repository.sendWebSocketMessage(payload);

      debugPrint('✅ Registros enviados por WebSocket, esperando respuesta...');

      // Esperar respuesta con timeout de 10 segundos
      debugPrint('⏳ Esperando respuesta del completer...');
      final resultado = await _envioCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Timeout esperando respuesta del servidor');
          responseSubscription?.cancel();
          return {
            'success': false,
            'message': 'Timeout: El servidor no respondió a tiempo',
          };
        },
      );

      debugPrint('📦 Resultado recibido del completer: $resultado');

      // Si fue exitoso, marcar registros como sincronizados
      if (resultado['success'] == true) {
        debugPrint('✅ Marcando registros como sincronizados...');
        for (final registro in registrosDB) {
          try {
            await _repository.marcarComoSincronizado(registro.idRegistro);
          } catch (e) {
            debugPrint('⚠️ Error marcando registro como sincronizado: $e');
          }
        }
        debugPrint('✅ Todos los registros marcados como sincronizados');
        
        // Marcar que los datos fueron enviados exitosamente
        _datosEnviados = true;
        
        // AHORA SÍ detener el cronómetro y marcar como completado
        if (_stopwatch.isRunning) {
          _stopwatch.stop();
          _timer?.cancel();
          debugPrint('⏸️ Cronómetro detenido tras envío exitoso');
        }
        _isCompleted = true;
        debugPrint('✅ Proceso completado - datos enviados y cronómetro detenido');
      }

      _isSyncing = false;
      _envioCompleter = null;
      notifyListeners();

      debugPrint('🎉 Retornando resultado final: $resultado');
      return resultado;
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR CRÍTICO en enviarRegistrosPorWebSocket: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _isSyncing = false;
      notifyListeners();

      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Sincroniza los registros pendientes con el servidor (solo marca como sincronizados en BD local)
  /// NOTA: Este método ya no se usa para enviar, solo para marcar como sincronizados
  Future<Map<String, dynamic>> syncRegistros() async {
    if (_isSyncing) {
      return {'success': false, 'message': 'Sincronización en progreso'};
    }

    if (_equipoActual == null) {
      return {'success': false, 'message': 'No hay equipo seleccionado'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _repository.syncRegistros(
        equipoId: _equipoActual!.id,
      );
      await _updateSyncStatus();

      _isSyncing = false;
      notifyListeners();

      return result;
    } catch (e) {
      debugPrint('Error en sincronización: $e');
      _isSyncing = false;
      notifyListeners();

      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Recarga los registros desde la base de datos
  Future<void> reloadRegistros() async {
    await _cargarRegistrosGuardados();
    await _updateSyncStatus();
  }

  /// Reinicia el cronómetro y limpia los registros
  Future<void> reset() async {
    _stopwatch.reset();
    _timer?.cancel();
    _isCompleted = false;

    // No limpiar registros de la base de datos, solo de la memoria
    _registros.clear();
    await _cargarRegistrosGuardados();

    notifyListeners();
  }
  
  /// Limpia completamente el estado (usado en logout)
  void clearAll() {
    debugPrint('🧹 TimerProvider: Limpiando todo el estado (logout)');
    
    // Detener cronómetro
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
    _stopwatch.reset();
    
    // Cancelar todos los timers
    _timer?.cancel();
    _timer = null;
    _checkTimer?.cancel();
    _checkTimer = null;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    
    // Cancelar suscripción WebSocket
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    
    // Limpiar datos
    _registros.clear();
    _equipoActual = null;
    _competenciaActual = null;
    _isCompleted = false;
    _isSyncing = false;
    _registrosPendientes = 0;
    _tiempoInicioOffset = 0;
    _envioCompleter = null;
    
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkTimer?.cancel();
    _autoSyncTimer?.cancel();
    _webSocketSubscription?.cancel();
    _repository.disconnectWebSocket();
    super.dispose();
  }
}
