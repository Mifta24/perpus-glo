import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:perpusglo/features/borrow/data/borrow_repository.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../../../common/widgets/empty_state.dart';
import '../../borrow/model/borrow_model.dart';
import '../../borrow/providers/borrow_provider.dart';
import 'package:intl/date_symbol_data_local.dart'; 

// Provider khusus untuk peminjaman yang terlambat
final overdueBorrowsProvider = StreamProvider<List<BorrowModel>>((ref) {
  // Cek semua peminjaman aktif
  final allBorrows = ref.watch(allBorrowsProvider);
  
  // Handle loading state dengan lebih baik
  return allBorrows.when(
    data: (borrows) {
      // Filter untuk mendapatkan buku yang terlambat saja
      return Stream.value(borrows
          .where((borrow) => borrow.status == BorrowStatus.overdue)
          .toList());
    },
    loading: () => const Stream.empty(), // Gunakan Stream.empty() daripada Stream.value([])
    error: (e, st) => Stream.error(e, st), // Teruskan error dengan stack trace
  );
});

class OverdueBooksPage extends ConsumerStatefulWidget {
  const OverdueBooksPage({Key? key}) : super(key: key);

  @override
  ConsumerState<OverdueBooksPage> createState() => _OverdueBooksPageState();
}

class _OverdueBooksPageState extends ConsumerState<OverdueBooksPage> {
  String? _searchQuery;
  final _searchController = TextEditingController();
  bool _isProcessing = false;

