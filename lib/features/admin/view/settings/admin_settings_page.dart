import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../common/widgets/loading_indicator.dart';
import '../../../profile/model/user_profile_model.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../notification/providers/notification_provider.dart';
import '../../../notification/model/notification_model.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  File? _profileImage;
  bool _isUploading = false;
  bool _isProfileDataLoaded = false;
  bool _notifyBorrowRequests = true;
  bool _notifyReturnRequests = true;
  bool _notifyOverdueBooks = true;
  bool _notifyFinePayments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile(UserProfileModel currentProfile) async {
    if (!_formKey.currentState!.validate()) return;

    // setState(() {
    //   _isUploading = true;
    // });

    try {
      // Perbarui informasi profil
      final userProfileController = ref.read(profileControllerProvider.notifier);

      // Unggah foto jika ada perubahan
      String? photoUrl;
      if (_profileImage != null) {
        // Implementasi upload foto profil
        // Untuk sementara, gunakan photoUrl yang sudah ada
        // photoUrl = currentProfile.photoUrl;
      }

      // Update profil dengan data baru
      await userProfileController.updateProfile(
        currentProfile.copyWith(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          photoUrl: photoUrl ?? currentProfile.photoUrl,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // 1. Perbaikan _saveNotificationSettings
  Future<void> _saveNotificationSettings() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Simpan pengaturan notifikasi ke provider (bukan ke Firebase melalui controller)
      ref.read(notificationSettingsProvider.notifier).update((state) => {
        'notifyBorrowRequests': _notifyBorrowRequests,
        'notifyReturnRequests': _notifyReturnRequests,
        'notifyOverdueBooks': _notifyOverdueBooks,
        'notifyFinePayments': _notifyFinePayments,
      });

      // Dapatkan service dan simpan ke Firebase
      final notificationService = ref.read(notificationServiceProvider);
      // Tambahkan metode untuk menyimpan pengaturan notifikasi ke preferences atau DB
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan notifikasi berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final notificationSettings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profil'),
            Tab(text: 'Notifikasi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Profile tab
          userProfileAsync.when(
            data: (profile) {
              // Load profile data into controllers once
              if (!_isProfileDataLoaded && profile != null) {
                _nameController.text = profile.name;
                _phoneController.text = profile.phoneNumber ?? '';
                _addressController.text = profile.address ?? '';
                _isProfileDataLoaded = true;
              }

              return profile != null
                  ? _buildProfileTab(profile)
                  : const Center(child: Text('Profil tidak ditemukan'));
            },
            loading: () => const Center(child: LoadingIndicator()),
            error: (error, _) => Center(
              child: Text('Error: ${error.toString()}'),
            ),
          ),

          // Notifications tab - ubah ini 
          _buildNotificationsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab(UserProfileModel profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile image and role
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    // onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : (profile.photoUrl != null
                                  ? NetworkImage(profile.photoUrl!) as ImageProvider
                                  : const AssetImage(
                                      'assets/images/default_avatar.png')),
                          child: _profileImage == null &&
                                  profile.photoUrl == null
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(profile.role),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getRoleLabel(profile.role),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Informasi Dasar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const Text(
              'Informasi Kontak',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : () => _updateProfile(profile),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('SIMPAN PERUBAHAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Perbaikan _buildNotificationsTab untuk tidak menggunakan when
  Widget _buildNotificationsTab() {
    // Baca nilai langsung dari provider
    final settings = ref.watch(notificationSettingsProvider);
    
    // Update nilai lokal sesuai dengan nilai dari provider
    _notifyBorrowRequests = settings['notifyBorrowRequests'] ?? true;
    _notifyReturnRequests = settings['notifyReturnRequests'] ?? true;
    _notifyOverdueBooks = settings['notifyOverdueBooks'] ?? true;
    _notifyFinePayments = settings['notifyFinePayments'] ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent notifications header
          const Text(
            'Pengaturan Notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Notification settings
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Notifikasi Permintaan Peminjaman'),
                  subtitle: const Text(
                      'Dapatkan notifikasi saat ada permintaan peminjaman baru'),
                  value: _notifyBorrowRequests,
                  onChanged: (value) {
                    setState(() {
                      _notifyBorrowRequests = value;
                    });
                  },
                  secondary: const Icon(Icons.book),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifikasi Permintaan Pengembalian'),
                  subtitle: const Text(
                      'Dapatkan notifikasi saat ada permintaan pengembalian buku'),
                  value: _notifyReturnRequests,
                  onChanged: (value) {
                    setState(() {
                      _notifyReturnRequests = value;
                    });
                  },
                  secondary: const Icon(Icons.assignment_return),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifikasi Keterlambatan'),
                  subtitle: const Text(
                      'Dapatkan notifikasi saat ada buku yang terlambat dikembalikan'),
                  value: _notifyOverdueBooks,
                  onChanged: (value) {
                    setState(() {
                      _notifyOverdueBooks = value;
                    });
                  },
                  secondary: const Icon(Icons.warning),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Notifikasi Pembayaran Denda'),
                  subtitle: const Text(
                      'Dapatkan notifikasi saat ada pembayaran denda'),
                  value: _notifyFinePayments,
                  onChanged: (value) {
                    setState(() {
                      _notifyFinePayments = value;
                    });
                  },
                  secondary: const Icon(Icons.payment),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Save settings button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _saveNotificationSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SIMPAN PENGATURAN'),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Recent notifications
          const Text(
            'Notifikasi Terbaru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildRecentNotifications(),
        ],
      ),
    );
  }

  // 4. Perbaikan _buildRecentNotifications untuk menangani List
  Widget _buildRecentNotifications() {
    final recentNotificationsAsync = ref.watch(userNotificationsProvider);

    return recentNotificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Belum ada notifikasi',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        // Sort notifications by createdAt
        final sortedNotifications = List.of(notifications)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Take only the last 5
        final recentNotifications = sortedNotifications.take(5).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentNotifications.length,
          itemBuilder: (context, index) {
            final notification = recentNotifications[index];
            return _buildNotificationItem(notification);
          },
        );
      },
      loading: () => const Center(child: LoadingIndicator()),
      error: (error, _) => Center(
        child: Text('Error: ${error.toString()}'),
      ),
    );
  }

  // 5. Perbaikan _buildNotificationItem untuk mengganti timestamp dan message ke createdAt dan body
  Widget _buildNotificationItem(NotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final formattedDate = dateFormat.format(notification.createdAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _getNotificationTypeColor(notification.type),
          child: Icon(
            _getNotificationTypeIcon(notification.type),
            color: Colors.white,
          ),
        ),
        title: Text(notification.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body), // changed from message to body
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationServiceProvider)
                .markAsRead(notification.id); // Changed to use service directly
          }
          
          // Navigasi ke halaman yang sesuai berdasarkan tipe notifikasi
          _navigateToNotificationDestination(notification);
        },
      ),
    );
  }

  void _navigateToNotificationDestination(NotificationModel notification) {
    switch (notification.type) {
      case NotificationType.borrowRequest:
      case NotificationType.borrowRequestAdmin:
        // context.push('/admin/borrows');
        break;
      case NotificationType.bookReturnRequest:
      case NotificationType.returnReminder:
        // context.push('/admin/borrows/return');
        break;
      case NotificationType.overdue:
      case NotificationType.bookReturnedLate:
        context.push('/admin/borrows/overdue');
        break;
      case NotificationType.payment:
      case NotificationType.fine:
        // context.push('/admin/payments');
        break;
      case NotificationType.announcement:
      case NotificationType.general:
      case NotificationType.info:
      case NotificationType.reminder:
      case NotificationType.borrowConfirmed:
      case NotificationType.borrowRejected:
      case NotificationType.bookReturned:
        // Tidak ada navigasi khusus
        break;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.librarian:
        return Colors.orange;
      case UserRole.user:
        return Colors.blue;
    }
  }

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
  
  IconData _getNotificationTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return Icons.notifications;
      case NotificationType.info:
        return Icons.info;
      case NotificationType.reminder:
        return Icons.access_time;
      case NotificationType.borrowRequest:
        return Icons.book;
      case NotificationType.borrowConfirmed:
        return Icons.check_circle;
      case NotificationType.borrowRejected:
        return Icons.cancel;
      case NotificationType.borrowRequestAdmin:
        return Icons.pending_actions;
      case NotificationType.returnReminder:
        return Icons.alarm;
      case NotificationType.bookReturned:
        return Icons.assignment_turned_in;
      case NotificationType.overdue:
        return Icons.warning;
      case NotificationType.fine:
        return Icons.attach_money;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.bookReturnedLate:
        return Icons.history;
      case NotificationType.bookReturnRequest:
        return Icons.assignment_return;
    }
  }
  

  Color _getNotificationTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.general:
        return Colors.blue;
      case NotificationType.info:
        return Colors.lightBlue;
      case NotificationType.reminder:
        return Colors.amber;
      case NotificationType.borrowRequest:
        return Colors.amber;
      case NotificationType.borrowConfirmed:
        return Colors.green;
      case NotificationType.borrowRejected:
        return Colors.red;
      case NotificationType.borrowRequestAdmin:
        return Colors.purple;
      case NotificationType.returnReminder:
        return Colors.orange;
      case NotificationType.bookReturned:
        return Colors.teal;
      case NotificationType.overdue:
        return Colors.deepOrange;
      case NotificationType.fine:
        return Colors.redAccent;
      case NotificationType.payment:
        return Colors.green;
      case NotificationType.announcement:
        return Colors.indigo;
      case NotificationType.bookReturnedLate:
        return Colors.red.shade700;
      case NotificationType.bookReturnRequest:
        return Colors.pink;
    }
  }
}