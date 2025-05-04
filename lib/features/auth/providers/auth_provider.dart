import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../model/user_model.dart';

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
  
  AuthController(this._repository) : super(const AsyncValue.data(null));
  
  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signInWithEmailAndPassword(email, password);
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
      await _repository.registerWithEmailAndPassword(name, email, password);
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

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});