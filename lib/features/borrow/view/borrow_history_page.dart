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
                  ref.read(borrowFilterProvider.notifier).state = selected ? status : null;
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
    final bool hasReturned = borrow.returnDate != null;
    
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
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: borrow.bookCover != null
                        ? Image.network(
                            borrow.bookCover!,
                            width: 60,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.book),
                              );
                            },
                          )
                        : Container(
                            width: 60,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.book),
                          ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Book details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          borrow.bookTitle ?? 'Judul tidak tersedia',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Borrow date
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              'Dipinjam: ${dateFormat.format(borrow.borrowDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Due date
                        Row(
                          children: [
                            Icon(
                              Icons.event, 
                              size: 14,
                              color: isOverdue && !hasReturned ? Colors.red : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tenggat: ${dateFormat.format(borrow.dueDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverdue && !hasReturned ? Colors.red : null,
                                fontWeight: isOverdue && !hasReturned ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                        
                        // Return date if returned
                        if (hasReturned) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle, 
                                size: 14,
                                color: isOverdue ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dikembalikan: ${dateFormat.format(borrow.returnDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue ? Colors.orange : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Fine if any
                        if (borrow.fine != null && borrow.fine! > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on, 
                                size: 14,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Denda: Rp ${borrow.fine!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: borrow.isPaid ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (borrow.isPaid)
                                const Text(
                                  '(Lunas)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                  ),
                                )
                              else
                                const Text(
                                  '(Belum dibayar)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            if (!hasReturned)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  onPressed: () {
                    _showReturnConfirmation(borrow.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text('KEMBALIKAN BUKU'),
                ),
              ),
          ],
        ),
      ),
    );
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
              
              final success = await ref.read(borrowControllerProvider.notifier)
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