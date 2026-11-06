# 04 · OAuth 2.0 + Push Notifications — Objetos perdidos y encontrados (Flutter + Firebase)

| Requisito | Implementación |
|---|---|
| Inicio de sesión con **Google OAuth 2.0** | `google_sign_in` → `idToken/accessToken` → `FirebaseAuth.signInWithCredential` (`lib/services/auth_service.dart`) |
| Perfil (nombre, correo, foto) | `ProfileTab` con los datos de la cuenta de Google |
| Publicar perdido/encontrado (nombre, descripción, foto, categoría, ubicación, fecha) | `PostFormScreen` + Firestore + Firebase Storage |
| Consultar publicaciones de otros | `FeedTab` (stream en tiempo real) |
| Buscar y filtrar por categoría, ubicación y fecha | barra de búsqueda + hoja de filtros |
| Detectar coincidencias | Cloud Function `onPostCreated/onPostUpdated`: tipo opuesto + misma categoría + similitud de descripción (60 %) y ubicación (40 %) |
| Push FCM por coincidencia | `pushToUser()` en `functions/index.js` a ambos dueños |
| Chat con el responsable | colección `chats/{id}/messages` (`chat_screens.dart`) |
| Notificación de nuevos mensajes | Cloud Function `onMessageCreated` |
| Marcar recuperado / entregado | botón en el detalle (sólo el dueño); `status = resuelto` |
| Historial personal | pestaña **Mis publicaciones** (incluye resueltas) |

**Reglas:** login obligatorio (`AuthGate` + reglas de Firestore) · sólo el dueño edita/elimina (`firestore.rules`) ·
al tocar una notificación se abre la publicación o conversación (`PushService.openFromData`, `onMessageOpenedApp`, `getInitialMessage`) ·
las resueltas salen del feed (query `status == pendiente`) · notificaciones con la app cerrada (mensajes FCM con bloque `notification` + canal Android de alta prioridad).

## Configuración
1. Crea un proyecto en Firebase y agrega la app Android (`com.example.objetos_perdidos`) con su **SHA‑1** (`cd android && ./gradlew signingReport`).
2. Activa **Authentication → Google**, **Firestore**, **Storage** y **Cloud Messaging**.
3. ```bash
   flutter create . --project-name objetos_perdidos
   dart pub global activate flutterfire_cli && flutterfire configure   # genera google-services.json
   flutter pub get
   firebase deploy --only firestore,storage,functions               # reglas, índices y Cloud Functions (plan Blaze)
   flutter run
   ```
4. `AndroidManifest.xml`: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` y dentro de `<application>`:
   ```xml
   <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="objetos_channel"/>
   ```
   `minSdkVersion 23`. En iOS habilita *Push Notifications* y *Background Modes → Remote notifications* y sube la llave APNs a Firebase.
