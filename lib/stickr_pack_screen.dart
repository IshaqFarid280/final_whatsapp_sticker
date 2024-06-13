import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_editor_plus/options.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:background_remover/background_remover.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:whatsapp_stickers_handler/exceptions.dart';
import 'package:whatsapp_stickers_handler/whatsapp_stickers_handler.dart';

class StickerPackScreen extends StatefulWidget {
  final String packId;
  final String packName;
  final String userId ;
  final String trayImage ;

  StickerPackScreen({required this.packId, required this.packName,required this.userId,required this.trayImage});

  @override
  _StickerPackScreenState createState() => _StickerPackScreenState();
}

class _StickerPackScreenState extends State<StickerPackScreen> {
  List<Uint8List?> _imageDataList = List.generate(30, (index) => null);
  List<bool> _isUploading = List.generate(30, (index) => false);


  Future<void> _uploadSticker(Uint8List imageData) async {
    try {
      // Compress the image to reduce size
      var result = await FlutterImageCompress.compressWithList(
        imageData,
        minWidth: 512,
        minHeight: 512,
        quality: 50, // Adjust quality to get the size under 100KB
        format: CompressFormat.webp
      );

      // Check if the image size is less than 100KB
      if (result.lengthInBytes < 100 * 1024) { // 100KB in bytes
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef = FirebaseStorage.instance.ref().child('stickers/$fileName.webp');
        UploadTask uploadTask = storageRef.putData(result);
        TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
        String imageUrl = await taskSnapshot.ref.getDownloadURL();
        await FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').add({
          'identifier': widget.packId,
          'name': widget.packName,
          'publisher': 'Trending Stickers',
          'publisher_email': 'Chauhantheleader@gmail.com',
          'privacy_policy_website': 'http://kethod.com/apps/trending-stickers/privacy-policy.html',
          'license_agreement_website': '',
          'image_data_version': '1',
          'image_url': imageUrl,
          'user_id': widget.userId
        });
      } else {
        // Handle the case where the image is too large
        print('Image size is too large to upload.');
        // Show a message to the user, e.g., using a Snackbar or a Dialog
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image size is too large (over 100KB). Please try a smaller image.'))
        );
      }
    } catch (e) {
      print("Error uploading sticker: $e");
      // Handle error, e.g., show a Snackbar or Dialog
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image. Please try again.'))
      );
    }
  }

  WhatsappStickersHandler whatsappStickersHandler = WhatsappStickersHandler();

  Future<void> _addStickersToWhatsApp() async {
    var packDoc = await FirebaseFirestore.instance.collection('packs').doc(widget.packId).get();

    if (!packDoc.exists) {
      print('Pack not found');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sticker pack not found.')));
      return;
    }

    var packData = packDoc.data()!;
    var stickersQuery = FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').get();
    var stickersData = await stickersQuery;

    Map<String, List<String>> formattedStickers = {};
    stickersData.docs.forEach((doc) {
      formattedStickers[doc['image_url']] = ["😀,😀"]; // Replace with actual emojis if available
    });

    try {
      await whatsappStickersHandler.addStickerPack(
        widget.packId,
        widget.packName,
        'Trending Stickers',
        widget.trayImage, // Ensure this field contains the correct tray image URL
        "",
        'http://kethod.com/apps/trending-stickers/privacy-policy.html',
        'http://kethod.com/apps/trending-stickers/privacy-policy.html',
        false, // Assuming it's not an animated sticker pack
        formattedStickers,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stickers added to WhatsApp!')));
    } catch (e,s) {
      print('Failed to add stickers to WhatsApp: $e');
      print('Failed to add stickers to WhatsApp: $s');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add stickers to WhatsApp.')));
    }
  }



  void _showBottomSheet(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return BottomSheetContent(
          packId: widget.packId,
          onImageSelected: (Uint8List imageData) async {
            // Remove background and resize to 400x400
            Uint8List? imageWithoutBackground = await _removeBackground(imageData);
            if (imageWithoutBackground != null) {
              setState(() {
                _imageDataList[index] = imageWithoutBackground;
              });
              Navigator.pop(context);
              _openImageEditor(context, imageWithoutBackground, index);
            }
          },
        );
      },
    );
  }

  Future<Uint8List?> _removeBackground(Uint8List imageData) async {
    try {
      // Remove background
      Uint8List? result = await removeBackground(imageBytes: imageData);

      if (result != null) {
        // Decode the image
        img.Image? image = img.decodeImage(result);
        if (image != null) {
          // Resize image to 400x400
          img.Image resizedImage = img.copyResize(image, width: 750, height: 750);

          // Encode the image to WebP format
          return await FlutterImageCompress.compressWithList(
            Uint8List.fromList(img.encodePng(resizedImage)),
            format: CompressFormat.webp,
          );
        }
      }
      return null;
    } catch (e) {
      print("Error removing background: $e");
      return null;
    }
  }

  Uint8List _resizeImage(Uint8List data, int width, int height) {
    img.Image? image = img.decodeImage(data);
    img.Image resized = img.copyResize(image!, width: width, height: height);
    return Uint8List.fromList(img.encodePng(resized));
  }

  Future<void> _openImageEditor(BuildContext context, Uint8List imageData, int index) async {
    var editedImageData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditor(
          image: imageData,
          cropOption: const CropOption(
            reversible: false,
          ),
          emojiOption: EmojiOption(),
        ),
      ),
    );

    if (editedImageData != null) {
      Uint8List? imageWithoutBackground = await _removeBackground(editedImageData);
      if (imageWithoutBackground != null) {
        Uint8List resizedImageData = _resizeImage(imageWithoutBackground, 512, 512);
        setState(() {
          _imageDataList[index] = resizedImageData;
          _uploadSticker(resizedImageData);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(widget.packName),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').snapshots(),
        builder: (context,AsyncSnapshot<QuerySnapshot> snapshot ){
          if(snapshot.connectionState == ConnectionState.waiting){
            return Center(child: CupertinoActivityIndicator(),);
          }else if (snapshot.data!.docs.isEmpty){
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
              ),
              itemCount: 30,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    if (_imageDataList[index] != null) {
                      _openImageEditor(context, _imageDataList[index]!, index);
                    } else {
                      _showBottomSheet(context, index);
                    }
                  },
                  child: Container(
                    margin: EdgeInsets.all(4.0),
                    color: Colors.grey[200],
                    child: _isUploading[index]
                        ? Center(child: CircularProgressIndicator())
                        : _imageDataList[index] != null
                        ? Image.memory(
                      _imageDataList[index]!,
                      fit: BoxFit.cover,
                    )
                        : Icon(Icons.add),
                  ),
                );
              },
            );
          }else if (snapshot.hasData){
            var data = snapshot.data!.docs;
            return Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1,
                    ),
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    physics: BouncingScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          if (index < _imageDataList.length && _imageDataList[index] != null) {
                            _openImageEditor(context, _imageDataList[index]!, index);
                          } else {
                            _showBottomSheet(context, index);
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.all(4.0),
                          color: Colors.grey[200],
                          child: data[index]['image_url'] != null
                              ? Image.network(
                            data[index]['image_url'],
                            fit: BoxFit.cover,
                          )
                              : Icon(Icons.add),
                        ),
                      );
                    },
                  ),
                ),
                TextButton(onPressed: (){
                  _addStickersToWhatsApp();
                }, child: Text('Add Stickers to WhatsApp')),
              ],
            );
          }else{
            return Center(child: Icon(Icons.error),);
          }
        }
      ),
    );
  }
}

class BottomSheetContent extends StatefulWidget {
  final String packId;
  final Function(Uint8List) onImageSelected;

  BottomSheetContent({required this.packId, required this.onImageSelected});

  @override
  _BottomSheetContentState createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<BottomSheetContent> {
  final picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      Uint8List imageData = await pickedFile.readAsBytes();
      widget.onImageSelected(imageData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: Icon(Icons.camera),
          title: Text('Take Photo'),
          onTap: () {
            _pickImage(ImageSource.camera);
          },
        ),
        ListTile(
          leading: Icon(Icons.photo),
          title: Text('Open Gallery'),
          onTap: () {
            _pickImage(ImageSource.gallery);
          },
        ),
      ],
    );
  }
}
