import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class UploadStickerScreen extends StatefulWidget {
  @override
  _UploadStickerScreenState createState() => _UploadStickerScreenState();
}

class _UploadStickerScreenState extends State<UploadStickerScreen> {
  final _formKey = GlobalKey<FormState>();
  String _authorName = '';
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
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('packs/$fileName');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
      String imageUrl = await taskSnapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('packs').add({
        'name': _stickerName,
        'pack_image': imageUrl,
        'user_id':userId,
        'is_animated':'false',
        'author_name':_authorName,
      }).then((value){

        Navigator.pop(context);
      });

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
                decoration: InputDecoration(labelText: 'Pack Name'),
                onSaved: (value) {
                  _authorName = value!;
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a pack name';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'author Name'),
                onSaved: (value) {
                  _stickerName = value!;
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a sticker name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.0),
              _imageFile == null
                  ? Text('No image selected.')
                  : Image.file(_imageFile!, width: MediaQuery.of(context).size.width*0.2, height: MediaQuery.of(context).size.height*0.2,),
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