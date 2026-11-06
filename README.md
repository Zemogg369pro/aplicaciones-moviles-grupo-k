# Desarrollo de Aplicaciones Móviles — Grupo K

**Alumno:** Juan Diego Gómez Gómez · Facultad de Ingeniería Arturo Narro Siller (UAT) · 7° semestre

| # | Tarea | Carpeta | Tecnologías |
|---|---|---|---|
| 1 | Bloc React Native Expo & Flutter GetX | [`01-reservaciones`](01-reservaciones) | Expo + patrón BLoC · Flutter + GetX · API REST Node/Express + JWT |
| 2 | Cámara, video, detección de objetos | [`02-camara-deteccion`](02-camara-deteccion) | Flutter · camera · YOLOv8 TFLite (local) · video_player |
| 3 | GPS + Bluetooth. Sensores | [`03-gps-bluetooth-sensores`](03-gps-bluetooth-sensores) | Flutter · geolocator · flutter_map · sensors_plus · flutter_blue_plus (BLE) |
| 4 | OAuth + push notification | [`04-oauth-push`](04-oauth-push) | Flutter · Google OAuth 2.0 · Firebase Auth/Firestore/Storage · FCM · Cloud Functions |
| 5 | Offline Sync | [`05-offline-sync`](05-offline-sync) | Flutter · SQLite · connectivity_plus · cola de sincronización · API REST idempotente |
| 6 | Websocket + deep link | [`06-websocket-deeplink`](06-websocket-deeplink) | Flutter · web_socket_channel · app_links · Node.js `ws` |

Cada carpeta tiene su propio `README.md` con la relación requisito → implementación y los pasos para ejecutarla.
Los proyectos Flutter incluyen `lib/` y `pubspec.yaml`; las carpetas de plataforma se generan con `flutter create .`.
