# 02 · Cámara, video y detección de objetos (Flutter + YOLOv8 TFLite)

Aplicación de cámara inteligente que detecta objetos **localmente en el dispositivo** con un modelo
**YOLOv8n en TensorFlow Lite** (80 clases COCO) usando `flutter_vision`. No usa ninguna API externa.

## Funcionalidades
| Requisito | Implementación |
|---|---|
| Fotos y video con la cámara | `camera` · `takePicture()` / `startVideoRecording()` (`lib/screens/camera_screen.dart`) |
| Cámara frontal / trasera | botón ⟳ (`_toggleCamera`), con recuadros espejados en la frontal |
| Detección en tiempo real | `startImageStream` → `Detector.onFrame` (YOLOv8) en cada fotograma libre |
| Recuadros + nombre + % de confianza | `BoxesPainter` (`lib/widgets.dart`) |
| Múltiples objetos simultáneos | YOLO devuelve todas las cajas (NMS iou 0.4) |
| Fotos/videos de la galería | `image_picker` (`gallery_screen.dart`) |
| Pausar video y analizar fotograma | `video_player` + `video_thumbnail` en la posición actual (`video_screen.dart`) |
| Conteo por categoría | `countByLabel` + chips de conteo |
| Guardar foto con recuadros y etiquetas | se dibujan con el paquete `image` y se guarda JPG (`Storage.saveAnnotated`) |
| Historial | JSON + archivos en el directorio de la app (`history_screen.dart`) |
| Compartir resultados | `share_plus` (imagen anotada + resumen) |
| Umbral mínimo configurable | pestaña **Ajustes** (slider, se guarda en `shared_preferences`) |
| Permisos cámara, micrófono, galería | `permission_handler` (`PermissionGate` en `main.dart`) |

## Modelo (obligatorio antes de compilar)
```bash
pip install ultralytics
yolo export model=yolov8n.pt format=tflite      # genera yolov8n_saved_model/yolov8n_float32.tflite
cp yolov8n_saved_model/yolov8n_float32.tflite assets/yolov8n.tflite
```
`assets/labels.txt` ya incluye las 80 clases COCO.

## Ejecutar
```bash
flutter create . --project-name camara_deteccion
flutter pub get
# copia los permisos de platform_config/ (ver abajo)
flutter run
```
Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```
`android/app/build.gradle`: `minSdkVersion 26`, y dentro de `android { aaptOptions { noCompress 'tflite' } }`.

iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`.
