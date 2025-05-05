import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../common/widgets/loading_indicator.dart';
import '../model/payment_model.dart';
import '../providers/payment_provider.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final String fineId; // ID of the borrow record
  final double amount;

  const PaymentPage({
    super.key,
    required this.fineId,
    required this.amount,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  PaymentModel? _payment;
  bool _isQrScanning = false;
  int _selectedPaymentMethod = 0; // 0 = QR, 1 = Transfer, 2 = Cash

  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  Future<void> _createPayment() async {
    final payment = await ref
        .read(paymentControllerProvider.notifier)
        .createPayment(widget.fineId, widget.amount);

    if (payment != null) {
      setState(() {
        _payment = payment;
      });
    }
  }

  void _completePayment() async {
    if (_payment == null) return;

    final paymentMethod = _getPaymentMethodName();

    final success = await ref
        .read(paymentControllerProvider.notifier)
        .completePayment(_payment!.id, paymentMethod);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to borrow history
      if (mounted) {
        context.go('/borrow-history');
      }
    }
  }

  void _cancelPayment() async {
    if (_payment == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Pembayaran'),
        content:
            const Text('Apakah Anda yakin ingin membatalkan pembayaran ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('TIDAK'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YA, BATALKAN'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(paymentControllerProvider.notifier)
          .cancelPayment(_payment!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran dibatalkan'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pop(context);
      }
    }
  }

  Future<void> _launchQrPayment() async {
    if (_payment?.paymentQrUrl == null) return;

    final url = Uri.parse(_payment!.paymentQrUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka QR Code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPaymentMethodName() {
    switch (_selectedPaymentMethod) {
      case 0:
        return 'QR Code';
      case 1:
        return 'Transfer Bank';
      case 2:
        return 'Tunai';
      default:
        return 'QR Code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Denda'),
      ),
      body: paymentState.isLoading && _payment == null
          ? const Center(child: LoadingIndicator())
          : _payment == null
              ? _buildErrorState()
              : _buildPaymentForm(),
      bottomNavigationBar: _payment != null ? _buildBottomButtons() : null,
    );
  }

  Widget _buildErrorState() {
    final paymentState = ref.watch(paymentControllerProvider);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Gagal memuat data pembayaran',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (paymentState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Error: ${paymentState.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _createPayment,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment info card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Denda',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        currencyFormat.format(widget.amount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ID Pembayaran'),
                      Text(_payment?.id ?? '-'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ID Peminjaman'),
                      Text(widget.fineId),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Payment method selection
          const Text(
            'Pilih Metode Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Payment method options
          _buildPaymentMethodSelection(),

          const SizedBox(height: 24),

          // Selected payment method details
          _buildSelectedPaymentMethod(),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      children: [
        // QR Code Payment
        RadioListTile(
          value: 0,
          groupValue: _selectedPaymentMethod,
          title: const Text('QR Code (QRIS)'),
          subtitle: const Text(
              'Bayar dengan QR Code via mobile banking atau e-wallet'),
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value as int;
              _isQrScanning = false;
            });
          },
        ),

        // Bank Transfer
        RadioListTile(
          value: 1,
          groupValue: _selectedPaymentMethod,
          title: const Text('Transfer Bank'),
          subtitle: const Text('Bayar dengan transfer bank'),
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value as int;
              _isQrScanning = false;
            });
          },
        ),

        // Cash
        RadioListTile(
          value: 2,
          groupValue: _selectedPaymentMethod,
          title: const Text('Tunai'),
          subtitle: const Text('Bayar langsung ke petugas perpustakaan'),
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value as int;
              _isQrScanning = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSelectedPaymentMethod() {
    switch (_selectedPaymentMethod) {
      case 0: // QR Code
        return _buildQrCodePayment();
      case 1: // Transfer Bank
        return _buildBankTransferPayment();
      case 2: // Cash
        return _buildCashPayment();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQrCodePayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pembayaran QR Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // QR Code Image or Scanner
        if (_isQrScanning)
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: MobileScannerController(),
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && mounted) {
                    setState(() {
                      _isQrScanning = false;
                    });

                    // In a real app, verify the QR code with the server
                    // For this demo, we'll just show a success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('QR Code berhasil dipindai'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
          )
        else
          Center(
            child: Column(
              children: [
                // QR Code display
                if (_payment?.paymentQrUrl != null)
                  GestureDetector(
                    onTap: _launchQrPayment,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.network(
                          _payment!.paymentQrUrl!,
                          height: 200,
                          width: 200,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              width: 200,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.qr_code,
                                size: 80,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                const Text(
                  'Scan QR Code ini dengan aplikasi mobile banking atau e-wallet Anda',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isQrScanning = true;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code Pembayaran'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBankTransferPayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer Bank',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Bank account info
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Rekening Bank',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBankInfo('Bank BNI', '1234567890', 'Perpustakaan GLO'),
                const Divider(height: 24),
                _buildBankInfo('Bank BRI', '9876543210', 'Perpustakaan GLO'),
                const Divider(height: 24),
                _buildBankInfo(
                    'Bank Mandiri', '5432167890', 'Perpustakaan GLO'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'Silakan transfer sesuai jumlah denda. Setelah transfer, tekan tombol "Konfirmasi Pembayaran" untuk menyelesaikan proses pembayaran.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBankInfo(
      String bankName, String accountNumber, String accountName) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bankName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(accountNumber),
            const SizedBox(height: 4),
            Text(accountName),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            // Copy to clipboard functionality
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Nomor rekening $bankName disalin'),
              ),
            );
          },
          tooltip: 'Salin nomor rekening',
        ),
      ],
    );
  }

  Widget _buildCashPayment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pembayaran Tunai',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pembayaran Tunai',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Silakan lakukan pembayaran tunai di meja petugas perpustakaan. Setelah membayar, petugas akan memperbarui status pembayaran Anda.',
              ),
              const SizedBox(height: 16),
              Text(
                'Total yang harus dibayar: ${currencyFormat.format(widget.amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    final paymentState = ref.watch(paymentControllerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: paymentState.isLoading ? null : _cancelPayment,
              child: const Text('BATALKAN'),
            ),
          ),

          const SizedBox(width: 16),

          // Confirm payment button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: paymentState.isLoading ? null : _completePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: paymentState.isLoading
                  ? const LoadingIndicator(color: Colors.white)
                  : const Text('KONFIRMASI PEMBAYARAN'),
            ),
          ),
        ],
      ),
    );
  }
}
