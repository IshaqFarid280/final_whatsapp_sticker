import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ManualBackgroundRemovalScreen extends StatefulWidget {
  final Uint8List imageData;
  final Function(Uint8List) onImageReady;

  ManualBackgroundRemovalScreen({required this.imageData, required this.onImageReady});

  @override
  _ManualBackgroundRemovalScreenState createState() => _ManualBackgroundRemovalScreenState();
}

class _ManualBackgroundRemovalScreenState extends State<ManualBackgroundRemovalScreen> {
  late Uint8List _currentImageData;
  late Uint8List _originalImageData;
  bool _backgroundRemoved = false;
  bool _isProcessing = false;
  List<Offset> _selectedPoints = [];

  @override
  void initState() {
    super.initState();
    _originalImageData = widget.imageData;
    _currentImageData = widget.imageData;
  }

  void _addSelectedPoint(Offset point) {
    setState(() {
      _selectedPoints.add(point);
    });
  }

  Future<void> _cropImage() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Decode the image
      img.Image image = img.decodeImage(_originalImageData)!;

      // Convert selected points to integer points
      List<int> points = [];
      for (var point in _selectedPoints) {
        points.add(point.dx.toInt());
        points.add(point.dy.toInt());
      }

      // Find the bounding box of the polygon
      int minX = _selectedPoints.map((p) => p.dx.toInt()).reduce((a, b) => a < b ? a : b);
      int minY = _selectedPoints.map((p) => p.dy.toInt()).reduce((a, b) => a < b ? a : b);
      int maxX = _selectedPoints.map((p) => p.dx.toInt()).reduce((a, b) => a > b ? a : b);
      int maxY = _selectedPoints.map((p) => p.dy.toInt()).reduce((a, b) => a > b ? a : b);

      // Ensure dimensions are valid
      int width = maxX - minX;
      int height = maxY - minY;

      if (width > 0 && height > 0) {
        // Create a new image with the size of the bounding box
        img.Image croppedImage = img.copyCrop(
          image,
          x: minX,
          y: minY,
          width: width,
          height: height,
        );

        // Encode the image to Uint8List
        _currentImageData = Uint8List.fromList(img.encodePng(croppedImage));
        _backgroundRemoved = true;
      } else {
        print("Invalid crop dimensions: width=$width, height=$height");
      }
    } catch (e) {
      print("Error cropping image: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _rollbackBackground() {
    setState(() {
      _currentImageData = _originalImageData;
      _backgroundRemoved = false;
      _selectedPoints.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Manual Background Removal'),
      ),
      body: GestureDetector(
        onTapUp: (details) {
          if (!_backgroundRemoved) {
            _addSelectedPoint(details.localPosition);
          }
        },
        child: Stack(
          children: [
            if (_currentImageData.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: _backgroundRemoved ? 3 : 0),
                ),
                child: Image.memory(_currentImageData),
              ),
            CustomPaint(
              painter: _SelectionPainter(selectedPoints: _selectedPoints),
            ),
            if (_isProcessing) Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _backgroundRemoved ? _rollbackBackground : _cropImage,
        child: _backgroundRemoved ? Icon(Icons.undo) : Icon(Icons.check),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final List<Offset> selectedPoints;

  _SelectionPainter({required this.selectedPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path path = Path();
    if (selectedPoints.isNotEmpty) {
      path.moveTo(selectedPoints.first.dx, selectedPoints.first.dy);
      for (var i = 1; i < selectedPoints.length; i++) {
        path.lineTo(selectedPoints[i].dx, selectedPoints[i].dy);
      }
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
