import 'package:background_remover/background_remover.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:extended_image/extended_image.dart';

class BackgroundOptionScreen extends StatefulWidget {
  final Uint8List imageData;
  final Function(Uint8List) onImageReady;

  BackgroundOptionScreen({required this.imageData, required this.onImageReady});

  @override
  _BackgroundOptionScreenState createState() => _BackgroundOptionScreenState();
}

class _BackgroundOptionScreenState extends State<BackgroundOptionScreen> {
  late Uint8List _currentImageData;
  late Uint8List _originalImageData;
  bool _backgroundRemoved = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _originalImageData = widget.imageData;
    _currentImageData = widget.imageData;
  }

  Future<void> _removeBackground() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      Uint8List? result = await removeBackground(imageBytes: _originalImageData);

      if (result != null) {
        img.Image? image = img.decodeImage(result);
        if (image != null) {
          img.Image resizedImage = img.copyResize(image, width: 750, height: 750);
          setState(() {
            _currentImageData = Uint8List.fromList(img.encodePng(resizedImage));
            _backgroundRemoved = true;
          });
        }
      }
    } catch (e) {
      print("Error removing background: $e");
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Background Options'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              CircularProgressIndicator()
            else
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExtendedImage.memory(
                  _currentImageData,
                  fit: BoxFit.cover,
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(8),
                  shape: BoxShape.rectangle,
                ),
              ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.no_photography),
                  onPressed: _backgroundRemoved ? _rollbackBackground : null,
                ),
                IconButton(
                  icon: Icon(Icons.auto_fix_high),
                  onPressed: _isProcessing ? null : _removeBackground,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {
                    widget.onImageReady(_currentImageData);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MyPainter extends CustomPainter {
  final double strokeWidth;
  final Color strokeColor;

  MyPainter({required this.strokeWidth, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius - (strokeWidth / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
