import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perpusglo/features/notification/model/notification_model.dart';
import 'package:perpusglo/features/notification/providers/notification_provider.dart';
import '../../../core/services/firebase_service.dart';
import '../model/borrow_model.dart';

class BorrowRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  final Ref _ref; // Tambahkan variabel ref

  // Ubah constructor untuk menerima ref
  BorrowRepository(this._ref);
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
        .orderBy('requestDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<BorrowModel> borrows = [];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if book is overdue but status hasn't been updated yet
        if (data['status'] == 'active') {
          final dueDate = (data['dueDate'] as Timestamp).toDate();
          if (now.isAfter(dueDate)) {
            // Update status ke overdue dan tambahkan denda
            final daysLate = now.difference(dueDate).inDays;
            final fine = daysLate > 0 ? daysLate * 2000.0 : 2000.0;

            // Update document (gunakan async operation untuk tidak menghambat UI)
            _borrowsRef.doc(doc.id).update({
              'status': 'overdue',
              'fine': data['fine'] ?? fine,
              'isPaid': false,
            });

            // Update data lokal untuk UI
            data['status'] = 'overdue';
            data['fine'] = data['fine'] ?? fine;
            data['isPaid'] = false;
          }
        }
      }

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

  Stream<List<BorrowModel>> getAllBorrows() {
  // Admin should see all borrows
  print('Getting all borrows...');
  
  return _borrowsRef
      .orderBy('requestDate', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
        print('Fetched ${snapshot.docs.length} borrows');
        
        final List<BorrowModel> borrows = [];
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('Document ID: ${doc.id}, Status: ${data['status']}');
          
          // Buat model
          final borrowModel = BorrowModel.fromJson({
            'id': doc.id,
            ...data,
          });
          
          // Tambahkan info buku dan user
          try {
            final bookDoc = await _booksRef.doc(borrowModel.bookId).get();
            if (bookDoc.exists) {
              final bookData = bookDoc.data() as Map<String, dynamic>;
              final borrowWithBookInfo = borrowModel.copyWith(
                bookTitle: bookData['title'] as String?,
                bookCover: bookData['coverUrl'] as String?,
                // booksAuthor: bookData['author'] as String?,
              );
              
              // Fetch user info
              final userDoc = await _usersRef.doc(borrowModel.userId).get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                borrows.add(borrowWithBookInfo.copyWith(
                  userName: userData['name'] as String?,
                ));
              } else {
                borrows.add(borrowWithBookInfo);
              }
            } else {
              borrows.add(borrowModel);
            }
          } catch (e) {
            print('Error fetching details: $e');
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
            .map((doc) =>
                BorrowModel.fromJson(doc.data() as Map<String, dynamic>))
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

    // Generate borrowId di luar transaction
    String borrowId = _borrowsRef.doc().id;

    try {
      // Use transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // 1. Get book document
        final bookDoc = await transaction.get(_booksRef.doc(bookId));
        if (!bookDoc.exists) {
          throw Exception('Buku tidak ditemukan');
        }

        final bookData = bookDoc.data() as Map<String, dynamic>;
        final availableStock = bookData['availableStock'] as int;

        // 2. Check stock (tetap cek walaupun belum mengurangi stok)
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
        final borrowedBooks =
            List<String>.from(userData['borrowedBooks'] ?? []);

        // 5. Check if user already requested or borrowed this book
        if (pendingBooks.contains(bookId)) {
          throw Exception(
              'Permintaan peminjaman untuk buku ini sudah diajukan');
        }
        if (borrowedBooks.contains(bookId)) {
          throw Exception('Buku sudah dipinjam');
        }

        // 6. Create borrow record with consistent timestamps
        final now = DateTime.now();
        final dueDate =
            now.add(const Duration(days: 7)); // 7 weeks borrowing period

        final borrowData = {
          'userId': userId,
          'bookId': bookId,
          'borrowDate': now, // Set borrow date to now
          'dueDate': dueDate,
          'status': 'pending', // Status pending, menunggu konfirmasi
          'isPaid': false, // Denda belum dibayar jika ada
          'fine': 0.0, // Denda awal 0 jika belum ada keterlambatan
          'requestDate': now, // Tambahkan tanggal pengajuan
        };

        // 7. Add book to user's pendingBooks
        pendingBooks.add(bookId);
        transaction
            .update(_usersRef.doc(userId), {'pendingBooks': pendingBooks});

        // 8. Create borrow document
        transaction.set(_borrowsRef.doc(borrowId), borrowData);
      });

      print("Berhasil membuat record peminjaman dengan ID: $borrowId");
      return borrowId;
    } catch (e) {
      print("Error saat meminjam buku: $e");
      throw Exception('Gagal meminjam buku: ${e.toString()}');
    }
  }

