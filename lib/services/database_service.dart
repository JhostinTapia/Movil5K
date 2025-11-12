import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/registro_tiempo.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'carrera_5k.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de registros de tiempo
    await db.execute('''
      CREATE TABLE registros_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_registro TEXT UNIQUE NOT NULL,
        equipo_id INTEGER NOT NULL,
        equipo_nombre TEXT NOT NULL,
        equipo_dorsal INTEGER NOT NULL,
        juez_id INTEGER NOT NULL,
        tiempo INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    // Índices para mejorar rendimiento
    await db.execute('''
      CREATE INDEX idx_equipo_id ON registros_tiempo(equipo_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_sincronizado ON registros_tiempo(sincronizado)
    ''');
  }

  // Guardar registro de tiempo
  Future<int> insertRegistroTiempo(
    RegistroTiempo registro,
    int equipoId,
    String equipoNombre,
    int equipoDorsal,
    int juezId,
  ) async {
    final db = await database;
    return await db.insert(
      'registros_tiempo',
      {
        'id_registro': registro.idRegistro,
        'equipo_id': equipoId,
        'equipo_nombre': equipoNombre,
        'equipo_dorsal': equipoDorsal,
        'juez_id': juezId,
        'tiempo': registro.tiempo,
        'timestamp': registro.timestamp.toIso8601String(),
        'sincronizado': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener registros por equipo
  Future<List<Map<String, dynamic>>> getRegistrosByEquipo(int equipoId) async {
    final db = await database;
    return await db.query(
      'registros_tiempo',
      where: 'equipo_id = ?',
      whereArgs: [equipoId],
      orderBy: 'tiempo ASC',
    );
  }

  // Obtener registros no sincronizados
  Future<List<Map<String, dynamic>>> getRegistrosNoSincronizados() async {
    final db = await database;
    return await db.query(
      'registros_tiempo',
      where: 'sincronizado = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
    );
  }

  // Marcar registros como sincronizados
  Future<int> marcarComoSincronizado(String idRegistro) async {
    final db = await database;
    return await db.update(
      'registros_tiempo',
      {'sincronizado': 1},
      where: 'id_registro = ?',
      whereArgs: [idRegistro],
    );
  }

  // Eliminar registro
  Future<int> deleteRegistro(String idRegistro) async {
    final db = await database;
    return await db.delete(
      'registros_tiempo',
      where: 'id_registro = ?',
      whereArgs: [idRegistro],
    );
  }

  // Contar registros por equipo
  Future<int> contarRegistrosPorEquipo(int equipoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registros_tiempo WHERE equipo_id = ?',
      [equipoId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Obtener todos los registros
  Future<List<Map<String, dynamic>>> obtenerTodosLosRegistros() async {
    final db = await database;
    return await db.query(
      'registros_tiempo',
      orderBy: 'timestamp DESC',
    );
  }

  // Obtener registros pendientes de sincronizar
  Future<List<Map<String, dynamic>>> obtenerRegistrosPendientes() async {
    final db = await database;
    return await db.query(
      'registros_tiempo',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
  }

  // Obtener conteo de registros por estado
  Future<Map<String, int>> obtenerEstadisticas() async {
    final db = await database;
    final total = await db.rawQuery('SELECT COUNT(*) as count FROM registros_tiempo');
    final pendientes = await db.rawQuery('SELECT COUNT(*) as count FROM registros_tiempo WHERE sincronizado = 0');
    final sincronizados = await db.rawQuery('SELECT COUNT(*) as count FROM registros_tiempo WHERE sincronizado = 1');
    
    return {
      'total': Sqflite.firstIntValue(total) ?? 0,
      'pendientes': Sqflite.firstIntValue(pendientes) ?? 0,
      'sincronizados': Sqflite.firstIntValue(sincronizados) ?? 0,
    };
  }

  // Limpiar todos los datos (solo para desarrollo/testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('registros_tiempo');
  }

  // Cerrar base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
