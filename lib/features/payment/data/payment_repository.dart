import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../model/payment_model.dart';
import '../../borrow/data/borrow_repository.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final FirebaseAuth _auth = FirebaseService.auth;
  final BorrowRepository _borrowRepository;
  
  PaymentRepository(this._borrowRepository);
  
  // Collection references
  CollectionReference get _paymentsRef => _firestore.collection('payments');
  CollectionReference get _usersRef => _firestore.collection('users');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Create a new payment
  Future<PaymentModel> createPayment(String borrowId, double amount) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User tidak ditemukan');
    }
    
    // Create payment document ID
    final paymentId = _paymentsRef.doc().id;
    
    // Create fake QR code URL (in real app would be generated from payment gateway)
    // For demo purposes, we'll use a static QR URL
    final paymentQrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=PAYMENT:$paymentId:$amount';
    
    final payment = PaymentModel(
      id: paymentId,
      userId: userId,
      borrowId: borrowId,
      amount: amount,
      status: PaymentStatus.pending,
      createdAt: DateTime.now(),
      paymentQrUrl: paymentQrUrl,
    );
    
    // Save to Firestore
    await _paymentsRef.doc(paymentId).set(payment.toJson());
    
    return payment;
  }
  
  // Get payment by ID
  Future<PaymentModel?> getPaymentById(String paymentId) async {
    final doc = await _paymentsRef.doc(paymentId).get();
    
    if (!doc.exists) return null;
    
    return PaymentModel.fromJson({
      'id': doc.id,
      ...doc.data() as Map<String, dynamic>,
    });
  }
  
  // Get user's payment history
  Stream<List<PaymentModel>> getUserPayments() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }
    
    return _paymentsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return PaymentModel.fromJson({
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            });
          }).toList();
        });
  }
  
  // Update payment status
  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status, {String? paymentMethod}) async {
    final data = <String, dynamic>{
      'status': status.toString().split('.').last,
    };
    
    if (status == PaymentStatus.completed) {
      data['completedAt'] = FieldValue.serverTimestamp();
    }
    
    if (paymentMethod != null) {
      data['paymentMethod'] = paymentMethod;
    }
    
    await _paymentsRef.doc(paymentId).update(data);
  }
  
  // Complete payment
  Future<void> completePayment(String paymentId, String paymentMethod) async {
    // Get payment details
    final payment = await getPaymentById(paymentId);
    if (payment == null) {
      throw Exception('Data pembayaran tidak ditemukan');
    }
    
    // Transaction to update payment status and handle fine
    await _firestore.runTransaction((transaction) async {
      // 1. Update payment status to completed
      transaction.update(_paymentsRef.doc(paymentId), {
        'status': PaymentStatus.completed.toString().split('.').last,
        'completedAt': FieldValue.serverTimestamp(),
        'paymentMethod': paymentMethod,
      });
      
      // 2. Mark borrow fine as paid
      await _borrowRepository.markFineAsPaid(payment.borrowId);
      
      // 3. Update user's fine amount
      final userDoc = await transaction.get(_usersRef.doc(payment.userId));
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final currentFine = (userData['fineAmount'] as num?)?.toDouble() ?? 0.0;
        
        // Only reduce if there's an actual fine
        if (currentFine > 0) {
          transaction.update(_usersRef.doc(payment.userId), {
            'fineAmount': currentFine - payment.amount <= 0 ? 0 : currentFine - payment.amount,
          });
        }
      }
    });
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final borrowRepository = ref.watch(borrowRepositoryProvider);
  return PaymentRepository(borrowRepository);
});