// Di BorrowRepository, tambahkan metode baru
  Future<void> checkOverdueBooks() async {
    try {
      final now = DateTime.now();

      // Ambil semua peminjaman dengan status 'active' dan dueDate < now
      final overdueQuery = await _borrowsRef
          .where('status', isEqualTo: 'active')
          .where('dueDate', isLessThan: Timestamp.fromDate(now))
          .get();

      // Jika tidak ada yang terlambat, keluar
      if (overdueQuery.docs.isEmpty) return;

      // Gunakan batch untuk update banyak dokumen sekaligus
      final batch = _firestore.batch();

      for (final doc in overdueQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dueDate = (data['dueDate'] as Timestamp).toDate();

        // Hitung denda (Rp 2.000 per hari terlambat)
        final daysLate = now.difference(dueDate).inDays;
        final fine =
            daysLate > 0 ? daysLate * 2000.0 : 2000.0; // Minimal 1 hari denda

        // Update status menjadi overdue dan tambahkan denda jika belum ada
        batch.update(doc.reference, {
          'status': 'overdue',
          'fine': data['fine'] ?? fine,
          'isPaid': data['isPaid'] ?? false,
        });

        // Kirim notifikasi ke pengguna
        try {
          final userId = data['userId'] as String;
          final bookId = data['bookId'] as String;

          // Ambil data buku untuk notifikasi
          final bookDoc = await _booksRef.doc(bookId).get();
          if (bookDoc.exists) {
            final bookData = bookDoc.data() as Map<String, dynamic>;
            final bookTitle = bookData['title'] as String;

            // Kirim notifikasi (pastikan ref.read sudah tersedia)
            final notificationService = _ref.read(notificationServiceProvider);
            await notificationService.createNotificationForUser(
              userId: userId,
              title: 'Buku Terlambat',
              body:
                  'Buku "$bookTitle" telah melewati tenggat waktu pengembalian. Denda: Rp ${fine.toStringAsFixed(0)}',
              type: NotificationType.overdue,
              data: {
                'borrowId': doc.id,
                'bookId': bookId,
                'fine': fine.toStringAsFixed(0),
              },
            );
          }
        } catch (notifError) {
          print('Error sending overdue notification: $notifError');
        }
      }

      // Commit perubahan
      await batch.commit();
      print('Updated ${overdueQuery.docs.length} overdue books');
    } catch (e) {
      print('Error checking overdue books: $e');
    }
  }

// Di borrow_repository.dart
  Stream<List<BorrowModel>> getPendingReturnBorrows() {
    // Debug untuk melihat jika fungsi dipanggil
    print('Getting pending return borrows...');

    return _borrowsRef
        .where('status',
            isEqualTo: 'pendingReturn') // Pastikan string persis sama
        .orderBy('returnRequestDate', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // Debug untuk melihat jumlah dokumen
      print('Fetched ${snapshot.docs.length} pending return borrows');

      final List<BorrowModel> borrows = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Debug status yang diterima dari database
        print('Borrow ID: ${doc.id}, Status: ${data['status']}');

        // Buat model dengan ID dokumen sebagai bagian dari data
        final borrowJson = {
          'id': doc.id,
          ...data,
        };

        // Buat model dasar
        BorrowModel borrowModel = BorrowModel.fromJson(borrowJson);

        // Tambahkan informasi buku
        try {
          final bookDoc = await _booksRef.doc(borrowModel.bookId).get();
          if (bookDoc.exists) {
            final bookData = bookDoc.data() as Map<String, dynamic>;
            borrowModel = borrowModel.copyWith(
              bookTitle: bookData['title'] as String?,
              bookCover: bookData['coverUrl'] as String?,
              // booksAuthor: bookData['author'] as String?,
            );
          }
        } catch (e) {
          print('Error fetching book details: $e');
        }

        // Tambahkan informasi user
        try {
          final userDoc = await _usersRef.doc(borrowModel.userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            borrowModel = borrowModel.copyWith(
              userName: userData['name'] as String?,
            );
          }
        } catch (e) {
          print('Error fetching user details: $e');
        }

        borrows.add(borrowModel);
      }

      return borrows;
    });
  }

