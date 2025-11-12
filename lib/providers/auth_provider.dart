import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/juez.dart';

class AuthProvider extends ChangeNotifier {
  Juez? _juez;
  bool _isLoading = false;

  Juez? get juez => _juez;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _juez != null;

  Future<void> login(String nombre, int competenciaId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulación de login - aquí irá la llamada al API
      await Future.delayed(const Duration(seconds: 1));

      _juez = Juez(
        id: 1,
        nombre: nombre,
        competenciaId: competenciaId,
        activo: true,
      );

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('juez_nombre', nombre);
      await prefs.setInt('juez_id', 1);
      await prefs.setInt('competencia_id', competenciaId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('juez_nombre');
    final id = prefs.getInt('juez_id');
    final competenciaId = prefs.getInt('competencia_id');

    if (nombre != null && id != null && competenciaId != null) {
      _juez = Juez(
        id: id,
        nombre: nombre,
        competenciaId: competenciaId,
        activo: true,
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _juez = null;
    notifyListeners();
  }
}
