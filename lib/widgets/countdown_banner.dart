import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';

/// Banner que muestra la cuenta regresiva hasta el inicio de la competencia
class CountdownBanner extends StatelessWidget {
  const CountdownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, timerProvider, child) {
        final competencia = timerProvider.competenciaActual;

        // No mostrar si no hay competencia o ya comenzó
        if (competencia == null || !timerProvider.competenciaPorComenzar) {
          return const SizedBox.shrink();
        }

        final tiempoRestante = timerProvider.tiempoHastaInicio;
        if (tiempoRestante == null || tiempoRestante.inSeconds <= 0) {
          return const SizedBox.shrink();
        }

        // Color según el tiempo restante
        final isUrgent = tiempoRestante.inMinutes < 5;
        final isWarning = tiempoRestante.inMinutes < 10;

        Color backgroundColor;
        Color textColor;
        IconData icon;

        if (isUrgent) {
          backgroundColor = Colors.red.shade100;
          textColor = Colors.red.shade900;
          icon = Icons.warning_amber_rounded;
        } else if (isWarning) {
          backgroundColor = Colors.orange.shade100;
          textColor = Colors.orange.shade900;
          icon = Icons.access_time;
        } else {
          backgroundColor = Colors.blue.shade100;
          textColor = Colors.blue.shade900;
          icon = Icons.schedule;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textColor.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: textColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: textColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          competencia.nombre,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Inicia en',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeUnit(
                    tiempoRestante.inHours.toString().padLeft(2, '0'),
                    'HORAS',
                    textColor,
                  ),
                  _buildSeparator(textColor),
                  _buildTimeUnit(
                    tiempoRestante.inMinutes
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0'),
                    'MINUTOS',
                    textColor,
                  ),
                  _buildSeparator(textColor),
                  _buildTimeUnit(
                    tiempoRestante.inSeconds
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0'),
                    'SEGUNDOS',
                    textColor,
                  ),
                ],
              ),
              if (isUrgent) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: textColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'El cronómetro iniciará automáticamente',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeUnit(String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
