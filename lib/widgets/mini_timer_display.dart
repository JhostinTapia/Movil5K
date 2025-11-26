import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';

/// Widget compacto que muestra el cronómetro sincronizado con el equipo actual
class MiniTimerDisplay extends StatelessWidget {
  final int equipoId;
  final Color? backgroundColor;
  final Color? textColor;

  const MiniTimerDisplay({
    super.key,
    required this.equipoId,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, timerProvider, child) {
        // Verificar si este es el equipo actual en el timer provider
        final esEquipoActual = timerProvider.equipoActual?.id == equipoId;
        
        // Si no es el equipo actual, mostrar estado inactivo
        if (!esEquipoActual) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap para iniciar',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        final isRunning = timerProvider.isRunning;
        final tiempo = timerProvider.tiempoFormateado;
        final registrados = timerProvider.participantesRegistrados;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cronómetro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: backgroundColor ?? (isRunning ? Colors.green.shade50 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRunning ? Colors.green.shade300 : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRunning ? Icons.timer : Icons.timer_off,
                    size: 14,
                    color: textColor ?? (isRunning ? Colors.green.shade700 : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tiempo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? (isRunning ? Colors.green.shade700 : Colors.grey.shade600),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Contador de participantes registrados
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 12,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '$registrados/15 registrados',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
