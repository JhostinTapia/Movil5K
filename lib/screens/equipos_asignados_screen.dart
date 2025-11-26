import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/timer_provider.dart';
import '../config/theme.dart';
import '../models/equipo.dart';
import '../models/competencia.dart';
import '../widgets/countdown_banner.dart';

class EquiposAsignadosScreen extends StatefulWidget {
  const EquiposAsignadosScreen({super.key});

  @override
  State<EquiposAsignadosScreen> createState() => _EquiposAsignadosScreenState();
}

class _EquiposAsignadosScreenState extends State<EquiposAsignadosScreen>
    with SingleTickerProviderStateMixin {
  List<Equipo> equiposAsignados = [];
  Competencia? competencia;
  bool isLoading = true;
  bool _isInitialLoad = true; // Para evitar notificaciones en carga inicial
  bool? _ultimoEstadoEnCurso; // Para detectar cambios reales
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  TimerProvider? _timerProvider; // Referencia al provider

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    // Registrar listener después de que el frame se construya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _escucharEventosWebSocket();
    });
    
    _cargarEquipos();
  }

  @override
  void dispose() {
    // Remover listener del TimerProvider
    if (_timerProvider != null) {
      _timerProvider!.removeListener(_onTimerProviderChanged);
      debugPrint('🔇 Listener removido del TimerProvider');
    }
    
    _controller.dispose();
    super.dispose();
  }

  /// Escucha eventos del WebSocket para actualizar el estado de la competencia
  void _escucharEventosWebSocket() {
    _timerProvider = Provider.of<TimerProvider>(context, listen: false);
    
    debugPrint('🎧 Registrando listener para eventos de competencia');
    debugPrint('   - TimerProvider: $_timerProvider');
    
    // Escuchar cambios en el TimerProvider
    _timerProvider!.addListener(_onTimerProviderChanged);
    
    debugPrint('   ✅ Listener registrado exitosamente');
  }

  /// Callback cuando cambia el estado del TimerProvider
  void _onTimerProviderChanged() {
    if (_timerProvider == null || !mounted) return;
    
    final competenciaActual = _timerProvider!.competenciaActual;
    if (competenciaActual == null) return;
    
    final estadoActual = competenciaActual.enCurso;
    
    // Solo procesar si el estado realmente cambió
    if (_ultimoEstadoEnCurso != estadoActual) {
      debugPrint('📱 _onTimerProviderChanged() - CAMBIO DETECTADO');
      debugPrint('   - competenciaActual: ${competenciaActual.nombre}');
      debugPrint('   - Estado anterior: $_ultimoEstadoEnCurso');
      debugPrint('   - Estado actual: $estadoActual');
      
      // Guardar el nuevo estado
      final estadoAnterior = _ultimoEstadoEnCurso;
      _ultimoEstadoEnCurso = estadoActual;
      
      // Solo mostrar notificación si NO es la carga inicial y hubo cambio
      if (!_isInitialLoad && estadoAnterior != null) {
        debugPrint('   ✅ CAMBIO DE ESTADO CONFIRMADO');
        
        if (estadoActual) {
          // La competencia acaba de iniciar
          debugPrint('   🟢 Mostrando notificación: INICIADA');
          _mostrarNotificacionCompetenciaIniciada(competenciaActual);
        } else {
          // La competencia se detuvo
          debugPrint('   🔴 Mostrando notificación: DETENIDA');
          _mostrarNotificacionCompetenciaDetenida(competenciaActual);
        }
      } else {
        debugPrint('   ⏭️ No se muestra notificación (carga inicial)');
      }
      
      // Siempre actualizar el estado local
      setState(() {
        competencia = competenciaActual;
        _isInitialLoad = false;
      });
    }
  }

  /// Muestra notificación cuando la competencia inicia
  void _mostrarNotificacionCompetenciaIniciada(Competencia comp) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¡Competencia iniciada!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    comp.nombre,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Muestra notificación cuando la competencia se detiene
  void _mostrarNotificacionCompetenciaDetenida(Competencia comp) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pause,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Competencia detenida',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    comp.nombre,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _cargarEquipos() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final timerProvider = Provider.of<TimerProvider>(context, listen: false);

      // Cargar competencias desde la API
      final competencias = await authProvider.repository.getCompetencias();
      if (competencias.isNotEmpty) {
        // Obtener la competencia activa y en curso (para el banner y monitoreo general)
        competencia = competencias.firstWhere(
          (c) => c.activa && c.enCurso,
          orElse: () => competencias.firstWhere(
            (c) => c.activa,
            orElse: () => competencias.first,
          ),
        );
        // Configurar la competencia principal en el TimerProvider para monitoreo
        await timerProvider.setCompetencia(competencia!);
      }

      // Cargar TODOS los equipos asignados al juez (sin filtrar)
      final todosLosEquipos = await authProvider.repository.getEquipos();

      setState(() {
        equiposAsignados = todosLosEquipos; // Todos los equipos, sin filtrar
        isLoading = false;
      });

      // Mostrar advertencia si no hay equipos asignados
      if (todosLosEquipos.isEmpty && mounted) {
        _mostrarAdvertenciaNoEquipos();
      }

      _controller.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al cargar equipos: $e')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _cargarEquipos,
            ),
          ),
        );
      }
    }
  }
  
  void _mostrarAdvertenciaNoEquipos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sin Equipos Asignados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No tienes equipos asignados en este momento.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'Por favor, contacta al administrador para que te asigne un equipo y puedas comenzar a registrar tiempos.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarEquipo(Equipo equipo, bool enCurso) async {
    // Si la competencia no está en curso, mostrar mensaje
    if (!enCurso) {
      if (!mounted) return;
      _mostrarCompetenciaNoIniciada();
      return;
    }

    // Buscar la competencia específica del equipo
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final competencias = await authProvider.repository.getCompetencias();
      final competenciaDelEquipo = competencias.firstWhere(
        (c) => c.id == equipo.competenciaId,
        orElse: () => competencia!,
      );
      
      if (!mounted) return;
      
      // Verificar si el equipo ya tiene datos enviados
      final yaEnviado = await authProvider.repository.equipoTieneRegistrosSincronizados(equipo.id);
      
      if (yaEnviado) {
        // Si ya envió datos, ir a pantalla de resultados
        Navigator.pushNamed(
          context,
          '/resultados',
          arguments: {'equipo': equipo, 'competencia': competenciaDelEquipo},
        );
      } else {
        // Si no ha enviado, ir a pantalla de registro de tiempos
        Navigator.pushNamed(
          context,
          '/timer',
          arguments: {'equipo': equipo, 'competencia': competenciaDelEquipo},
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar competencia: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _mostrarCompetenciaNoIniciada() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.schedule, color: Colors.orange.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Competencia no iniciada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta competencia aún no ha comenzado.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'Solo puedes registrar tiempos de equipos cuya competencia esté en curso.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Retorna un mapa con el estado de la competencia de un equipo
  Future<Map<String, dynamic>> _obtenerEstadoCompetencia(Equipo equipo) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final competencias = await authProvider.repository.getCompetencias();
      final competenciaDelEquipo = competencias.firstWhere(
        (c) => c.id == equipo.competenciaId,
        orElse: () => Competencia(
          id: 0,
          nombre: 'Desconocida',
          fechaHora: DateTime.now(),
          categoria: 'estudiantes',
          activa: false,
          enCurso: false,
        ),
      );
      
      return {
        'competencia': competenciaDelEquipo,
        'enCurso': competenciaDelEquipo.enCurso,
        'activa': competenciaDelEquipo.activa,
      };
    } catch (e) {
      return {
        'competencia': null,
        'enCurso': false,
        'activa': false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: Stack(
          children: [
            // Fondo curvo decorativo
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(flex: 2, child: Container()),
                  Expanded(
                    flex: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido principal
            SafeArea(
              child: Column(
                children: [
                  // Header con información del juez
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      children: [
                        // Botón de logout
                        Row(
                          children: [
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () {
                                // Limpiar estado del timer antes de cerrar sesión
                                final timerProvider = Provider.of<TimerProvider>(context, listen: false);
                                timerProvider.clearAll();
                                
                                // Cerrar sesión
                                authProvider.logout();
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Card de información del juez
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF667eea),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Juez Asignado',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      authProvider.juez?.nombre ?? 'Sin nombre',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Título de sección
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            FontAwesomeIcons.users,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Equipos Asignados',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667eea),
                          ),
                        ),
                        const Spacer(),
                        if (!isLoading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${equiposAsignados.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Banner de cuenta regresiva
                  const CountdownBanner(),

                  const SizedBox(height: 12),

                  // Lista de equipos
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _cargarEquipos,
                      color: const Color(0xFF667eea),
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            )
                          : equiposAsignados.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF667eea,
                                        ).withOpacity(0.1),
                                        const Color(
                                          0xFF764ba2,
                                        ).withOpacity(0.1),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    FontAwesomeIcons.userGroup,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay equipos asignados',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Arrastra hacia abajo para actualizar',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                              ),
                            ),
                          )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemCount: equiposAsignados.length,
                                itemBuilder: (context, index) {
                                  final equipo = equiposAsignados[index];
                                  return _buildEquipoCard(equipo, index);
                                },
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipoCard(Equipo equipo, int index) {
    final gradientColors = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)],
      [const Color(0xFF43A047), const Color(0xFF66BB6A)],
      [const Color(0xFFFFA726), const Color(0xFFFF9800)],
      [const Color(0xFFE53935), const Color(0xFFEF5350)],
    ];

    final gradient = gradientColors[index % gradientColors.length];

    return FutureBuilder<Map<String, dynamic>>(
      future: _obtenerEstadoCompetencia(equipo),
      builder: (context, snapshot) {
        final estadoCompetencia = snapshot.data;
        final enCurso = estadoCompetencia?['enCurso'] ?? false;
        final activa = estadoCompetencia?['activa'] ?? false;
        
        // Determinar color y texto del badge de estado para la card de competencia
        Color estadoBgColor;
        Color estadoTextColor;
        String estadoTexto;
        
        if (enCurso) {
          estadoBgColor = Colors.green.shade100;
          estadoTextColor = Colors.green.shade700;
          estadoTexto = 'En Curso';
        } else if (activa) {
          estadoBgColor = Colors.orange.shade100;
          estadoTextColor = Colors.orange.shade700;
          estadoTexto = 'Programada';
        } else {
          estadoBgColor = Colors.grey.shade200;
          estadoTextColor = Colors.grey.shade700;
          estadoTexto = 'Inactiva';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de competencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        equipo.competenciaNombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: estadoBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        estadoTexto,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: estadoTextColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Tarjeta del equipo
              Opacity(
                opacity: enCurso ? 1.0 : 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: enCurso ? () => _seleccionarEquipo(equipo, enCurso) : () => _mostrarCompetenciaNoIniciada(),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: enCurso ? Colors.green.shade300 : Colors.grey.shade300,
                            width: enCurso ? 2.5 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Badge del dorsal con gradiente
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: enCurso ? gradient : [Colors.grey.shade400, Colors.grey.shade500],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: gradient[0].withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'DORSAL',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '#${equipo.dorsal}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Información del equipo
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nombre del equipo
                                  Text(
                                    equipo.nombre,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  
                                  // Badge simple de estado
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: enCurso 
                                          ? Colors.green.shade50 
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: enCurso 
                                            ? Colors.green.shade300 
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          enCurso ? Icons.check_circle : Icons.lock,
                                          size: 12,
                                          color: enCurso 
                                              ? Colors.green.shade700 
                                              : Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          enCurso ? 'Disponible' : 'Bloqueado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: enCurso 
                                                ? Colors.green.shade700 
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Icono de flecha o candado
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: enCurso ? gradient[0].withOpacity(0.1) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                enCurso ? Icons.arrow_forward_ios : Icons.lock,
                                color: enCurso ? gradient[0] : Colors.grey.shade500,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
