import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/register_page.dart';
import '../features/books/view/books_page.dart';
import '../features/books/view/book_detail_page.dart';
import '../features/borrow/view/borrow_history_page.dart';
import '../features/borrow/view/borrow_detail_page.dart';
import '../features/history/view/history_page.dart';
import '../features/notification/view/notification_page.dart';
import '../features/payment/view/payment_history_page.dart';
import '../features/payment/view/payment_page.dart';
import '../features/profile/view/profile_page.dart';
import '../features/profile/view/edit_profile_page.dart';
import '../features/profile/view/settings_page.dart';


// router.dart digunakan untuk mengatur routing aplikasi menggunakan GoRouter
final GoRouter router = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth Routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // Main App Routes
    GoRoute(
      path: '/books',
      builder: (context, state) => const BooksPage(),
    ),
    GoRoute(
      path: '/books/:id',
      builder: (context, state) {
        final bookId = state.pathParameters['id'] ?? '';
        return BookDetailPage(bookId: bookId);
      },
    ),

    // Borrow Routes
    GoRoute(
      path: '/borrow-history',
      builder: (context, state) => const BorrowHistoryPage(),
    ),
    GoRoute(
      path: '/borrow/:id',
      builder: (context, state) {
        final borrowId = state.pathParameters['id'] ?? '';
        return BorrowDetailPage(borrowId: borrowId);
      },
    ),

    // Payment Routes
    GoRoute(
      path: '/payment/:id',
      builder: (context, state) {
        final fineId = state.pathParameters['id'] ?? '';
        final amount =
            double.tryParse(state.uri.queryParameters['amount'] ?? '0') ?? 0.0;
        return PaymentPage(fineId: fineId, amount: amount);
      },
    ),
    GoRoute(
      path: '/payment-history',
      builder: (context, state) => const PaymentHistoryPage(),
    ),

    // Notification Route
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationPage(),
    ),

    // History Route
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryPage(),
    ),

    // Profile Routes
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),
    
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
