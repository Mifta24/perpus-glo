import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../model/borrow_model.dart';
import '../../books/model/book_model.dart';

class BorrowRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  
  // Collection references
  CollectionReference get _borrowsRef => _firestore.collection('borrows');
  CollectionReference get _booksRef => _firestore.collection('books');
  CollectionReference get _usersRef => _firestore.collection('users');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get user's borrow history
  Stream<List<BorrowModel>> getUserBorrowHistory() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }
    
    return _borrowsRef
        .where('userId', isEqualTo: userId)
        .orderBy('borrowDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final List<BorrowModel> borrows = [];
          
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final borrowModel = BorrowModel.fromJson({
              'id': doc.id,
              ...data,
            });
            
            // Fetch book information for UI
            try {
              final bookDoc = await _booksRef.doc(borrowModel.bookId).get();
              if (bookDoc.exists) {
                final bookData = bookDoc.data() as Map<String, dynamic>;
                final bookWithInfo = borrowModel.copyWith(
                  bookTitle: bookData['title'] as String,
                  bookCover: bookData['coverUrl'] as String,
                );
                borrows.add(bookWithInfo);
              } else {
                borrows.add(borrowModel);
              }
            } catch (e) {
              // If book fetch fails, still add the borrow record
              borrows.add(borrowModel);
            }
          }
          
          return borrows;
        });
  }
  
  // Borrow a book
  Future<void> borrowBook(String bookId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }
    
    // Use transaction to ensure data consistency
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
      
      // 6. Create borrow record
      final borrowId = _borrowsRef.doc().id;
      final borrowDate = DateTime.now();
      final dueDate = borrowDate.add(const Duration(days: 14)); // 2 weeks borrowing period
      
      final borrowData = {
        'id': borrowId,
        'userId': userId,
        'bookId': bookId,
        'borrowDate': borrowDate,
        'dueDate': dueDate,
        'status': 'active',
        'isPaid': true, // No fine at first
      };
      
      // 7. Update book available stock
      transaction.update(_booksRef.doc(bookId), {
        'availableStock': availableStock - 1
      });
      
      // 8. Add book to user's borrowedBooks
      borrowedBooks.add(bookId);
      transaction.update(_usersRef.doc(userId), {
        'borrowedBooks': borrowedBooks
      });
      
      // 9. Create borrow document
      transaction.set(_borrowsRef.doc(borrowId), borrowData);
    });
  }
  
  // Return a book
  Future<void> returnBook(String borrowId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }
    
    return _firestore.runTransaction((transaction) async {
      // 1. Get borrow document
      final borrowDoc = await transaction.get(_borrowsRef.doc(borrowId));
      if (!borrowDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }
      
      final borrowData = borrowDoc.data() as Map<String, dynamic>;
      final bookId = borrowData['bookId'] as String;
      final dueDate = (borrowData['dueDate'] as Timestamp).toDate();
      
      // 2. Get book document
      final bookDoc = await transaction.get(_booksRef.doc(bookId));
      if (!bookDoc.exists) {
        throw Exception('Buku tidak ditemukan');
      }
      
      final bookData = bookDoc.data() as Map<String, dynamic>;
      final availableStock = bookData['availableStock'] as int;
      final totalStock = bookData['totalStock'] as int;
      
      // 3. Check if stock would exceed total
      if (availableStock >= totalStock) {
        throw Exception('Semua buku sudah kembali');
      }
      
      // 4. Get user document
      final userDoc = await transaction.get(_usersRef.doc(userId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }
      
      // 5. Get current borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);
      
      // 6. Check if user has borrowed this book
      if (!borrowedBooks.contains(bookId)) {
        throw Exception('Buku tidak sedang dipinjam oleh Anda');
      }
      
      // 7. Calculate status and fine
      final returnDate = DateTime.now();
      final isOverdue = returnDate.isAfter(dueDate);
      final status = isOverdue ? 'overdue' : 'returned';
      
      double fine = 0;
      if (isOverdue) {
        // Hitung denda: Rp 1.000 per hari terlambat
        final difference = returnDate.difference(dueDate).inDays;
        fine = difference * 1000;
      }
      
      // 8. Update borrow document
      transaction.update(_borrowsRef.doc(borrowId), {
        'returnDate': returnDate,
        'status': status,
        'fine': fine,
        'isPaid': fine == 0, // If there's no fine, mark as paid
      });
      
      // 9. Update book stock
      transaction.update(_booksRef.doc(bookId), {
        'availableStock': availableStock + 1
      });
      
      // 10. Remove book from user's borrowedBooks
      borrowedBooks.remove(bookId);
      
      final updateData = <String, dynamic>{
        'borrowedBooks': borrowedBooks,
      };
      
      // If there's a fine, update user's fineAmount
      if (fine > 0) {
        final currentFine = (userData['fineAmount'] as num?)?.toDouble() ?? 0.0;
        updateData['fineAmount'] = currentFine + fine;
      }
      
      transaction.update(_usersRef.doc(userId), updateData);
    });
  }
  
  // Get a specific borrow by ID
  Future<BorrowModel?> getBorrowById(String borrowId) async {
    final doc = await _borrowsRef.doc(borrowId).get();
    
    if (!doc.exists) return null;
    
    final data = doc.data() as Map<String, dynamic>;
    final borrowModel = BorrowModel.fromJson({
      'id': doc.id,
      ...data,
    });
    
    // Get book information
    try {
      final bookDoc = await _booksRef.doc(borrowModel.bookId).get();
      if (bookDoc.exists) {
        final bookData = bookDoc.data() as Map<String, dynamic>;
        return borrowModel.copyWith(
          bookTitle: bookData['title'] as String,
          bookCover: bookData['coverUrl'] as String,
        );
      }
    } catch (_) {
      // Ignore errors, return basic model if book info can't be fetched
    }
    
    return borrowModel;
  }
  
  // Update borrow status
  Future<void> updateBorrowStatus(String borrowId, BorrowStatus status) async {
    await _borrowsRef.doc(borrowId).update({
      'status': status.toString().split('.').last,
    });
  }
  
  // Mark a borrow fine as paid
  Future<void> markFineAsPaid(String borrowId) async {
    await _borrowsRef.doc(borrowId).update({
      'isPaid': true,
    });
    
    // Get the fine amount and update user's total fine
    final borrowDoc = await _borrowsRef.doc(borrowId).get();
    if (borrowDoc.exists) {
      final borrowData = borrowDoc.data() as Map<String, dynamic>;
      final userId = borrowData['userId'] as String;
      final fine = (borrowData['fine'] as num?)?.toDouble() ?? 0.0;
      
      if (fine > 0) {
        final userDoc = await _usersRef.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final currentFine = (userData['fineAmount'] as num?)?.toDouble() ?? 0.0;
          
          // Subtract the paid fine from user's total
          await _usersRef.doc(userId).update({
            'fineAmount': currentFine - fine,
          });
        }
      }
    }
  }
}

final borrowRepositoryProvider = Provider<BorrowRepository>((ref) {
  return BorrowRepository();
});