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
// import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/services/firebase_service.dart';

class AddEditBookPage extends ConsumerStatefulWidget {
  final String? bookId;

  const AddEditBookPage({super.key, this.bookId});

  @override
  ConsumerState<AddEditBookPage> createState() => _AddEditBookPageState();
}

class _AddEditBookPageState extends ConsumerState<AddEditBookPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = '';
  final _totalStockController = TextEditingController();
  DateTime _publishedDate = DateTime.now();
  final _coverUrlController =
      TextEditingController(); // Tambahkan controller untuk URL cover
  File? _imageFile;
  String? _existingImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.bookId != null) {
      _loadBookData();
    }
  }

  Future<void> _loadBookData() async {
    setState(() {
      _isLoading = true;
    });

    final bookAsync = await ref.read(bookByIdProvider(widget.bookId!).future);

    if (bookAsync != null) {
      _titleController.text = bookAsync.title;
      _authorController.text = bookAsync.author;
      _descriptionController.text = bookAsync.description;
      _selectedCategory = bookAsync.category;
      _totalStockController.text = bookAsync.totalStock.toString();
      _publishedDate = bookAsync.publishedDate;
      _existingImageUrl = bookAsync.coverUrl;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _totalStockController.dispose();
    _coverUrlController.dispose();
    _imageFile = null; // Reset image file on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bookId != null;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Buku' : 'Tambah Buku'),
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover image
                    Center(
                      child: _buildImagePicker(),
                    ),

                    const SizedBox(height: 24),

                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Buku',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Judul buku tidak boleh kosong';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Author field
                    TextFormField(
                      controller: _authorController,
                      decoration: const InputDecoration(
                        labelText: 'Penulis',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Penulis tidak boleh kosong';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Deskripsi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Category dropdown
                    categoriesAsync.when(
                      data: (categories) {
                        if (_selectedCategory.isEmpty &&
                            categories.isNotEmpty) {
                          _selectedCategory = categories.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                          ),
                          value:
                              categories.any((c) => c.name == _selectedCategory)
                                  ? _selectedCategory
                                  : (categories.isNotEmpty
                                      ? categories.first.name
                                      : null),
                          items: categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category.name,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kategori tidak boleh kosong';
                            }
                            return null;
                          },
                        );
                      },
                      loading: () => const LoadingIndicator(),
                      error: (error, _) => Text('Error: $error'),
                    ),

                    const SizedBox(height: 16),

                    // Published date picker
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Terbit',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy')
                                .format(_publishedDate)),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stock field
                    TextFormField(
                      controller: _totalStockController,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Stok',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Jumlah stok tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Jumlah stok harus berupa angka positif';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveBook,
                        child: Text(
                            isEditing ? 'SIMPAN PERUBAHAN' : 'TAMBAH BUKU'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _imageFile != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showImageSourceOptions(),
          child: Container(
            width: 200,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: hasImage
                  ? DecorationImage(
                      image: _imageFile != null
                          ? FileImage(_imageFile!) as ImageProvider
                          : NetworkImage(_existingImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasImage
                ? null
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 50,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tambahkan Cover',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _imageFile = null;
                _existingImageUrl = null;
              });
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text(
              'Hapus Cover',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Masukkan URL Gambar'),
              onTap: () {
                Navigator.pop(context);
                _showUrlInputDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _publishedDate = picked;
      });
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isEditing = widget.bookId != null;
    String coverUrl = _existingImageUrl ?? '';

    // Show loading
    setState(() {
      _isLoading = true;
    });

    // Upload image if selected
    if (_imageFile != null) {
      try {
        final storageRef = FirebaseService.storage
            .ref()
            .child('book_covers/${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(_imageFile!);

        coverUrl = await uploadTask.ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }
    // Use existing URL if entered via dialog
    else if (_coverUrlController.text.isNotEmpty) {
      coverUrl = _coverUrlController.text;
    }

    // Create or update book
    try {
      final totalStock = int.parse(_totalStockController.text);

      // Ambil availableStock dari buku yang ada untuk edit
      int availableStock = totalStock;
      if (isEditing) {
        final existingBook = ref.read(bookByIdProvider(widget.bookId!)).value;
        if (existingBook != null) {
          // Jika total stock berubah, sesuaikan available stock
          if (existingBook.totalStock != totalStock) {
            final stockDiff = totalStock - existingBook.totalStock;
            availableStock = existingBook.availableStock + stockDiff;
            if (availableStock < 0) availableStock = 0;
          } else {
            availableStock = existingBook.availableStock;
          }
        }
      }

      final book = BookModel(
        id: widget.bookId.toString(), // Set id hanya jika editing
        title: _titleController.text,
        author: _authorController.text,
        coverUrl: coverUrl,
        description: _descriptionController.text,
        category: _selectedCategory,
        totalStock: totalStock,
        availableStock: availableStock,
        publishedDate: _publishedDate,
      );

      bool success;
      if (isEditing) {
        success = await ref
            .read(bookControllerProvider.notifier)
            .updateBook(widget.bookId!, book);
      } else {
        success = await ref.read(bookControllerProvider.notifier).addBook(book);
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Buku berhasil diperbarui'
                : 'Buku berhasil ditambahkan'),
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Gagal memperbarui buku'
                : 'Gagal menambahkan buku'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Di file add_edit_book_page.dart, tambahkan metode untuk menampilkan dialog input URL
  Future<void> _showUrlInputDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambahkan URL Cover'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _coverUrlController,
              decoration: const InputDecoration(
                labelText: 'URL Gambar',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            if (_coverUrlController.text.isNotEmpty)
              SizedBox(
                height: 100,
                child: Image.network(
                  _coverUrlController.text,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.red),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
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
              if (_coverUrlController.text.isNotEmpty) {
                setState(() {
                  _existingImageUrl = _coverUrlController.text;
                  _imageFile = null; // Reset file picker selection
                });
              }
              Navigator.pop(context);
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }
}
