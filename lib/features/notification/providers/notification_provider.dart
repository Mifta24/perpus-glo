import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/notification_service.dart';
import '../model/notification_model.dart';

// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider for user notifications stream
final userNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.getUserNotifications();
});

// Provider for unread notifications count
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(userNotificationsProvider);
  return notificationsAsync.when(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Controller for notification actions
class NotificationStateController extends StateNotifier<AsyncValue<void>> {
  final NotificationService _service;
  
  NotificationStateController(this._service) : super(const AsyncValue.data(null));
  
  Future<void> markAsRead(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await _service.markAsRead(notificationId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();
    try {
      await _service.markAllAsRead();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> deleteNotification(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteNotification(notificationId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> scheduleReturnReminder({
    required String borrowId,
    required String bookTitle,
    required DateTime dueDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.scheduleReturnReminder(
        borrowId: borrowId,
        bookTitle: bookTitle,
        dueDate: dueDate,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> sendFineNotification({
    required String borrowId,
    required String bookTitle,
    required double amount,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.createNotification(
        title: 'Denda Keterlambatan',
        body: 'Anda dikenakan denda sebesar Rp ${amount.toStringAsFixed(0)} untuk buku "$bookTitle"',
        type: NotificationType.fine,
        data: {
          'borrowId': borrowId,
          'amount': amount,
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final notificationControllerProvider = StateNotifierProvider<NotificationStateController, AsyncValue<void>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationStateController(service);
});