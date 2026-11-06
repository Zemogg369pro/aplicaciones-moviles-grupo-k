# 06 · WebSocket + Deep Link — Mensajería instantánea (Flutter + Node.js `ws`)

## Mensajería en tiempo real
| Requisito | Implementación |
|---|---|
| Registro e inicio de sesión | `POST /auth/register`, `/auth/login` (JWT) |
| Lista de usuarios disponibles | `GET /users` + pestaña **Usuarios** con estado en línea |
| Conversaciones individuales y grupales | `POST /conversations` (`direct` / `group`) |
| Mensajes en tiempo real | WebSocket `/ws?token=` · eventos `message`/`ack` |
| Conectado / desconectado | evento `presence` + “últ. vez” |
| “escribiendo…” | evento `typing` (con *throttle* y expiración a 5 s) |
| Estados enviando → enviado → entregado → leído | local `enviando`; `ack` = enviado; `deliveredTo` / `readBy` en el servidor → evento `status` (✓, ✓✓, ✓✓ azul) |
| Fecha y hora | separadores por día y hora en cada burbuja |
| Historial en el servidor | `GET /conversations/:id/messages` (persistencia `db.json`), orden cronológico |
| Imágenes y archivos | subida HTTP `POST /upload` (multer) y el WebSocket notifica el mensaje con el adjunto |
| Editar / eliminar propios | pulsación larga → eventos `edit` / `delete` (sólo el remitente) |
| No leídos por conversación | `unread` en `GET /conversations` + incremento en vivo |
| Reconexión automática | backoff 1 → 30 s (`ChatStore._scheduleReconnect`) + heartbeat ping/pong en el servidor |
| Pendientes al reconectar, sin duplicar | *outbox* persistente con `clientId` UUID; el servidor deduplica por `clientId` |
| Sólo participantes acceden | validación en REST (403) y en cada evento WS |

## Deep Linking
| Requisito | Implementación |
|---|---|
| Enlace único por conversación | `https://chat.ejemplo.com/chat/{id}` (campo `link`) |
| Compartir por WhatsApp, correo, etc. | botón compartir → `share_plus` |
| Abrir el chat al tocar el enlace | `app_links`: `getInitialLink()` (app cerrada) + `uriLinkStream` (abierta / segundo plano) → `DeepLinks.process` |
| Sin sesión → login y continuar | el enlace queda en `DeepLinks.pending` y se procesa después de autenticarse |
| Android App Links / iOS Universal Links | `platform_config/` + `/.well-known/assetlinks.json` y `/.well-known/apple-app-site-association` servidos por el backend |
| Enlace inválido / conversación inexistente | diálogo “Enlace no disponible” (404) |
| Privadas no accesibles para no autorizados | 403 → “No tienes permiso…” |
| Invitación a grupos (solicitar o aceptar) | `https://chat.ejemplo.com/join/{code}` → grupo **abierto** entra directo; **con aprobación** envía solicitud que el admin acepta/rechaza |

## Ejecutar
```bash
cd backend && npm install && npm start                      # http://localhost:5000  ws://localhost:5000/ws

cd ../app
flutter create . --project-name chat_realtime --org com.example
# pegar platform_config/AndroidManifest_intent_filters.xml en AndroidManifest.xml
flutter pub get
flutter run --dart-define=API_URL=http://<IP-de-tu-PC>:5000
```
Probar deep link sin dominio propio:
```bash
adb shell am start -a android.intent.action.VIEW -d "chatapp://chat/<id-de-conversación>"
```
Para App Links reales, publica el backend en tu dominio con HTTPS y define `PUBLIC_URL`, `ANDROID_PACKAGE`, `ANDROID_SHA256` e `IOS_APP_ID`.
