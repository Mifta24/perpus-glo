import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/history/model/activity_model.dart';
import '../../auth/model/user_model.dart';
import '../../../core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  // Collection references
  CollectionReference get _historyRef => _firestore.collection('history');
  CollectionReference get _usersRef => _firestore.collection('users');

  // Get all admin activities
  Stream<List<ActivityModel>> getAllAdminActivities() {
    return _historyRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip if userId is missing
        if (!data.containsKey('userId')) continue;

        final userId = data['userId'] as String;

        // Check if the user is admin or librarian
        final userDoc = await _usersRef.doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;
        final userRole = userData['role'] as String?;

        // Only include activities from admin or librarian
        if (userRole != 'admin' && userRole != 'librarian') continue;

        // Get user name
        final userName = userData['name'] as String?;

        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
            'userRole': userRole,
          });

          activities.add(activity);
        } catch (e) {
          print('Error parsing admin activity: $e');
          // Skip invalid activities
        }
      }

      return activities;
    });
  }

  // Get admin activities filtered by type
  Stream<List<ActivityModel>> getAdminActivitiesByType(ActivityType type) {
    return _historyRef
        .where('activityType', isEqualTo: type.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip if userId is missing
        if (!data.containsKey('userId')) continue;

        final userId = data['userId'] as String;

        // Check if the user is admin or librarian
        final userDoc = await _usersRef.doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;
        final userRole = userData['role'] as String?;

        // Only include activities from admin or librarian
        if (userRole != 'admin' && userRole != 'librarian') continue;

        // Get user name
        final userName = userData['name'] as String?;

        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
            'userRole': userRole,
          });

          activities.add(activity);
        } catch (e) {
          print('Error parsing admin activity by type: $e');
          // Skip invalid activities
        }
      }

      return activities;
    });
  }

  // Get admin activities for date range
  Stream<List<ActivityModel>> getAdminActivitiesByDateRange(
      DateTime start, DateTime end) {
    return _historyRef
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp',
            isLessThanOrEqualTo: end.add(const Duration(days: 1)))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip if userId is missing
        if (!data.containsKey('userId')) continue;

        final userId = data['userId'] as String;

        // Check if the user is admin or librarian
        final userDoc = await _usersRef.doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;
        final userRole = userData['role'] as String?;

        // Only include activities from admin or librarian
        if (userRole != 'admin' && userRole != 'librarian') continue;

        // Get user name
        final userName = userData['name'] as String?;

        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
            'userRole': userRole,
          });

          activities.add(activity);
        } catch (e) {
          print('Error parsing admin activity by date range: $e');
          // Skip invalid activities
        }
      }

      return activities;
    });
  }

  // Delete history item
  Future<void> deleteActivityItem(String activityId) async {
    await _historyRef.doc(activityId).delete();
  }

  // Clear all admin activities older than a certain date
  Future<void> clearOldAdminActivities(DateTime cutoffDate) async {
    // Untuk menghapus aktivitas admin lama, kita perlu mendapatkan
    // daftar admin/pustakawan terlebih dahulu
    final adminUserIds = <String>[];

    final adminsSnapshot =
        await _usersRef.where('role', whereIn: ['admin', 'librarian']).get();

    for (var doc in adminsSnapshot.docs) {
      adminUserIds.add(doc.id);
    }

    // Jika tidak ada admin, tidak ada yang perlu dihapus
    if (adminUserIds.isEmpty) return;

    // Dapatkan aktivitas admin yang lebih lama dari cutoffDate
    // Kita perlu melakukannya secara batch karena tidak bisa melakukan
    // "where in" dan "where less than" secara bersamaan
    final batch = _firestore.batch();
    int count = 0;

    for (final adminId in adminUserIds) {
      final activitiesSnapshot = await _historyRef
          .where('userId', isEqualTo: adminId)
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      for (var doc in activitiesSnapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Firebase memiliki batas 500 operasi per batch
        if (count >= 450) {
          await batch.commit();
          count = 0;
        }
      }
    }

    // Commit batch terakhir jika ada
    if (count > 0) {
      await batch.commit();
    }
  }
}

// Provider for AdminHistoryRepository
final adminHistoryRepositoryProvider = Provider<AdminHistoryRepository>((ref) {
  return AdminHistoryRepository();
});

// Provider for activity type filter
final activityTypeFilterProvider = StateProvider<ActivityType?>((ref) => null);

// Provider for date range
final selectedDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Provider untuk filter berdasarkan role
final roleFilterProvider = StateProvider<String?>((ref) => null);

// Provider for all admin activities with filters applied
final allActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final repository = ref.watch(adminHistoryRepositoryProvider);
  final typeFilter = ref.watch(activityTypeFilterProvider);
  final dateRange = ref.watch(selectedDateRangeProvider);
  final roleFilter = ref.watch(roleFilterProvider);

  // Dapatkan data sesuai filter tipe dan tanggal
  Stream<List<ActivityModel>> activitiesStream;
  if (typeFilter != null) {
    activitiesStream = repository.getAdminActivitiesByType(typeFilter);
  } else if (dateRange != null) {
    activitiesStream = repository.getAdminActivitiesByDateRange(
        dateRange.start, dateRange.end);
  } else {
    activitiesStream = repository.getAllAdminActivities();
  }

  // Filter berdasarkan role jika diperlukan
  if (roleFilter != null) {
    return activitiesStream.map((activities) =>
        activities.where((activity) =>
            activity.userRole?.toLowerCase() == roleFilter.toLowerCase() ||
            (activity.metadata?['role'] as String?)?.toLowerCase() == roleFilter.toLowerCase()
        ).toList()
    );
  }

  return activitiesStream;
});

// Controller for admin history actions
class AdminHistoryController extends StateNotifier<AsyncValue<void>> {
  final AdminHistoryRepository _repository;

  AdminHistoryController(this._repository) : super(const AsyncValue.data(null));

  Future<void> deleteActivityItem(String activityId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteActivityItem(activityId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> clearOldActivities(int daysToKeep) async {
    state = const AsyncValue.loading();
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      await _repository.clearOldAdminActivities(cutoffDate);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminHistoryControllerProvider =
    StateNotifierProvider<AdminHistoryController, AsyncValue<void>>((ref) {
  final repository = ref.watch(adminHistoryRepositoryProvider);
  return AdminHistoryController(repository);
});
