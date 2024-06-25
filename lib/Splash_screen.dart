import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'BottomScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User? _user;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    _user = _auth.currentUser;

    if (_user == null) {
      // No user is signed in, attempt to sign in automatically with device ID
      await _signInWithDeviceId();
    } else {
      // User is already signed in, navigate to appropriate screen
      _navigateToBottomScreen();
    }
  }

  Future<void> _signInWithDeviceId() async {
    String deviceId = await _getDeviceId();
    print('${deviceId} the device id');

    // Construct email with device ID
    String email = 'users${deviceId}@gmail.com'; // Use \$ to escape $ in strings
    String password = '12345678'; // Default password

    print('${email} the email');
    try {
      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;

      // Navigate to bottom screen after successful login
      _navigateToBottomScreen();
    } catch (e) {
      // If user does not exist, attempt to create account
      if (e is FirebaseAuthException && e.code == 'user-not-found') {
        try {
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          _user = userCredential.user;

          // Navigate to bottom screen after successful signup
          _navigateToBottomScreen();
        } catch (e) {
          print('Failed to create user: $e');
          // Handle sign-up failure, e.g., show an error message
        }
      }
      else  if (e is FirebaseAuthException && e.code == 'invalid-credential') {
        try {
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          _user = userCredential.user;

          // Navigate to bottom screen after successful signup
          _navigateToBottomScreen();
        } catch (e) {
          print('Failed to create user: $e');
          // Handle sign-up failure, e.g., show an error message
        }
      }

      else {
        print('Failed to sign in: $e');
        // Handle other sign-in errors
      }
    }
  }

  Future<String> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // unique ID on Android
    }
    throw UnsupportedError('Unsupported platform');
  }

  void _navigateToBottomScreen() {
    if (_user != null) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => BottomScreen(userId: _user!.uid)),
      );
    } else {
      // Handle case where user is not authenticated
      // You might want to show an error message or handle this scenario differently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Image.asset('assets/sticker_packs/what.png', fit: BoxFit.cover),
      ),
    );
  }
}
