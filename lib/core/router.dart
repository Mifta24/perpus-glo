import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/register_page.dart';
import '../features/books/view/books_page.dart';
import '../features/books/view/book_detail_page.dart';
import '../features/borrow/view/borrow_history_page.dart';
import '../features/payment/view/payment_page.dart';

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

    // Payment Routes
    GoRoute(
      path: '/payment/:id',
      builder: (context, state) {
        final fineId = state.pathParameters['id'] ?? '';
        return PaymentPage(fineId: fineId);
      },
    ),
  ],
);
