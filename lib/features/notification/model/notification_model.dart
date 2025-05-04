import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  reminder,    // Pengingat pengembalian buku
  overdue,     // Buku terlambat
  fine,        // Denda
  info,        // Informasi umum
  bookReady,   // Buku yang direservasi sudah tersedia
}

extension NotificationTypeExtension on NotificationType {
  String get title {
    switch (this) {
      case NotificationType.reminder:
        return 'Pengingat Pengembalian';
      case NotificationType.overdue:
        return 'Buku Terlambat';
      case NotificationType.fine:
        return 'Informasi Denda';
      case NotificationType.info:
        return 'Informasi';
      case NotificationType.bookReady:
        return 'Buku Tersedia';
    }
  }
  
  String get icon {
    switch (this) {
      case NotificationType.reminder:
        return 'ic_reminder';
      case NotificationType.overdue:
        return 'ic_overdue';
      case NotificationType.fine:
        return 'ic_fine';
      case NotificationType.info:
        return 'ic_info';
      case NotificationType.bookReady:
        return 'ic_book';
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;
  
  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });
  
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.info,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'createdAt': createdAt,
      'isRead': isRead,
      'data': data,
    };
  }
  
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}