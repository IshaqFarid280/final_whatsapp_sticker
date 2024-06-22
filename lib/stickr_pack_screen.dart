import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_stickers_handler/exceptions.dart';
import 'dart:io';
import 'package:whatsapp_stickers_plus/whatsapp_stickers.dart';

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


  Future<void> _downloadAndAddStickers() async {
    print("Starting _downloadAndAddStickers function.");

    // Get application documents directory
    var applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
    var stickersDirectory = Directory('${applicationDocumentsDirectory.path}/stickers');
    print("Application documents directory: ${applicationDocumentsDirectory.path}");

    // Create stickers directory
    await stickersDirectory.create(recursive: true);
    print("Created stickers directory at: ${stickersDirectory.path}");

    final dio = Dio();

    try {
      // Fetch pack data from Firestore
      var packDataSnapshot = await FirebaseFirestore.instance.collection('packs').doc(widget.packId).get();
      if (!packDataSnapshot.exists) {
        print("Pack data not found for packId: ${widget.packId}");
        return;
      }

      // Print all fields in the pack document snapshot for debugging
      print("Pack data: ${packDataSnapshot.data()}");

      // Extract pack data fields with null checks
      String trayImageUrl = packDataSnapshot['pack_image'] ?? '';
      String trayImageFileName = 'tray_${Random().nextInt(100000)}.webp';
      String name = packDataSnapshot['name'] ?? '';
      String publisher = 'Trending Stickers'; // Replace with actual publisher
      String privacyPolicyWebsite = 'http://example.com/privacy-policy.html'; // Replace with actual URL
      String licenseAgreementWebsite = 'http://example.com/license-agreement.html'; // Replace with actual URL

      if (trayImageUrl.isEmpty || name.isEmpty || publisher.isEmpty) {
        print("Required pack data fields are missing.");
        return;
      }

      // Download and convert tray image
      String trayImagePath = '${stickersDirectory.path}/$trayImageFileName';
      await dio.download(trayImageUrl, trayImagePath);
      await convertImageToWebP(trayImagePath, trayImagePath);
      print("Downloaded tray image.");

      // Fetch stickers data from Firestore
      var stickersData = await FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').get();
      if (stickersData.docs.isEmpty) {
        print("No stickers found for packId: ${widget.packId}");
        return;
      }

      // Ensure we have between 3 and 30 stickers
      if (stickersData.docs.length < 3 || stickersData.docs.length > 30) {
        print("Invalid number of stickers: ${stickersData.docs.length}");
        return;
      }

      // Create the sticker pack
      print("Creating sticker pack with packId: ${widget.packId}");
      var stickerPack = WhatsappStickers(
        identifier: widget.packId, // Use packId as identifier for the pack
        name: name,
        publisher: publisher,
        trayImageFileName: WhatsappStickerImage.fromFile(trayImagePath),
        publisherWebsite: '',
        privacyPolicyWebsite: privacyPolicyWebsite,
        licenseAgreementWebsite: licenseAgreementWebsite,
      );

      // Default emojis to use if none are found in the database
      List<String> defaultEmojis = ["😊", "😂", "❤️"];

      // Download each sticker image
      for (var stickerSnapshot in stickersData.docs) {
        var stickerData = stickerSnapshot.data();
        if (stickerData == null) continue;

        String imageUrl = stickerData['image_url'];
        String stickerFileName = '${Random().nextInt(100000)}.webp';

        // Determine the local file path
        String localFilePath = '${stickersDirectory.path}/$stickerFileName';

        // Download sticker image
        await dio.download(imageUrl, localFilePath);
        print("Downloaded sticker: $imageUrl");

        // Convert sticker to WebP format
        await convertImageToWebP(localFilePath, localFilePath);
        print("Converted and saved sticker: $localFilePath");

        // Use dummy emojis if none are provided
        List<String> emojis = stickerData['emojis'] ?? defaultEmojis;
        if (emojis.length > 3) {
          print("Too many emojis for sticker: $localFilePath. Using only the first 3.");
          emojis = emojis.sublist(0, 3);
        }

        // Add sticker to pack using the .webp path
        stickerPack.addSticker(WhatsappStickerImage.fromFile(localFilePath), emojis);
      }

      print("All stickers added to the pack.");

      // Send sticker pack to WhatsApp
      try {
        print("Sending sticker pack to WhatsApp.");
        await stickerPack.sendToWhatsApp();
        print("Sticker pack sent to WhatsApp successfully.");
      } on WhatsappStickersException catch (e) {
        print("Failed to send sticker pack to WhatsApp. Error: ${e.cause}");
      }

    } catch (e, s) {
      print("Error in _downloadAndAddStickers: $e");
      print("Error stack trace: $s");
    }
  }


  Future<void> convertImageToWebP(String imagePath, String outputPath) async {
    try {
      // Compress image to WebP format
      Uint8List? imageBytes = await FlutterImageCompress.compressWithFile(
        imagePath,
        format: CompressFormat.webp,
        quality: 50,
      );

      // Check if imageBytes is not null before proceeding
      if (imageBytes != null) {
        // Write compressed image bytes to file
        await File(outputPath).writeAsBytes(imageBytes);

        print("Converted image to WebP: $outputPath");
      } else {
        print("Failed to compress image: imageBytes is null");
      }
    } catch (e) {
      print("Failed to convert image to WebP: $e");
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
                        onTap:() {
                        if (_imageDataList[index] != null) {
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
                TextButton(
                  onPressed: () async {
                    await _downloadAndAddStickers();
                  },
                  child: Text('Add Stickers to WhatsApp'),
                ),
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
