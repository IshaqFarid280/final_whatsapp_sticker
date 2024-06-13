import 'package:background_remover/background_remover.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

class UploadStickerScreen extends StatefulWidget {
  @override
  _UploadStickerScreenState createState() => _UploadStickerScreenState();
}

class _UploadStickerScreenState extends State<UploadStickerScreen> {
  final _formKey = GlobalKey<FormState>();
  String _authorName = '';
  String _packName = '';
  File? _imageFile;

  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      }
    });
  }

  Future<Uint8List?> _processImage(File imageFile) async {
    Uint8List imageData = await imageFile.readAsBytes();
    Uint8List? imageWithoutBackground = await removeBackground(imageBytes: imageData);

    if (imageWithoutBackground == null) {
      return null; // Return null if background removal failed
    }

    img.Image image = img.decodeImage(imageWithoutBackground)!;
    img.Image resizedImage = img.copyResize(image, width: 96, height: 96);

    List<int> pngData = img.encodePng(resizedImage);
    Uint8List compressedImage = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(pngData),
      minWidth: 96,
      minHeight: 96,
      quality: 50, // Lower the quality further
      format: CompressFormat.png, // Try JPEG instead of PNG
      rotate: 0,
    );


    if (compressedImage.lengthInBytes > 100 * 1024) {
      print("Image size is still greater than 100 KB after further compression.");
      return null; // Handle this case as needed
    }

    return compressedImage;
  }


  Future<void> _uploadSticker() async {
    if (_formKey.currentState!.validate() && _imageFile != null) {
      _formKey.currentState!.save();
      String userId = FirebaseAuth.instance.currentUser!.uid;
      Uint8List? processedImageData = await _processImage(_imageFile!);

      if (processedImageData != null) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef = FirebaseStorage.instance.ref().child('packs/$fileName.png');
        UploadTask uploadTask = storageRef.putData(processedImageData);
        TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
        String imageUrl = await taskSnapshot.ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('packs').add({
          'name': _packName,
          'pack_image': imageUrl,
          'user_id': userId,
          'is_animated': 'false',
          'author_name': _authorName,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Sticker'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Author Name'),
                onSaved: (value) {
                  _authorName = value!;
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a Author name';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Pack Name'),
                onSaved: (value) {
                  _packName = value!;
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a Pack name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.0),
              _imageFile == null
                  ? Text('No image selected.')
                  : Image.file(_imageFile!, width: MediaQuery.of(context).size.width * 0.2, height: MediaQuery.of(context).size.height * 0.2),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Select Image'),
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: _uploadSticker,
                child: Text('Upload Sticker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
