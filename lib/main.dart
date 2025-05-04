import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase_options.dart';
import 'core/router.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Perpus GLO',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set up Firebase Messaging
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    
    // Get FCM token
    String? token = await messaging.getToken();
    print('FCM Token: $token');
  }
  
  // Firebase Auth instance
  static FirebaseAuth get auth => FirebaseAuth.instance;
  
  // Firestore instance
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  
  // Messaging instance
  static FirebaseMessaging get messaging => FirebaseMessaging.instance;
}