# 08 · Local storage, Hive y SQLite (Flutter)

Una app que usa cada tecnología para lo que mejor sabe hacer:

| Tema de la tarea | Tecnología | Dónde | Qué guarda |
|---|---|---|---|
| **Inicio de sesión** | SharedPreferences (local storage clave‑valor) | `lib/storage/session_storage.dart` | Sesión activa, "recordar usuario" y cuentas registradas (contraseña con hash SHA‑256) |
| **Datos de usuario** | Hive (NoSQL) | `lib/storage/user_data_storage.dart` → `UserDataStorage` | Perfil y preferencias de cada usuario (nombre, correo, teléfono, modo oscuro, tamaño de letra), una caja por usuario |
| **Caché** | Hive | `CacheStorage` | Respuesta de una API con fecha y vigencia de 5 min. Si no hay internet, muestra la última copia |
| **Información de aplicación** | SQLite (`sqflite`) | `lib/storage/app_info_db.dart` | Tabla `app_events`: aperturas, inicios de sesión, pantallas visitadas y versión, con consultas `GROUP BY` |

## Cuándo usar cada una
- **SharedPreferences:** valores pequeños y simples, como banderas, sesión o configuración.
- **Hive:** objetos o mapas que se leen y escriben rápido, sin necesidad de consultas complejas.
- **SQLite:** datos estructurados en tablas, cuando se necesitan filtros, orden, agregados o índices.

## Ejecutar
```bash
flutter create . --project-name almacenamiento_local --platforms=android,ios
flutter pub get
flutter run
```
Prueba: crea una cuenta, guarda tus datos, cierra la app y vuelve a abrirla. La sesión, los datos y la bitácora siguen ahí. En la pestaña de caché, activa el modo avión y verás la copia guardada.
