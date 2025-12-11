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
  bool _marcandoTiempo = false; // Lock para evitar doble-click
  Equipo? _equipoActual;
  Competencia? _competenciaActual;
  bool _isCompleted = false;
  bool _isSyncing = false;
  bool _datosEnviados = false;
  int _registrosPendientes = 0;
  StreamSubscription? _webSocketSubscription;
  
  // ========== PROTECCIÓN CONTRA OPERACIONES CONCURRENTES ==========
  bool _isLoadingEquipo = false; // Bloqueo para setEquipo
  bool _isLoadingRegistros = false; // Bloqueo para carga de registros
  int? _equipoEnCarga; // ID del equipo siendo cargado
  
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
  bool get marcandoTiempo => _marcandoTiempo; // Exponer estado del lock

  /// Marca manualmente los datos como enviados
  /// Útil cuando el servidor confirma que ya tiene los registros (error 409)
  void marcarComoEnviado() {
    _datosEnviados = true;
    _isCompleted = true;
    notifyListeners();
    debugPrint('✅ Datos marcados como enviados manualmente');
  }

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
  /// PROTEGIDO contra llamadas concurrentes para evitar duplicación
  Future<void> setEquipo(Equipo equipo) async {
    // ========== PROTECCIÓN CRÍTICA CONTRA LLAMADAS CONCURRENTES ==========
    if (_isLoadingEquipo) {
      debugPrint(
        '⚠️ BLOQUEADO setEquipo: Ya hay una carga de equipo en proceso',
      );
      return;
    }

    // Si es el mismo equipo que ya está cargado, verificar si ya terminó de cargar
    if (_equipoEnCarga == equipo.id) {
      debugPrint(
        '⚠️ BLOQUEADO setEquipo: Equipo ${equipo.id} ya está siendo cargado',
      );
      return;
    }

    // Si ya es el equipo actual y ya cargó, no recargar innecesariamente
    if (_equipoActual?.id == equipo.id &&
        !_isLoadingEquipo &&
        _registros.isNotEmpty) {
      debugPrint(
        'ℹ️ Equipo ${equipo.id} ya está cargado con ${_registros.length} registros',
      );
      return;
    }

    // Activar bloqueos
    _isLoadingEquipo = true;
    _equipoEnCarga = equipo.id;

    debugPrint(
      '🔒 Iniciando carga de equipo: ${equipo.nombre} (ID: ${equipo.id})',
    );

    try {
      // IMPORTANTE: Resetear TODO el estado ANTES de cualquier operación
      // Esto evita que la UI muestre estados residuales del equipo anterior
      _datosEnviados = false;
      _isCompleted = false;
      _registros.clear();
      _equipoActual = equipo;
      
      // Notificar inmediatamente para que la UI muestre estado limpio
      notifyListeners();
      debugPrint('   🧹 Estado reseteado: datosEnviados=false, isCompleted=false, registros=0');

      // Verificar SOLO en BD local si hay registros sincronizados
      // La app móvil es la fuente de verdad - NUNCA consulta registros del servidor
      final yaEnviado = await _repository.equipoTieneRegistrosSincronizados(equipo.id);
      _datosEnviados = yaEnviado;
      
      if (yaEnviado) {
        debugPrint('   ✅ Registros ya sincronizados (BD local)');
      }

      // Cargar registros desde BD local
      await reloadRegistros();

      debugPrint('   - Registros cargados: ${_registros.length}');
      debugPrint('   - Datos enviados: $_datosEnviados');

      // Solo marcar como completado si los datos fueron enviados
      if (_datosEnviados) {
        _isCompleted = true;
        debugPrint('   ✅ Equipo marcado como completado (datos ya enviados)');
      } else if (_registros.length >= maxParticipantes) {
        debugPrint(
          '   ℹ️ Ya hay ${_registros.length} registros, pero aún no se han enviado',
        );
        _isCompleted = false;
      } else {
        _isCompleted = false;
        debugPrint('   📝 Equipo listo para registrar tiempos');
      }

      notifyListeners();
    } finally {
      // SIEMPRE liberar bloqueos
      _isLoadingEquipo = false;
      _equipoEnCarga = null;
      debugPrint('🔓 Carga de equipo completada');
    }
  }

  /// Establece la competencia actual y configura el monitoreo
  Future<void> setCompetencia(Competencia competencia) async {
    debugPrint('🏁 ESTABLECIENDO COMPETENCIA:');
    debugPrint('   - ID: ${competencia.id}');
    debugPrint('   - Nombre: ${competencia.nombre}');
    debugPrint('   - En curso: ${competencia.enCurso}');
    debugPrint('   - Activa: ${competencia.activa}');
    debugPrint('   - Fecha inicio: ${competencia.fechaInicio}');
    
    // ========== RESETEAR ESTADO ANTES DE CAMBIAR DE COMPETENCIA ==========
    // Esto es CRÍTICO para evitar que el tiempo de una competencia
    // se muestre en otra competencia diferente
    if (_competenciaActual != null && _competenciaActual!.id != competencia.id) {
      debugPrint('🔄 Cambiando de competencia ${_competenciaActual!.id} a ${competencia.id}');
      debugPrint('   🧹 Reseteando estado del cronómetro...');
      
      // Detener el cronómetro si está corriendo
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
      }
      
      // Resetear el stopwatch
      _stopwatch.reset();
      
      // Limpiar timestamps del servidor
      _serverStartedAt = null;
      _serverFinishedAt = null;
      _tiempoInicioOffset = 0;
      
      debugPrint('   ✅ Estado reseteado: stopwatch=0, serverStartedAt=null');
    }
    
    _competenciaActual = competencia;

    // Si la competencia ya está en curso, sincronizar con el timestamp del servidor
    if (competencia.enCurso && competencia.fechaInicio != null) {
      _serverStartedAt = competencia.fechaInicio;
      debugPrint('✅ Sincronizando con timestamp del servidor: $_serverStartedAt');
    } else {
      // Si NO está en curso, asegurarse de que no hay timestamp
      _serverStartedAt = null;
      debugPrint('⏸️ Competencia no iniciada - sin timestamp de servidor');
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
  /// PROTEGIDO contra llamadas concurrentes con Set para garantizar unicidad
  Future<void> _cargarRegistrosGuardados() async {
    if (_equipoActual == null) return;

    // ========== PROTECCIÓN CONTRA CARGA CONCURRENTE ==========
    if (_isLoadingRegistros) {
      debugPrint(
        '⚠️ BLOQUEADO _cargarRegistrosGuardados: Ya hay una carga en proceso',
      );
      return;
    }

    _isLoadingRegistros = true;
    debugPrint(
      '🔒 Iniciando carga de registros para equipo ${_equipoActual!.id}',
    );

    try {
      debugPrint(
        '🔍 Consultando registros del equipo ${_equipoActual!.id} en BD...',
      );
      final registrosGuardados = await _repository.getRegistrosByEquipo(
        _equipoActual!.id,
      );
      debugPrint(
        '   📊 Registros encontrados en BD: ${registrosGuardados.length}',
      );

      // LIMPIEZA ATÓMICA: Limpiar y agregar en una sola operación
      _registros.clear();

      // DEDUPLICACIÓN: Usar Set para garantizar unicidad por idRegistro
      final Set<String> idsAgregados = {};
      for (final registro in registrosGuardados) {
        if (!idsAgregados.contains(registro.idRegistro)) {
          _registros.add(registro);
          idsAgregados.add(registro.idRegistro);
        } else {
          debugPrint(
            '   ⚠️ Registro duplicado detectado y omitido: ${registro.idRegistro}',
          );
        }
      }

      debugPrint('📋 Registros cargados en memoria: ${_registros.length}');
      if (_registros.isNotEmpty) {
        debugPrint(
          '   - Primer registro: ${_registros.first.tiempoFormateado}',
        );
        debugPrint('   - Último registro: ${_registros.last.tiempoFormateado}');
      }

      // Solo marcar como completado si los datos ya fueron enviados
      // NO por tener 15 registros
      if (_datosEnviados) {
        _isCompleted = true;
        debugPrint(
          '   ✅ Competencia completada para este equipo (datos enviados)',
        );

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
    } finally {
      // SIEMPRE liberar el bloqueo
      _isLoadingRegistros = false;
      debugPrint('🔓 Carga de registros completada');
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

  /// Refresca los datos desde la base de datos local
  /// Usado por pull-to-refresh para dar confianza al usuario
  Future<void> refrescarDatos() async {
    if (_equipoActual == null) return;
    
    debugPrint('🔄 Refrescando datos...');
    
    try {
      // Recargar registros desde BD
      await _cargarRegistrosGuardados();
      
      // Actualizar estado de sincronización
      await _updateSyncStatus();
      
      // Verificar si los datos ya fueron enviados
      final yaEnviado = await _repository.equipoTieneRegistrosSincronizados(_equipoActual!.id);
      if (yaEnviado && !_datosEnviados) {
        _datosEnviados = true;
        _isCompleted = true;
        debugPrint('   ✅ Datos ya sincronizados detectados');
      }
      
      debugPrint('   ✅ Datos refrescados: ${_registros.length} registros');
      notifyListeners();
    } catch (e) {
      debugPrint('   ❌ Error al refrescar: $e');
    }
  }

  /// Marca un nuevo tiempo
  /// PROTECCIÓN: Lock para evitar doble-click y validación estricta del límite
  Future<void> marcarTiempo() async {
    // LOCK: Evitar doble-click
    if (_marcandoTiempo) {
      debugPrint('⚠️ marcarTiempo() ignorado - ya hay una operación en curso');
      return;
    }
    
    _marcandoTiempo = true;
    // NO llamar notifyListeners aquí para evitar parpadeo
    
    try {
      debugPrint('🏁 marcarTiempo() llamado');
      debugPrint('   - registros actuales: ${_registros.length}');

      // VALIDACIÓN ESTRICTA: Verificar límite en memoria
      if (_registros.length >= maxParticipantes) {
        debugPrint('❌ LÍMITE ALCANZADO en memoria: ${_registros.length}/$maxParticipantes');
        return;
      }
      
      // Verificar también en BD (por si hay inconsistencia)
      if (_equipoActual != null) {
        final registrosEnBD = await _repository.getRegistrosByEquipo(_equipoActual!.id);
        if (registrosEnBD.length >= maxParticipantes) {
          debugPrint('❌ LÍMITE ALCANZADO en BD: ${registrosEnBD.length}/$maxParticipantes');
          // Sincronizar memoria con BD
          _registros.clear();
          _registros.addAll(registrosEnBD);
          notifyListeners();
          return;
        }
      }

      if (puedeMarcarTiempo && _equipoActual != null) {
        // Usar el getter que calcula desde el timestamp del servidor
        final tiempo = elapsedMilliseconds;
        final registro = RegistroTiempo.fromTiempoTotal(
          idRegistro: const Uuid().v4(),
          equipoId: _equipoActual!.id,
          tiempoMs: tiempo,
          timestamp: DateTime.now(),
        );

        debugPrint('   ✅ Agregando registro: ${registro.tiempoFormateado}');

        // GUARDAR en base de datos local PRIMERO (con validación)
        final guardadoExitoso = await _repository.saveRegistroTiempo(registro, _equipoActual!);
        
        if (!guardadoExitoso) {
          debugPrint('   ❌ No se pudo guardar - límite alcanzado en BD');
          await _cargarRegistrosGuardados();
          return;
        }
        
        // Solo agregar a memoria si se guardó exitosamente
        _registros.add(registro);
        debugPrint('   💾 Guardado: ${_registros.length}/$maxParticipantes');

        if (_registros.length >= maxParticipantes) {
          debugPrint('   🎯 Máximo alcanzado - listo para enviar');
        }

        // UN SOLO notifyListeners al final
        notifyListeners();
      } else {
        debugPrint('   ⚠️ No se puede marcar tiempo');
      }
    } finally {
      _marcandoTiempo = false;
      // NO llamar notifyListeners aquí - ya se llamó arriba si hubo cambios
    }
  }

  /// Aplica penalización por jugadores faltantes
  /// Genera N registros de tiempo ficticios con el tiempo de penalización especificado
  /// PROTECCIÓN: Valida que no se excedan los 15 registros máximos
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
    
    // VALIDACIÓN CRÍTICA: No permitir superar el límite
    final registrosActuales = _registros.length;
    final espacioDisponible = maxParticipantes - registrosActuales;
    
    if (espacioDisponible <= 0) {
      debugPrint('❌ No hay espacio para penalizaciones. Ya hay $registrosActuales/$maxParticipantes registros');
      return;
    }
    
    // Limitar la cantidad de penalizaciones al espacio disponible
    final penalizacionesAAplicar = jugadoresFaltantes > espacioDisponible 
        ? espacioDisponible 
        : jugadoresFaltantes;
    
    if (penalizacionesAAplicar != jugadoresFaltantes) {
      debugPrint('⚠️ Ajustando penalizaciones: solicitadas=$jugadoresFaltantes, aplicables=$penalizacionesAAplicar');
    }

    debugPrint('⚖️ Aplicando penalización...');
    debugPrint('   - Registros actuales: $registrosActuales/$maxParticipantes');
    debugPrint('   - Espacio disponible: $espacioDisponible');
    debugPrint('   - Penalizaciones a aplicar: $penalizacionesAAplicar');
    debugPrint('   - Minutos por registro: $minutosPenalizacion');

    final penalizacionMs =
        minutosPenalizacion * 60 * 1000; // Convertir minutos a ms

    // Crear N registros (uno por cada jugador faltante, limitado al espacio disponible)
    for (int i = 0; i < penalizacionesAAplicar; i++) {
      // Verificar antes de cada inserción
      if (_registros.length >= maxParticipantes) {
        debugPrint('❌ Límite alcanzado durante penalización. Deteniendo.');
        break;
      }
      
      final registro = RegistroTiempo.fromTiempoTotal(
        idRegistro: const Uuid().v4(),
        equipoId: _equipoActual!.id,
        tiempoMs: penalizacionMs,
        timestamp: DateTime.now(),
        penalizado: true,
      );

      debugPrint('   ✅ Creando registro ${i + 1}/$penalizacionesAAplicar');
      debugPrint('      - ID: ${registro.idRegistro}');
      debugPrint(
        '      - Tiempo: $penalizacionMs ms (${registro.tiempoFormateado})',
      );

      // Guardar en BD local PRIMERO (con validación)
      final guardadoExitoso = await _repository.saveRegistroTiempo(registro, _equipoActual!);
      
      if (!guardadoExitoso) {
        debugPrint('      ❌ No se pudo guardar - límite alcanzado');
        break; // Detener el loop
      }
      
      _registros.add(registro);
      debugPrint('      💾 Guardado en BD local');
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

  /// Envía los registros por HTTP cuando el juez presiona "Enviar Data"
  /// Lee los registros desde la BD local y los envía por HTTP POST
  /// (más confiable que WebSocket para operaciones de guardado)
  Future<Map<String, dynamic>> enviarRegistrosPorWebSocket() async {
    debugPrint('🚀 enviarRegistrosPorHttp() INICIADO');
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

    // CARGAR registros desde BD local para validación ANTES de iniciar sincronización
    debugPrint('📋 Validando registros desde BD local...');
    final registrosDB = await _repository.getRegistrosByEquipo(_equipoActual!.id);
    
    // VALIDACIÓN CRÍTICA 1: Verificar que hay exactamente 15 registros
    if (registrosDB.length != maxParticipantes) {
      debugPrint('❌ VALIDACIÓN FALLIDA: Se requieren exactamente $maxParticipantes registros');
      debugPrint('   - Registros actuales: ${registrosDB.length}');
      return {
        'success': false,
        'message': 'Se requieren exactamente $maxParticipantes registros. Tienes ${registrosDB.length}.',
      };
    }
    
    // VALIDACIÓN CRÍTICA 2: Verificar que todos los registros pertenecen al equipo actual
    final registrosInvalidos = registrosDB.where((r) => r.equipoId != _equipoActual!.id).toList();
    if (registrosInvalidos.isNotEmpty) {
      debugPrint('❌ VALIDACIÓN FALLIDA: Hay registros de otro equipo');
      debugPrint('   - Registros inválidos: ${registrosInvalidos.length}');
      return {
        'success': false,
        'message': 'Error de consistencia: Los registros no coinciden con el equipo actual',
      };
    }
    
    // VALIDACIÓN CRÍTICA 3: Verificar que ningún registro está ya sincronizado
    final registrosSincronizados = registrosDB.where((r) => r.sincronizado).toList();
    if (registrosSincronizados.isNotEmpty) {
      debugPrint('❌ VALIDACIÓN FALLIDA: Hay registros ya sincronizados');
      debugPrint('   - Registros sincronizados: ${registrosSincronizados.length}');
      _datosEnviados = true; // Marcar como enviados
      return {
        'success': false,
        'message': 'Los datos de este equipo ya fueron enviados al servidor',
        'yaEnviado': true
      };
    }
    
    debugPrint('✅ Validaciones pasadas: ${registrosDB.length} registros válidos');

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('📤 Enviando ${registrosDB.length} registros por HTTP...');

      // Enviar por HTTP usando el nuevo método del repository
      final resultado = await _repository.enviarRegistrosPorHttp(
        equipoId: _equipoActual!.id,
        registros: registrosDB,
      );

      debugPrint('📦 Resultado del servidor: $resultado');

      // Si fue exitoso, marcar como completado
      if (resultado['success'] == true) {
        debugPrint('✅ Registros enviados exitosamente');
        
        // Los registros ya fueron marcados como sincronizados en el SyncService
        _datosEnviados = true;
        
        // Detener el cronómetro y marcar como completado
        if (_stopwatch.isRunning) {
          _stopwatch.stop();
          _timer?.cancel();
          debugPrint('⏸️ Cronómetro detenido tras envío exitoso');
        }
        _isCompleted = true;
        debugPrint('✅ Proceso completado - datos enviados y cronómetro detenido');
      }

      _isSyncing = false;
      notifyListeners();

      debugPrint('🎉 Retornando resultado final: $resultado');
      return {
        'success': resultado['success'] ?? false,
        'message': resultado['success'] == true 
            ? 'Registros enviados exitosamente' 
            : (resultado['errores']?.isNotEmpty == true 
                ? resultado['errores'].first 
                : 'Error al enviar registros'),
        'total': resultado['exitosos'] ?? 0,
        'fallidos': resultado['fallidos'] ?? 0,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR en enviarRegistrosPorHttp: $e');
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
