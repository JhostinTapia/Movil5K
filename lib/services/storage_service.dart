import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    // Limpiar tokens AGRESIVAMENTE de espacios, saltos de línea, #, tabs, etc.
    final cleanAccess = accessToken.trim().replaceAll(RegExp(r'[#\n\r\t]'), '');
    final cleanRefresh = refreshToken.trim().replaceAll(RegExp(r'[#\n\r\t]'), '');
    
    await prefs.setString(_keyAccessToken, cleanAccess);
    await prefs.setString(_keyRefreshToken, cleanRefresh);
  }

  /// Guardar solo el access token
  Future<void> saveAccessToken(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    // Limpiar token AGRESIVAMENTE de espacios, saltos de línea, #, tabs, etc.
    final cleanToken = accessToken.trim().replaceAll(RegExp(r'[#\n\r\t]'), '');
    await prefs.setString(_keyAccessToken, cleanToken);
  }

  /// Obtener access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    
    if (token == null) return null;
    
    // Limpiar token AGRESIVAMENTE de espacios y caracteres extras
    final cleanToken = token.trim().replaceAll(RegExp(r'[#\n\r\t]'), '');
    
    // Si el token estaba corrupto, guardarlo limpio (migración automática)
    if (token != cleanToken) {
      debugPrint('🔧 Token corrupto detectado - Aplicando limpieza automática');
      debugPrint('   Token original length: ${token.length}');
      debugPrint('   Token limpio length: ${cleanToken.length}');
      await prefs.setString(_keyAccessToken, cleanToken);
    }
    
    return cleanToken;
  }

  /// Obtener refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyRefreshToken);
    
    if (token == null) return null;
    
    // Limpiar token AGRESIVAMENTE de espacios y caracteres extras
    final cleanToken = token.trim().replaceAll(RegExp(r'[#\n\r\t]'), '');
    
    // Si el token estaba corrupto, guardarlo limpio (migración automática)
    if (token != cleanToken) {
      debugPrint('🔧 Refresh token corrupto detectado - Aplicando limpieza automática');
      await prefs.setString(_keyRefreshToken, cleanToken);
    }
    
    return cleanToken;
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
