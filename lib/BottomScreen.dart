import 'package:flutter/material.dart';
import 'package:testing_sticker/views/myStickers/upload_stickers.dart';
import 'package:testing_sticker/views/myStickers/my_stickers.dart';
import 'package:testing_sticker/views/allStickers/all_sticker_screens.dart';




class BottomScreen extends StatefulWidget {
  final String userId ;
  const BottomScreen({required this.userId});
  @override
  State<BottomScreen> createState() => _BottomScreenState();
}

class _BottomScreenState extends State<BottomScreen> {
  late int indexx;
  late List<Widget> screens;

  @override
  void initState() {
    super.initState();
    indexx = 0;
    screens = [
      AllStickersScreen(),
      UserPacksScreen(),
      UploadStickerScreen(),
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: screens[indexx],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
            currentIndex: indexx,
            type:BottomNavigationBarType.fixed,
            selectedFontSize: 10.0,
            unselectedFontSize: 8.0,
            selectedIconTheme: const IconThemeData(color:Colors.blue),
            unselectedIconTheme: const IconThemeData(color:Colors.black ),
            selectedItemColor: Colors.blue,
            unselectedItemColor:Colors.white,
            onTap: (index){
              indexx=index;
              setState(() {
              });
            },
            items: const [
              BottomNavigationBarItem(icon:Icon(Icons.public_outlined),label:'Community'),
              BottomNavigationBarItem(icon:Icon(Icons.person),label:'My Sticker'),
              BottomNavigationBarItem(icon:Icon(Icons.groups_2_outlined),label:'Create'),
            ],
    )
    );
  }
}
