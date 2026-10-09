import 'package:flutter/material.dart';

class SignatureCanvasWidget extends StatefulWidget {
  final Function(List<List<Offset>> strokes)? onSignatureChanged;
  final double height;

  const SignatureCanvasWidget({
    super.key,
    this.onSignatureChanged,
    this.height = 180,
  });

  @override
  State<SignatureCanvasWidget> createState() => SignatureCanvasWidgetState();
}

class SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  bool get hasSignature => _strokes.isNotEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
    widget.onSignatureChanged?.call(_strokes);
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      widget.onSignatureChanged?.call(_strokes);
    }
  }

  String exportStrokesData() {
    if (_strokes.isEmpty) return "";
    List<String> strokeStrings = [];
    for (var stroke in _strokes) {
      List<String> pointStrings = stroke.map((p) => "${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}").toList();
      strokeStrings.add(pointStrings.join(";"));
    }
    return strokeStrings.join("|");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _strokes.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Stack(
            children: [
              // GUIDELINE WATERMARK
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.draw_rounded, size: 36, color: Color(0xFFE2E8F0)),
                    SizedBox(height: 6),
                    Text(
                      "Draw Employee Digital Signature Here",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "(Works with Touchscreen, Mouse, or Laptop Touchpad)",
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                    ),
                  ],
                ),
              ),

              // INTERACTIVE CANVAS (STRICTLY CLIPPED TO BOX BOUNDS)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _currentStroke = [details.localPosition];
                      _strokes.add(_currentStroke);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentStroke.add(details.localPosition);
                    });
                    widget.onSignatureChanged?.call(_strokes);
                  },
                  onPanEnd: (details) {
                    _currentStroke = [];
                    widget.onSignatureChanged?.call(_strokes);
                  },
                  child: CustomPaint(
                    painter: SignaturePainter(strokes: _strokes),
                    size: Size.infinite,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  hasSignature ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: hasSignature ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  hasSignature ? "Signature Captured!" : "Signature Required",
                  style: TextStyle(
                    color: hasSignature ? Colors.green : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: hasSignature ? undo : null,
                  icon: const Icon(Icons.undo_rounded, size: 14),
                  label: const Text("Undo", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: hasSignature ? clear : null,
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text("Clear Canvas", style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  SignaturePainter({
    required this.strokes,
    this.color = const Color(0xFF1E293B),
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (var stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      } else {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}

class SavedSignatureViewer extends StatelessWidget {
  final String strokesData;
  final double height;

  const SavedSignatureViewer({
    super.key,
    required this.strokesData,
    this.height = 100,
  });

  List<List<Offset>> _parseStrokes(String data) {
    if (data.trim().isEmpty) return [];
    List<List<Offset>> strokes = [];
    try {
      List<String> strokeParts = data.split("|");
      for (var s in strokeParts) {
        if (s.trim().isEmpty) continue;
        List<Offset> points = [];
        List<String> pointParts = s.split(";");
        for (var p in pointParts) {
          List<String> coords = p.split(",");
          if (coords.length == 2) {
            double? dx = double.tryParse(coords[0]);
            double? dy = double.tryParse(coords[1]);
            if (dx != null && dy != null) {
              points.add(Offset(dx, dy));
            }
          }
        }
        if (points.isNotEmpty) strokes.add(points);
      }
    } catch (_) {}
    return strokes;
  }

  @override
  Widget build(BuildContext context) {
    final strokes = _parseStrokes(strokesData);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: strokes.isEmpty
            ? const Center(
                child: Text(
                  "[ No Digital Signature Captured ]",
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              )
            : CustomPaint(
                painter: SignaturePainter(strokes: strokes, color: const Color(0xFF0F172A), strokeWidth: 2.5),
                size: Size.infinite,
              ),
      ),
    );
  }
}
