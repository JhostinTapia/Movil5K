import 'package:flutter/material.dart';
import '../models/juez.dart';
import '../models/competencia.dart';
import '../repositories/app_repository.dart';

/// Provider que maneja el estado de autenticación del juez
class AuthProvider extends ChangeNotifier {
  final AppRepository _repository;

  Juez? _juez;
  List<Competencia> _competencias = [];
  bool _isLoading = false;
  String? _error;

  AuthProvider({AppRepository? repository})
    : _repository = repository ?? AppRepository();

  // Getters
  Juez? get juez => _juez;
  List<Competencia> get competencias => _competencias;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _juez != null;
  String? get error => _error;
  AppRepository get repository => _repository;

  /// Inicia sesión con username y password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.login(username, password);

      _juez = result['juez'] as Juez;
      _competencias = result['competencias'] as List<Competencia>;

      _isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Intenta restaurar la sesión guardada
  Future<void> loadSavedSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasSession = await _repository.hasSession();

      if (hasSession) {
        _juez = await _repository.restoreSession();

        if (_juez != null) {
          // Cargar competencias
          _competencias = await _repository.getCompetencias();

          // Conectar WebSocket automáticamente al restaurar sesión
          debugPrint('🔌 Restaurando sesión - Conectando WebSocket...');
          try {
            await connectWebSocket();
            debugPrint('✅ WebSocket conectado al restaurar sesión');
          } catch (e) {
            debugPrint('⚠️ Error conectando WebSocket al restaurar: $e');
            // No fallar la restauración de sesión si el WebSocket falla
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando sesión: $e');
      _juez = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cierra sesión
  Future<void> logout() async {
    try {
      await _repository.logout();
      _juez = null;
      _competencias = [];
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error en logout: $e');
    }
  }

  /// Refresca el access token
  Future<void> refreshToken() async {
    try {
      await _repository.refreshAccessToken();
    } catch (e) {
      debugPrint('Error refrescando token: $e');
      // Si falla el refresh, cerrar sesión
      await logout();
    }
  }

  /// Actualiza la lista de competencias
  Future<void> refreshCompetencias() async {
    try {
      _competencias = await _repository.getCompetencias();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refrescando competencias: $e');
    }
  }

  /// Conecta el WebSocket para recibir notificaciones en tiempo real
  Future<void> connectWebSocket() async {
    if (_juez == null) {
      debugPrint('⚠️ No se puede conectar WebSocket: no hay juez autenticado');
      return;
    }

    try {
      await _repository.connectWebSocket(_juez!.id);
      debugPrint('✅ WebSocket conectado para juez ${_juez!.id}');
    } catch (e) {
      debugPrint('❌ Error conectando WebSocket: $e');
      rethrow;
    }
  }

  /// Limpia el error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Obtiene un mensaje de error amigable
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('networkexception') ||
        errorStr.contains('failed host lookup')) {
      return 'No hay conexión a internet. Verifica tu red WiFi.';
    }

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Usuario o contraseña incorrectos';
    }

    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'Usuario inactivo. Contacta al administrador';
    }
    
    if (errorStr.contains('no tienes equipos asignados')) {
      return 'No tienes equipos asignados. Contacta al administrador';
    }
    
    if (errorStr.contains('no tienes competencias activas') || 
        errorStr.contains('competencia no está activa')) {
      return 'No hay competencias activas. Contacta al administrador';
    }

    if (errorStr.contains('500') || errorStr.contains('internal server error')) {
      return 'Error en el servidor. Intenta más tarde';
    }

    if (errorStr.contains('timeoutexception') || errorStr.contains('timed out')) {
      return 'La solicitud tardó demasiado. Intenta nuevamente';
    }
    
    if (errorStr.contains('connection refused')) {
      return 'No se puede conectar al servidor. Verifica la configuración';
    }

    return 'Error al iniciar sesión. Por favor intenta nuevamente';
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