// Di BorrowRepository
  Future<void> confirmReturn(String borrowId) async {
    final adminId = currentUserId;
    if (adminId == null) {
      throw Exception('Admin tidak ditemukan');
    }

    // Use transaction properly with all reads first
    try {
      // Get all necessary documents first
      final borrowDocSnapshot = await _borrowsRef.doc(borrowId).get();
      if (!borrowDocSnapshot.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final borrowData = borrowDocSnapshot.data() as Map<String, dynamic>;
      final bookId = borrowData['bookId'] as String;
      final userId = borrowData['userId'] as String;
      final dueDate = (borrowData['dueDate'] as Timestamp).toDate();

      // Get user document
      final userDocSnapshot = await _usersRef.doc(userId).get();
      if (!userDocSnapshot.exists) {
        throw Exception('User tidak ditemukan');
      }

      // Get book document
      final bookDocSnapshot = await _booksRef.doc(bookId).get();
      if (!bookDocSnapshot.exists) {
        throw Exception('Buku tidak ditemukan');
      }

      // Calculate fine if returned late
      double fine = 0.0;
      final now = DateTime.now();
      final bool isLate = now.isAfter(dueDate);

      if (isLate) {
        // Normalisasi untuk perhitungan hari yang lebih akurat
        final DateTime normalizedDueDate =
            DateTime(dueDate.year, dueDate.month, dueDate.day);
        final DateTime normalizedNow = DateTime(now.year, now.month, now.day);

        // Calculate days late
        final daysLate = normalizedNow.difference(normalizedDueDate).inDays;
        final int effectiveDaysLate = daysLate > 0 ? daysLate : 1;

        // Fine per day (e.g., Rp 2.000 per day)
        fine = effectiveDaysLate * 2000;
      }

      // Now start transaction with all data already fetched
      await _firestore.runTransaction((transaction) async {
        // Update borrow document
        transaction.update(_borrowsRef.doc(borrowId), {
          'returnDate': now,
          'status': isLate ? 'overdue' : 'returned',
          'fine': fine,
          'isPaid': fine <= 0, // Mark as paid if no fine
          'confirmedReturnBy': adminId,
          'confirmReturnDate': now,
        });

        // Update borrowed books list
        final userData = userDocSnapshot.data() as Map<String, dynamic>;
        final borrowedBooks =
            List<String>.from(userData['borrowedBooks'] ?? []);
        borrowedBooks.remove(bookId);
        transaction
            .update(_usersRef.doc(userId), {'borrowedBooks': borrowedBooks});

        // Update user fine amount if there's a fine
        if (fine > 0) {
          final currentFine = (userData['fineAmount'] ?? 0.0) as double;
          transaction.update(
              _usersRef.doc(userId), {'fineAmount': currentFine + fine});
        }

        // Update book available count
        final bookData = bookDocSnapshot.data() as Map<String, dynamic>;
        final availableStock = (bookData['availableStock'] ?? 0) as int;
        transaction.update(
            _booksRef.doc(bookId), {'availableStock': availableStock + 1});
      });

      // Send notification to user after transaction succeeds
      try {
        final notificationService = _ref.read(notificationServiceProvider);
        final bookData = bookDocSnapshot.data() as Map<String, dynamic>;
        final bookTitle = bookData['title'] as String;

        await notificationService.createNotificationForUser(
          userId: userId,
          title: 'Buku Berhasil Dikembalikan',
          body: 'Buku "$bookTitle" telah berhasil dikembalikan.',
          type: isLate
              ? NotificationType.bookReturnedLate
              : NotificationType.bookReturned,
          data: {
            'borrowId': borrowId,
            'bookId': bookId,
            'fine': fine.toString(),
          },
        );
      } catch (notifError) {
        print('Error sending return notification: $notifError');
      }
    } catch (e) {
      print("Error confirming return: $e");
      throw Exception('Gagal mengonfirmasi pengembalian buku: ${e.toString()}');
    }
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
        'borrowDate': DateTime.now(), // Set borrow date to now
        'dueDate': DateTime.now().add(const Duration(days: 7)), // 7 days due
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
//   Future<void> returnBook(String borrowId) async {
//     final userId = currentUserId;
//     if (userId == null) {
//       throw Exception('User tidak ditemukan');
//     }

//     try {
//       // Get borrow document first
//       final borrowDoc = await _borrowsRef.doc(borrowId).get();
//       if (!borrowDoc.exists) {
//         throw Exception('Data peminjaman tidak ditemukan');
//       }

//       final borrowData = borrowDoc.data() as Map<String, dynamic>;
//       final bookId = borrowData['bookId'] as String;
//       final dueDate = (borrowData['dueDate'] as Timestamp).toDate();

//       // Calculate fine if returned late
//       double fine = 0.0;
//       final now = DateTime.now();

// // Normalisasi untuk perhitungan hari yang lebih akurat
//       final DateTime normalizedDueDate =
//           DateTime(dueDate.year, dueDate.month, dueDate.day);
//       final DateTime normalizedNow = DateTime(now.year, now.month, now.day);
//       final bool isLate = normalizedNow.isAfter(normalizedDueDate);

//       if (isLate) {
//         // Calculate days late (minimal 1 hari jika terlambat)
//         final daysLate = normalizedNow.difference(normalizedDueDate).inDays;
//         final int effectiveDaysLate = daysLate > 0 ? daysLate : 1;

//         // Fine per day (e.g., Rp 2.000 per day)
//         fine = effectiveDaysLate * 2000;
//       }

//       // Use transaction for atomic update
//       await _firestore.runTransaction((transaction) async {
//         // 1. Update borrow document
//         transaction.update(_borrowsRef.doc(borrowId), {
//           'returnDate': now,
//           'status': isLate ? 'overdue' : 'returned',
//           'fine': fine,
//           'isPaid': fine <= 0, // Mark as paid if no fine
//         });

//         // 2. Get user document
//         final userDoc = await transaction.get(_usersRef.doc(userId));
//         if (!userDoc.exists) {
//           throw Exception('User tidak ditemukan');
//         }

//         // 3. Update borrowed books list
//         final userData = userDoc.data() as Map<String, dynamic>;
//         final borrowedBooks =
//             List<String>.from(userData['borrowedBooks'] ?? []);
//         borrowedBooks.remove(bookId);
//         transaction
//             .update(_usersRef.doc(userId), {'borrowedBooks': borrowedBooks});

//         // 4. Update user fine amount if there's a fine
//         if (fine > 0) {
//           final currentFine = (userData['fineAmount'] ?? 0.0) as double;
//           transaction.update(
//               _usersRef.doc(userId), {'fineAmount': currentFine + fine});
//         }

//         // 5. Update book available count
//         final bookDoc = await transaction.get(_booksRef.doc(bookId));
//         if (bookDoc.exists) {
//           final bookData = bookDoc.data() as Map<String, dynamic>;
//           final availableStock = (bookData['availableStock'] ?? 0) as int;
//           transaction.update(
//               _booksRef.doc(bookId), {'availableStock': availableStock + 1});
//         }
//       });
//     } catch (e) {
//       print("Error returning book: $e");
//       throw Exception('Gagal mengembalikan buku: ${e.toString()}');
//     }
//   }

// Di BorrowRepository
  Future<void> returnBook(String borrowId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }

    try {
      // Read operations first
      final borrowDoc = await _borrowsRef.doc(borrowId).get();
      if (!borrowDoc.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      final borrowData = borrowDoc.data() as Map<String, dynamic>;
      final bookId = borrowData['bookId'] as String;
      final status = borrowData['status'] as String;

      // Check if the status is active
      if (status != 'active' && status != 'overdue') {
        throw Exception('Buku tidak dalam status yang dapat dikembalikan');
      }

      // Update status to pending_return instead of directly returned
      await _borrowsRef.doc(borrowId).update({
        'returnRequestDate': DateTime.now(),
        'status': 'pendingReturn',
        'returnedBy': userId,
      });

      // Notify admin/librarian through notification system
      try {
        final bookDoc = await _booksRef.doc(bookId).get();
        if (bookDoc.exists) {
          final bookData = bookDoc.data() as Map<String, dynamic>;
          final bookTitle = bookData['title'] as String;

          // Send notification to admins (if you have a notification system for admins)
          final notificationService = _ref.read(notificationServiceProvider);
          await notificationService.createNotificationForAdmins(
            title: 'Permintaan Pengembalian Buku',
            body: 'Pengguna ingin mengembalikan buku: "$bookTitle"',
            type: NotificationType.bookReturnRequest,
            data: {
              'borrowId': borrowId,
              'bookId': bookId,
              'userId': userId,
            },
          );
        }
      } catch (notifError) {
        print('Error sending return request notification: $notifError');
        // Continue even if notification fails
      }
    } catch (e) {
      print("Error returning book: $e");
      throw Exception('Gagal meminta pengembalian buku: ${e.toString()}');
    }
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

  Future<void> payFine(String borrowId, String paymentMethod) async {
    try {
      // Get the borrow document
      final borrowDoc = await _borrowsRef.doc(borrowId).get();
      if (!borrowDoc.exists) {
        throw Exception('Peminjaman tidak ditemukan');
      }

      // Cast data ke Map<String, dynamic> terlebih dahulu
      final borrowData = borrowDoc.data() as Map<String, dynamic>;

      // Update the document
      await _borrowsRef.doc(borrowId).update({
        'isPaid': true,
        'paymentMethod': paymentMethod,
        'paymentDate': DateTime.now(),
      });

      // Update user's fineAmount if needed
      final userId = borrowData['userId'] as String?;
      if (userId != null) {
        final userDoc = await _usersRef.doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final currentFine = (userData['fineAmount'] ?? 0.0) as double;
          final borrowFine = (borrowData['fine'] ?? 0.0) as double;

          // Reduce user's total fine
          if (currentFine > 0 && borrowFine > 0) {
            double newFine = currentFine - borrowFine;
            if (newFine < 0) newFine = 0;
            await _usersRef.doc(userId).update({'fineAmount': newFine});
          }
        }
      }
    } catch (e) {
      print("Error paying fine: $e");
      throw Exception('Gagal memproses pembayaran: ${e.toString()}');
    }
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
  return BorrowRepository(ref);
});
