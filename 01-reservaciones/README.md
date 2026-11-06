# 01 · Bloc (React Native Expo) & Flutter GetX — Gestión de servicios y reservaciones

La misma aplicación implementada dos veces sobre una API REST común:

| Carpeta | Tecnología | Gestión de estado |
|---|---|---|
| `backend/` | Node.js + Express + JWT | API REST (persistencia en `db.json`) |
| `expo-bloc/` | React Native + Expo | Patrón **BLoC** (eventos → bloc → estados, `src/bloc/`) |
| `flutter-getx/` | Flutter | **GetX** (controllers reactivos `.obs`, rutas y bindings) |

## Funcionalidades
**Cliente:** registro/inicio de sesión · explorar y buscar establecimientos/servicios · ver precios, descripción y horarios disponibles · reservar y cancelar · historial y estado de citas · notificaciones de cambios en sus citas.

**Administrador:** registrar/editar su establecimiento (horario y días) · CRUD de servicios (precio y duración) · ver reservaciones con filtros · confirmar, cancelar y finalizar citas.

## Reglas implementadas
- No se permiten reservaciones en horarios ocupados (validado en cliente **y** servidor; responde 409 si alguien ganó el horario).
- La disponibilidad se calcula con la **duración** de cada servicio y el horario del establecimiento (bloques de 15 min).
- No se permiten fechas/horas pasadas.
- Estados: `pendiente → confirmada → finalizada`, o `cancelada` (transiciones validadas en el servidor).
- Mensajes de carga, confirmación y error en todas las pantallas.

## Cómo ejecutar
```bash
# 1) API
cd backend && npm install && npm start          # http://localhost:3000

# 2) Expo (BLoC)  — pon la IP de tu PC en app.json > extra.apiUrl
cd expo-bloc && npm install && npx expo start

# 3) Flutter (GetX)
cd flutter-getx
flutter create . --project-name reservaciones_getx   # genera android/ios
flutter pub get
flutter run --dart-define=API_URL=http://<IP-de-tu-PC>:3000
```
> En Android, para HTTP local agrega `android:usesCleartextTraffic="true"` en `<application>` del `AndroidManifest.xml`.
