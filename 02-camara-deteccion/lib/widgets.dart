import 'package:flutter/material.dart';
import 'detector.dart';

/// Pinta recuadros + etiqueta (nombre y % de confianza) sobre una imagen de tamaño [imageSize]
class BoxesPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final bool mirror;
  BoxesPainter(this.detections, this.imageSize, {this.mirror = false});

  static const _palette = [Colors.red, Colors.green, Colors.blue, Colors.amber, Colors.purple, Colors.pink];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageSize.width, sy = size.height / imageSize.height;
    for (final d in detections) {
      final color = _palette[d.label.hashCode.abs() % _palette.length];
      var left = d.x1 * sx, right = d.x2 * sx;
      if (mirror) {
        final l = size.width - right;
        right = size.width - left;
        left = l;
      }
      final rect = Rect.fromLTRB(left, d.y1 * sy, right, d.y2 * sy);
      canvas.drawRect(rect, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3);
      final tp = TextPainter(
        text: TextSpan(text: ' ${d.caption} ', style: TextStyle(color: Colors.white, fontSize: 13, background: Paint()..color = color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, (rect.top - tp.height).clamp(0, size.height)));
    }
  }

  @override
  bool shouldRepaint(BoxesPainter old) => old.detections != detections;
}

/// Lista de conteo de objetos por categoría
class CountsView extends StatelessWidget {
  final List<Detection> detections;
  const CountsView(this.detections, {super.key});
  @override
  Widget build(BuildContext context) {
    final counts = countByLabel(detections);
    if (counts.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('No se detectaron objetos'));
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: counts.entries.map((e) => Chip(avatar: CircleAvatar(child: Text('${e.value}')), label: Text(e.key))).toList(),
    );
  }
}
