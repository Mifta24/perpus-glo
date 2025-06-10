import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../common/widgets/loading_indicator.dart';
import '../../../../common/widgets/empty_state.dart';
import '../../../history/model/activity_model.dart';
import '../../providers/admin_history_provider.dart';

class AdminHistoryPage extends ConsumerWidget {
  const AdminHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allActivitiesAsync = ref.watch(allActivitiesProvider);
    final selectedDateRange = ref.watch(selectedDateRangeProvider);
    final roleFilter = ref.watch(roleFilterProvider);
    final typeFilter = ref.watch(activityTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Aktivitas Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date filter indicator
          if (selectedDateRange != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey[200],
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Filter: ${DateFormat('dd/MM/yyyy').format(selectedDateRange.start)} - '
                    '${DateFormat('dd/MM/yyyy').format(selectedDateRange.end)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(selectedDateRangeProvider.notifier).state = null,
                  ),
                ],
              ),
            ),
          
          // Role filter indicator
          if (roleFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Icon(
                    roleFilter.toLowerCase() == 'admin' 
                      ? Icons.admin_panel_settings 
                      : Icons.local_library,
                    size: 16,
                    color: roleFilter.toLowerCase() == 'admin' 
                      ? Colors.red[700] 
                      : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter: ${roleFilter.toLowerCase() == 'admin' ? 'Admin' : 'Pustakawan'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(roleFilterProvider.notifier).state = null,
                  ),
                ],
              ),
            ),
          
          // Type filter indicator
          if (typeFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.green[50],
              child: Row(
                children: [
                  Icon(
                    _getActivityIcon(typeFilter),
                    size: 16,
                    color: _getActivityColor(typeFilter),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filter: ${_getActivityTypeName(typeFilter)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref.read(activityTypeFilterProvider.notifier).state = null,
                  ),
                ],
              ),
            ),
          
          // Activity list
          Expanded(
            child: allActivitiesAsync.when(
              data: (activities) {
                if (activities.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'Belum Ada Aktivitas',
                    message: 'Aktivitas yang terjadi di perpustakaan akan muncul di sini',
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _buildActivityItem(context, activity);
                  },
                );
              },
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: ${error.toString()}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, ActivityModel activity) {
    final userRole = activity.metadata?['userRole'] as String? ?? 
                    (activity.metadata?['role'] as String?) ?? 'admin';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getActivityColor(activity.activityType),
              child: Icon(
                _getActivityIcon(activity.activityType),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(activity.description),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activity.userName ?? 'Unknown Admin',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Admin Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(userRole),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        userRole.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(activity.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showActivityDetails(context, activity),
            ),
            onTap: () => _showActivityDetails(context, activity),
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(BuildContext context, ActivityModel activity) {
    final userRole = activity.userRole ?? 
                    (activity.metadata?['role'] as String?) ?? 
                    'admin';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('Detail Aktivitas'),
            const Spacer(),
            // Admin Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(userRole),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                userRole.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Activity type
              const Text(
                'Jenis Aktivitas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  Icon(
                    _getActivityIcon(activity.activityType),
                    size: 16,
                    color: _getActivityColor(activity.activityType),
                  ),
                  const SizedBox(width: 8),
                  Text(_getActivityTypeName(activity.activityType)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Description
              const Text(
                'Deskripsi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(activity.description),
              const SizedBox(height: 16),
              
              // Admin Info
              const Text(
                'Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text('${activity.userName ?? 'Unknown'} (${userRole.toUpperCase()})'),
              const SizedBox(height: 16),
              
              // Timestamp
              const Text(
                'Waktu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(_formatDateTime(activity.timestamp)),
              const SizedBox(height: 16),
              
              // Metadata if available
              if (activity.metadata != null && activity.metadata!.isNotEmpty) ...[
                const Text(
                  'Detail Tambahan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: activity.metadata!.entries
                        .where((entry) => entry.key != 'userRole' && entry.key != 'role')
                        .map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatMetadataKey(entry.key)}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatMetadataValue(entry.value),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Filter Aktivitas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            
            // Activity Type Filters
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
              child: Text(
                'BERDASARKAN JENIS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Semua Aktivitas'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Peminjaman Buku'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = ActivityType.borrowBook;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: const Text('Pengembalian Buku'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = ActivityType.returnBook;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Penambahan Buku'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = ActivityType.addBook;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Pembaruan Buku'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = ActivityType.updateBook;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Pembaruan Profil'),
              onTap: () {
                ref.read(activityTypeFilterProvider.notifier).state = ActivityType.updateProfile;
                Navigator.pop(context);
              },
            ),
            
            const Divider(),
            
            // Role Filters
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
              child: Text(
                'BERDASARKAN PERAN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_outline, color: Colors.grey[700]),
              title: const Text('Semua Peran'),
              onTap: () {
                ref.read(roleFilterProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: Colors.red[700]),
              title: const Text('Admin'),
              onTap: () {
                ref.read(roleFilterProvider.notifier).state = 'admin';
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.local_library, color: Colors.blue[700]),
              title: const Text('Pustakawan'),
              onTap: () {
                ref.read(roleFilterProvider.notifier).state = 'librarian';
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Opsi Lainnya',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('Hapus Log Lama'),
            subtitle: const Text('Hapus aktivitas yang lebih dari 30 hari'),
            onTap: () {
              Navigator.pop(context);
              _confirmClearOldActivities(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: Colors.blue),
            title: const Text('Ekspor Log'),
            subtitle: const Text('Ekspor data aktivitas ke CSV'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ekspor akan hadir segera')),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmClearOldActivities(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Log Lama'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua log aktivitas yang lebih dari 30 hari? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearOldActivities(context, ref);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearOldActivities(BuildContext context, WidgetRef ref) async {
    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menghapus log lama...'),
          ],
        ),
      ),
    );
    
    try {
      await ref.read(adminHistoryControllerProvider.notifier).clearOldActivities(30);
      
      if (context.mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log lama berhasil dihapus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final initialDateRange = ref.read(selectedDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (picked != null) {
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today, show time
      return 'Hari ini, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Kemarin, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // This week
      return '${difference.inDays} hari yang lalu';
    } else {
      // Full date
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  Color _getActivityColor(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.borrowBook:
        return Colors.green;
      case ActivityType.returnBook:
        return Colors.blue;
      case ActivityType.addBook:
        return Colors.purple;
      case ActivityType.updateBook:
        return Colors.orange;
      case ActivityType.deleteBook:
        return Colors.red;
      case ActivityType.updateProfile:
        return Colors.teal;
      case ActivityType.login:
        return Colors.indigo;
      case ActivityType.logout:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.borrowBook:
        return Icons.book;
      case ActivityType.returnBook:
        return Icons.assignment_return;
      case ActivityType.addBook:
        return Icons.add_box;
      case ActivityType.updateBook:
        return Icons.edit;
      case ActivityType.deleteBook:
        return Icons.delete;
      case ActivityType.updateProfile:
        return Icons.person;
      case ActivityType.login:
        return Icons.login;
      case ActivityType.logout:
        return Icons.logout;
      default:
        return Icons.info;
    }
  }

  String _getActivityTypeName(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.borrowBook:
        return 'Peminjaman Buku';
      case ActivityType.returnBook:
        return 'Pengembalian Buku';
      case ActivityType.addBook:
        return 'Penambahan Buku';
      case ActivityType.updateBook:
        return 'Pembaruan Buku';
      case ActivityType.deleteBook:
        return 'Penghapusan Buku';
      case ActivityType.updateProfile:
        return 'Pembaruan Profil';
      case ActivityType.login:
        return 'Login';
      case ActivityType.logout:
        return 'Logout';
      default:
        return 'Umum';
    }
  }

  // Tambahkan fungsi ini untuk warna role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red[700]!;
      case 'librarian':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  // Format metadata key untuk tampilan yang lebih baik
  String _formatMetadataKey(String key) {
    // Kapitalisasi huruf pertama dan ubah camelCase ke spasi
    final formatted = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  // Format nilai metadata
  String _formatMetadataValue(dynamic value) {
    if (value == null) return 'N/A';
    
    if (value is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(value.toDate());
    }
    
    if (value is bool) {
      return value ? 'Ya' : 'Tidak';
    }
    
    return value.toString();
  }
}