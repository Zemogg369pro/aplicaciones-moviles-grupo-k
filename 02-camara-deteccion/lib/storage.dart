import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'detector.dart';

/// Elemento del historial (foto o video analizado)
class HistoryItem {
  final String id;
  final String type; // 'foto' | 'video'
  final String path; // imagen anotada o video
  final String? framePath; // para videos: fotograma analizado (anotado)
  final DateTime date;
  final List<Detection> detections;

  HistoryItem({required this.id, required this.type, required this.path, this.framePath, required this.date, required this.detections});

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'path': path, 'framePath': framePath,
        'date': date.toIso8601String(), 'detections': detections.map((d) => d.toJson()).toList(),
      };
  factory HistoryItem.fromJson(Map j) => HistoryItem(
        id: j['id'], type: j['type'], path: j['path'], framePath: j['framePath'],
        date: DateTime.parse(j['date']),
        detections: (j['detections'] as List).map((d) => Detection.fromJson(d)).toList(),
      );

  Map<String, int> get counts => countByLabel(detections);
  String get summary => counts.entries.map((e) => '${e.value} ${e.key}').join(', ');
}

class Storage {
  static Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/detecciones');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _file() async => File('${(await _dir()).path}/historial.json');

  static Future<List<HistoryItem>> load() async {
    final f = await _file();
    if (!await f.exists()) return [];
    final list = jsonDecode(await f.readAsString()) as List;
    return list.map((e) => HistoryItem.fromJson(e)).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> _saveAll(List<HistoryItem> items) async =>
      (await _file()).writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));

  static Future<void> add(HistoryItem item) async {
    final items = await load();
    items.insert(0, item);
    await _saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await load();
    final it = items.where((e) => e.id == id);
    for (final i in it) {
      for (final p in [i.path, i.framePath]) {
        if (p != null && await File(p).exists()) await File(p).delete();
      }
    }
    items.removeWhere((e) => e.id == id);
    await _saveAll(items);
  }

  /// Dibuja recuadros y etiquetas sobre la imagen y la guarda como JPG
  static Future<String> saveAnnotated(img.Image image, List<Detection> dets, {String prefix = 'foto'}) async {
    final out = img.Image.from(image);
    const colors = [
      [239, 68, 68], [34, 197, 94], [59, 130, 246], [234, 179, 8], [168, 85, 247], [236, 72, 153],
    ];
    final thick = (out.width / 250).clamp(2, 8).toInt();
    for (final d in dets) {
      final c = colors[d.label.hashCode.abs() % colors.length];
      final color = img.ColorRgb8(c[0], c[1], c[2]);
      img.drawRect(out, x1: d.x1.toInt(), y1: d.y1.toInt(), x2: d.x2.toInt(), y2: d.y2.toInt(), color: color, thickness: thick);
      final font = out.width > 1200 ? img.arial48 : img.arial24;
      final th = out.width > 1200 ? 52 : 28;
      final ty = (d.y1 - th).clamp(0, out.height - th).toInt();
      img.fillRect(out, x1: d.x1.toInt(), y1: ty, x2: (d.x1 + d.caption.length * th * 0.55).toInt(), y2: ty + th, color: color);
      img.drawString(out, d.caption, font: font, x: d.x1.toInt() + 4, y: ty + 2, color: img.ColorRgb8(255, 255, 255));
    }
    final path = '${(await _dir()).path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(img.encodeJpg(out, quality: 90));
    return path;
  }

  static Future<String> copyVideo(String src) async {
    final path = '${(await _dir()).path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(src).copy(path);
    return path;
  }
}

/// Decodifica una imagen corrigiendo la orientación EXIF; devuelve la imagen y sus bytes JPG
Future<(img.Image, Uint8List)> decodeUpright(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('No se pudo leer la imagen');
  final upright = img.bakeOrientation(decoded);
  return (upright, Uint8List.fromList(img.encodeJpg(upright, quality: 95)));
}
