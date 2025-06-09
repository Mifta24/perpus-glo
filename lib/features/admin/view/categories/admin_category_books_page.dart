// Buat file ini jika belum ada

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/widgets/loading_indicator.dart';
import '../../../../common/widgets/empty_state.dart';
import '../../../categories/providers/category_provider.dart';
import '../../../books/providers/book_provider.dart';
import '../../../books/model/book_model.dart';

class AdminCategoryBooksPage extends ConsumerWidget {
  final String categoryId;

  const AdminCategoryBooksPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(categoryByIdProvider(categoryId));
    final booksAsync = ref.watch(booksByCategoryProvider(categoryId));

    return Scaffold(
      appBar: AppBar(
        title: categoryAsync.when(
          data: (category) => Text('Buku Kategori: ${category?.name ?? ""}'),
          loading: () => const Text('Memuat...'),
          error: (_, __) => const Text('Kategori'),
        ),
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.book_outlined,
              title: 'Belum Ada Buku',
              message: 'Belum ada buku dalam kategori ini',
              actionLabel: 'Tambah Buku',
              onActionPressed: () => context.push('/admin/books/add'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookItem(context, book);
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/books/add', 
          extra: {'categoryId': categoryId}),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBookItem(BuildContext context, BookModel book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: book.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book.coverUrl!,
                width: 50,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 50,
                  height: 70,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, color: Colors.grey),
                ),
              ),
            )
          : Container(
              width: 50,
              height: 70,
              color: Colors.grey[300],
              child: const Icon(Icons.book, color: Colors.grey),
            ),
        title: Text(book.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.author != null && book.author!.isNotEmpty)
              Text(book.author!),
            Text(
              'Stok: ${book.availableStock ?? 0} / ${book.totalStock ?? 0}',
              style: TextStyle(
                color: (book.availableStock ?? 0) > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.push('/admin/books/${book.id}/edit'),
        ),
        onTap: () => context.push('/books/${book.id}'),
      ),
    );
  }
}