# 📱 Carrera 5K UNL - Aplicación Móvil

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.32.8-02569B?style=for-the-badge&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?style=for-the-badge&logo=dart)
![License](https://img.shields.io/badge/License-UNL-green?style=for-the-badge)

**Sistema de Registro de Tiempos para Árbitros**

_Universidad Nacional de Loja - Carrera Atlética 5 km_

[Características](#-características) • [Instalación](#-instalación) • [Documentación](#-documentación) • [Uso](#-uso)

</div>

---

## 📋 Descripción

Aplicación móvil desarrollada en **Flutter** para que los árbitros/jueces registren los tiempos de los participantes durante la Carrera Atlética de 5 km de la Universidad Nacional de Loja.

La app funciona de manera **autónoma** sin conexión a Internet, guardando los datos localmente y sincronizándolos cuando hay conectividad disponible.

---

## ✨ Características

### 🎯 Funcionalidad Principal

-   ✅ **Cronómetro de alta precisión** (milisegundos)
-   ✅ **Registro con un solo botón** al cruce de meta
-   ✅ **Límite automático** de 15 participantes por equipo
-   ✅ **Detención automática** al completar 15 registros
-   ✅ **Lista en tiempo real** de todos los tiempos marcados
-   ✅ **Persistencia local** de datos (offline-first)
-   ✅ **Sincronización automática** cuando hay conexión

### 🎨 Interfaz de Usuario

-   ✅ Diseño moderno y deportivo
-   ✅ Indicadores visuales de estado (Detenido/En Curso/Completado)
-   ✅ Medallas para top 3 participantes (🥇🥈🥉)
-   ✅ Animaciones sutiles y fluidas
-   ✅ Tema de colores coherente y profesional

### 🔧 Funciones Adicionales

-   ✅ Autenticación de jueces
-   ✅ Gestión de equipos asignados
-   ✅ Eliminación de registros erróneos
-   ✅ Reset con confirmación
-   ✅ Menú de opciones avanzadas

---

## 📱 Capturas

### Login Screen

```
┌─────────────────────────┐
│    [Logo Carrera 5K]    │
│                         │
│  ┌───────────────────┐  │
│  │ Nombre del Juez   │  │
│  │ Categoría         │  │
│  │ [Iniciar Sesión]  │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Timer Screen

```
┌─────────────────────────┐
│ Dorsal 101              │
│ Equipo Medicina         │
│ 5/15 participantes      │
├─────────────────────────┤
│    [ EN CURSO ]         │
│      12:34.56           │
├─────────────────────────┤
│ [Iniciar] [Reset]       │
│ [MARCAR TIEMPO]         │
├─────────────────────────┤
│ 🥇 12:03.45             │
│ 🥈 12:15.78             │
│ 🥉 12:34.56             │
│ ...                     │
└─────────────────────────┘
```

---

## 🚀 Instalación

### Requisitos Previos

-   Flutter SDK ≥ 3.8.1
-   Dart SDK ≥ 3.8.1
-   Android Studio / VS Code
-   Dispositivo Android o Emulador

### Pasos

```bash
# 1. Navegar al directorio del proyecto
cd aplicacion_movil

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar la app
flutter run

# 4. (Opcional) Compilar APK
flutter build apk --release
```

**Ver**: [INICIO_RAPIDO.md](INICIO_RAPIDO.md) para instrucciones detalladas.

---

## 📖 Documentación

| Documento                                            | Descripción                          |
| ---------------------------------------------------- | ------------------------------------ |
| **[RESUMEN.md](RESUMEN.md)**                         | Visión general del proyecto completo |
| **[DOC_APP.md](DOC_APP.md)**                         | Documentación técnica detallada      |
| **[GUIA_USO.md](GUIA_USO.md)**                       | Manual de usuario para jueces        |
| **[GUIA_VISUAL.md](GUIA_VISUAL.md)**                 | Diseño UI/UX y mockups               |
| **[INTEGRACION_BACKEND.md](INTEGRACION_BACKEND.md)** | Guía de integración con Django       |
| **[INICIO_RAPIDO.md](INICIO_RAPIDO.md)**             | Comenzar en 5 minutos                |

---

## 🎯 Uso Rápido

### Para Desarrolladores

```bash
# Ejecutar en modo debug
flutter run

# Hot reload (durante ejecución)
Presiona 'r'

# Ver logs
flutter logs

# Limpiar y recompilar
flutter clean && flutter pub get && flutter run
```

### Para Jueces (Día del Evento)

1. **Abrir la app** → Aparece el login
2. **Ingresar nombre** y seleccionar categoría
3. **Presionar Iniciar** cuando comience la carrera
4. **Presionar MARCAR TIEMPO** cada vez que un participante cruce la meta
5. Al llegar a 15, el cronómetro se detiene automáticamente
6. **Sincronizar datos** cuando haya conexión WiFi

**Ver**: [GUIA_USO.md](GUIA_USO.md) para instrucciones completas.

---

## 🏗️ Arquitectura

```
lib/
├── config/          # Configuración (tema, constantes)
├── models/          # Modelos de datos
├── providers/       # Gestión de estado (Provider)
├── screens/         # Pantallas de la app
├── widgets/         # Widgets reutilizables
└── main.dart        # Punto de entrada
```

### Tecnologías

-   **Framework**: Flutter 3.32.8
-   **Lenguaje**: Dart 3.8.1
-   **Estado**: Provider
-   **Storage**: SharedPreferences
-   **HTTP**: http package
-   **IDs**: UUID
-   **Animaciones**: flutter_animate

---

## 🔗 Integración con Backend

La app está diseñada para conectarse con el servidor Django ubicado en `Server5K/`.

### Configuración del Servidor (IMPORTANTE)

Antes de compilar la app para producción, debes configurar la URL del servidor en `lib/config/api_config.dart`:

```dart
// Para producción, cambia estos valores:
static const String _productionUrl = 'http://TU_DOMINIO_O_IP:8000';
static const bool isProduction = true;  // Cambiar a true
```

**Ejemplos de URLs de producción:**

-   `http://api.midominio.com:8000` (HTTP con dominio)
-   `https://api.midominio.com` (HTTPS con dominio)
-   `http://203.0.113.50:8000` (HTTP con IP pública)

**Para desarrollo local:**

```dart
static const bool isProduction = false;  // Usa _developmentUrl
static const String _developmentUrl = 'http://192.168.0.190:8000';  // Tu IP local
```

### Modelos Compatibles

-   ✅ Competencia
-   ✅ Juez
-   ✅ Equipo
-   ✅ RegistroTiempo

### Endpoints Esperados

```
POST   /api/auth/login/
GET    /api/equipos/?juez={id}
POST   /api/registros/
POST   /api/registros/bulk/
GET    /api/registros/?equipo={id}
```

**Ver**: [INTEGRACION_BACKEND.md](INTEGRACION_BACKEND.md) para implementación completa.

---

## 🎨 Personalización

### Cambiar Colores

Editar `lib/config/theme.dart`:

```dart
static const Color primaryColor = Color(0xFF1E88E5);
static const Color secondaryColor = Color(0xFF43A047);
```

### Cambiar Límite de Participantes

Editar `lib/providers/timer_provider.dart`:

```dart
static const int maxParticipantes = 15;
```

---

## 🧪 Testing

```bash
# Ejecutar tests
flutter test

# Coverage
flutter test --coverage
```

---

## 📦 Dependencias Principales

```yaml
dependencies:
    flutter:
        sdk: flutter
    provider: ^6.1.1 # State management
    shared_preferences: ^2.2.2 # Local storage
    http: ^1.2.0 # HTTP requests
    uuid: ^4.3.3 # UUID generation
    intl: ^0.19.0 # Date formatting
    flutter_animate: ^4.5.0 # Animations
    font_awesome_flutter: ^10.7.0 # Icons
```

---

## 🐛 Solución de Problemas

### La app no compila

```bash
flutter clean
flutter pub get
flutter run
```

### No se ven los cambios

```bash
# Hot reload
Presiona 'r'

# Hot restart
Presiona 'R'
```

### Error de dependencias

```bash
flutter pub upgrade
```

**Más ayuda**: Ver [issues comunes](INICIO_RAPIDO.md#-solución-rápida-de-problemas)

---

## 📋 Checklist Pre-Evento

-   [ ] Instalar app en todos los dispositivos
-   [ ] Verificar permisos de almacenamiento
-   [ ] Probar cronómetro y marcación
-   [ ] Configurar red WiFi local
-   [ ] Verificar IP del servidor
-   [ ] Hacer backup de APK
-   [ ] Cargar completamente las baterías
-   [ ] Hacer prueba end-to-end

---

## 🤝 Contribuir

Este proyecto es de uso exclusivo para la Universidad Nacional de Loja.

Para modificaciones:

1. Clonar el repositorio
2. Crear una rama: `git checkout -b feature/nueva-funcionalidad`
3. Commit cambios: `git commit -am 'Agregar funcionalidad'`
4. Push a la rama: `git push origin feature/nueva-funcionalidad`
5. Crear Pull Request

---

## 👥 Equipo

**Desarrollado para:**

-   Universidad Nacional de Loja
-   Carrera de Pedagogía de la Actividad Física y Deporte

---

## 📄 Licencia

© 2025 Universidad Nacional de Loja. Todos los derechos reservados.

---

## 📞 Soporte

Para soporte técnico durante el evento:

-   Ver documentación en carpeta del proyecto
-   Contactar al coordinador técnico

---

## 🎉 Estado del Proyecto

```
✅ Diseño UI/UX        - 100%
✅ Funcionalidad Core  - 100%
✅ Gestión de Estado   - 100%
✅ Persistencia Local  - 100%
⚠️  Integración API    - Pendiente (Backend)
⚠️  Testing           - Pendiente
⚠️  Despliegue        - Pendiente
```

**Última actualización**: Noviembre 2025

---

<div align="center">

**Hecho con ❤️ en Flutter**

[⬆ Volver arriba](#-carrera-5k-unl---aplicación-móvil)

</div>
