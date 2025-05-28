import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../model/user_model.dart';
import '../../history/data/history_repository.dart';
import '../../history/model/history_model.dart';

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

// Current user data provider
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final repository = ref.watch(authRepositoryProvider);

  return authState.when(
    data: (user) async {
      if (user != null) {
        return await repository.getUserData(user.uid);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Auth controller for login, register, etc.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  final HistoryRepository _historyRepository = HistoryRepository();

  AuthController(this._repository) : super(const AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // Proses login
      await _repository.signInWithEmailAndPassword(email, password);

      // Catat aktivitas dalam try-catch terpisah
      try {
        await _historyRepository.addActivity(
          activityType: ActivityType.login,
          description: 'Login berhasil dengan email $email',
        );
      } catch (historyError) {
        // Log error tapi jangan gagalkan proses login
        debugPrint('Error saat mencatat history: $historyError');
      }

      state = const AsyncValue.data(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // Proses registrasi
      await _repository.registerWithEmailAndPassword(name, email, password);

      // Catat aktivitas dalam try-catch terpisah
      try {
        await _historyRepository.addActivity(
          activityType: ActivityType.register,
          description: 'Pendaftaran akun baru dengan email $email',
          metadata: {
            'name': name,
            'email': email,
          },
        );
      } catch (historyError) {
        // Log error tapi jangan gagalkan proses register
        debugPrint('Error saat mencatat history: $historyError');
      }

      state = const AsyncValue.data(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _repository.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Staff login 
  Future<bool> staffLogin(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // Proses login staff
      await _repository.signInWithEmailAndPassword(email, password);

      // Catat aktivitas dalam try-catch terpisah
      try {
        await _historyRepository.addActivity(
          activityType: ActivityType.login,
          description: 'Staff login berhasil dengan email $email',
        );
      } catch (historyError) {
        // Log error tapi jangan gagalkan proses login
        debugPrint('Error saat mencatat history: $historyError');
      }

      state = const AsyncValue.data(null);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.signOut();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
