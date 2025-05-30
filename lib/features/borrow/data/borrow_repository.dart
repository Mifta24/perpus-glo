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

  // getActiveBorrows
  Stream<List<BorrowModel>> getActiveBorrows() {
    return _borrowsRef
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: BorrowStatus.active)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BorrowModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Get borrow by ID
  Future<BorrowModel?> getBorrowById(String borrowId) async {
    final doc = await _borrowsRef.doc(borrowId).get();
    if (!doc.exists) {
      return null;
    }

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
        return borrowModel.copyWith(
          bookTitle: bookData['title'] as String,
          bookCover: bookData['coverUrl'] as String,
        );
      }
    } catch (e) {
      // If book fetch fails, return borrow without book info
    }

    return borrowModel;
  }

  // Borrow a book (request borrowing)
  Future<String> borrowBook(String bookId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }

    // Use transaction to ensure data consistency
    String borrowId = '';
    await _firestore.runTransaction((transaction) async {
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

      // 4. Get current pending and borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final pendingBooks = List<String>.from(userData['pendingBooks'] ?? []);
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);

      // 5. Check if user already requested or borrowed this book
      if (pendingBooks.contains(bookId)) {
        throw Exception('Permintaan peminjaman untuk buku ini sudah diajukan');
      }
      if (borrowedBooks.contains(bookId)) {
        throw Exception('Buku sudah dipinjam');
      }

      // 6. Create borrow record
      borrowId = _borrowsRef.doc().id;
      final borrowDate = DateTime.now();
      final dueDate =
          borrowDate.add(const Duration(days: 14)); // 2 weeks borrowing period

      final borrowData = {
        'userId': userId,
        'bookId': bookId,
        'borrowDate': borrowDate,
        'dueDate': dueDate,
        'status': 'pending', // Status pending, menunggu konfirmasi pustakawan
        'isPaid': true, // No fine at first
        'requestDate': borrowDate, // Tambahkan tanggal pengajuan
      };

      // 7. Add book to user's pendingBooks
      pendingBooks.add(bookId);
      transaction.update(_usersRef.doc(userId), {'pendingBooks': pendingBooks});

      // 8. Create borrow document
      transaction.set(_borrowsRef.doc(borrowId), borrowData);
    });

    return borrowId;
  }

  // Confirm borrow by librarian/admin
  Future<void> confirmBorrow(String borrowId) async {
    final adminId = currentUserId;
    if (adminId == null) {
      throw Exception('Admin tidak ditemukan');
    }

    return _firestore.runTransaction((transaction) async {
      // 1. Get borrow document
      final borrowDoc = await transaction.get(_borrowsRef.doc(borrowId));
      if (!borrowDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final borrowData = borrowDoc.data() as Map<String, dynamic>;
      final userId = borrowData['userId'] as String;
      final bookId = borrowData['bookId'] as String;
      final status = borrowData['status'] as String;

      // 2. Verify status is pending
      if (status != 'pending') {
        throw Exception('Peminjaman sudah dikonfirmasi atau ditolak');
      }

      // 3. Get book document
      final bookDoc = await transaction.get(_booksRef.doc(bookId));
      if (!bookDoc.exists) {
        throw Exception('Buku tidak ditemukan');
      }

      final bookData = bookDoc.data() as Map<String, dynamic>;
      final availableStock = bookData['availableStock'] as int;

      // 4. Check stock
      if (availableStock <= 0) {
        throw Exception('Stok buku tidak tersedia');
      }

      // 5. Get user document
      final userDoc = await transaction.get(_usersRef.doc(userId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }

      // 6. Get user's pending and borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final pendingBooks = List<String>.from(userData['pendingBooks'] ?? []);
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);

      // 7. Move book from pendingBooks to borrowedBooks
      if (!pendingBooks.contains(bookId)) {
        throw Exception('Buku tidak dalam daftar permintaan user');
      }
      pendingBooks.remove(bookId);
      borrowedBooks.add(bookId);

      // 8. Update borrow document
      transaction.update(_borrowsRef.doc(borrowId), {
        'status': 'active',
        'confirmDate': DateTime.now(),
        'confirmedBy': adminId,
      });

      // 9. Update book stock
      transaction.update(
          _booksRef.doc(bookId), {'availableStock': availableStock - 1});

      // 10. Update user's book lists
      transaction.update(_usersRef.doc(userId), {
        'pendingBooks': pendingBooks,
        'borrowedBooks': borrowedBooks,
      });
    });
  }

// Tambahkan method returnBook
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
      final status = borrowData['status'] as String;
      final borrowUserId = borrowData['userId'] as String;

      // 2. Verify borrowing status is active
      if (status != 'active') {
        throw Exception('Buku tidak dalam status dipinjam');
      }

      // 3. Verify the current user is the borrower or an admin (implementation of admin check could be added here)
      if (borrowUserId != userId) {
        // For now, just check if borrower is same as current user
        throw Exception(
            'Anda tidak memiliki akses untuk mengembalikan buku ini');
      }

      // 4. Get book document
      final bookDoc = await transaction.get(_booksRef.doc(bookId));
      if (!bookDoc.exists) {
        throw Exception('Buku tidak ditemukan');
      }

      final bookData = bookDoc.data() as Map<String, dynamic>;
      final availableStock = bookData['availableStock'] as int;

      // 5. Get user document
      final userDoc = await transaction.get(_usersRef.doc(borrowUserId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }

      // 6. Get user's borrowed books
      final userData = userDoc.data() as Map<String, dynamic>;
      final borrowedBooks = List<String>.from(userData['borrowedBooks'] ?? []);

      // 7. Remove book from borrowedBooks
      if (!borrowedBooks.contains(bookId)) {
        throw Exception('Buku tidak ada dalam daftar peminjaman');
      }
      borrowedBooks.remove(bookId);

      // 8. Check if return is overdue
      final dueDate = (borrowData['dueDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final isOverdue = now.isAfter(dueDate);

      // 9. Calculate fine if overdue
      double? fine;
      if (isOverdue) {
        // Calculate days overdue
        final daysOverdue = now.difference(dueDate).inDays;
        // Fine calculation: 1000 per day
        fine = daysOverdue * 1000.0;
      }

      // 10. Update borrow document
      transaction.update(_borrowsRef.doc(borrowId), {
        'status': isOverdue ? 'overdue' : 'returned',
        'returnDate': now,
        'fine': fine,
        'isPaid':
            fine == null, // If there's no fine, mark as paid automatically
      });

      // 11. Update book stock
      transaction.update(
          _booksRef.doc(bookId), {'availableStock': availableStock + 1});

      // 12. Update user's borrowed books
      transaction.update(
          _usersRef.doc(borrowUserId), {'borrowedBooks': borrowedBooks});
    });
  }

  // Reject borrow request by librarian/admin
  Future<void> rejectBorrow(String borrowId, String reason) async {
    final adminId = currentUserId;
    if (adminId == null) {
      throw Exception('Admin tidak ditemukan');
    }

    return _firestore.runTransaction((transaction) async {
      // 1. Get borrow document
      final borrowDoc = await transaction.get(_borrowsRef.doc(borrowId));
      if (!borrowDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final borrowData = borrowDoc.data() as Map<String, dynamic>;
      final userId = borrowData['userId'] as String;
      final bookId = borrowData['bookId'] as String;
      final status = borrowData['status'] as String;

      // 2. Verify status is pending
      if (status != 'pending') {
        throw Exception('Peminjaman sudah dikonfirmasi atau ditolak');
      }

      // 3. Get user document
      final userDoc = await transaction.get(_usersRef.doc(userId));
      if (!userDoc.exists) {
        throw Exception('User tidak ditemukan');
      }

      // 4. Get user's pending books
      final userData = userDoc.data() as Map<String, dynamic>;
      final pendingBooks = List<String>.from(userData['pendingBooks'] ?? []);

      // 5. Remove book from pendingBooks
      pendingBooks.remove(bookId);

      // 6. Update borrow document
      transaction.update(_borrowsRef.doc(borrowId), {
        'status': 'rejected',
        'rejectDate': DateTime.now(),
        'rejectedBy': adminId,
        'rejectReason': reason,
      });

      // 7. Update user's pending books
      transaction.update(_usersRef.doc(userId), {'pendingBooks': pendingBooks});
    });
  }

  // Get all pending borrow requests (for admin/librarian)
  Stream<List<BorrowModel>> getPendingBorrows() {
    return _borrowsRef
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final borrows = <BorrowModel>[];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final borrowModel = BorrowModel.fromJson({
          'id': doc.id,
          ...data,
        });

        try {
          // Get book information
          final bookDoc = await _booksRef.doc(borrowModel.bookId).get();
          if (bookDoc.exists) {
            final bookData = bookDoc.data() as Map<String, dynamic>;

            // Get user information
            final userDoc = await _usersRef.doc(borrowModel.userId).get();
            final userData =
                userDoc.exists ? userDoc.data() as Map<String, dynamic> : null;
            final userName =
                userData != null ? userData['name'] as String? : null;

            final bookWithInfo = borrowModel.copyWith(
              bookTitle: bookData['title'] as String,
              bookCover: bookData['coverUrl'] as String,
              userName: userName ?? 'Unknown User',
            );
            borrows.add(bookWithInfo);
          } else {
            borrows.add(borrowModel);
          }
        } catch (e) {
          borrows.add(borrowModel);
        }
      }

      return borrows;
    });
  }

  // Get count of active loans for all users
  /// Menghitung jumlah peminjaman aktif untuk semua pengguna
  Future<int> getActiveLoansCount() async {
    final snapshot =
        await _borrowsRef.where('status', isEqualTo: 'active').get();

    return snapshot.docs.length;
  }

  // Get count of overdue borrows
  Future<int> getOverdueBorrowsCount() async {
    final now = DateTime.now();
    final snapshot = await _borrowsRef
        .where('dueDate', isLessThan: Timestamp.fromDate(now))
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs.length;
  }
}

//  Digunakan untuk provider yang mengakses repository ini
final borrowRepositoryProvider = Provider<BorrowRepository>((ref) {
  return BorrowRepository();
});
