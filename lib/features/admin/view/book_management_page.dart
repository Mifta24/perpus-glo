import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../../books/model/book_model.dart';
import '../../books/providers/book_provider.dart';
import '../../categories/providers/category_provider.dart';
import 'add_edit_book_page.dart';

class BookManagementPage extends ConsumerWidget {
  const BookManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Buku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/books/add'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Buku'),
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Text('Tidak ada buku yang tersedia'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookItem(context, ref, book);
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, _) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }

  Widget _buildBookItem(BuildContext context, WidgetRef ref, BookModel book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Dismissible(
        key: Key(book.id ?? ''),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmDialog(context, book);
        },
        onDismissed: (direction) {
          _deleteBook(context, ref, book.id!);
        },
        child: InkWell(
          onTap: () => context.push('/admin/books/edit/${book.id}'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: book.coverUrl.isNotEmpty
                    ? Image.network(
                        book.coverUrl,
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.book),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            book.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.book,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stok: ${book.availableStock}/${book.totalStock}',
                            style: TextStyle(
                              fontSize: 12,
                              color: book.isAvailable ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Terbit: ${DateFormat('dd/MM/yyyy').format(book.publishedDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.push('/admin/books/edit/${book.id}'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context, BookModel book) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Buku'),
        content: Text('Apakah Anda yakin ingin menghapus buku "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  void _deleteBook(BuildContext context, WidgetRef ref, String bookId) {
    ref.read(bookControllerProvider.notifier).deleteBook(bookId).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buku berhasil dihapus')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus buku')),
        );
      }
    });
  }

  void _showFilterOptions(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Buku Berdasarkan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  data: (categories) {
                    return categories.isEmpty
                        ? const Text('Tidak ada kategori')
                        : SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(category.name),
                                    selected: false,
                                    onSelected: (selected) {
                                      Navigator.pop(context);
                                      // TODO: Implement category filtering
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (error, _) => Text('Error: ${error.toString()}'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ketersediaan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Tersedia'),
                      selected: false,
                      onSelected: (selected) {
                        Navigator.pop(context);
                        // TODO: Implement availability filtering
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Tidak Tersedia'),
                      selected: false,
                      onSelected: (selected) {
                        Navigator.pop(context);
                        // TODO: Implement availability filtering
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari Buku'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Masukkan judul atau penulis',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () {
              final query = searchController.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(context);
                // Navigate to search results
                context.push('/admin/books/search/$query');
              }
            },
            child: const Text('CARI'),
          ),
        ],
      ),
    );
  }
}