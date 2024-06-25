import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:background_remover/background_remover.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:image_editor_plus/options.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:testing_sticker/background_remover_screen.dart';
import 'package:whatsapp_stickers_exporter/whatsapp_stickers_exporter.dart';

class AllStickerCommunityScreen extends StatefulWidget {
  final String packId;
  final String packName;
  final String userId ;
  final String trayImage ;

  AllStickerCommunityScreen({required this.packId, required this.packName,required this.userId,required this.trayImage});

  @override
  State<AllStickerCommunityScreen> createState() => _AllStickerCommunityScreenState();
}

class _AllStickerCommunityScreenState extends State<AllStickerCommunityScreen> {
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
            // Uint8List? imageWithoutBackground = await _removeBackground(imageData);
            // if (imageWithoutBackground != null) {
            //   setState(() {
            //     _imageDataList[index] = imageWithoutBackground;
            //   });
            //   Navigator.pop(context);
            //   _openImageEditor(context, imageWithoutBackground, index);
            // }
            Navigator.push(context, CupertinoPageRoute(
                builder: (ctx) => BackgroundOptionScreen(
                    imageData: imageData,
                    onImageReady: (processedImage){
                      setState(() {
                        _imageDataList[index] = processedImage;
                      });
                      _openImageEditor(context, processedImage, index);
                    })));
          },
        );
      },
    );
  }

  Future<void> _incrementDownloadCount(String packId) async {
    DocumentReference packRef = FirebaseFirestore.instance.collection('packs').doc(packId);
    await packRef.update({
      'download_count': FieldValue.increment(1)
    });
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
    var editedImageData = await Navigator.pushReplacement(
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

    var applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
    var stickersDirectory = Directory('${applicationDocumentsDirectory.path}/stickers');
    print("Application documents directory: ${applicationDocumentsDirectory.path}");

    await stickersDirectory.create(recursive: true);
    print("Created stickers directory at: ${stickersDirectory.path}");

    // Create separate directory for tray image
    var trayImagesDirectory = Directory('${stickersDirectory.path}/tray_images');
    await trayImagesDirectory.create(recursive: true);
    print("Created tray images directory at: ${trayImagesDirectory.path}");

    final dio = Dio();

    try {
      var packDataSnapshot = await FirebaseFirestore.instance.collection('packs').doc(widget.packId).get();
      if (!packDataSnapshot.exists) {
        print("Pack data not found for packId: ${widget.packId}");
        return;
      }

      print("Pack data: ${packDataSnapshot.data()}");

      String trayImageUrl = packDataSnapshot['pack_image'] ?? '';
      String trayImageFileName = 'tray_${Random().nextInt(100000)}.png'; // Ensure PNG format for tray image
      String name = packDataSnapshot['name'] ?? '';
      String publisher = 'Trending Stickers'; // Replace with actual publisher
      String privacyPolicyWebsite = 'http://example.com/privacy-policy.html'; // Replace with actual URL
      String licenseAgreementWebsite = 'http://example.com/license-agreement.html'; // Replace with actual URL

      if (trayImageUrl.isEmpty || name.isEmpty || publisher.isEmpty) {
        print("Required pack data fields are missing.");
        return;
      }

      // Download tray image and save in tray images directory
      String trayImagePath = '${trayImagesDirectory.path}/$trayImageFileName';
      await dio.download(trayImageUrl, trayImagePath);
      print("Downloaded tray image as PNG: $trayImagePath");

      if (!await File(trayImagePath).exists()) {
        print("Tray image file does not exist: $trayImagePath");
        return;
      }

      var stickersData = await FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').get();
      if (stickersData.docs.isEmpty) {
        print("No stickers found for packId: ${widget.packId}");
        return;
      }

      if (stickersData.docs.length < 3 || stickersData.docs.length > 30) {
        print("Invalid number of stickers: ${stickersData.docs.length}");
        return;
      }

      print("Creating sticker set for packId: ${widget.packId}");

      List<List<String>> stickerSet = [];

      List<String> defaultEmojis = ["😊", "😂", "❤️"];

      for (var stickerSnapshot in stickersData.docs) {
        var stickerData = stickerSnapshot.data();
        if (stickerData == null) continue;

        String imageUrl = stickerData['image_url'];
        String stickerFileName = '${Random().nextInt(100000)}.webp';

        String localFilePath = '${stickersDirectory.path}/$stickerFileName';

        try {
          await dio.download(imageUrl, localFilePath);
          print("Downloaded sticker: $imageUrl");

          // Ensure the sticker file exists
          if (!await File(localFilePath).exists()) {
            print("Sticker file does not exist: $localFilePath");
            continue; // Skip to next sticker on failure
          }

          List<String> emojis = stickerData['emojis'] ?? defaultEmojis;
          if (emojis.length > 3) {
            print("Too many emojis for sticker: $localFilePath. Using only the first 3.");
            emojis = emojis.sublist(0, 3);
          }

          List<String> stickerObject = [];
          stickerObject.add(WhatsappStickerImage.fromFile(localFilePath).path);
          stickerObject.addAll(emojis);

          stickerSet.add(stickerObject);
        } catch (e) {
          print("Error downloading or processing sticker: $e");
        }
      }

      var exporter = WhatsappStickersExporter();
      try {
        await exporter.addStickerPack(
            widget.packId, // identifier
            name, // name
            publisher, // publisher
            WhatsappStickerImage.fromFile(trayImagePath).path, // trayImage
            '', // publisherWebsite
            privacyPolicyWebsite, // privacyPolicyWebsite
            licenseAgreementWebsite, // licenseAgreementWebsite
            false, // animatedStickerPack
            stickerSet
        );
        _incrementDownloadCount(widget.packId);
        print("Sticker pack sent to WhatsApp successfully.");
      } catch (e) {
        print("Failed to send sticker pack to WhatsApp. Error: $e");
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

  bool _isLoading = false;
  ProgressDialog? _progressDialog;

  @override
  void initState() {
    super.initState();
    _progressDialog = ProgressDialog(context: context);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.packName),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('packs').doc(widget.packId).collection('stickers').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CupertinoActivityIndicator());
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // If no stickers exist in Firestore, show 30 empty slots
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
          }
          else {
            // If stickers exist in Firestore, populate existing stickers and show remaining empty slots
            var data = snapshot.data!.docs;
            List<String> imageUrlList = data.map((doc) => doc['image_url'] as String).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Author Name here'),

                      Row(
                        children: [
                          Icon(Icons.favorite_border, ),
                          SizedBox(width: MediaQuery.of(context).size.width*0.02,),

                          Icon(Icons.share, ),
                          SizedBox(width: MediaQuery.of(context).size.width*0.02,),
                        ],
                      )
                    ],),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1,
                    ),
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      if (index < imageUrlList.length) {
                        // Show existing stickers from Firestore
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
                            child: imageUrlList[index] != null
                                ? Image.network(
                              imageUrlList[index],
                              fit: BoxFit.cover,
                            )
                                : Icon(Icons.add),
                          ),
                        );
                      } else {
                        // Show empty slots for new stickers
                        return GestureDetector(
                          onTap: () {
                            _showBottomSheet(context, index);
                          },
                          child: Container(
                            margin: EdgeInsets.all(4.0),
                            color: Colors.grey[200],
                            child: _isUploading[index]
                                ? Center(child: CircularProgressIndicator())
                                : Container(
                              decoration: BoxDecoration(
                                // No color specified, so the background will be removed
                                border: Border.all(
                                  color: Colors.blue, // Border color
                                  width: 3.0,         // Border width
                                ),),
                              child: _imageDataList[index] != null
                                  ? Image.memory(
                                _imageDataList[index]!,
                                fit: BoxFit.cover,

                              )
                                  : Icon(Icons.add,
                                color: Colors.blue,),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _progressDialog!.show(
                      max: 100,
                      msg: 'Downloading stickers...',
                      progressType: ProgressType.valuable,
                    );
                    try {
                      await _downloadAndAddStickers();
                    } catch (e) {
                      // Handle error here, e.g., show a Snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add stickers to WhatsApp.')),
                      );
                    } finally {

                      _progressDialog!.close();
                    }
                  },
                  child: Text('Add Stickers to WhatsApp'),
                ),
                // if (_isLoading)
                //   CupertinoActivityIndicator(),
              ],
            );
          }

        },
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