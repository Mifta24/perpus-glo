import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../model/book_model.dart';

// BookRepository digunakan untuk mengambil data buku dari Firestore
class BookRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;

  // Collection references
  CollectionReference get _booksRef => _firestore.collection('books');
  CollectionReference get _usersRef => _firestore.collection('users');

  // Get all books
  Stream<List<BookModel>> getBooks() {
    return _booksRef.orderBy('title').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BookModel.fromJson(
            {'id': doc.id, ...doc.data() as Map<String, dynamic>});
      }).toList();
    });
  }

  // Get books by category
  Stream<List<BookModel>> getBooksByCategory(String category) {
    return _booksRef
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BookModel.fromJson(
            {'id': doc.id, ...doc.data() as Map<String, dynamic>});
      }).toList();
    });
  }

  // Search books
  Stream<List<BookModel>> searchBooks(String query) {
    // Firebase tidak mendukung search text secara native
    // Solusi sederhana: ambil semua buku dan filter di client side
    return _booksRef.snapshots().map((snapshot) {
      final allBooks = snapshot.docs.map((doc) {
        return BookModel.fromJson(
            {'id': doc.id, ...doc.data() as Map<String, dynamic>});
      }).toList();

      return allBooks.where((book) {
        final titleLower = book.title.toLowerCase();
        final authorLower = book.author.toLowerCase();
        final queryLower = query.toLowerCase();

        return titleLower.contains(queryLower) ||
            authorLower.contains(queryLower);
      }).toList();
    });
  }

  // Get book by id
  Future<BookModel?> getBookById(String bookId) async {
    final doc = await _booksRef.doc(bookId).get();

    if (doc.exists) {
      return BookModel.fromJson(
          {'id': doc.id, ...doc.data() as Map<String, dynamic>});
    }

    return null;
  }

  // Borrow book
  Future<void> borrowBook(String bookId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }

    // Transaction untuk memastikan data konsisten
    return _firestore.runTransaction((transaction) async {
      // 1. Get book document
      final bookDoc = await transaction.get(_booksRef.doc(bookId));
      if (!bookDoc.exists) {
        throw Exception('Buku tidak ditemukan');
      }

      final bookData = bookDoc.data() as Map<String, dynamic>;
      final availableStock = bookData['availableStock'] as int;

      // 2. Check stock
      if (availableStock <= 0) {
        throw Exception('Stok buku tidak tersedia');
      }

      // 3. Get user document
      final userDoc = await transaction.get(_usersRef.doc(userId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }

      // 4. Get current borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);

      // 5. Check if user already borrowed this book
      if (borrowedBooks.contains(bookId)) {
        throw Exception('Buku sudah dipinjam');
      }

      // 6. Update book stock
      transaction.update(
          _booksRef.doc(bookId), {'availableStock': availableStock - 1});

      // 7. Add book to user's borrowedBooks
      borrowedBooks.add(bookId);
      transaction
          .update(_usersRef.doc(userId), {'borrowedBooks': borrowedBooks});
    });
  }

  // Return book
  Future<void> returnBook(String bookId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }

    return _firestore.runTransaction((transaction) async {
      // 1. Get book document
      final bookDoc = await transaction.get(_booksRef.doc(bookId));
      if (!bookDoc.exists) {
        throw Exception('Buku tidak ditemukan');
      }

      final bookData = bookDoc.data() as Map<String, dynamic>;
      final availableStock = bookData['availableStock'] as int;
      final totalStock = bookData['totalStock'] as int;

      // 2. Check if stock would exceed total
      if (availableStock >= totalStock) {
        throw Exception('Semua buku sudah kembali');
      }

      // 3. Get user document
      final userDoc = await transaction.get(_usersRef.doc(userId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }

      // 4. Get current borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);

      // 5. Check if user has borrowed this book
      if (!borrowedBooks.contains(bookId)) {
        throw Exception('Buku tidak sedang dipinjam');
      }

      // 6. Update book stock
      transaction.update(
          _booksRef.doc(bookId), {'availableStock': availableStock + 1});

      // 7. Remove book from user's borrowedBooks
      borrowedBooks.remove(bookId);
      transaction
          .update(_usersRef.doc(userId), {'borrowedBooks': borrowedBooks});
    });
  }

 
  Stream<List<BookModel>> getBooksByPopularity({required int limit}) {
    return _booksRef
        .orderBy('borrowCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BookModel.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }).toList();
    });
  }

  Stream<List<BookModel>> getLatestBooks({required int limit}) {
    return _booksRef
        .orderBy('addedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return BookModel.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }).toList();
    });
  }

  // Get list of categories
  Future<List<String>> getCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }
}

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});
