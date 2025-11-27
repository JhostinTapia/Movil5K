import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/timer_provider.dart';
import '../config/theme.dart';
import '../models/equipo.dart';
import '../models/registro_tiempo.dart';
import '../widgets/time_mark_card.dart';

class ResultadosEquipoScreen extends StatefulWidget {
  const ResultadosEquipoScreen({super.key});

  @override
  State<ResultadosEquipoScreen> createState() => _ResultadosEquipoScreenState();
}

class _ResultadosEquipoScreenState extends State<ResultadosEquipoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final timerProvider = Provider.of<TimerProvider>(context, listen: false);
        final equipo = args['equipo'] as Equipo;
        
        await timerProvider.setEquipo(equipo);
      }
    });
  }

  String _formatearTiempo(int milliseconds) {
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds % 3600000) ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _calcularEstadisticas(List<RegistroTiempo> registros) {
    if (registros.isEmpty) {
      return {
        'mejorTiempo': 0,
        'peorTiempo': 0,
        'tiempoTotal': 0,
        'totalParticipantes': 0,
      };
    }

    final tiempos = registros.map((r) => r.tiempo).toList();
    
    // Filtrar tiempos válidos (excluir penalizaciones de 00:00:00.00)
    final tiemposValidos = tiempos.where((t) => t > 0).toList();
    
    final mejorTiempo = tiemposValidos.isNotEmpty 
        ? tiemposValidos.reduce((a, b) => a < b ? a : b)
        : 0;
    final peorTiempo = tiempos.reduce((a, b) => a > b ? a : b);
    final tiempoTotal = tiempos.reduce((a, b) => a + b);

    return {
      'mejorTiempo': mejorTiempo,
      'peorTiempo': peorTiempo,
      'tiempoTotal': tiempoTotal,
      'totalParticipantes': registros.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TimerProvider>(
        builder: (context, timerProvider, child) {
          if (timerProvider.equipoActual == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final estadisticas = _calcularEstadisticas(timerProvider.registros);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timerProvider.equipoActual!.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Dorsal #${timerProvider.equipoActual!.dorsal}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Datos Enviados',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Estadísticas Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Total Participantes
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildEstadisticaItem(
                                icon: FontAwesomeIcons.users,
                                label: 'Participantes',
                                valor: '${estadisticas['totalParticipantes']}',
                                color: const Color(0xFF667eea),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.grey.shade300,
                              ),
                              _buildEstadisticaItem(
                                icon: FontAwesomeIcons.trophy,
                                label: 'Mejor Tiempo',
                                valor: _formatearTiempo(estadisticas['mejorTiempo']),
                                color: const Color(0xFFE53935),
                                esTiempo: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Tiempo Total y Peor Tiempo
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.chartLine,
                                      color: const Color(0xFF43A047),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tiempo Total',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatearTiempo(estadisticas['tiempoTotal']),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF43A047),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      FontAwesomeIcons.hourglass,
                                      color: const Color(0xFFFFA726),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Más Lento',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatearTiempo(estadisticas['peorTiempo']),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFFA726),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lista de registros
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                const Icon(
                                  FontAwesomeIcons.clockRotateLeft,
                                  color: Color(0xFF667eea),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Todos los Registros',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                          Expanded(
                            child: timerProvider.registros.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.inbox,
                                          size: 60,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay registros',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    itemCount: timerProvider.registros.length,
                                    itemBuilder: (context, index) {
                                      final registro = timerProvider.registros[index];
                                      return TimeMarkCard(
                                        registro: registro,
                                        posicion: index + 1,
                                        mostrarBotonEliminar: false, // Nunca mostrar en resultados
                                        onDelete: () {}, // No hace nada
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
          );
        },
      ),
    );
  }

  Widget _buildEstadisticaItem({
    required IconData icon,
    required String label,
    required String valor,
    required Color color,
    bool esTiempo = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: esTiempo ? 16 : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
