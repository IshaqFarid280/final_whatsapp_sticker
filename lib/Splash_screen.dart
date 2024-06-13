import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'BottomScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  FirebaseAuth  auth = FirebaseAuth.instance;

  Future<String?> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // unique ID on Android
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor; // unique ID on iOS
    }
    return null;
  }

  checkUserStatus() async {
    await auth.signInAnonymously().then((value){
      Navigator.push(context, CupertinoPageRoute(builder: (context)=> BottomScreen(userId: auth.currentUser!.uid)));
    });
  }

  @override
  void initState() {
    super.initState();
    checkUserStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Image.asset('assets/images/splash.jpg', fit: BoxFit.cover),
      ),
    );
  }
}
