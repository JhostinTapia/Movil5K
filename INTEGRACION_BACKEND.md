# Notas de Integración - Backend Django

## 🔗 Endpoints del API a Implementar

Basado en los modelos del servidor Django, estos son los endpoints que la app móvil necesitará consumir:

### 1. Autenticación y Jueces

#### `POST /api/auth/login/`
**Request:**
```json
{
  "nombre": "Juan Pérez",
  "competencia_id": 1
}
```

**Response:**
```json
{
  "id": 1,
  "nombre": "Juan Pérez",
  "competencia": 1,
  "activo": true,
  "token": "abc123..." // opcional si usas JWT
}
```

#### `GET /api/jueces/{id}/`
Obtener información del juez autenticado

### 2. Competencias

#### `GET /api/competencias/`
Listar competencias activas

**Response:**
```json
[
  {
    "id": 1,
    "nombre": "Carrera 5K UNL 2025",
    "fecha_hora": "2025-11-15T09:00:00Z",
    "categoria": "estudiantes",
    "activa": true,
    "en_curso": true,
    "fecha_inicio": "2025-11-15T09:00:00Z",
    "fecha_fin": null
  }
]
```

#### `GET /api/competencias/{id}/`
Obtener detalles de una competencia específica

#### `POST /api/competencias/{id}/iniciar/`
Iniciar competencia (solo juez central)

#### `POST /api/competencias/{id}/detener/`
Detener competencia (solo juez central)

### 3. Equipos

#### `GET /api/equipos/?juez={juez_id}`
Obtener equipos asignados a un juez

**Response:**
```json
[
  {
    "id": 1,
    "nombre": "Equipo Medicina",
    "dorsal": 101,
    "juez_asignado": 1
  }
]
```

#### `GET /api/equipos/{id}/`
Obtener detalles de un equipo específico

### 4. Registros de Tiempo

#### `POST /api/registros/`
Crear nuevo registro de tiempo

**Request:**
```json
{
  "id_registro": "550e8400-e29b-41d4-a716-446655440000",
  "equipo": 1,
  "tiempo": 756890,
  "timestamp": "2025-11-15T09:12:34.567Z"
}
```

**Response:**
```json
{
  "id_registro": "550e8400-e29b-41d4-a716-446655440000",
  "equipo": 1,
  "tiempo": 756890,
  "timestamp": "2025-11-15T09:12:34.567Z"
}
```

#### `POST /api/registros/bulk/`
Crear múltiples registros (sincronización offline)

**Request:**
```json
{
  "registros": [
    {
      "id_registro": "550e8400-e29b-41d4-a716-446655440000",
      "equipo": 1,
      "tiempo": 756890,
      "timestamp": "2025-11-15T09:12:34.567Z"
    },
    {
      "id_registro": "660e8400-e29b-41d4-a716-446655440001",
      "equipo": 1,
      "tiempo": 789123,
      "timestamp": "2025-11-15T09:13:09.123Z"
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "created": 2,
  "errors": []
}
```

#### `GET /api/registros/?equipo={equipo_id}`
Obtener todos los registros de un equipo

#### `DELETE /api/registros/{id_registro}/`
Eliminar un registro (solo antes de finalizar)

### 5. Sincronización

#### `POST /api/sync/`
Sincronizar todos los datos pendientes

**Request:**
```json
{
  "juez_id": 1,
  "registros": [...],
  "last_sync": "2025-11-15T09:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "synced_count": 15,
  "conflicts": [],
  "server_time": "2025-11-15T09:15:00Z"
}
```

## 📝 Implementación en Django REST Framework

### Ejemplo de ViewSet para Registros

```python
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import RegistroTiempo, Equipo
from .serializers import RegistroTiempoSerializer

class RegistroTiempoViewSet(viewsets.ModelViewSet):
    queryset = RegistroTiempo.objects.all()
    serializer_class = RegistroTiempoSerializer
    lookup_field = 'id_registro'
    
    def get_queryset(self):
        queryset = super().get_queryset()
        equipo_id = self.request.query_params.get('equipo', None)
        if equipo_id:
            queryset = queryset.filter(equipo_id=equipo_id)
        return queryset
    
    @action(detail=False, methods=['post'])
    def bulk(self, request):
        """Crear múltiples registros a la vez"""
        registros_data = request.data.get('registros', [])
        created = []
        errors = []
        
        for registro_data in registros_data:
            serializer = self.get_serializer(data=registro_data)
            if serializer.is_valid():
                serializer.save()
                created.append(serializer.data)
            else:
                errors.append({
                    'data': registro_data,
                    'errors': serializer.errors
                })
        
        return Response({
            'success': len(errors) == 0,
            'created': len(created),
            'errors': errors
        }, status=status.HTTP_201_CREATED if len(errors) == 0 else status.HTTP_207_MULTI_STATUS)
```

### Serializers Necesarios

```python
from rest_framework import serializers
from .models import Competencia, Juez, Equipo, RegistroTiempo

class CompetenciaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Competencia
        fields = '__all__'

class JuezSerializer(serializers.ModelSerializer):
    class Meta:
        model = Juez
        fields = '__all__'

class EquipoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Equipo
        fields = '__all__'

class RegistroTiempoSerializer(serializers.ModelSerializer):
    class Meta:
        model = RegistroTiempo
        fields = ['id_registro', 'equipo', 'tiempo', 'timestamp']
```

### URLs

```python
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    CompetenciaViewSet,
    JuezViewSet,
    EquipoViewSet,
    RegistroTiempoViewSet
)

router = DefaultRouter()
router.register(r'competencias', CompetenciaViewSet)
router.register(r'jueces', JuezViewSet)
router.register(r'equipos', EquipoViewSet)
router.register(r'registros', RegistroTiempoViewSet)

urlpatterns = [
    path('api/', include(router.urls)),
]
```

