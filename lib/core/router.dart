import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perpusglo/features/admin/view/categories/admin_categories_page.dart';
import 'package:perpusglo/features/admin/view/categories/admin_category_books_page.dart';
import 'package:perpusglo/features/admin/view/history/admin_history_page.dart';
import 'package:perpusglo/features/admin/view/overdue_books_page.dart';
import 'package:perpusglo/features/admin/view/settings/admin_settings_page.dart';
import 'package:perpusglo/features/admin/view/user_edit_page.dart';
import 'package:perpusglo/features/admin/view/user_search_results_page.dart';
import 'package:perpusglo/features/borrow/view/debug_overdue_page.dart';
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
// Import halaman admin
import '../features/admin/view/admin_dashboard_page.dart';
import '../features/admin/view/admin_login_page.dart';
import '../features/admin/view/book_management_page.dart';
import '../features/admin/view/add_edit_book_page.dart';
import '../features/admin/view/borrow_management_page.dart';
import '../features/admin/view/user_management_page.dart';

// router.dart digunakan untuk mengatur routing aplikasi menggunakan GoRouter
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  // initialLocation: '/login',
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',

  // Gabungan dari kedua fungsi redirect
  redirect: (context, state) async {
    // 1. Periksa status autentikasi
    final authState = FirebaseAuth.instance.currentUser;
    final isLoggedIn = authState != null;

    // 2. Tentukan jenis rute yang diminta
    final isAdminRoute = state.matchedLocation.startsWith('/admin');
    final isLoginRoute = state.matchedLocation == '/login';
    final isRegisterRoute = state.matchedLocation == '/register';
    final isAdminLoginRoute = state.matchedLocation == '/admin/login';
    final isAuthRoute = isLoginRoute || isRegisterRoute || isAdminLoginRoute;

    // 3. Logika untuk rute auth (admin dan umum)
    if (!isLoggedIn) {
      // Jika belum login
      if (isAuthRoute) {
        // Biarkan akses ke halaman auth
        return null;
      } else if (isAdminRoute) {
        // Redirect ke admin login untuk rute admin
        return '/admin/login';
      } else {
        // Redirect ke login untuk rute user biasa
        return '/login';
      }
    }

    // 4. Jika sudah login, periksa role user
    String? userRole;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authState.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userRole = userData['role'] as String? ?? 'user';
      } else {
        // Jika dokumen user tidak ditemukan, anggap sebagai user biasa
        userRole = 'user';
      }
    } catch (e) {
      print('Error fetching user role: $e');
      // Fallback ke user biasa jika terjadi error
      userRole = 'user';
    }

    // 5. Redirect berdasarkan role & lokasi
    if (isLoggedIn) {
      // 5a. Jika sudah login dan mencoba akses halaman auth
      if (isLoginRoute || isRegisterRoute) {
        if (userRole == 'admin' || userRole == 'librarian') {
          return '/admin'; // Admin/Pustakawan ke dashboard admin
        } else {
          return '/home'; // User biasa ke home
        }
      }

      // 5b. Jika admin/pustakawan mencoba akses home user
      if ((userRole == 'admin' || userRole == 'librarian') &&
          (state.matchedLocation == '/home' || state.matchedLocation == '/')) {
        return '/admin';
      }

      // 5c. Jika user biasa mencoba akses rute admin
      if (userRole == 'user' && isAdminRoute) {
        return '/home';
      }

      // 5d. Jika admin/pustakawan mencoba akses admin login
      if ((userRole == 'admin' || userRole == 'librarian') &&
          isAdminLoginRoute) {
        return '/admin';
      }
    }

    // Default: tidak ada redirect
    return null;
  },
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
      path: '/categories/:id',
      builder: (context, state) {
        final categoryId = state.pathParameters['id'] ?? '';
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

    // Admin Routes - BARU
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/admin/books',
      builder: (context, state) => const BookManagementPage(),
    ),
    GoRoute(
      path: '/admin/books/add',
      builder: (context, state) => const AddEditBookPage(),
    ),
    GoRoute(
      path: '/admin/books/edit/:id',
      builder: (context, state) {
        final bookId = state.pathParameters['id'] ?? '';
        return AddEditBookPage(bookId: bookId);
      },
    ),
    GoRoute(
      path: '/admin/borrows',
      builder: (context, state) => const BorrowManagementPage(),
    ),
    GoRoute(
      path: '/admin/borrows/overdue',
      builder: (context, state) => const OverdueBooksPage(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UserManagementPage(),
    ),
    GoRoute(
      path: '/admin/users/:id',
      builder: (context, state) {
        final userId = state.pathParameters['id']!;
        return UserEditPage(userId: userId);
      },
    ),
    GoRoute(
      path: '/admin/users/search/:query',
      builder: (context, state) {
        final query = state.pathParameters['query']!;
        return UserSearchResultsPage(query: query);
      },
    ),
    GoRoute(
      path: '/admin/history',
      builder: (context, state) => const AdminHistoryPage(),
    ),

    // Rute untuk mengelola kategori
    GoRoute(
      path: '/admin/categories',
      builder: (context, state) => const AdminCategoriesPage(),
    ),

    GoRoute(
      path: '/admin/categories/:id/books',
      builder: (context, state) {
        final categoryId = state.pathParameters['id']!;
        return AdminCategoryBooksPage(categoryId: categoryId);
      },
    ),
    // Rute untuk mengelola pengaturan admin
    GoRoute(
      path: '/admin/settings',
      builder: (context, state) => const AdminSettingsPage(),
    ),
    // Di router.dart
    GoRoute(
      path: '/debug-overdue',
      builder: (context, state) => const DebugOverduePage(),
    ),
  ],
);
