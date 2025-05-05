import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perpusglo/features/categories/view/category_detail_page.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view/register_page.dart';
import '../features/home/view/main_navigation.dart';
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
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  initialLocation: '/login',
  navigatorKey: _rootNavigatorKey,
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

    // Main navigation route
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationPage(initialIndex: 0),
    ),
    GoRoute(
      path: '/books',
      builder: (context, state) => const MainNavigationPage(initialIndex: 1),
    ),
    GoRoute(
      path: '/borrows',
      builder: (context, state) => const MainNavigationPage(initialIndex: 2),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const MainNavigationPage(initialIndex: 3),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const MainNavigationPage(initialIndex: 4),
    ),

    // Detail routes
    GoRoute(
      path: '/books/:id',
      builder: (context, state) => BookDetailPage(
        bookId: state.pathParameters['id']!,
      ),
    ),
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
      path: '/history',
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: '/payment-history',
      builder: (context, state) => const PaymentHistoryPage(),
    ),

    //  Categories routes
    GoRoute(
      path: '/categories/:categoryId',
      builder: (context, state) {
        final categoryId = state.pathParameters['categoryId'] ?? '';
        return CategoryDetailPage(categoryId: categoryId);
      },
    ),

    // Profile routes
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
  // Redirect to login if not authenticated
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    // List of paths that don't require authentication
    final nonAuthRoutes = ['/login', '/register'];

    // If not logged in and trying to access protected route, redirect to login
    if (!isLoggedIn && !nonAuthRoutes.contains(state.matchedLocation)) {
      return '/login';
    }

    // If logged in and trying to access login/register, redirect to home
    if (isLoggedIn && nonAuthRoutes.contains(state.matchedLocation)) {
      return '/home';
    }

    return null;
  },
);
