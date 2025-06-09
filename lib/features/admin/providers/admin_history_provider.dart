import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/history/model/activity_model.dart';
import '../../../features/history/data/history_repository.dart';
import '../../../core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  
  // Collection references
  CollectionReference get _historyRef => _firestore.collection('history');
  CollectionReference get _usersRef => _firestore.collection('users');

  // Get all activities
  Stream<List<ActivityModel>> getAllActivities() {
    return _historyRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Get user name from userId
        String? userName;
        if (data.containsKey('userId')) {
          final userId = data['userId'] as String;
          final userDoc = await _usersRef.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['name'] as String?;
          }
        }
        
        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
          });
          
          activities.add(activity);
        } catch (e) {
          print('Error parsing activity: $e');
          // Skip invalid activities
        }
      }
      
      return activities;
    });
  }

  // Get activities filtered by type
  Stream<List<ActivityModel>> getActivitiesByType(ActivityType type) {
    return _historyRef
        .where('activityType', isEqualTo: type.toString().split('.').last)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Get user name
        String? userName;
        if (data.containsKey('userId')) {
          final userId = data['userId'] as String;
          final userDoc = await _usersRef.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['name'] as String?;
          }
        }
        
        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
          });
          
          activities.add(activity);
        } catch (e) {
          print('Error parsing activity by type: $e');
          // Skip invalid activities
        }
      }
      
      return activities;
    });
  }

  // Get activities for date range
  Stream<List<ActivityModel>> getActivitiesByDateRange(
      DateTime start, DateTime end) {
    return _historyRef
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end.add(const Duration(days: 1)))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<ActivityModel> activities = [];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Get user name
        String? userName;
        if (data.containsKey('userId')) {
          final userId = data['userId'] as String;
          final userDoc = await _usersRef.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['name'] as String?;
          }
        }
        
        try {
          final activity = ActivityModel.fromJson({
            'id': doc.id,
            ...data,
            'userName': userName,
          });
          
          activities.add(activity);
        } catch (e) {
          print('Error parsing activity by date range: $e');
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

  // Clear all activities older than a certain date
  Future<void> clearOldActivities(DateTime cutoffDate) async {
    final batch = _firestore.batch();
    final oldActivities =
        await _historyRef.where('timestamp', isLessThan: cutoffDate).get();

    for (var doc in oldActivities.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
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

// Provider for all activities with filters applied
final allActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final repository = ref.watch(adminHistoryRepositoryProvider);
  final typeFilter = ref.watch(activityTypeFilterProvider);
  final dateRange = ref.watch(selectedDateRangeProvider);
  
  if (typeFilter != null) {
    return repository.getActivitiesByType(typeFilter);
  } else if (dateRange != null) {
    return repository.getActivitiesByDateRange(dateRange.start, dateRange.end);
  } else {
    return repository.getAllActivities();
  }
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
      await _repository.clearOldActivities(cutoffDate);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final adminHistoryControllerProvider = StateNotifierProvider<AdminHistoryController, AsyncValue<void>>((ref) {
  final repository = ref.watch(adminHistoryRepositoryProvider);
  return AdminHistoryController(repository);
});