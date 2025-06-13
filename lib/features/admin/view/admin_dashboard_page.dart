import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../../profile/providers/profile_provider.dart';
import '../../books/providers/book_provider.dart';
import '../../borrow/providers/borrow_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/model/user_profile_model.dart';
import '../../profile/providers/profile_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});
  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.librarian:
        return 'Pustakawan';
      case UserRole.user:
        return 'Pengguna';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final booksCountAsync = ref.watch(booksCountProvider);
    final activeLoansCountAsync = ref.watch(activeLoansCountProvider);
    //  untuk jumlah peminjaman yang terlambat
    final overdueBorrowsCountAsync = ref.watch(overdueBorrowsCountProvider);

// Cek role user
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      data: (profile) {
        // Jika bukan admin atau pustakawan, redirect ke home
        if (profile == null ||
            (profile.role != UserRole.admin &&
                profile.role != UserRole.librarian)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Anda tidak memiliki akses ke halaman ini')),
            );
          });
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
          body: profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile tidak ditemukan'));
              }

              if (!profile.isLibrarian && !profile.isAdmin) {
                // Jika pengguna bukan pustakawan atau admin, tampilkan akses ditolak
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Akses Ditolak',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Anda tidak memiliki izin untuk mengakses halaman ini',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/books'),
                        child: const Text('Kembali ke Aplikasi'),
                      ),
                    ],
                  ),
                );
              }

              return _buildDashboardContent(context, profile, booksCountAsync,
                  activeLoansCountAsync, overdueBorrowsCountAsync, ref);
            },
            loading: () => const Center(child: LoadingIndicator()),
            error: (error, _) => Center(
              child: Text('Error: ${error.toString()}'),
            ),
          ),
          drawer: Drawer(
            child: _buildAdminDrawer(context, ref),
          ),
        );
      },
      loading: () => const Center(child: LoadingIndicator()),
      error: (error, _) => Center(
        child: Text('Error: ${error.toString()}'),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    dynamic profile,
    AsyncValue<int> booksCountAsync,
    AsyncValue<int> activeLoansCountAsync,
    AsyncValue<int> overdueBorrowsCountAsync,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(booksCountProvider);
        ref.refresh(activeLoansCountProvider);
        ref.refresh(overdueBorrowsCountProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              color: Colors.deepPurple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple,
                      child: profile.photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                profile.photoUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang, ${profile.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getRoleLabel(profile.role),
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats grid
            const Text(
              'Statistik Perpustakaan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatCard(
                  context: context,
                  title: 'Total Buku',
                  icon: Icons.book,
                  valueAsync: booksCountAsync,
                  color: Colors.blue,
                  onTap: () => context.push('/admin/books'),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Dipinjam',
                  icon: Icons.bookmark,
                  valueAsync: activeLoansCountAsync,
                  color: Colors.green,
                  onTap: () => context.push('/admin/borrows'),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Terlambat',
                  icon: Icons.warning,
                  valueAsync: overdueBorrowsCountAsync,
                  color: Colors.orange,
                  onTap: () => context.push('/admin/borrows/overdue'),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Kategori',
                  icon: Icons.category,
                  valueAsync: ref.watch(categoriesCountProvider),
                  color: Colors.purple,
                  onTap: () => context.push('/admin/categories'),
                ),
                // Di AdminDashboardPage
                // ListTile(
                //   title: const Text('Debug Overdue Books'),
                //   subtitle: const Text('Check overdue books calculation'),
                //   leading: const Icon(Icons.bug_report),
                //   onTap: () => context.push('/debug-overdue'),
                // ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick actions
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.add_box,
                    label: 'Tambah Buku',
                    color: Colors.green,
                    onTap: () => context.push('/admin/books/add'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.book_online,
                    label: 'Pinjamkan Buku',
                    color: Colors.blue,
                    onTap: () => context.push('/admin/borrows'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.history,
                    label: 'Riwayat',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/admin/history'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.people,
                    label: 'Kelola User',
                    color: Colors.teal,
                    onTap: () => context.push('/admin/users'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent activities
            const Text(
              'Aktivitas Terbaru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(context, ref),
            // Di AdminDashboardPage
            // ElevatedButton(
            //   onPressed: () async {
            //     // Tampilkan dialog konfirmasi terlebih dahulu
            //     final shouldFix = await showDialog<bool>(
            //       context: context,
            //       builder: (context) => AlertDialog(
            //         title: const Text('Perbaiki Status Pengembalian'),
            //         content: const Text('Ini akan memperbaiki status peminjaman yang sudah dikembalikan tapi statusnya tidak konsisten. Lanjutkan?'),
            //         actions: [
            //           TextButton(
            //             onPressed: () => Navigator.pop(context, false),
            //             child: const Text('BATAL'),
            //           ),
            //           ElevatedButton(
            //             onPressed: () => Navigator.pop(context, true),
            //             child: const Text('PERBAIKI'),
            //           ),
            //         ],
            //       ),
            //     );
                
            //     if (shouldFix != true) return;
                
            //     // Tampilkan loading
            //     showDialog(
            //       context: context, 
            //       barrierDismissible: false,
            //       builder: (context) => const AlertDialog(
            //         content: Column(
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             CircularProgressIndicator(),
            //             SizedBox(height: 16),
            //             Text('Memperbaiki status...'),
            //           ],
            //         ),
            //       ),
            //     );
                
            //     // Jalankan perbaikan
            //     final count = await ref.read(fixReturnedStatusProvider.future);
                
            //     // Tutup dialog loading
            //     Navigator.pop(context);
                
            //     // Tampilkan hasil
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       SnackBar(content: Text('Berhasil memperbaiki $count peminjaman')),
            //     );
                
            //     // Refresh data
            //     ref.refresh(allBorrowsProvider);
            //   },
            //   style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            //   child: const Text('PERBAIKI STATUS PENGEMBALIAN'),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required AsyncValue<int> valueAsync,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              valueAsync.when(
                data: (value) => Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                loading: () => const LoadingIndicator(),
                error: (_, __) => const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context, WidgetRef ref) {
    final recentActivities = ref.watch(userHistoryProvider);

    return recentActivities.when(
      data: (activities) {
        if (activities.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('Belum ada aktivitas'),
              ),
            ),
          );
        }

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length > 5 ? 5 : activities.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getActivityColor(activity.activityType),
                  child: Icon(
                    _getActivityIcon(activity.activityType),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(activity.description),
                subtitle: Text(
                  _formatDate(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Show activity details if needed
                },
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: LoadingIndicator()),
      ),
      error: (error, _) => Center(
        child: Text('Error: ${error.toString()}'),
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) => ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(profile?.name ?? 'Staff'),
            accountEmail: Text(profile?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: profile?.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(
                        profile!.photoUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      profile?.name.isNotEmpty ?? false
                          ? profile!.name[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(fontSize: 24),
                    ),
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade700,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Kelola Buku'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/books');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text('Kelola Peminjaman'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/borrows');
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Kelola Kategori'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/categories');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Kelola Pengguna'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/users');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Riwayat Aktivitas'),
            onTap: () {
              Navigator.pop(context);
              context.push('/admin/history');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      loading: () => const Center(child: LoadingIndicator()),
      error: (_, __) => const Center(child: Text('Error loading profile')),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/admin/login');
              }
            },
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(dynamic activityType) {
    // Implement based on your ActivityType enum
    switch (activityType.toString()) {
      case 'ActivityType.borrowBook':
        return Colors.green;
      case 'ActivityType.returnBook':
        return Colors.blue;
      case 'ActivityType.addBook':
        return Colors.purple;
      case 'ActivityType.updateBook':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(dynamic activityType) {
    // Implement based on your ActivityType enum
    switch (activityType.toString()) {
      case 'ActivityType.borrowBook':
        return Icons.book;
      case 'ActivityType.returnBook':
        return Icons.assignment_return;
      case 'ActivityType.addBook':
        return Icons.add_box;
      case 'ActivityType.updateBook':
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}
