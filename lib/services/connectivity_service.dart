import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../config/api_config.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  // Verificar si hay conexión al servidor (red local o internet)
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Primero verificar si hay alguna conexión WiFi o móvil
      if (!connectivityResult.contains(ConnectivityResult.mobile) &&
          !connectivityResult.contains(ConnectivityResult.wifi)) {
        return false;
      }
      
      // Verificar conectividad real al servidor haciendo ping
      // Extraer host y puerto de la URL base
      final uri = Uri.parse(ApiConfig.baseUrl);
      final host = uri.host;
      final port = uri.port;
      
      try {
        // Intentar conectar al servidor con timeout de 5 segundos
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        socket.destroy();
        return true; // Hay conectividad al servidor
      } on SocketException {
        // No se puede conectar al servidor
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Stream para escuchar cambios en la conectividad
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}
