import 'package:cloud_firestore/cloud_firestore.dart';
// BookModel.dart digunakan untuk menyimpan data buku
// yang diambil dari Firestore. Model ini memiliki beberapa atribut
class BookModel {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final String category;
  final int availableStock;
  final int totalStock;
  final DateTime publishedDate;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.category,
    required this.availableStock,
    required this.totalStock,
    required this.publishedDate,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      availableStock: json['availableStock'] as int,
      totalStock: json['totalStock'] as int,
      publishedDate: (json['publishedDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'description': description,
      'category': category,
      'availableStock': availableStock,
      'totalStock': totalStock,
      'publishedDate': publishedDate,
    };
  }

  bool get isAvailable => availableStock > 0;
}