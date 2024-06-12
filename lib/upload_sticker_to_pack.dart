import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class UploadStickerScreen extends StatefulWidget {
  final String packId;
  final bool isUser;

  UploadStickerScreen({required this.packId,required this.isUser});

  @override
  _UploadStickerScreenState createState() => _UploadStickerScreenState();
}

class _UploadStickerScreenState extends State<UploadStickerScreen> {
  final _formKey = GlobalKey<FormState>();
  String _stickerName = '';
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

  Future<void> _uploadSticker() async {
    if (_formKey.currentState!.validate() && _imageFile != null) {
      _formKey.currentState!.save();
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('stickers/$fileName');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').add({
        'name': 'stickerName',
        'image_url': imageUrl,
      });

      Navigator.pop(context);
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
              // TextFormField(
              //   decoration: InputDecoration(labelText: 'Sticker Name'),
              //   onSaved: (value) {
              //     _stickerName = value!;
              //   },
              //   validator: (value) {
              //     if (value!.isEmpty) {
              //       return 'Please enter a sticker name';
              //     }
              //     return null;
              //   },
              // ),
              SizedBox(height: 20.0),
              _imageFile == null
                  ? Text('No image selected.')
                  : Image.file(_imageFile!),
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