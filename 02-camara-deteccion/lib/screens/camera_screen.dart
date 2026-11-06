import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../detector.dart';
import '../storage.dart';
import '../widgets.dart';
import 'analyze_screen.dart';
import 'video_screen.dart';

/// Cámara en vivo: detección en tiempo real, foto, video y cambio frontal/trasera
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  int camIndex = 0;
  List<Detection> detections = [];
  Size frameSize = const Size(1, 1);
  bool liveDetection = true;
  bool recording = false;
  Duration recTime = Duration.zero;
  Timer? recTimer;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
      controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _start(camIndex);
    }
  }

  Future<void> _setup() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No hay cámaras disponibles');
      await _start(0);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> _start(int index) async {
    final old = controller;
    controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(cameras[index], ResolutionPreset.medium, enableAudio: true, imageFormatGroup: ImageFormatGroup.yuv420);
    await c.initialize();
    controller = c;
    camIndex = index;
    if (liveDetection) await _startStream();
    if (mounted) setState(() {});
  }

  Future<void> _startStream() async {
    final c = controller;
    if (c == null || c.value.isStreamingImages) return;
    await c.startImageStream((CameraImage img) async {
      final res = await Detector.instance.onFrame(img);
      if (res == null || !mounted) return;
      setState(() {
        detections = res;
        // flutter_vision devuelve coordenadas en orientación vertical (ancho = alto del sensor)
        frameSize = Size(img.height.toDouble(), img.width.toDouble());
      });
    });
  }

  Future<void> _stopStream() async {
    if (controller?.value.isStreamingImages ?? false) await controller!.stopImageStream();
    if (mounted) setState(() => detections = []);
  }

  Future<void> _toggleCamera() async {
    if (cameras.length < 2 || recording) return;
    await _start((camIndex + 1) % cameras.length);
  }

  Future<void> _takePhoto() async {
    final c = controller;
    if (c == null || recording) return;
    await _stopStream();
    try {
      final file = await c.takePicture();
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyzeScreen(imagePath: file.path, source: 'foto')));
    } catch (e) {
      _snack('Error al tomar la foto: $e');
    } finally {
      if (liveDetection && mounted) await _startStream();
    }
  }

  Future<void> _toggleRecording() async {
    final c = controller;
    if (c == null) return;
    if (!recording) {
      await _stopStream(); // la mayoría de dispositivos no permite stream + grabación a la vez
      await c.startVideoRecording();
      recTime = Duration.zero;
      recTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => recTime += const Duration(seconds: 1)));
      setState(() => recording = true);
    } else {
      final file = await c.stopVideoRecording();
      recTimer?.cancel();
      setState(() => recording = false);
      final saved = await Storage.copyVideo(file.path);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoScreen(videoPath: saved, isNew: true)));
      if (liveDetection && mounted) await _startStream();
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Scaffold(body: Center(child: Text(error!)));
    final c = controller;
    final front = cameras.isNotEmpty && cameras[camIndex].lensDirection == CameraLensDirection.front;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Cámara inteligente'),
        actions: [
          Row(children: [
            const Text('IA en vivo'),
            Switch(
              value: liveDetection,
              onChanged: recording ? null : (v) async {
                setState(() => liveDetection = v);
                v ? await _startStream() : await _stopStream();
              },
            ),
          ]),
        ],
      ),
      body: c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1 / c.value.aspectRatio,
                    child: Stack(fit: StackFit.expand, children: [
                      CameraPreview(c),
                      CustomPaint(painter: BoxesPainter(detections, frameSize, mirror: front)),
                      if (recording)
                        Positioned(
                          top: 8, left: 8,
                          child: Chip(
                            backgroundColor: Colors.red,
                            label: Text('● REC ${recTime.inMinutes.toString().padLeft(2, '0')}:${(recTime.inSeconds % 60).toString().padLeft(2, '0')}'),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
              if (liveDetection) Container(color: Colors.black54, width: double.infinity, child: CountsView(detections)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton.filledTonal(iconSize: 32, onPressed: _toggleCamera, icon: const Icon(Icons.cameraswitch), tooltip: 'Frontal / trasera'),
                  IconButton.filled(iconSize: 48, onPressed: _takePhoto, icon: const Icon(Icons.camera), tooltip: 'Tomar foto'),
                  IconButton.filledTonal(
                    iconSize: 32,
                    style: recording ? IconButton.styleFrom(backgroundColor: Colors.red) : null,
                    onPressed: _toggleRecording,
                    icon: Icon(recording ? Icons.stop : Icons.videocam),
                    tooltip: recording ? 'Detener' : 'Grabar video',
                  ),
                ]),
              ),
            ]),
    );
  }
}
