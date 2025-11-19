import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/timer_provider.dart';
import '../config/theme.dart';

class TimerDisplay extends StatelessWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.secondaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: timerProvider.isRunning
              ? AppTheme.secondaryColor
              : Colors.grey.shade300,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: timerProvider.isRunning
                ? AppTheme.secondaryColor.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Indicador de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: timerProvider.isCompleted
                  ? AppTheme.secondaryColor
                  : timerProvider.isRunning
                  ? AppTheme.accentColor
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(
                      onPlay: (controller) => timerProvider.isRunning
                          ? controller.repeat()
                          : controller.stop(),
                    )
                    .fadeIn(duration: 500.ms)
                    .then()
                    .fadeOut(duration: 500.ms),
                const SizedBox(width: 8),
                Text(
                  timerProvider.isCompleted
                      ? 'COMPLETADO'
                      : timerProvider.isRunning
                      ? 'EN CURSO'
                      : 'DETENIDO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Display del cronómetro con etiquetas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Horas
              _buildTimeUnit(
                value: timerProvider.horas.toString().padLeft(2, '0'),
                label: 'HORAS',
                isRunning: timerProvider.isRunning,
                isCompleted: timerProvider.isCompleted,
              ),
              _buildSeparator(
                timerProvider.isRunning,
                timerProvider.isCompleted,
              ),

              // Minutos
              _buildTimeUnit(
                value: timerProvider.minutos.toString().padLeft(2, '0'),
                label: 'MIN',
                isRunning: timerProvider.isRunning,
                isCompleted: timerProvider.isCompleted,
              ),
              _buildSeparator(
                timerProvider.isRunning,
                timerProvider.isCompleted,
              ),

              // Segundos
              _buildTimeUnit(
                value: timerProvider.segundos.toString().padLeft(2, '0'),
                label: 'SEG',
                isRunning: timerProvider.isRunning,
                isCompleted: timerProvider.isCompleted,
              ),
              _buildSeparator(
                timerProvider.isRunning,
                timerProvider.isCompleted,
                isDot: true,
              ),

              // Milisegundos (centésimas)
              _buildTimeUnit(
                value: (timerProvider.milisegundos ~/ 10).toString().padLeft(
                  2,
                  '0',
                ),
                label: 'CS',
                isRunning: timerProvider.isRunning,
                isCompleted: timerProvider.isCompleted,
                isSmall: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit({
    required String value,
    required String label,
    required bool isRunning,
    required bool isCompleted,
    bool isSmall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 48 : 64,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isCompleted
                ? AppTheme.secondaryColor
                : isRunning
                ? AppTheme.primaryColor
                : AppTheme.textSecondary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(
    bool isRunning,
    bool isCompleted, {
    bool isDot = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isDot ? 4 : 8,
        right: isDot ? 4 : 8,
        bottom: 20,
      ),
      child: Text(
        isDot ? '.' : ':',
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: isCompleted
              ? AppTheme.secondaryColor
              : isRunning
              ? AppTheme.primaryColor
              : AppTheme.textSecondary,
          height: 1,
        ),
      ),
    );
  }
}
