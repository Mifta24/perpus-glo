import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../model/borrow_model.dart';
import '../providers/borrow_provider.dart';
import 'borrow_detail_page.dart';

class BorrowHistoryPage extends ConsumerStatefulWidget {
  const BorrowHistoryPage({super.key});

  @override
  ConsumerState<BorrowHistoryPage> createState() => _BorrowHistoryPageState();
}

class _BorrowHistoryPageState extends ConsumerState<BorrowHistoryPage> {
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final borrowsAsync = ref.watch(userBorrowHistoryProvider);
    final selectedFilter = ref.watch(borrowFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Peminjaman'),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: borrowsAsync.when(
              data: (borrows) {
                if (borrows.isEmpty) {
                  return const Center(
                    child: Text('Belum ada riwayat peminjaman'),
                  );
                }

                // Filter borrows if filter is selected
                final filteredBorrows = selectedFilter != null
                    ? borrows.where((b) => b.status == selectedFilter).toList()
                    : borrows;

                if (filteredBorrows.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada peminjaman dengan status ${selectedFilter?.name ?? ""}',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBorrows.length,
                  itemBuilder: (context, index) {
                    return _buildBorrowItem(filteredBorrows[index]);
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

  Widget _buildFilterChips() {
    return SizedBox(
      height: 60,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // All filter
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: const Text('Semua'),
              selected: ref.watch(borrowFilterProvider) == null,
              onSelected: (selected) {
                if (selected) {
                  ref.read(borrowFilterProvider.notifier).state = null;
                }
              },
            ),
          ),

          // Status filters
          ...BorrowStatus.values.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(status.name),
                selected: ref.watch(borrowFilterProvider) == status,
                labelStyle: TextStyle(
                  color: ref.watch(borrowFilterProvider) == status
                      ? Colors.white
                      : null,
                ),
                backgroundColor: status.color.withOpacity(0.1),
                selectedColor: status.color,
                onSelected: (selected) {
                  ref.read(borrowFilterProvider.notifier).state =
                      selected ? status : null;
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBorrowItem(BorrowModel borrow) {
    final bool isOverdue = borrow.status == BorrowStatus.overdue;
    final bool isPending = borrow.status == BorrowStatus.pending;
    final bool hasReturned = borrow.returnDate != null;
    final bool needsPayment =
        borrow.fine != null && borrow.fine! > 0 && !borrow.isPaid;

    // Cek jika terlambat (borrow date + 7 hari < now)
    final bool isLate = DateTime.now().difference(borrow.borrowDate).inDays > 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BorrowDetailPage(borrowId: borrow.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Container(
              color: borrow.status.color,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                borrow.status.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tombol kembalikan hanya muncul jika:
                  // 1. Belum dikembalikan
                  // 2. Status bukan pending
                  if (!hasReturned && !isPending)
                    ElevatedButton(
                      onPressed: () {
                        _showReturnConfirmation(borrow.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text('KEMBALIKAN BUKU'),
                    ),

                  // Tombol bayar denda muncul jika:
                  // 1. Ada denda
                  // 2. Belum dibayar
                  if (needsPayment)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          _showPaymentDialog(borrow.id, borrow.fine!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size.fromHeight(40),
                        ),
                        child: const Text('BAYAR DENDA'),
                      ),
                    ),

                  // Peringatan keterlambatan
                  if (isLate && !hasReturned && !isPending && !isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Sudah ${DateTime.now().difference(borrow.borrowDate).inDays} hari dipinjam, harap segera dikembalikan untuk menghindari denda.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  // Info jika status pending
                  if (isPending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Permintaan peminjaman sedang menunggu konfirmasi pustakawan.',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontSize: 12,
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
    );
  }

  // Tambahkan method untuk menampilkan dialog pembayaran denda
  void _showPaymentDialog(String borrowId, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bayar Denda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jumlah denda: Rp ${amount.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            const Text('Pilih metode pembayaran:'),
            const SizedBox(height: 8),
            _buildPaymentMethodButton(
              icon: Icons.account_balance_wallet,
              title: 'E-Wallet',
              onTap: () => _processPayment(borrowId, 'e-wallet'),
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodButton(
              icon: Icons.credit_card,
              title: 'Kartu Kredit/Debit',
              onTap: () => _processPayment(borrowId, 'card'),
            ),
            const SizedBox(height: 8),
            _buildPaymentMethodButton(
              icon: Icons.person,
              title: 'Bayar di Perpustakaan',
              onTap: () => _processPayment(borrowId, 'onsite'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATALKAN'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(String borrowId, String method) async {
    Navigator.pop(context); // Close payment dialog

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicator(),
            SizedBox(height: 16),
            Text('Memproses pembayaran...'),
          ],
        ),
      ),
    );

    try {
      // Process payment
      final success = await ref
          .read(borrowControllerProvider.notifier)
          .payFine(borrowId, method);

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran berhasil diproses'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memproses pembayaran'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReturnConfirmation(String borrowId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kembalikan Buku'),
        content: const Text('Apakah Anda yakin ingin mengembalikan buku ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATALKAN'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ref
                  .read(borrowControllerProvider.notifier)
                  .returnBook(borrowId);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Buku berhasil dikembalikan'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('YA, KEMBALIKAN'),
          ),
        ],
      ),
    );
  }
}