 @override
  void initState() {
    super.initState();
    // Inisialisasi data locale untuk bahasa Indonesia
    initializeDateFormatting('id_ID', null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overdueBooksAsync = ref.watch(overdueBorrowsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Terlambat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshOverdueStatus(context),
            tooltip: 'Perbarui Status Keterlambatan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari buku atau peminjam...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = null;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.isNotEmpty ? value.toLowerCase() : null;
                });
              },
            ),
          ),

          // Stats summary
          overdueBooksAsync.when(
            data: (overdueBooks) {
              final totalOverdue = overdueBooks.length;
              int totalFine = 0;
              
              for (var borrow in overdueBooks) {
                if (borrow.fine != null) {
                  totalFine += borrow.fine!.round();
                }
              }
              
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Total Terlambat',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalOverdue',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Total Denda',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(
                                locale: 'id',
                                symbol: 'Rp',
                                decimalDigits: 0,
                              ).format(totalFine),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Memuat data buku terlambat...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Terjadi kesalahan: ${e.toString()}',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Overdue books list
          Expanded(
            child: overdueBooksAsync.when(
              data: (overdueBooks) {
                // Filter books based on search query
                final filteredBooks = _searchQuery != null
                    ? overdueBooks.where((borrow) {
                        final bookTitle = borrow.bookTitle?.toLowerCase() ?? '';
                        final userName = borrow.userName?.toLowerCase() ?? '';
                        return bookTitle.contains(_searchQuery!) ||
                            userName.contains(_searchQuery!);
                      }).toList()
                    : overdueBooks;

                if (filteredBooks.isEmpty) {
                  return EmptyState(
                    icon: Icons.check_circle_outline,
                    title: overdueBooks.isEmpty
                        ? 'Tidak Ada Buku Terlambat'
                        : 'Tidak Ada Hasil Pencarian',
                    message: overdueBooks.isEmpty
                        ? 'Semua peminjaman buku dikembalikan tepat waktu'
                        : 'Coba dengan kata kunci pencarian yang berbeda',
                    iconColor: Colors.green,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(overdueBorrowsProvider);
                    await ref.read(borrowRepositoryProvider).checkOverdueBooks();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      return _buildOverdueBookItem(context, filteredBooks[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data buku terlambat...',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              error: (e, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error: ${e.toString()}',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(overdueBorrowsProvider),
                      child: Text('COBA LAGI'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBookItem(BuildContext context, BorrowModel borrow) {
    final daysLate = DateTime.now().difference(borrow.dueDate).inDays;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover
                borrow.bookCover != null && borrow.bookCover!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          borrow.bookCover!,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 80,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.book, size: 40),
                              ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.book, size: 40),
                      ),
                const SizedBox(width: 16),
                
                // Book details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrow.bookTitle ?? 'Buku Tidak Diketahui',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        borrow.booksAuthor ?? 'Penulis tidak diketahui',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Peminjam: ${borrow.userName ?? 'Tidak diketahui'}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.event_busy, size: 16, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Tenggat: ${dateFormat.format(borrow.dueDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Terlambat: $daysLate hari',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Denda: ${NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp',
                              decimalDigits: 0,
                            ).format(borrow.fine ?? 0)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Gunakan Wrap untuk mengganti Row agar tidak overflow
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showBorrowDetails(context, borrow),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('DETAIL'),
                ),
                FilledButton.icon(
                  onPressed: () => _processReturn(context, borrow),
                  icon: const Icon(Icons.assignment_return, size: 18),
                  // Buat label lebih pendek agar tidak overflow
                  label: const Text('PROSES KEMBALI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBorrowDetails(BuildContext context, BorrowModel borrow) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Peminjaman'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Book info
              const Text(
                'Informasi Buku',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Judul: ${borrow.bookTitle ?? 'Tidak diketahui'}'),
              Text('Penulis: ${borrow.booksAuthor ?? 'Tidak diketahui'}'),
              Text('ID Buku: ${borrow.bookId}'),
              
              const SizedBox(height: 16),
              
              // Borrower info
              const Text(
                'Informasi Peminjam',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Nama: ${borrow.userName ?? 'Tidak diketahui'}'),
              Text('ID Peminjam: ${borrow.userId}'),
              
              const SizedBox(height: 16),
              
              // Borrow info
              const Text(
                'Informasi Peminjaman',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Tanggal Pinjam: ${dateFormat.format(borrow.borrowDate)}'),
              Text('Tenggat Waktu: ${dateFormat.format(borrow.dueDate)}'),
              Text('Status: ${_getBorrowStatusText(borrow.status)}'),
              
              const SizedBox(height: 16),
              
              // Fine info
              const Text(
                'Informasi Denda',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Keterlambatan: ${DateTime.now().difference(borrow.dueDate).inDays} hari'),
              Text('Jumlah Denda: ${NumberFormat.currency(
                locale: 'id',
                symbol: 'Rp',
                decimalDigits: 0,
              ).format(borrow.fine ?? 0)}'),
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

  String _getBorrowStatusText(BorrowStatus? status) {
    switch (status) {
      case BorrowStatus.active:
        return 'Aktif';
      case BorrowStatus.overdue:
        return 'Terlambat';
      case BorrowStatus.returned:
        return 'Dikembalikan';
      case BorrowStatus.lost:
        return 'Hilang';
      case BorrowStatus.pending:
        return 'Menunggu Konfirmasi';
      case BorrowStatus.pendingReturn:
        return 'Menunggu Pengembalian';
      case BorrowStatus.rejected:
        return 'Ditolak';
      default:
        return 'Tidak diketahui';
    }
  }

  Future<void> _processReturn(BuildContext context, BorrowModel borrow) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proses Pengembalian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Memproses pengembalian buku "${borrow.bookTitle}".'),
            const SizedBox(height: 16),
            if (borrow.fine != null && borrow.fine! > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Buku ini memiliki denda keterlambatan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jumlah denda: ${NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp',
                        decimalDigits: 0,
                      ).format(borrow.fine)}',
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmReturn(context, borrow, true);
            },
            child: const Text('TERIMA TANPA DENDA'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmReturn(context, borrow, false);
            },
            child: const Text('TERIMA DENGAN DENDA'),
          ),
        ],
      ),
    );
  }

  // PERBAIKAN: Gabungkan fungsi _confirmReturn dan _confirmReturnWithFine 
  // menjadi satu fungsi yang menerima parameter waiveFine
  Future<void> _confirmReturn(BuildContext context, BorrowModel borrow, bool waiveFine) async {
    // Tampilkan dialog loading
    setState(() {
      _isProcessing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Memproses pengembalian ${waiveFine ? "tanpa denda" : "dengan denda"}...'),
          ],
        ),
      ),
    );

    try {
      // Proses pengembalian dan tandai buku sebagai dikembalikan langsung
      await ref.read(borrowControllerProvider.notifier).confirmReturn(borrow.id);
      
      if (mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        // Tampilkan snackbar sukses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buku berhasil dikembalikan ${waiveFine ? "tanpa denda" : "dengan denda"}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data
        ref.refresh(overdueBorrowsProvider);
      }
    } catch (e) {
      if (mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        // Tampilkan snackbar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _refreshOverdueStatus(BuildContext context) async {
    // Tampilkan dialog konfirmasi
    final shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perbarui Status Keterlambatan'),
        content: const Text(
          'Ini akan memperbarui status keterlambatan semua buku yang masih dipinjam. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('PERBARUI'),
          ),
        ],
      ),
    );
    
    if (shouldRefresh != true) return;
    
    // Tampilkan dialog loading
    setState(() {
      _isProcessing = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memperbarui status keterlambatan...'),
          ],
        ),
      ),
    );

    try {
      // Perbarui status keterlambatan
      await ref.read(borrowRepositoryProvider).checkOverdueBooks();
      
      if (mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        // Refresh data dahulu
        ref.refresh(overdueBorrowsProvider);
        
        // Tampilkan snackbar sukses
        // Ambil data jumlah buku terlambat setelah refresh
        final overdueBooksAsync = await ref.read(overdueBorrowsProvider.future);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${overdueBooksAsync.length} buku terlambat ditemukan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Tutup dialog loading
        Navigator.pop(context);
        
        // Tampilkan snackbar error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}