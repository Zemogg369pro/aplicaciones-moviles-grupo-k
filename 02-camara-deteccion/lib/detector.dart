import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de una detección. Coordenadas en píxeles de la imagen original.
class Detection {
  final String label;
  final double confidence;
  final double x1, y1, x2, y2;
  Detection(this.label, this.confidence, this.x1, this.y1, this.x2, this.y2);

  factory Detection.fromYolo(Map r) {
    final b = (r['box'] as List).map((e) => (e as num).toDouble()).toList();
    return Detection(r['tag'] as String, b[4], b[0], b[1], b[2], b[3]);
  }
  factory Detection.fromJson(Map j) => Detection(j['label'], (j['confidence'] as num).toDouble(),
      (j['x1'] as num).toDouble(), (j['y1'] as num).toDouble(), (j['x2'] as num).toDouble(), (j['y2'] as num).toDouble());
  Map<String, dynamic> toJson() => {'label': label, 'confidence': confidence, 'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2};

  String get caption => '$label ${(confidence * 100).toStringAsFixed(0)}%';
}

/// Cuenta los objetos detectados por categoría
Map<String, int> countByLabel(List<Detection> d) {
  final m = <String, int>{};
  for (final x in d) {
    m[x.label] = (m[x.label] ?? 0) + 1;
  }
  return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}

/// Envoltura del modelo YOLOv8 TFLite. Todo se ejecuta en el dispositivo (sin API externa).
class Detector {
  Detector._();
  static final instance = Detector._();

  final _vision = FlutterVision();
  bool _loaded = false;
  bool _busy = false;
  double threshold = 0.5; // umbral mínimo de confianza configurable

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    threshold = prefs.getDouble('threshold') ?? 0.5;
    await _vision.loadYoloModel(
      modelPath: 'assets/yolov8n.tflite',
      labels: 'assets/labels.txt',
      modelVersion: 'yolov8',
      quantization: false,
      numThreads: 2,
      useGpu: false,
    );
    _loaded = true;
  }

  Future<void> setThreshold(double v) async {
    threshold = v;
    (await SharedPreferences.getInstance()).setDouble('threshold', v);
  }

  /// Detección en un fotograma de la transmisión de la cámara (tiempo real).
  /// Devuelve null si el modelo sigue ocupado con el fotograma anterior.
  Future<List<Detection>?> onFrame(CameraImage img) async {
    if (!_loaded || _busy) return null;
    _busy = true;
    try {
      final res = await _vision.yoloOnFrame(
        bytesList: img.planes.map((p) => p.bytes).toList(),
        imageHeight: img.height,
        imageWidth: img.width,
        iouThreshold: 0.4,
        confThreshold: threshold,
        classThreshold: threshold,
      );
      return res.map(Detection.fromYolo).where((d) => d.confidence >= threshold).toList();
    } finally {
      _busy = false;
    }
  }

  /// Detección sobre una imagen (foto tomada, galería o fotograma de video).
  Future<List<Detection>> onImage(Uint8List bytes, int width, int height) async {
    await load();
    while (_busy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _busy = true;
    try {
      final res = await _vision.yoloOnImage(
        bytesList: bytes,
        imageHeight: height,
        imageWidth: width,
        iouThreshold: 0.5,
        confThreshold: threshold,
        classThreshold: threshold,
      );
      return res.map(Detection.fromYolo).where((d) => d.confidence >= threshold).toList();
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    if (_loaded) await _vision.closeYoloModel();
    _loaded = false;
  }
}
