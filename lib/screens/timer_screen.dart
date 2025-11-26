import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/timer_provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../models/equipo.dart';
import '../models/competencia.dart';
import '../widgets/time_mark_card.dart';
import '../widgets/database_viewer_modal.dart';
import '../services/connectivity_service.dart';
import '../services/websocket_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  StreamSubscription? _wsMessageSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final timerProvider = Provider.of<TimerProvider>(
          context,
          listen: false,
        );
        final equipo = args['equipo'] as Equipo;
        final competencia = args['competencia'] as Competencia?;

        // Primero establecer la competencia para que el cronómetro
        // se sincronice correctamente con el estado de ESTA competencia
        if (competencia != null) {
          await timerProvider.setCompetencia(competencia);
        }
        
        // Luego establecer el equipo
        await timerProvider.setEquipo(equipo);
        
        // Conectar el TimerProvider al WebSocket
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.juez != null) {
          timerProvider.connectWebSocket(authProvider.juez!.id);
          debugPrint('🔌 TimerProvider conectado al WebSocket');
        }
        
        // Escuchar mensajes del WebSocket (incluyendo errores)
        _subscribeToWebSocketMessages(timerProvider);
      }
    });
  }
  
  void _subscribeToWebSocketMessages(TimerProvider timerProvider) {
    // Cancelar suscripción anterior si existe
    _wsMessageSubscription?.cancel();
    
    // Obtener el stream de mensajes WebSocket desde AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messageStream = authProvider.repository.webSocketMessages;
    
    if (messageStream == null) {
      debugPrint('⚠️ No hay stream de WebSocket disponible');
      return;
    }
    
    // Escuchar mensajes del WebSocket
    _wsMessageSubscription = messageStream.listen(
      (message) {
        if (!mounted) return;
        
        // Manejar mensajes de error
        if (message.type == WebSocketMessageType.error) {
          final errorMsg = message.data['mensaje'] as String? ?? 'Error de conexión';
          final errorTecnico = message.data['error_tecnico'] as String?;
          
          _mostrarErrorWebSocket(errorMsg, errorTecnico);
        }
        // Aquí puedes agregar otros tipos de mensajes en el futuro
      },
    );
  }
  
  void _mostrarErrorWebSocket(String mensaje, String? errorTecnico) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Error de Conexión',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (errorTecnico != null && errorTecnico.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  'Detalles técnicos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorTecnico,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Volver a la pantalla de equipos
              Navigator.of(context).pop();
            },
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Intentar reconectar
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final juezId = authProvider.juez?.id;
              
              if (juezId != null) {
                try {
                  await authProvider.repository.reconnectWebSocket(juezId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reconectando...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al reconectar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _wsMessageSubscription?.cancel();
    super.dispose();
  }

  List<Color> _getEstadoColors(TimerProvider provider) {
    if (provider.isCompleted) {
      return [
        AppTheme.secondaryColor,
        AppTheme.secondaryColor.withOpacity(0.8),
      ];
    }
    if (provider.isRunning) {
      return [const Color(0xFF667eea), const Color(0xFF764ba2)];
    }
    return [Colors.grey.shade400, Colors.grey.shade500];
  }

  IconData _getEstadoIcon(TimerProvider provider) {
    if (provider.isCompleted) return Icons.check_circle;
    if (provider.isRunning) return Icons.play_circle_filled;
    return Icons.pause_circle;
  }



  void _mostrarConfirmacionEnvio(BuildContext context) async {
    final connectivityService = ConnectivityService();
    final hasInternet = await connectivityService.hasInternetConnection();

    if (!hasInternet) {
      if (context.mounted) {
        _mostrarModalSinInternet(context);
      }
      return;
    }

    // Asegurar que el WebSocket esté conectado antes de enviar
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);

    debugPrint('🔌 Verificando conexión WebSocket antes de enviar...');
    if (!timerProvider.isWebSocketConnected) {
      debugPrint('⚠️ WebSocket desconectado, intentando reconectar...');
      try {
        await authProvider.connectWebSocket();
        debugPrint('✅ WebSocket reconectado exitosamente');
      } catch (e) {
        debugPrint('❌ Error reconectando WebSocket: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Error conectando al servidor. Intente nuevamente.',
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      debugPrint('✅ WebSocket ya está conectado');
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enviar Datos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Desea enviar los datos recolectados al servidor?\n\nEsto enviará todos los registros de tiempo al servidor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _enviarDatos(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Enviar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _mostrarModalSinInternet(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sin Conexión a Internet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Para enviar los datos al servidor necesitas estar conectado a Internet.\n\nLos datos están guardados de forma segura y podrás enviarlos más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarModalExito(BuildContext context, int cantidadRegistros) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43A047).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono de éxito con animación
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),

                // Título
                const Text(
                  '¡Envío Exitoso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Cantidad de registros
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$cantidadRegistros registros sincronizados',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Todos los datos fueron sincronizados correctamente con el servidor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Botón de Aceptar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF43A047),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _enviarDatos(BuildContext context) async {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);

    // Verificar si los datos ya fueron enviados
    if (timerProvider.datosEnviados) {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Datos Ya Enviados',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Los datos de este equipo ya fueron enviados al servidor exitosamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFFA726),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Guardar referencia al Navigator ANTES de cualquier operación async
    final navigator = Navigator.of(context);

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Enviando datos...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Enviar registros por WebSocket (carga desde BD internamente)
      final resultado = await timerProvider.enviarRegistrosPorWebSocket();

      // Cerrar indicador de carga usando navigator guardado
      navigator.pop();

      // Pequeña espera para que el pop se complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Mostrar modal según el resultado
      if (resultado['success'] == true) {
        // Usar el mismo navigator para mostrar el siguiente dialog
        _mostrarModalExito(navigator.context, resultado['total'] ?? 0);
      } else {
        // Mostrar error usando navigator.context
        showDialog(
          context: navigator.context,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Error al Enviar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    resultado['message'] ?? 'Error desconocido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE53935),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Aceptar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enviando datos: $e');
      // Intentar cerrar indicador de carga si aún está abierto
      navigator.pop();

      await Future.delayed(const Duration(milliseconds: 100));

      showDialog(
        context: navigator.context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE53935), Color(0xFFEF5350)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ocurrió un error al enviar los datos: $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE53935),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _mostrarDialogPenalizacion(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    int jugadoresFaltantes = 1; // Valor inicial
    int minutosPenalizacion = 2; // Minutos de penalización por defecto

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF57C00), Color(0xFFE64A19)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),

                // Título
                const Text(
                  'Aplicar Penalización',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Configura la cantidad de jugadores faltantes y el tiempo de penalización.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 24),

                // Selector de jugadores faltantes
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Jugadores Faltantes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botón -
                          IconButton(
                            onPressed: jugadoresFaltantes > 1
                                ? () => setState(() => jugadoresFaltantes--)
                                : null,
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.white,
                            disabledColor: Colors.white.withOpacity(0.3),
                            iconSize: 36,
                          ),
                          const SizedBox(width: 20),

                          // Número
                          Container(
                            width: 70,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$jugadoresFaltantes',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF57C00),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Botón +
                          IconButton(
                            onPressed: jugadoresFaltantes < 14
                                ? () => setState(() => jugadoresFaltantes++)
                                : null,
                            icon: const Icon(Icons.add_circle),
                            color: Colors.white,
                            disabledColor: Colors.white.withOpacity(0.3),
                            iconSize: 36,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de minutos de penalización
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Minutos de Penalización',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botón -
                          IconButton(
                            onPressed: minutosPenalizacion > 1
                                ? () => setState(() => minutosPenalizacion--)
                                : null,
                            icon: const Icon(Icons.remove_circle),
                            color: Colors.white,
                            disabledColor: Colors.white.withOpacity(0.3),
                            iconSize: 36,
                          ),
                          const SizedBox(width: 20),

                          // Número
                          Container(
                            width: 70,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$minutosPenalizacion',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF57C00),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Botón +
                          IconButton(
                            onPressed: minutosPenalizacion < 30
                                ? () => setState(() => minutosPenalizacion++)
                                : null,
                            icon: const Icon(Icons.add_circle),
                            color: Colors.white,
                            disabledColor: Colors.white.withOpacity(0.3),
                            iconSize: 36,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Resumen de penalización
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Se crearán $jugadoresFaltantes registros de $minutosPenalizacion min c/u',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await timerProvider.aplicarPenalizacion(
                            jugadoresFaltantes,
                            minutosPenalizacion,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$jugadoresFaltantes registros de $minutosPenalizacion min agregados',
                                ),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFF57C00),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Aplicar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMenuOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.storage_rounded,
                color: AppTheme.primaryColor,
              ),
              title: const Text('Ver Base de Datos Local'),
              subtitle: const Text('Registros almacenados en SQLite'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const DatabaseViewerModal(),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF57C00),
              ),
              title: const Text('Aplicar Penalización'),
              subtitle: const Text('Por jugadores faltantes'),
              onTap: () {
                Navigator.pop(context);
                _mostrarDialogPenalizacion(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                Navigator.pop(context);
                
                // Limpiar estado del timer antes de cerrar sesión
                final timerProvider = Provider.of<TimerProvider>(context, listen: false);
                timerProvider.clearAll();
                
                // Cerrar sesión
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);
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
                  Expanded(flex: 3, child: Container()),
                  Expanded(
                    flex: 7,
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
                  // Header compacto
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (authProvider.juez != null)
                                Text(
                                  authProvider.juez!.nombre,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (timerProvider.equipoActual != null)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '#${timerProvider.equipoActual!.dorsal}',
                                        style: const TextStyle(
                                          color: Color(0xFF667eea),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        timerProvider.equipoActual!.nombre,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                timerProvider.participantesRegistrados >=
                                    TimerProvider.maxParticipantes
                                ? Colors.white
                                : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            '${timerProvider.participantesRegistrados}/${TimerProvider.maxParticipantes}',
                            style: TextStyle(
                              color:
                                  timerProvider.participantesRegistrados >=
                                      TimerProvider.maxParticipantes
                                  ? const Color(0xFF667eea)
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () => _mostrarMenuOpciones(context),
                        ),
                      ],
                    ),
                  ),

                  // Cronómetro e indicador de estado (ocultar si datos ya fueron enviados)
                  if (!timerProvider.datosEnviados)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Indicador de estado de la competencia
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _getEstadoColors(timerProvider),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _getEstadoColors(
                                    timerProvider,
                                  )[0].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getEstadoIcon(timerProvider),
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timerProvider.estadoCompetencia,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Cronómetro
                          Text(
                            timerProvider.tiempoFormateado,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            height: 1.1,
                            foreground: Paint()
                              ..shader =
                                  LinearGradient(
                                    colors: timerProvider.isCompleted
                                        ? [
                                            AppTheme.secondaryColor,
                                            AppTheme.secondaryColor.withOpacity(
                                              0.8,
                                            ),
                                          ]
                                        : timerProvider.isRunning
                                        ? [
                                            const Color(0xFF667eea),
                                            const Color(0xFF764ba2),
                                          ]
                                        : [
                                            Colors.grey.shade600,
                                            Colors.grey.shade500,
                                          ],
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 200, 70),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón de envío cuando hay 15 registros o está completado
                  if (timerProvider.participantesRegistrados >= 15 || timerProvider.isCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: timerProvider.datosEnviados
                              ? const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            if (!timerProvider.datosEnviados)
                              BoxShadow(
                                color: const Color(
                                  0xFF667eea,
                                ).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: timerProvider.datosEnviados
                              ? null
                              : () => _mostrarConfirmacionEnvio(context),
                          icon: Icon(
                            timerProvider.datosEnviados
                                ? Icons.check_circle
                                : Icons.cloud_upload,
                            size: 20,
                          ),
                          label: Text(
                            timerProvider.datosEnviados
                                ? 'Datos Ya Enviados'
                                : 'Enviar Data Recolectada',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Botón marcar tiempo
                  if (timerProvider.isRunning && timerProvider.canAddMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667eea).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: timerProvider.marcarTiempo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FontAwesomeIcons.flag, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'MARCAR TIEMPO',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Lista de registros
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header de registros
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF667eea),
                                        Color(0xFF764ba2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    FontAwesomeIcons.listCheck,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Registros de Tiempo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF667eea),
                                  ),
                                ),
                                const Spacer(),
                                if (timerProvider.registros.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF667eea),
                                          Color(0xFF764ba2),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${timerProvider.registros.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Lista
                          Expanded(
                            child: timerProvider.registros.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            FontAwesomeIcons.clockRotateLeft,
                                            size: 50,
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay registros',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Presiona "MARCAR TIEMPO" al\ncruce de cada participante',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    itemCount: timerProvider.registros.length,
                                    itemBuilder: (context, index) {
                                      final registro =
                                          timerProvider.registros[index];
                                      return TimeMarkCard(
                                        registro: registro,
                                        posicion: index + 1,
                                        onDelete: () =>
                                            timerProvider.eliminarRegistro(
                                              registro.idRegistro,
                                            ),
                                      );
                                    },
                                  ),
                          ),
                        ],
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
}
