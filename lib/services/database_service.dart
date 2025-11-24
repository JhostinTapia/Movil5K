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
      version: 4, // Incrementada para agregar columna penalizado
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de registros de tiempo
    await db.execute('''
      CREATE TABLE registros_tiempo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_registro TEXT UNIQUE NOT NULL,
        equipo_id INTEGER NOT NULL,
        tiempo INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        horas INTEGER DEFAULT 0,
        minutos INTEGER DEFAULT 0,
        segundos INTEGER DEFAULT 0,
        milisegundos INTEGER DEFAULT 0,
        sincronizado INTEGER DEFAULT 0,
        penalizado INTEGER DEFAULT 0
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Recrear tabla completamente con columna penalizado

      // 1. Eliminar tabla vieja
      await db.execute('DROP TABLE IF EXISTS registros_tiempo');

      // 2. Crear tabla nueva con esquema correcto
      await db.execute('''
        CREATE TABLE registros_tiempo (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_registro TEXT UNIQUE NOT NULL,
          equipo_id INTEGER NOT NULL,
          tiempo INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          horas INTEGER DEFAULT 0,
          minutos INTEGER DEFAULT 0,
          segundos INTEGER DEFAULT 0,
          milisegundos INTEGER DEFAULT 0,
          sincronizado INTEGER DEFAULT 0,
          penalizado INTEGER DEFAULT 0
        )
      ''');

      // 3. Recrear índices
      await db.execute('''
        CREATE INDEX idx_equipo_id ON registros_tiempo(equipo_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_sincronizado ON registros_tiempo(sincronizado)
      ''');
    }
  }

  // Guardar registro de tiempo
  Future<int> insertRegistroTiempo(RegistroTiempo registro) async {
    final db = await database;
    return await db.insert(
      'registros_tiempo',
      registro.toDbMap(),
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
  Future<List<RegistroTiempo>> getRegistrosNoSincronizados(int equipoId) async {
    final db = await database;
    final maps = await db.query(
      'registros_tiempo',
      where: 'sincronizado = ? AND equipo_id = ?',
      whereArgs: [0, equipoId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => RegistroTiempo.fromDbMap(map)).toList();
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

  // Obtener todos los registros con información del equipo
  Future<List<Map<String, dynamic>>> obtenerTodosLosRegistros() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        rt.*,
        e.nombre as equipo_nombre,
        e.dorsal as equipo_dorsal
      FROM registros_tiempo rt
      LEFT JOIN equipos e ON rt.equipo_id = e.id
      ORDER BY rt.timestamp DESC
    ''');
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
    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registros_tiempo',
    );
    final pendientes = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registros_tiempo WHERE sincronizado = 0',
    );
    final sincronizados = await db.rawQuery(
      'SELECT COUNT(*) as count FROM registros_tiempo WHERE sincronizado = 1',
    );

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
