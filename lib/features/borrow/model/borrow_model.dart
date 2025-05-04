import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BorrowStatus {
  active,    // Sedang dipinjam
  returned,  // Sudah dikembalikan
  overdue,   // Terlambat
  lost       // Hilang
}

extension BorrowStatusExtension on BorrowStatus {
  String get name {
    switch (this) {
      case BorrowStatus.active:
        return 'Dipinjam';
      case BorrowStatus.returned:
        return 'Dikembalikan';
      case BorrowStatus.overdue:
        return 'Terlambat';
      case BorrowStatus.lost:
        return 'Hilang';
    }
  }
  
  Color get color {
    switch (this) {
      case BorrowStatus.active:
        return Colors.blue;
      case BorrowStatus.returned:
        return Colors.green;
      case BorrowStatus.overdue:
        return Colors.orange;
      case BorrowStatus.lost:
        return Colors.red;
    }
  }
}

class BorrowModel {
  final String id;
  final String userId;
  final String bookId;
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final BorrowStatus status;
  final double? fine;
  final bool isPaid;
  
  // Properti tambahan untuk UI, tidak disimpan di Firestore
  final String? bookTitle;
  final String? bookCover;
  
  BorrowModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.borrowDate,
    required this.dueDate,
    this.returnDate,
    required this.status,
    this.fine,
    required this.isPaid,
    this.bookTitle,
    this.bookCover,
  });
  
  factory BorrowModel.fromJson(Map<String, dynamic> json) {
    return BorrowModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bookId: json['bookId'] as String,
      borrowDate: (json['borrowDate'] as Timestamp).toDate(),
      dueDate: (json['dueDate'] as Timestamp).toDate(),
      returnDate: json['returnDate'] != null 
          ? (json['returnDate'] as Timestamp).toDate() 
          : null,
      status: BorrowStatus.values.firstWhere(
        (e) => e.toString() == 'BorrowStatus.${json['status']}',
        orElse: () => BorrowStatus.active,
      ),
      fine: json['fine']?.toDouble(),
      isPaid: json['isPaid'] as bool? ?? false,
      bookTitle: json['bookTitle'] as String?,
      bookCover: json['bookCover'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookId': bookId,
      'borrowDate': borrowDate,
      'dueDate': dueDate,
      'returnDate': returnDate,
      'status': status.toString().split('.').last,
      'fine': fine,
      'isPaid': isPaid,
      // Properti UI tidak disimpan
    };
  }
  
  BorrowModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    DateTime? borrowDate,
    DateTime? dueDate,
    DateTime? returnDate,
    BorrowStatus? status,
    double? fine,
    bool? isPaid,
    String? bookTitle,
    String? bookCover,
  }) {
    return BorrowModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      borrowDate: borrowDate ?? this.borrowDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      fine: fine ?? this.fine,
      isPaid: isPaid ?? this.isPaid,
      bookTitle: bookTitle ?? this.bookTitle,
      bookCover: bookCover ?? this.bookCover,
    );
  }
  
  // Method untuk cek apakah peminjaman telah melewati tenggat waktu
  bool isOverdue() {
    if (returnDate != null) {
      return returnDate!.isAfter(dueDate);
    }
    return DateTime.now().isAfter(dueDate);
  }
  
  // Method untuk menghitung denda
  double calculateFine() {
    if (returnDate == null && !isOverdue()) return 0;
    
    final DateTime endDate = returnDate ?? DateTime.now();
    if (!endDate.isAfter(dueDate)) return 0;
    
    // Hitung selisih hari
    final difference = endDate.difference(dueDate).inDays;
    
    // Rumus denda: Rp 1.000 per hari terlambat
    return difference * 1000;
  }
}