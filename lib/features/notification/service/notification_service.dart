import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firebase_service.dart';
import '../model/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Collection references
  CollectionReference get _notificationsRef => _firestore.collection('notifications');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Initialize notifications
  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/app_icon', // Replace with your app icon
      [
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Notification channel for basic notifications',
          defaultColor: Colors.blue,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        NotificationChannel(
          channelGroupKey: 'reminder_channel_group',
          channelKey: 'reminder_channel',
          channelName: 'Reminder Notifications',
          channelDescription: 'Notification channel for reminders',
          defaultColor: Colors.orange,
          ledColor: Colors.orange,
          importance: NotificationImportance.High,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'basic_channel_group',
          channelGroupName: 'Basic Group',
        ),
        NotificationChannelGroup(
          channelGroupKey: 'reminder_channel_group',
          channelGroupName: 'Reminder Group',
        ),
      ],
      debug: true,
    );
    
    // Request notification permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }
  
  // Send local notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationType type = NotificationType.info,
    Map<String, String>? payload,
  }) async {
    String channelKey = type == NotificationType.reminder || type == NotificationType.overdue
        ? 'reminder_channel'
        : 'basic_channel';
        
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: payload,
        category: NotificationCategory.Message,
      ),
    );
  }
  
  // Create notification in Firestore
  Future<NotificationModel> createNotification({
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    final notificationId = _notificationsRef.doc().id;
    
    final notification = NotificationModel(
      id: notificationId,
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      data: data,
    );
    
    await _notificationsRef.doc(notificationId).set(notification.toJson());
    
    // Show local notification
    await showNotification(
      id: notificationId.hashCode,
      title: title,
      body: body,
      type: type,
      payload: data?.map((key, value) => MapEntry(key, value.toString())),
    );
    
    return notification;
  }
  
  // Get user notifications
  Stream<List<NotificationModel>> getUserNotifications() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }
    
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return NotificationModel.fromJson({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            });
          }).toList();
        });
  }
  
  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).update({
      'isRead': true,
    });
  }
  
  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = currentUserId;
    if (userId == null) {
      return;
    }
    
    final batch = _firestore.batch();
    final unreadNotifications = await _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    for (var doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    await batch.commit();
  }
  
  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef.doc(notificationId).delete();
  }
  
  // Schedule reminder notification for book due date
  Future<void> scheduleReturnReminder({
    required String borrowId,
    required String bookTitle,
    required DateTime dueDate,
  }) async {
    // Schedule reminder 1 day before due date
    final reminderDate = dueDate.subtract(const Duration(days: 1));
    
    // Check if reminder date is in the future
    if (reminderDate.isAfter(DateTime.now())) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: borrowId.hashCode,
          channelKey: 'reminder_channel',
          title: 'Pengingat Pengembalian Buku',
          body: 'Buku "$bookTitle" harus dikembalikan besok',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          payload: {
            'borrowId': borrowId,
          },
        ),
        schedule: NotificationCalendar.fromDate(date: reminderDate),
      );
      
      // Also create a Firestore notification that will be displayed in the app
      await createNotification(
        title: 'Pengingat Pengembalian Buku',
        body: 'Buku "$bookTitle" harus dikembalikan besok',
        type: NotificationType.reminder,
        data: {
          'borrowId': borrowId,
          'scheduledFor': reminderDate.toIso8601String(),
        },
      );
    }
  }
  
  // Cancel scheduled notification
  Future<void> cancelScheduledNotification(int notificationId) async {
    await AwesomeNotifications().cancel(notificationId);
  }
  
  // Listen to notification actions (for handling notification taps)
  Stream<ReceivedAction> get actionStream => 
      AwesomeNotifications().actionStream;
  
  void dispose() {
    AwesomeNotifications().actionSink.close();
  }
}