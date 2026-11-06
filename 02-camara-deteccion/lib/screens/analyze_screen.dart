import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import '../detector.dart';
import '../storage.dart';
import '../widgets.dart';

/// Analiza una imagen (foto, imagen de galería o fotograma de video), muestra resultados,
/// permite guardarla con recuadros/etiquetas en el historial y compartirla.
class AnalyzeScreen extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String source; // 'foto' | 'galeria' | 'video'
  final String? videoPath;
  const AnalyzeScreen({super.key, this.imagePath, this.imageBytes, required this.source, this.videoPath});
  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  img.Image? image;
  Uint8List? jpg;
  List<Detection> detections = [];
  bool loading = true;
  String? savedPath;
  String? error;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final raw = widget.imageBytes ?? await File(widget.imagePath!).readAsBytes();
      final (decoded, bytes) = await decodeUpright(raw);
      final res = await Detector.instance.onImage(bytes, decoded.width, decoded.height);
      setState(() {
        image = decoded;
        jpg = bytes;
        detections = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  Future<String> _save() async {
    if (savedPath != null) return savedPath!;
    final path = await Storage.saveAnnotated(image!, detections, prefix: widget.source);
    final now = DateTime.now();
    await Storage.add(HistoryItem(
      id: now.millisecondsSinceEpoch.toString(),
      type: widget.source == 'video' ? 'video' : 'foto',
      path: widget.source == 'video' ? widget.videoPath! : path,
      framePath: widget.source == 'video' ? path : null,
      date: now,
      detections: detections,
    ));
    setState(() => savedPath = path);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado en el historial')));
    return path;
  }

  Future<void> _share() async {
    final path = await _save();
    final summary = countByLabel(detections).entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
    await Share.shareXFiles([XFile(path)], text: 'Objetos detectados:\n$summary');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.source == 'video' ? 'Análisis de fotograma' : 'Análisis de imagen')),
      body: loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Detectando objetos...')]))
          : error != null
              ? Center(child: Text('Error: $error'))
              : ListView(children: [
                  AspectRatio(
                    aspectRatio: image!.width / image!.height,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(jpg!, fit: BoxFit.fill),
                      CustomPaint(painter: BoxesPainter(detections, Size(image!.width.toDouble(), image!.height.toDouble()))),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${detections.length} objeto(s) detectado(s) · umbral ${(Detector.instance.threshold * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CountsView(detections),
                      const Divider(),
                      ...detections.map((d) => ListTile(dense: true, leading: const Icon(Icons.crop_free), title: Text(d.label),
                          trailing: Text('${(d.confidence * 100).toStringAsFixed(1)}%'))),
                    ]),
                  ),
                ]),
      bottomNavigationBar: loading || error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: savedPath == null ? _save : null, icon: const Icon(Icons.save), label: Text(savedPath == null ? 'Guardar' : 'Guardado'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Compartir'))),
                ]),
              ),
            ),
    );
  }
}
