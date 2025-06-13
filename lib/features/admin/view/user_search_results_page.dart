import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../../../common/widgets/empty_state.dart';
import '../../profile/model/user_profile_model.dart';
import '../../profile/providers/admin_provider.dart';

class UserSearchResultsPage extends ConsumerWidget {
  final String query;

  const UserSearchResultsPage({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchUsersProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hasil Pencarian: $query'),
      ),
      body: searchResultsAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: 'Tidak Ada Hasil',
              message: 'Tidak ditemukan pengguna dengan kata kunci "$query"',
              actionLabel: 'Cari Lagi',
              onActionPressed: () => _showSearchDialog(context, ref),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserItem(context, user);
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, _) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSearchDialog(context, ref),
        child: const Icon(Icons.search),
      ),
    );
  }

  Widget _buildUserItem(BuildContext context, UserProfileModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/users/${user.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 30,
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        _getInitials(user.name),
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        user.roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.push('/admin/users/${user.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();
    searchController.text = query;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari Pengguna'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Masukkan nama atau email',
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
              final newQuery = searchController.text.trim();
              if (newQuery.isNotEmpty) {
                Navigator.pop(context);
                // Navigate to search results with new query
                context.push('/admin/users/search/$newQuery');
              }
            },
            child: const Text('CARI'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
}