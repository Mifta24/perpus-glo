import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router.dart';
import 'features/notification/service/notification_service.dart';
import 'features/categories/providers/category_provider.dart'; // Tambahkan import ini
import 'features/notification/controller/notification_controller.dart';
import 'features/notification/providers/notification_provider.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initialize();

  // Initialize Notification Service
  await NotificationService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  void _setupNotificationHandlers(WidgetRef ref) {
    ref
        .read(notificationServiceProvider)
        .actionStream
        .listen((ReceivedAction receivedAction) {
      // Handle notification tap
      if (receivedAction.payload != null) {
        final payload = receivedAction.payload!;

        // Example: Navigate based on payload
        if (payload.containsKey('borrowId')) {
          router.push('/borrow/${payload['borrowId']}');
        } else if (payload.containsKey('bookId')) {
          router.push('/books/${payload['bookId']}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Setup notification handlers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationHandlers(ref);
    });

    // Initialize default categories when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(categoryControllerProvider.notifier)
          .initializeDefaultCategories();
    });

    return MaterialApp.router(
      title: 'Perpus GLO',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
