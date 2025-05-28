import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/category_repository.dart';
import '../model/category_model.dart';

// Provider for all categories
final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getAllCategories();
});

// Provider for popular categories (with most books)
final popularCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoriesWithBookCount();
});

// Provider for a specific category
final categoryProvider =
    StreamProvider.family<CategoryModel?, String>((ref, categoryId) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoryById(categoryId);
});

// Provider for categories count
final categoriesCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoriesCount();
});

// Controller for category actions
class CategoryController extends StateNotifier<AsyncValue<void>> {
  final CategoryRepository _repository;

  CategoryController(this._repository) : super(const AsyncValue.data(null));

  Future<void> addCategory(CategoryModel category) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addCategory(category);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateCategory(category);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteCategory(categoryId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> initializeDefaultCategories() async {
    state = const AsyncValue.loading();
    try {
      await _repository.initializeDefaultCategoriesIfNeeded();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// Provider for CategoryController
final categoryControllerProvider =
    StateNotifierProvider<CategoryController, AsyncValue<void>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryController(repository);
});
