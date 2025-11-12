# Aplicación Móvil - Carrera 5K UNL

Aplicación móvil desarrollada en Flutter para el registro de tiempos en la Carrera Atlética de 5 km de la Universidad Nacional de Loja.

## 📱 Características Principales

### Para Árbitros/Jueces

- **Autenticación**: Login simple para jueces con selección de categoría
- **Control de Cronómetro**: Cronómetro de alta precisión con visualización en formato MM:SS.CS
- **Registro de Tiempos**: Marcación de tiempos para cada participante que cruza la meta
- **Gestión de Equipos**: Visualización del equipo asignado con dorsal y nombre
- **Límite de Participantes**: Control automático de hasta 15 participantes por equipo
- **Lista de Registros**: Visualización en tiempo real de todos los tiempos marcados
- **Eliminación de Registros**: Posibilidad de eliminar registros erróneos
- **Detención Automática**: El cronómetro se detiene al registrar el participante 15

## 🎨 Diseño

La aplicación cuenta con:
- **Tema moderno y deportivo** con colores azul y verde
- **Interfaz intuitiva** optimizada para uso durante competencias
- **Diseño responsivo** para diferentes tamaños de pantalla
- **Indicadores visuales** de estado (en curso, detenido, completado)
- **Animaciones sutiles** para mejor experiencia de usuario
- **Medallas visuales** para los 3 primeros lugares

## 📂 Estructura del Proyecto

```
lib/
├── config/
│   └── theme.dart              # Configuración de tema y colores
├── models/
│   ├── competencia.dart        # Modelo de Competencia
│   ├── equipo.dart             # Modelo de Equipo
│   ├── juez.dart               # Modelo de Juez
│   └── registro_tiempo.dart    # Modelo de Registro de Tiempo
├── providers/
│   ├── auth_provider.dart      # Gestión de autenticación
│   └── timer_provider.dart     # Gestión del cronómetro y registros
├── screens/
│   ├── login_screen.dart       # Pantalla de inicio de sesión
│   └── timer_screen.dart       # Pantalla principal con cronómetro
├── widgets/
│   ├── time_mark_card.dart     # Tarjeta de registro individual
│   └── timer_display.dart      # Display del cronómetro
└── main.dart                   # Punto de entrada de la app
```

## 🚀 Instalación y Ejecución

### Requisitos Previos

- Flutter SDK (>=3.8.1)
- Dart SDK
- Android Studio / VS Code con extensiones de Flutter
- Dispositivo Android/iOS o Emulador

### Pasos de Instalación

1. **Clonar el repositorio** (o navegar a la carpeta del proyecto)

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

## 📦 Dependencias Principales

- `provider: ^6.1.1` - Gestión de estado
- `shared_preferences: ^2.2.2` - Almacenamiento local
- `http: ^1.2.0` - Peticiones HTTP
- `uuid: ^4.3.3` - Generación de IDs únicos
- `intl: ^0.19.0` - Formato de fechas y horas
- `flutter_animate: ^4.5.0` - Animaciones
- `font_awesome_flutter: ^10.7.0` - Iconos

## 🎯 Funcionalidades Detalladas

### Pantalla de Login

- Campo de texto para nombre del juez
- Selector de categoría (Estudiantes/Interfacultades)
- Persistencia de sesión con SharedPreferences
- Diseño atractivo con gradiente y animaciones

### Pantalla de Control de Tiempos

1. **Header del Equipo**
   - Muestra dorsal del equipo
   - Nombre del equipo
   - Contador de participantes registrados (X/15)

2. **Cronómetro Digital**
   - Display grande y legible
   - Formato MM:SS.CS
   - Indicador visual de estado (Detenido/En curso/Completado)
   - Animación de pulsación cuando está activo

3. **Controles**
   - Botón Iniciar/Pausar (verde/naranja)
   - Botón Reset con confirmación (rojo)
   - Botón "MARCAR TIEMPO" (azul, destacado)

4. **Lista de Registros**
   - Tarjetas individuales por cada marca
   - Posición del participante
   - Tiempo formateado
   - Hora de registro
   - Medallas visuales para top 3
   - Opción de eliminar con confirmación

### Menú de Opciones

- Sincronizar datos con servidor
- Cambiar equipo asignado
- Cerrar sesión

## 🔄 Flujo de Uso

1. El juez inicia sesión con su nombre
2. Se le asigna un equipo automáticamente
3. Cuando inicia la carrera, presiona "Iniciar"
4. Cada vez que un participante cruza la meta, presiona "MARCAR TIEMPO"
5. El sistema registra automáticamente el tiempo exacto
6. Puede ver todos los registros en la lista inferior
7. Al llegar a 15 participantes, el cronómetro se detiene automáticamente
8. Puede sincronizar los datos cuando haya conexión disponible

## 🎨 Paleta de Colores

- **Primary (Azul)**: `#1E88E5` - Botones principales y header
- **Secondary (Verde)**: `#43A047` - Éxito y estado activo
- **Accent (Naranja)**: `#FFA726` - Pausar y advertencias
- **Error (Rojo)**: `#E53935` - Eliminar y errores
- **Background**: `#F5F5F5` - Fondo general

## 📱 Capturas de Pantalla

### Login Screen
- Diseño con gradiente azul
- Formulario centrado con card elevado
- Selector de categoría

### Timer Screen
- Header con información del equipo
- Cronómetro grande y visible
- Botones de control accesibles
- Lista scrolleable de registros

## 🔐 Consideraciones de Seguridad

- Validación de formularios
- Confirmaciones para acciones destructivas
- Persistencia segura de credenciales
- Manejo de errores robusto

## 🚧 Próximas Mejoras

- [ ] Integración con API REST del servidor Django
- [ ] Sincronización automática en background
- [ ] Soporte offline completo con cola de sincronización
- [ ] Exportación de datos a CSV/Excel
- [ ] Notificaciones push
- [ ] Modo oscuro
- [ ] Estadísticas y gráficos en tiempo real
- [ ] Escaneo de códigos QR para equipos

## 👥 Créditos

Desarrollado para la Universidad Nacional de Loja
Carrera de Pedagogía de la Actividad Física y Deporte

## 📄 Licencia

Este proyecto es de uso exclusivo para la Universidad Nacional de Loja.
