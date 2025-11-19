import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/juez.dart';

/// Servicio de almacenamiento local seguro
/// Usa SharedPreferences para persistir datos
class StorageService {
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyJuez = 'juez_data';
  static const String _keyLastSync = 'last_sync';

  /// Guardar tokens de autenticación
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  /// Guardar solo el access token
  Future<void> saveAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
  }

  /// Obtener access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  /// Obtener refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  /// Guardar información del juez
  Future<void> saveJuez(Juez juez) async {
    final prefs = await SharedPreferences.getInstance();
    final juezJson = json.encode(juez.toJson());
    await prefs.setString(_keyJuez, juezJson);
  }

  /// Obtener información del juez
  Future<Juez?> getJuez() async {
    final prefs = await SharedPreferences.getInstance();
    final juezJson = prefs.getString(_keyJuez);

    if (juezJson == null) return null;

    try {
      final juezMap = json.decode(juezJson) as Map<String, dynamic>;
      return Juez.fromJson(juezMap);
    } catch (e) {
      return null;
    }
  }

  /// Guardar fecha de última sincronización
  Future<void> saveLastSyncTime(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSync, dateTime.toIso8601String());
  }

  /// Obtener fecha de última sincronización
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_keyLastSync);

    if (lastSyncStr == null) return null;

    try {
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      return null;
    }
  }

  /// Limpiar todos los datos
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyJuez);
    await prefs.remove(_keyLastSync);
  }

  /// Verificar si hay una sesión activa
  Future<bool> hasActiveSession() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }
}
