import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../config/theme.dart';

class DatabaseViewerModal extends StatefulWidget {
  const DatabaseViewerModal({super.key});

  @override
  State<DatabaseViewerModal> createState() => _DatabaseViewerModalState();
}

class _DatabaseViewerModalState extends State<DatabaseViewerModal> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;

  List<Map<String, dynamic>> _registros = [];
  Map<String, int> _estadisticas = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final registros = await _dbService.obtenerTodosLosRegistros();
      final stats = await _dbService.obtenerEstadisticas();

      setState(() {
        _registros = registros;
        _estadisticas = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatearTiempo(int milisegundos) {
    final duracion = Duration(milliseconds: milisegundos);
    final minutos = duracion.inMinutes;
    final segundos = duracion.inSeconds.remainder(60);
    final centesimas = (duracion.inMilliseconds.remainder(1000) / 10).floor();
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}.${centesimas.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Base de Datos Local',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Registros almacenados en SQLite',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _cargarDatos,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Estadísticas
          if (!_isLoading && _estadisticas.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total', _estadisticas['total'] ?? 0, Icons.list_alt),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                  _buildStatItem('Pendientes', _estadisticas['pendientes'] ?? 0, Icons.cloud_upload),
                  Container(width: 1, height: 30, color: Colors.white.withOpacity(0.3)),
                  _buildStatItem('Sincronizados', _estadisticas['sincronizados'] ?? 0, Icons.cloud_done),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : _buildRegistrosList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrosList() {
    if (_registros.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay registros en la base de datos',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Los tiempos marcados aparecerán aquí',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _registros.length,
      itemBuilder: (context, index) {
        final registro = _registros[index];
        final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
        final timestamp = DateTime.parse(registro['timestamp'] as String);
        final sincronizado = (registro['sincronizado'] as int) == 1;
        final tiempoFormateado = _formatearTiempo(registro['tiempo'] as int);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: sincronizado
                  ? AppTheme.secondaryColor.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              child: Icon(
                sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                color: sincronizado
                    ? AppTheme.secondaryColor
                    : Colors.orange,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(
                  tiempoFormateado,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Dorsal ${registro['equipo_dorsal']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  registro['equipo_nombre'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            trailing: sincronizado
                ? const Icon(Icons.check_circle, color: AppTheme.secondaryColor, size: 28)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'Pendiente',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
