# Guía Rápida de Uso - App Carrera 5K UNL

## 🏃‍♂️ Inicio Rápido

### 1. Pantalla de Bienvenida (Splash)
Al abrir la app, verás el logo de la aplicación mientras se carga. 
- Si ya iniciaste sesión antes, te llevará directo a la pantalla de control
- Si es tu primera vez, te llevará al login

### 2. Inicio de Sesión

**Campos a completar:**
- **Nombre del Juez**: Escribe tu nombre completo
- **Categoría**: Selecciona una opción:
  - 🎓 Estudiantes por Equipos
  - 🏛️ Interfacultades por Equipos

**Botón**: Presiona "Iniciar Sesión"

### 3. Pantalla de Control de Tiempos

#### Elementos de la Pantalla:

**A. Información del Equipo (Top)**
```
┌─────────────────────────┐
│    Dorsal 101           │
│  Equipo Medicina        │
│  5 / 15 participantes   │
└─────────────────────────┘
```

**B. Cronómetro**
```
┌─────────────────────────┐
│    [EN CURSO]           │
│     12:45.89            │
│     MM:SS.CS            │
└─────────────────────────┘
```

**C. Botones de Control**
- 🟢 **INICIAR/PAUSAR**: Controla el cronómetro
- 🔴 **RESET**: Reinicia todo (pide confirmación)
- 🔵 **MARCAR TIEMPO**: Registra cuando pasa un participante

**D. Lista de Registros**
Cada registro muestra:
- 🥇 Posición (medalla para top 3)
- ⏱️ Tiempo exacto
- 🕐 Hora de registro
- 🗑️ Botón eliminar

## 📋 Flujo de Trabajo Durante la Carrera

### Paso 1: Preparación
1. Abre la app e inicia sesión
2. Verifica que tengas asignado el equipo correcto
3. Ten el dispositivo listo antes de que inicie la carrera

### Paso 2: Inicio de la Carrera
1. Cuando se dé la señal de salida, presiona **INICIAR**
2. El cronómetro comenzará a correr
3. Verás el indicador cambiar a "EN CURSO" (naranja)

### Paso 3: Registro de Participantes
Cada vez que un participante de tu equipo cruce la meta:

1. Presiona el botón grande **"MARCAR TIEMPO"**
2. Aparecerá inmediatamente en la lista abajo
3. Verás:
   - El número de participante (1, 2, 3, etc.)
   - El tiempo exacto que marcó
   - La hora en que registraste

**⚠️ Importante:**
- Puedes presionar el botón rápidamente varias veces
- Cada presión registra un nuevo participante
- Máximo 15 participantes por equipo

### Paso 4: Finalización Automática
Al registrar el participante número 15:
- El cronómetro se **detiene automáticamente**
- El indicador cambia a "COMPLETADO" (verde)
- Ya no puedes agregar más registros

### Paso 5: Sincronización
1. Presiona el botón **⋮** (tres puntos) en el header
2. Selecciona "Sincronizar Datos"
3. Los registros se enviarán al servidor central

## 🔧 Funciones Adicionales

### Pausar el Cronómetro
- Presiona el botón "PAUSAR" (cambia de verde a naranja)
- El cronómetro se detiene temporalmente
- Presiona "INICIAR" nuevamente para continuar

### Eliminar un Registro Incorrecto
1. En la lista, busca el registro a eliminar
2. Presiona el ícono 🗑️
3. Confirma la eliminación
4. El registro desaparece y se ajustan las posiciones

### Reiniciar Todo (Reset)
**Solo usar en caso de error grave:**
1. Presiona el botón rojo 🔴
2. Confirma que quieres reiniciar
3. Se borran todos los registros
4. El cronómetro vuelve a 00:00.00

### Cambiar de Equipo
1. Presiona **⋮** en el header
2. Selecciona "Cambiar Equipo"
3. Elige el nuevo equipo asignado

### Cerrar Sesión
1. Presiona **⋮** en el header
2. Selecciona "Cerrar Sesión"
3. Regresarás al login

## 💡 Consejos y Mejores Prácticas

### Antes de la Carrera
✅ Carga completa del dispositivo
✅ Verifica conexión WiFi local
✅ Haz una prueba rápida con el cronómetro
✅ Familiarízate con el botón "MARCAR TIEMPO"

### Durante la Carrera
✅ Mantén el dispositivo en mano, listo
✅ Concéntrate en los participantes de tu equipo
✅ Presiona "MARCAR TIEMPO" inmediatamente al cruce
✅ No te preocupes por el orden, el sistema los ordena

### Después de la Carrera
✅ Revisa que tengas 15 registros
✅ Verifica que no haya tiempos duplicados
✅ Sincroniza los datos lo antes posible
✅ Mantén la app abierta hasta confirmar sincronización

## ⚠️ Solución de Problemas

### "No puedo marcar más tiempos"
- Verifica que no hayas alcanzado los 15 participantes
- Revisa que el cronómetro esté en estado "EN CURSO"

### "Se registró un tiempo incorrecto"
- Usa el botón 🗑️ para eliminarlo
- Márcalo nuevamente si aún está a tiempo

### "La app se cerró durante la carrera"
- Los datos se guardan automáticamente
- Al reabrir, estarás en la misma sesión
- Los registros previos se mantienen

### "No se sincronizan los datos"
- Verifica la conexión WiFi
- Intenta nuevamente más tarde
- Los datos están guardados localmente

### "Necesito reiniciar pero tengo registros"
- Solo usa Reset si es absolutamente necesario
- Considera eliminar registros individuales en su lugar
- El Reset borra TODO

## 📊 Interpretando la Información

### Indicadores de Estado

| Color | Estado | Significado |
|-------|--------|-------------|
| 🔴 Rojo | DETENIDO | Cronómetro no activo |
| 🟠 Naranja | EN CURSO | Carrera en progreso |
| 🟢 Verde | COMPLETADO | 15 participantes registrados |

### Símbolos en la Lista

| Símbolo | Significado |
|---------|-------------|
| 🥇 | Primer lugar del equipo |
| 🥈 | Segundo lugar del equipo |
| 🥉 | Tercer lugar del equipo |
| 🚩 | Lugares 4 al 15 |

### Formato de Tiempo

**MM:SS.CS**
- **MM** = Minutos (00-99)
- **SS** = Segundos (00-59)
- **CS** = Centésimas de segundo (00-99)

Ejemplo: **12:34.56** = 12 minutos, 34 segundos, 56 centésimas

## 🎯 Casos de Uso Especiales

### Dos participantes llegan casi al mismo tiempo
1. Presiona "MARCAR TIEMPO" dos veces rápidamente
2. El sistema registrará ambos con milisegundos de diferencia
3. Esto es normal y correcto

### Un participante abandona
- No hagas nada especial
- Simplemente no marques su tiempo
- Al final tendrás menos de 15 registros

### Hay un empate perfecto
- Es casi imposible (precisión de milisegundos)
- El sistema mantiene el orden de llegada

### Necesito pausar a la mitad
1. Presiona "PAUSAR"
2. El cronómetro se detiene
3. Los registros ya hechos se mantienen
4. Presiona "INICIAR" para continuar

## 📞 Contacto y Soporte

Para problemas técnicos durante el evento:
- Contacta al coordinador técnico
- Reporta errores de sincronización inmediatamente
- Mantén los datos locales hasta confirmar respaldo

---

**¡Buena suerte con la carrera! 🏃‍♂️🏃‍♀️**
