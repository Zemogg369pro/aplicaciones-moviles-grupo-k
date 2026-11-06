# 03 · GPS + Bluetooth + Sensores (Flutter)

Aplicación de monitoreo de recorridos y dispositivos cercanos.

| Requisito | Implementación (`lib/`) |
|---|---|
| Ubicación actual en mapa | `geolocator` + `flutter_map` (OpenStreetMap) — `TrackScreen` |
| Registrar recorridos (inicio/fin manual) | botones Iniciar / Finalizar → `Tracker.startTrip/stopTrip` |
| Distancia, duración y velocidad en vivo | `Geolocator.distanceBetween` acumulada, timer de 1 s, `position.speed` |
| Dibujar ruta | `PolylineLayer` con los puntos del recorrido |
| Movimiento / detenido (acelerómetro real) | `userAccelerometerEventStream` (sin gravedad), promedio móvil > 0.6 m/s² |
| Cambios de orientación (giroscopio) | `gyroscopeEventStream`: integra la velocidad angular en Z y registra giros ≥ 45° |
| Escaneo BLE, nombre y RSSI | `flutter_blue_plus` — `BleScreen` |
| Proximidad aproximada por RSSI | modelo log-distance `d = 10^((txPower − RSSI)/(10·n))`, etiquetas inmediato/cerca/medio/lejos |
| Seleccionar dispositivo y registrar detecciones | tocar dispositivo → se guarda hora + lat/lng cada 5 s mientras se detecta |
| Historial persistente y detalle | `shared_preferences` (JSON) — `HistoryScreen` / `TripDetail` con mapa, BLE y eventos |
| Permisos | `permission_handler`: ubicación, bluetoothScan/Connect, sensores |

## Ejecutar
```bash
flutter create . --project-name recorridos_ble
flutter pub get
flutter run       # usar un teléfono físico: el emulador no tiene BLE ni sensores reales
```
**AndroidManifest.xml**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.HIGH_SAMPLING_RATE_SENSORS"/>
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```
`minSdkVersion 21`. iOS: `NSLocationWhenInUseUsageDescription`, `NSBluetoothAlwaysUsageDescription`, `NSMotionUsageDescription`.
