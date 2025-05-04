import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../model/book_model.dart';
import '../providers/book_provider.dart';
import '../../auth/providers/auth_provider.dart';

class BookDetailPage extends ConsumerWidget {
  final String bookId;
  
  const BookDetailPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookByIdProvider(bookId));
    final borrowState = ref.watch(borrowControllerProvider);
    final userAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Buku'),
      ),
      body: bookAsync.when(
        data: (book) {
          if (book == null) {
            return const Center(
              child: Text('Buku tidak ditemukan'),
            );
          }
          
          return _buildBookDetail(context, ref, book);
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
      bottomNavigationBar: bookAsync.when(
        data: (book) {
          if (book == null) return const SizedBox.shrink();
          
          return userAsync.when(
            data: (user) {
              final bool isBookBorrowed = user?.borrowedBooks.contains(bookId) ?? false;
              
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: borrowState.isLoading || !book.isAvailable && !isBookBorrowed
                      ? null
                      : () async {
                          if (isBookBorrowed) {
                            await ref.read(borrowControllerProvider.notifier).returnBook(bookId);
                          } else {
                            await ref.read(borrowControllerProvider.notifier).borrowBook(bookId);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBookBorrowed ? Colors.orange : Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: borrowState.isLoading
                      ? const LoadingIndicator(color: Colors.white)
                      : Text(
                          isBookBorrowed ? 'KEMBALIKAN BUKU' : 'PINJAM BUKU',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              );
            },
            loading: () => const SizedBox(height: 80, child: Center(child: LoadingIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
  
  Widget _buildBookDetail(BuildContext context, WidgetRef ref, BookModel book) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final borrowState = ref.watch(borrowControllerProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book Cover and Basic Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  book.coverUrl,
                  width: 120,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 180,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Book info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'by ${book.author}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.category,
                      'Kategori',
                      book.category,
                    ),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Tanggal terbit',
                      dateFormat.format(book.publishedDate),
                    ),
                    _buildInfoRow(
                      Icons.book,
                      'Ketersediaan',
                      '${book.availableStock} / ${book.totalStock}',
                      iconColor: book.isAvailable ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Description section
          const Text(
            'Deskripsi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Error message if any
          if (borrowState.hasError)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: ${borrowState.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor ?? Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}