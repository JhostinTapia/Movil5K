# 🚀 Inicio Rápido - 5 Minutos

## ✅ Pre-requisitos

- Flutter instalado ✓
- Dispositivo Android conectado o emulador
- VS Code o Android Studio

---

## 📱 Ejecutar la App (Primera Vez)

### 1. Instalar Dependencias
```bash
cd c:\Users\JATM\Desktop\AppMovil\aplicacion_movil
flutter pub get
```

### 2. Verificar Dispositivos Conectados
```bash
flutter devices
```

### 3. Ejecutar la App
```bash
flutter run
```

**¡Listo!** La app se abrirá en tu dispositivo.

---

## 🎮 Probar la App (Sin Backend)

### Flujo de Prueba:

1. **Splash Screen** (2 segundos)
   - Verás el logo y loading

2. **Login**
   - Nombre: `Juez Demo`
   - Categoría: Selecciona cualquiera
   - Click en `INICIAR SESIÓN`

3. **Timer Screen**
   - Se asigna automáticamente: "Equipo Medicina - Dorsal 101"
   - Click `INICIAR` → El cronómetro comienza
   - Click `MARCAR TIEMPO` → Registra participante #1
   - Repite hasta 15 veces
   - Al llegar a 15, el cronómetro se detiene automáticamente

4. **Probar Funciones**
   - Ver lista de registros abajo
   - Click 🗑️ para eliminar un registro
   - Click ⋮ (menú) para ver opciones
   - Click 🔄 para resetear (confirma)

---

## 🔧 Comandos Útiles

### Ejecutar en modo debug
```bash
flutter run
```

### Ejecutar en modo release
```bash
flutter run --release
```

### Hot Reload (durante ejecución)
Presiona `r` en la terminal

### Hot Restart (durante ejecución)
Presiona `R` en la terminal

### Ver logs
```bash
flutter logs
```

### Compilar APK
```bash
flutter build apk --release
```
El APK estará en: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Archivos Importantes

| Archivo | Descripción |
|---------|-------------|
| `lib/main.dart` | Punto de entrada |
| `lib/screens/timer_screen.dart` | Pantalla principal |
| `lib/providers/timer_provider.dart` | Lógica del cronómetro |
| `pubspec.yaml` | Dependencias |
| `RESUMEN.md` | Documentación completa |

---

## 🎨 Personalizar

### Cambiar Colores
Edita: `lib/config/theme.dart`

```dart
static const Color primaryColor = Color(0xFF1E88E5); // Azul
static const Color secondaryColor = Color(0xFF43A047); // Verde
```

### Cambiar Límite de Participantes
Edita: `lib/providers/timer_provider.dart`

```dart
static const int maxParticipantes = 15; // Cambiar aquí
```

### Cambiar Equipo Demo
Edita: `lib/screens/timer_screen.dart`

```dart
final equipoDemo = Equipo(
  id: 1,
  nombre: 'Equipo Medicina', // Cambiar nombre
  dorsal: 101,               // Cambiar dorsal
  juezAsignado: 1,
);
```

---

## 🐛 Solución Rápida de Problemas

### Error: "No devices found"
```bash
flutter doctor
```
Conecta un dispositivo o inicia emulador.

### Error: "Dependencies not found"
```bash
flutter clean
flutter pub get
```

### Error: "Build failed"
```bash
flutter clean
flutter pub get
flutter run
```

### App muy lenta
Ejecuta en modo release:
```bash
flutter run --release
```

---

## 📱 Instalar en Dispositivo Real

### Opción 1: USB
1. Habilita "Depuración USB" en el teléfono
2. Conecta el cable USB
3. Ejecuta `flutter run`

### Opción 2: APK
1. Compila: `flutter build apk --release`
2. Copia el APK al teléfono
3. Instala el APK

---

## 🔗 Próximo Paso: Conectar al Backend

Ver: `INTEGRACION_BACKEND.md`

1. Implementar endpoints en Django
2. Actualizar URL en `lib/services/api_service.dart`
3. Probar sincronización

---

## 📚 Documentación Completa

- `RESUMEN.md` - Visión general del proyecto
- `DOC_APP.md` - Documentación técnica
- `GUIA_USO.md` - Manual para jueces
- `GUIA_VISUAL.md` - Diseño UI/UX
- `INTEGRACION_BACKEND.md` - Integración con Django

---

## ✨ Tips

- Usa **Hot Reload** (`r`) para ver cambios instantáneos
- El estado se mantiene durante Hot Reload
- Los datos se guardan en SharedPreferences
- Para resetear datos: desinstala la app

---

**¡Disfruta desarrollando! 🎉**
