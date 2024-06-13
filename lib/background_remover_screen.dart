import 'package:background_remover/background_remover.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing)
            CircularProgressIndicator()
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: _backgroundRemoved ? 3 : 0),
              ),
              child: Image.memory(_currentImageData),
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
    );
  }
}