## 🔄 Implementación en Flutter

### API Service

Crear archivo: `lib/services/api_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/registro_tiempo.dart';
import '../models/equipo.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.100:8000/api';
  
  // Headers comunes
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };
  
  // Login
  static Future<Map<String, dynamic>> login(String nombre, int competenciaId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: headers,
      body: jsonEncode({
        'nombre': nombre,
        'competencia_id': competenciaId,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error en login');
    }
  }
  
  // Obtener equipos del juez
  static Future<List<Equipo>> getEquiposJuez(int juezId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/equipos/?juez=$juezId'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Equipo.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener equipos');
    }
  }
  
  // Crear registro individual
  static Future<RegistroTiempo> crearRegistro(RegistroTiempo registro) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registros/'),
      headers: headers,
      body: jsonEncode(registro.toJson()),
    );
    
    if (response.statusCode == 201) {
      return RegistroTiempo.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al crear registro');
    }
  }
  
  // Sincronización masiva
  static Future<Map<String, dynamic>> syncRegistros(List<RegistroTiempo> registros) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registros/bulk/'),
      headers: headers,
      body: jsonEncode({
        'registros': registros.map((r) => r.toJson()).toList(),
      }),
    );
    
    if (response.statusCode == 201 || response.statusCode == 207) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error en sincronización');
    }
  }
}
```

### Integrar en TimerProvider

Modificar `lib/providers/timer_provider.dart`:

```dart
Future<void> sincronizarRegistros() async {
  if (_registros.isEmpty) return;
  
  try {
    final result = await ApiService.syncRegistros(_registros);
    if (result['success']) {
      // Marcar como sincronizado
      notifyListeners();
    }
  } catch (e) {
    print('Error sincronizando: $e');
    // Los datos quedan guardados localmente
  }
}
```

## 🗄️ Almacenamiento Local (SQLite)

Para persistencia offline completa, considera usar `sqflite`:

### Agregar a pubspec.yaml
```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.3
```

### Database Helper

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }
  
  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'carrera5k.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE registros(
            id_registro TEXT PRIMARY KEY,
            equipo_id INTEGER,
            tiempo INTEGER,
            timestamp TEXT,
            sincronizado INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }
  
  Future<void> insertarRegistro(RegistroTiempo registro) async {
    final db = await database;
    await db.insert('registros', {
      'id_registro': registro.idRegistro,
      'equipo_id': registro.equipoId,
      'tiempo': registro.tiempo,
      'timestamp': registro.timestamp.toIso8601String(),
      'sincronizado': 0,
    });
  }
  
  Future<List<RegistroTiempo>> getRegistrosPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros',
      where: 'sincronizado = ?',
      whereArgs: [0],
    );
    
    return List.generate(maps.length, (i) {
      return RegistroTiempo.fromJson(maps[i]);
    });
  }
  
  Future<void> marcarSincronizado(String idRegistro) async {
    final db = await database;
    await db.update(
      'registros',
      {'sincronizado': 1},
      where: 'id_registro = ?',
      whereArgs: [idRegistro],
    );
  }
}
```

## 🔐 Consideraciones de Seguridad

1. **HTTPS**: Usar siempre HTTPS en producción
2. **Autenticación**: Implementar JWT o tokens de sesión
3. **Validación**: Validar todos los datos en backend
4. **Rate Limiting**: Limitar requests por IP/usuario
5. **CORS**: Configurar correctamente para permitir la app

### Configuración CORS en Django

```python
# settings.py
INSTALLED_APPS = [
    ...
    'corsheaders',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    ...
]

# En desarrollo
CORS_ALLOW_ALL_ORIGINS = True

# En producción
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://192.168.1.100:8000",
]
```

## 📱 Configuración de Red Local

Para desarrollo y uso en evento sin Internet:

1. **Servidor Django**: Ejecutar con `python manage.py runserver 0.0.0.0:8000`
2. **Red WiFi Local**: Conectar todos los dispositivos a la misma red
3. **IP Fija**: Configurar IP estática para el servidor
4. **Firewall**: Permitir puerto 8000

### En la App Flutter

Actualizar la URL base según el entorno:

```dart
class ApiConfig {
  static const String devUrl = 'http://localhost:8000/api';
  static const String localNetworkUrl = 'http://192.168.1.100:8000/api';
  static const String prodUrl = 'https://api.carrera5k.unl.edu.ec/api';
  
  static String get baseUrl {
    // Detectar automáticamente o configurar
    return localNetworkUrl;
  }
}
```

## 🧪 Testing

### Pruebas Backend

```python
from django.test import TestCase
from .models import Equipo, RegistroTiempo

class RegistroTiempoTestCase(TestCase):
    def test_crear_registro(self):
        equipo = Equipo.objects.create(...)
        registro = RegistroTiempo.objects.create(
            equipo=equipo,
            tiempo=756890
        )
        self.assertEqual(registro.tiempo, 756890)
```

### Pruebas Flutter

```dart
void main() {
  test('Formato de tiempo correcto', () {
    final registro = RegistroTiempo(
      idRegistro: '123',
      equipoId: 1,
      tiempo: 756890,
      timestamp: DateTime.now(),
    );
    expect(registro.tiempoFormateado, '12:36.890');
  });
}
```

---

**Notas Finales:**
- Implementar manejo robusto de errores de red
- Considerar reconexión automática
- Mantener logs de sincronización
- Implementar versionado de API
