import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/borrow_repository.dart';
import '../model/borrow_model.dart';

// Provider untuk stream history peminjaman user
final userBorrowHistoryProvider = StreamProvider<List<BorrowModel>>((ref) {
  final repository = ref.watch(borrowRepositoryProvider);
  return repository.getUserBorrowHistory();
});

// Provider untuk detail peminjaman berdasarkan ID
final borrowByIdProvider = FutureProvider.family<BorrowModel?, String>((ref, borrowId) async {
  final repository = ref.watch(borrowRepositoryProvider);
  return repository.getBorrowById(borrowId);
});

// Provider untuk filter status peminjaman
final borrowFilterProvider = StateProvider<BorrowStatus?>((ref) => null);

// Provider untuk peminjaman terfilter
final filteredBorrowsProvider = Provider<List<BorrowModel>>((ref) {
  final borrowsAsync = ref.watch(userBorrowHistoryProvider);
  final filter = ref.watch(borrowFilterProvider);
  
  return borrowsAsync.when(
    data: (borrows) {
      if (filter == null) return borrows;
      return borrows.where((borrow) => borrow.status == filter).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for active borrows
final activeBorrowsProvider = StreamProvider<List<BorrowModel>>((ref) {
  final repository = ref.watch(borrowRepositoryProvider);
  return repository.getActiveBorrows();
});

// Controller untuk aksi peminjaman
class BorrowController extends StateNotifier<AsyncValue<void>> {
  final BorrowRepository _repository;
  
  BorrowController(this._repository) : super(const AsyncValue.data(null));
  
  Future<bool> borrowBook(String bookId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.borrowBook(bookId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  
  Future<bool> returnBook(String borrowId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.returnBook(borrowId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  
  Future<bool> updateBorrowStatus(String borrowId, BorrowStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBorrowStatus(borrowId, status);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
  
  Future<bool> markFineAsPaid(String borrowId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.markFineAsPaid(borrowId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final borrowControllerProvider = StateNotifierProvider<BorrowController, AsyncValue<void>>((ref) {
  final repository = ref.watch(borrowRepositoryProvider);
  return BorrowController(repository);
});