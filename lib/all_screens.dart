import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:testing_sticker/stickr_pack_screen.dart';

class AllStickersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
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
                      return InkWell(
                        onTap: (){
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) => StickerPackScreen(packId: pack.id,packName: pack['name'],),
                          //   ),
                          // );
                        },
                        child: Container(
                          height: 250,
                          width: MediaQuery.sizeOf(context).width * 1,
                          child:
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pack['name']),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: List.generate(stickers.length, (index){
                                    var sticker = stickers[index];
                                    return Column(
                                      children: [
                                        Image.network(
                                          sticker['image_url'],
                                          height: 100,
                                          width: 100,
                                        ),
                                        SizedBox(height: 8.0),
                                        Text(sticker['name']),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ],
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

