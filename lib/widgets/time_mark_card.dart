import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/registro_tiempo.dart';
import '../config/theme.dart';

class TimeMarkCard extends StatelessWidget {
  final RegistroTiempo registro;
  final int posicion;
  final VoidCallback onDelete;

  const TimeMarkCard({
    super.key,
    required this.registro,
    required this.posicion,
    required this.onDelete,
  });

  List<Color> _getPosicionGradient(int pos) {
    if (pos == 1) {
      // Rojo - 1er lugar
      return [const Color(0xFFE53935), const Color(0xFFD32F2F)];
    }
    if (pos == 2) {
      // Rosado - 2do lugar
      return [const Color(0xFFEC407A), const Color(0xFFD81B60)];
    }
    if (pos == 3) {
      // Morado - 3er lugar
      return [const Color(0xFF7E57C2), const Color(0xFF5E35B1)];
    }
    // Naranja - resto
    return [const Color(0xFFFF6F00), const Color(0xFFE65100)];
  }

  IconData _getPosicionIcon(int pos) {
    if (pos == 1) return FontAwesomeIcons.trophy;
    if (pos == 2) return FontAwesomeIcons.medal;
    if (pos == 3) return FontAwesomeIcons.award;
    return FontAwesomeIcons.flagCheckered;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm:ss');
    final gradient = _getPosicionGradient(posicion);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Badge de posición
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getPosicionIcon(posicion),
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$posicion',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Información del tiempo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registro.tiempoFormateado,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateFormat.format(registro.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botón eliminar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.accentColor,
                              ),
                              const SizedBox(width: 12),
                              const Text('Eliminar Registro'),
                            ],
                          ),
                          content: Text(
                            '¿Desea eliminar el registro #$posicion?\n\nTiempo: ${registro.tiempoFormateado}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                onDelete();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorColor,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
