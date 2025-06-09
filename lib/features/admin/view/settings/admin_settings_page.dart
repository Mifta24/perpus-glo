import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/widgets/loading_indicator.dart';
// import '../../../settings/providers/settings_provider.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _maxBooksPerUserController = TextEditingController();
  final _borrowDurationController = TextEditingController();
  final _finePerDayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _maxBooksPerUserController.dispose();
    _borrowDurationController.dispose();
    _finePerDayController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    final settings = ref.read(appSettingsProvider).value;
    if (settings != null) {
      _maxBooksPerUserController.text = settings.maxBooksPerUser.toString();
      _borrowDurationController.text = settings.borrowDurationDays.toString();
      _finePerDayController.text = settings.fineAmountPerDay.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Perpustakaan'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null) {
            return const Center(
              child: Text('Gagal memuat pengaturan'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pengaturan Peminjaman',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Max books per user
                          TextFormField(
                            controller: _maxBooksPerUserController,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah Maksimum Buku per Pengguna',
                              hintText: 'Masukkan jumlah maksimum',
                              helperText: 'Jumlah maksimum buku yang dapat dipinjam oleh satu pengguna',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Tidak boleh kosong';
                              }
                              final number = int.tryParse(value);
                              if (number == null || number <= 0) {
                                return 'Masukkan angka positif';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Borrow duration days
                          TextFormField(
                            controller: _borrowDurationController,
                            decoration: const InputDecoration(
                              labelText: 'Durasi Peminjaman (hari)',
                              hintText: 'Masukkan jumlah hari',
                              helperText: 'Durasi standar untuk peminjaman buku',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Tidak boleh kosong';
                              }
                              final number = int.tryParse(value);
                              if (number == null || number <= 0) {
                                return 'Masukkan angka positif';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pengaturan Denda',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Fine amount per day
                          TextFormField(
                            controller: _finePerDayController,
                            decoration: const InputDecoration(
                              labelText: 'Denda per Hari (Rp)',
                              hintText: 'Masukkan jumlah denda',
                              helperText: 'Jumlah denda yang dikenakan untuk setiap hari keterlambatan',
                              prefixText: 'Rp ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Tidak boleh kosong';
                              }
                              final number = int.tryParse(value);
                              if (number == null || number < 0) {
                                return 'Masukkan angka valid';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pengaturan Notifikasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Notification settings
                          SwitchListTile(
                            title: const Text('Notifikasi Jatuh Tempo'),
                            subtitle: const Text('Kirim pengingat untuk buku yang akan jatuh tempo'),
                            value: settings.enableDueDateReminders,
                            onChanged: (value) {
                              ref.read(settingsControllerProvider.notifier).updateSettings(
                                enableDueDateReminders: value,
                              );
                            },
                          ),
                          
                          SwitchListTile(
                            title: const Text('Notifikasi Keterlambatan'),
                            subtitle: const Text('Kirim notifikasi untuk buku yang terlambat dikembalikan'),
                            value: settings.enableOverdueNotifications,
                            onChanged: (value) {
                              ref.read(settingsControllerProvider.notifier).updateSettings(
                                enableOverdueNotifications: value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('SIMPAN PENGATURAN'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reset to default button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetToDefault,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('RESET KE DEFAULT'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final maxBooksPerUser = int.parse(_maxBooksPerUserController.text);
      final borrowDurationDays = int.parse(_borrowDurationController.text);
      final fineAmountPerDay = double.parse(_finePerDayController.text);

      ref.read(settingsControllerProvider.notifier).updateSettings(
        maxBooksPerUser: maxBooksPerUser,
        borrowDurationDays: borrowDurationDays, 
        fineAmountPerDay: fineAmountPerDay,
      ).then(
        (success) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pengaturan berhasil disimpan')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan pengaturan')),
            );
          }
        },
      );
    }
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Pengaturan'),
        content: const Text('Apakah Anda yakin ingin mengatur ulang semua pengaturan ke nilai default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(settingsControllerProvider.notifier).resetToDefault().then(
                (success) {
                  if (success) {
                    // Update text fields with default values
                    _loadSettings();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengaturan berhasil direset ke default')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal mereset pengaturan')),
                    );
                  }
                },
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }
}