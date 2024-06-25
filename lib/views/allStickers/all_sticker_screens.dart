import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:testing_sticker/views/allStickers/all_sticker_community_screen.dart';
import 'package:testing_sticker/views/myStickers/my_sticker_pack_screen.dart';

class AllStickersScreen extends StatelessWidget {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> _toggleFavorite(String packId, bool isFavorited) async {
    String userId = _auth.currentUser!.uid;
    DocumentReference packRef = FirebaseFirestore.instance.collection('packs').doc(packId);

    if (isFavorited) {
      await packRef.update({
        'favorites': FieldValue.arrayRemove([userId])
      });
    } else {
      await packRef.update({
        'favorites': FieldValue.arrayUnion([userId])
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('All Sticker Packs'),
        ),
        body: StreamBuilder(
            stream: FirebaseFirestore.instance.collection('packs').snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              var packs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: packs.length,
                itemBuilder: (context, index) {
                  var pack = packs[index];
                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('packs')
                        .doc(pack.id)
                        .collection('stickers')
                        .limit(5)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) {
                        return ListTile(
                          onTap: (){

                          },
                          title: Text(pack['name']),
                          subtitle: Text('Loading...'),
                        );
                      }
                      var stickers = snapshot.data!.docs;
                      bool isFavorited = pack['favorites'].contains(_auth.currentUser!.uid);

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllStickerCommunityScreen(
                                packId: pack.id,
                                packName: pack['name'],
                                userId:pack['user_id'],
                                trayImage:pack['pack_image'] ,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Card(
                            elevation: 5.0,
                            child: Container(
                              width: MediaQuery.sizeOf(context).width * 1,
                              child:
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(pack['name'], style: TextStyle(
                                              fontSize: 18.0, fontWeight: FontWeight.bold
                                            ),),
                                            Row(
                                              children: [
                                                Text(pack['author_name'], style: TextStyle(
                                                    fontSize: 15.0, fontWeight: FontWeight.w500
                                                ),),
                                                 Text(' . ', style: TextStyle(
                                                   fontSize: 18.0
                                                 ),),
                                                Text('${stickers.length} no of stickers', style: TextStyle(
                                                    fontSize: 12.0, fontWeight: FontWeight.normal
                                                ),),
                                              ],
                                            ),

                                          ],
                                        ),
                                        Column(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _toggleFavorite(pack.id, isFavorited),
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                                                child: Icon(
                                                  isFavorited ? Icons.favorite : Icons.favorite_border,
                                                  color: isFavorited ? Colors.red : Colors.grey,
                                                ),
                                              ),
                                            ),

                                            SizedBox(height: MediaQuery.of(context).size.height*0.01,),
                                            Row(
                                              children: [
                                                Icon(Icons.download, color: Colors.red, size: 16.0,),
                                                Text('${stickers.length}', style: TextStyle(
                                                    fontSize: 12.0, fontWeight: FontWeight.normal,
                                                  color: Colors.red,
                                                  fontStyle: FontStyle.italic
                                                ),),
                                              ],
                                            ),

                                          ],
                                        ),
                                      ],
                                    ),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: List.generate(stickers.length, (index){
                                          var sticker = stickers[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                                            child: CircleAvatar(
                                              maxRadius: 20,
                                              backgroundColor: Colors.white,
                                              child: Image.network(
                                                sticker['image_url'],
                                                height: 50,
                                                width: 50,
                                              ),
                                            ),
                                          );
                                          // return Column(
                                          //   children: [
                                          //     Image.network(
                                          //       sticker['image_url'],
                                          //       height: 50,
                                          //       width: 50,
                                          //     ),
                                          //     // SizedBox(height: 8.0),
                                          //     // Text(sticker['name']),
                                          //   ],
                                          // );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            ),
        );
    }
}

