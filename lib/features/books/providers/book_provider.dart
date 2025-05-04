import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/book_repository.dart';
import '../model/book_model.dart';

// Provider untuk stream daftar buku
final booksProvider = StreamProvider<List<BookModel>>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBooks();
});

// Provider untuk buku berdasarkan kategori
final booksByCategoryProvider = StreamProvider.family<List<BookModel>, String>((ref, category) {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBooksByCategory(category);
});

// Provider untuk pencarian buku
final bookSearchProvider = StreamProvider.family<List<BookModel>, String>((ref, query) {
  if (query.isEmpty) {
    return ref.watch(booksProvider.stream);
  }
  final repository = ref.watch(bookRepositoryProvider);
  return repository.searchBooks(query);
});

// Provider untuk buku berdasarkan ID
final bookByIdProvider = FutureProvider.family<BookModel?, String>((ref, id) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBookById(id);
});

// Provider untuk daftar kategori
final categoriesProvider = FutureProvider<List<String>>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getCategories();
});

// Provider untuk aksi peminjaman & pengembalian buku
class BorrowController extends StateNotifier<AsyncValue<void>> {
  final BookRepository _repository;
  
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
  
  Future<bool> returnBook(String bookId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.returnBook(bookId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final borrowControllerProvider = StateNotifierProvider<BorrowController, AsyncValue<void>>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return BorrowController(repository);
});