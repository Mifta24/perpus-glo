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

// Provider untuk mengakses pengguna berdasarkan ID (admin only)
final userProfileByIdProvider =
    StreamProvider.family<UserProfileModel, String>((ref, userId) {
  final profileRepository = ref.watch(profileRepositoryProvider);
  return profileRepository.getUserProfileById(userId);
});

// Provider for specific user by ID
final userByIdProvider =
    StreamProvider.family<UserProfileModel?, String>((ref, userId) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getUserById(userId);
});

// Provider untuk mencari pengguna berdasarkan query (admin only)
final searchUsersProvider = FutureProvider.family<List<UserProfileModel>, String>((ref, query) async {
  final profileRepository = ref.watch(profileRepositoryProvider);
  return profileRepository.searchUsers(query);
});

// Controller for admin actions on profiles
class AdminProfileController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;

  AdminProfileController(this._repository) : super(const AsyncValue.data(null));

  Future<void> updateUser(UserProfileModel user) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateUserProfile(user);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    state = const AsyncValue.loading();
    try {
      final currentProfile = await _repository.getUserProfileById(userId).first;
      final updatedProfile = currentProfile.copyWith(role: role);
      await _repository.updateUserProfile(updatedProfile);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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

  Future<void> deleteUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteUser(userId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
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

final adminProfileControllerProvider =
    StateNotifierProvider<AdminProfileController, AsyncValue<void>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return AdminProfileController(repository);
});
