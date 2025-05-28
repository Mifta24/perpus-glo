import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../model/user_profile_model.dart';

// Provider for all users
final allUsersProvider = StreamProvider<List<UserProfileModel>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getAllUsers();
});

// Provider for user count
final userCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserCount();
});

// Provider for specific user by ID
final userByIdProvider = StreamProvider.family<UserProfileModel?, String>((ref, userId) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserById(userId);
});

// Controller for admin actions on profiles
class AdminProfileController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;

  AdminProfileController(this._repository) : super(const AsyncValue.data(null));

  Future<bool> updateUserRole(UserProfileModel user) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateUserRole(user.id, user.role);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deactivateUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deactivateUser(userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> activateUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.activateUser(userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final adminProfileControllerProvider = StateNotifierProvider<AdminProfileController, AsyncValue<void>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return AdminProfileController(repository);
});