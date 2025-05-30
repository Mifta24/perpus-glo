import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../borrow/model/borrow_model.dart';
import '../../borrow/providers/borrow_provider.dart';
import '../../profile/model/user_profile_model.dart';
import '../../profile/providers/profile_provider.dart';

class BorrowManagementPage extends ConsumerStatefulWidget {
  const BorrowManagementPage({super.key});

  @override
  ConsumerState<BorrowManagementPage> createState() => _BorrowManagementPageState();
}

class _BorrowManagementPageState extends ConsumerState<BorrowManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    
    return userProfileAsync.when(
      data: (profile) {
        // Check if user is admin or librarian
        if (profile == null || 
            (profile.role != UserRole.admin && profile.role != UserRole.librarian)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Anda tidak memiliki akses ke halaman ini')),
            );
          });
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }
        
        return _buildMainContent();
      },
      loading: () => const Scaffold(body: Center(child: LoadingIndicator())),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Manajemen Peminjaman')),
        body: const Center(child: Text('Terjadi kesalahan')),
      ),
    );
  }
  
  Widget _buildMainContent() {
    final pendingBorrowsAsync = ref.watch(pendingBorrowsProvider);
    final allBorrowsAsync = ref.watch(userBorrowHistoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Peminjaman'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Permintaan'),
            Tab(text: 'Aktif'),
            Tab(text: 'Semua'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending borrows tab
          pendingBorrowsAsync.when(
            data: (borrows) => _buildBorrowsList(borrows, isPending: true),
            loading: () => const Center(child: LoadingIndicator()),
            error: (_, __) => const Center(child: Text('Terjadi kesalahan')),
          ),
          
          // Active borrows tab
          allBorrowsAsync.when(
            data: (borrows) {
              final activeOnly = borrows.where((b) => b.status == BorrowStatus.active).toList();
              return _buildBorrowsList(activeOnly);
            },
            loading: () => const Center(child: LoadingIndicator()),
            error: (_, __) => const Center(child: Text('Terjadi kesalahan')),
          ),
          
          // All borrows tab
          allBorrowsAsync.when(
            data: (borrows) => _buildBorrowsList(borrows),
            loading: () => const Center(child: LoadingIndicator()),
            error: (_, __) => const Center(child: Text('Terjadi kesalahan')),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBorrowsList(List<BorrowModel> borrows, {bool isPending = false}) {
    if (borrows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.hourglass_empty : Icons.bookmark_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'Tidak ada permintaan peminjaman' : 'Tidak ada data peminjaman',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: borrows.length,
      itemBuilder: (context, index) {
        final borrow = borrows[index];
        return _buildBorrowCard(borrow, isPending: isPending);
      },
    );
  }
  
  Widget _buildBorrowCard(BorrowModel borrow, {bool isPending = false}) {
    final controller = ref.watch(borrowControllerProvider);
    final isLoading = controller.isLoading;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borrow.status.color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: borrow.status.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: ${borrow.status.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: borrow.status.color,
                  ),
                ),
                if (isPending)
                  Text(
                    'Diajukan: ${_dateFormat.format(borrow.requestDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          
          // Main content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: borrow.bookCover != null
                      ? Image.network(
                          borrow.bookCover!,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 120,
                            color: Colors.grey[300],
                            child: const Icon(Icons.book, size: 40),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 40),
                        ),
                ),
                
                const SizedBox(width: 12),
                
                // Book details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrow.bookTitle ?? 'Unknown Book',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('ID Buku: ${borrow.bookId}'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Peminjam', borrow.userName ?? 'Unknown User'),
                      _buildInfoRow('ID User', borrow.userId),
                      _buildInfoRow('Tenggat', _dateFormat.format(borrow.dueDate)),
                      if (borrow.returnDate != null)
                        _buildInfoRow('Dikembalikan', _dateFormat.format(borrow.returnDate!)),
                      if (borrow.fine != null && borrow.fine! > 0)
                        _buildInfoRow('Denda', 'Rp ${borrow.fine!.toStringAsFixed(0)}',
                            textColor: borrow.isPaid ? Colors.green : Colors.red),
                      
                      // Rejection reason if applicable
                      if (borrow.status == BorrowStatus.rejected && borrow.rejectReason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Alasan Penolakan: ${borrow.rejectReason}',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons for pending borrows
          if (isPending)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => _showRejectDialog(borrow.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('TOLAK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _confirmBorrow(borrow.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('TERIMA'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmBorrow(String borrowId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Peminjaman'),
        content: const Text('Apakah Anda yakin ingin mengonfirmasi peminjaman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('KONFIRMASI'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await ref.read(borrowControllerProvider.notifier).confirmBorrow(borrowId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Peminjaman berhasil dikonfirmasi'
                : 'Gagal mengonfirmasi peminjaman'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
  
  void _showRejectDialog(String borrowId) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Peminjaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berikan alasan penolakan:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Alasan penolakan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final controller = ref.watch(borrowControllerProvider);
              final isLoading = controller.isLoading;
              
              return ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alasan penolakan harus diisi')),
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        
                        final success = await ref.read(borrowControllerProvider.notifier)
                            .rejectBorrow(borrowId, reasonController.text.trim());
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Peminjaman berhasil ditolak'
                                  : 'Gagal menolak peminjaman'),
                              backgroundColor: success ? Colors.orange : Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('TOLAK'),
              );
            },
          ),
        ],
      ),
    );
  }
}