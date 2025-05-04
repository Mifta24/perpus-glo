import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl; // Ubah menjadi nullable dengan tanda ?
  final DateTime createdAt;
  final List<String> borrowedBooks;
  final double fineAmount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl, // Tidak required lagi
    required this.createdAt,
    required this.borrowedBooks,
    required this.fineAmount,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?, // Menerima null
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      borrowedBooks: List<String>.from(json['borrowedBooks'] ?? []), // Handle jika null
      fineAmount: (json['fineAmount'] ?? 0).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'borrowedBooks': borrowedBooks,
      'fineAmount': fineAmount,
    };
  }
  
  // Tambahkan method copyWith untuk memudahkan update model
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    List<String>? borrowedBooks,
    double? fineAmount,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      borrowedBooks: borrowedBooks ?? this.borrowedBooks,
      fineAmount: fineAmount ?? this.fineAmount,
    );
  }
}