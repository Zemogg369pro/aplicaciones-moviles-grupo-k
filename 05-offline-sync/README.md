# 05 · Offline Sync — Reportes de incidencias (Flutter + API REST)

Arquitectura **Offline‑First**: todo se guarda primero en SQLite y una cola de sincronización lo envía al servidor cuando hay conexión real.

```
UI ──► SQLite (reports) ──► sync_queue (FIFO) ──► SyncEngine ──► PUT /reports/:uuid ──► API (confirma 200/201)
                 ▲                                    │
                 └──── estado: pendiente / sincronizando / sincronizado / error
```

| Requisito | Implementación |
|---|---|
| Registrar con título, descripción, categoría, foto, GPS y fecha | `ReportForm` (`image_picker`, `geolocator`) |
| Crear / editar / eliminar sin Internet | `SyncEngine.save/delete` escriben en SQLite y encolan |
| Persistencia aunque se cierre o reinicie | `sqflite` + fotos copiadas al directorio de la app |
| Detectar cambios de red | `connectivity_plus.onConnectivityChanged` |
| Verificar conectividad **real** con el servidor | `GET /health` con timeout antes de sincronizar |
| Sincronización automática | al recuperar red, al abrir la app y cada 15 s si hay pendientes |
| Estados por reporte | `pendiente`, `sincronizando`, `sincronizado`, `error` |
| Cola en orden | tabla `sync_queue` procesada por `id ASC`; si un envío falla se detiene y los datos permanecen |
| Progreso | barra `Enviando X de N` |
| Reintentos automáticos | backoff exponencial 2 s → 5 min (`LocalDb.markFailed`) |
| Sin duplicados en el servidor | UUID generado en el cliente + `PUT` idempotente + `Idempotency-Key`; el servidor ignora versiones viejas |
| Marcado sincronizado sólo con confirmación | se actualiza únicamente con respuesta 2xx |
| Botón sincronizar manual | ícono ⟳ en la barra superior (ignora el backoff) |
| Última sincronización exitosa | se guarda en `shared_preferences` y se muestra en la barra de estado |
| Al reabrir la app revisa pendientes | `SyncEngine.start()` restablece los “sincronizando” y procesa la cola |

## Ejecutar
```bash
cd backend && npm install && npm start            # http://localhost:4000
# npm run flaky  -> simula 40 % de fallos para probar reintentos

cd ../app
flutter create . --project-name incidencias_offline
flutter pub get
flutter run --dart-define=API_URL=http://<IP-de-tu-PC>:4000
```
AndroidManifest: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `CAMERA` y `android:usesCleartextTraffic="true"`.

**Prueba sugerida:** activa modo avión → crea 3 reportes (quedan *pendiente*) → cierra la app → desactiva modo avión y ábrela → se envían en orden y pasan a *sincronizado*.
