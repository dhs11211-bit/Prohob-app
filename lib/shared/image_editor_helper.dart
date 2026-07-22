import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DrawingPoint {
  final Offset point;
  final Paint paint;
  DrawingPoint({required this.point, required this.paint});
}

class ImagePainter extends CustomPainter {
  final List<DrawingPoint?> points;
  ImagePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
            points[i]!.point, points[i + 1]!.point, points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ImageEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageEditorScreen({Key? key, required this.imageBytes})
      : super(key: key);

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  List<DrawingPoint?> points = [];
  final GlobalKey _globalKey = GlobalKey();

  Future<Uint8List?> _captureEditedImage() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return widget.imageBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Mark Photo", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {
              if (points.isNotEmpty) {
                setState(() => points.removeLast());
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF10B981)),
            onPressed: () async {
              Uint8List? editedBytes = await _captureEditedImage();
              Navigator.pop(context, editedBytes);
            },
          )
        ],
      ),
      body: Center(
        child: RepaintBoundary(
          key: _globalKey,
          child: Stack(
            children: [
              Image.memory(widget.imageBytes, fit: BoxFit.contain),
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    setState(() {
                      points.add(DrawingPoint(
                          point:
                              renderBox.globalToLocal(details.globalPosition),
                          paint: Paint()
                            ..color = Colors.red
                            ..strokeWidth = 4.0
                            ..strokeCap = StrokeCap.round));
                    });
                  },
                  onPanEnd: (details) => setState(() => points.add(null)),
                  child: CustomPaint(
                      painter: ImagePainter(points), size: Size.infinite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
