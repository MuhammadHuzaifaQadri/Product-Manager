import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  // Payment methods available
  static const String STRIPE = 'stripe';
  static const String RAZORPAY = 'razorpay';
  static const String CASH = 'cash';
  
  // Payment status
  static const String PENDING = 'pending';
  static const String SUCCESS = 'success';
  static const String FAILED = 'failed';

  // Process payment
  static Future<Map<String, dynamic>> processPayment({
    required BuildContext context,
    required double amount,
    required String method,
    required String productId,
    String? productName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Please login to continue',
        };
      }

      // Create payment record
      final paymentData = {
        'userId': user.uid,
        'userEmail': user.email,
        'amount': amount,
        'method': method,
        'productId': productId,
        'productName': productName,
        'status': PENDING,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .add(paymentData);

      // Process based on method
      Map<String, dynamic> result;
      
      switch (method) {
        case STRIPE:
          result = await _processStripePayment(context, amount, paymentDoc.id);
          break;
        case RAZORPAY:
          result = await _processRazorpayPayment(context, amount, paymentDoc.id);
          break;
        case CASH:
          result = await _processCashPayment(context, amount, paymentDoc.id);
          break;
        default:
          result = {
            'success': false,
            'message': 'Invalid payment method',
          };
      }

      // Update payment status
      await paymentDoc.update({
        'status': result['success'] ? SUCCESS : FAILED,
        'completedAt': FieldValue.serverTimestamp(),
        'transactionId': result['transactionId'],
        'message': result['message'],
      });

      return result;
    } catch (e) {
      print('Payment error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Stripe payment (Demo - needs Stripe SDK)
  static Future<Map<String, dynamic>> _processStripePayment(
    BuildContext context,
    double amount,
    String paymentId,
  ) async {
    // For demo purposes - actual Stripe integration would go here
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate success
    return {
      'success': true,
      'message': 'Payment successful via Stripe',
      'transactionId': 'stripe_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // Razorpay payment (Demo - needs Razorpay SDK)
  static Future<Map<String, dynamic>> _processRazorpayPayment(
    BuildContext context,
    double amount,
    String paymentId,
  ) async {
    // For demo purposes - actual Razorpay integration would go here
    await Future.delayed(const Duration(seconds: 2));
    
    // Simulate success
    return {
      'success': true,
      'message': 'Payment successful via Razorpay',
      'transactionId': 'razorpay_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // Cash payment (On delivery)
  static Future<Map<String, dynamic>> _processCashPayment(
    BuildContext context,
    double amount,
    String paymentId,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    
    return {
      'success': true,
      'message': 'Cash on delivery confirmed',
      'transactionId': 'cash_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // Show payment dialog
  static Future<bool> showPaymentDialog({
    required BuildContext context,
    required String productId,
    required String productName,
    required double price,
  }) async {
    String selectedMethod = CASH;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payment, color: Colors.blue),
              SizedBox(width: 8),
              Text('Payment'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price:'),
                        Text(
                          '\$$price',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment methods
              const Text(
                'Select Payment Method:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Cash on Delivery
              RadioListTile<String>(
                value: CASH,
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() => selectedMethod = value!);
                },
                title: const Text('Cash on Delivery'),
                subtitle: const Text('Pay when you receive'),
                secondary: const Icon(Icons.money, color: Colors.green),
              ),

              // Stripe
              RadioListTile<String>(
                value: STRIPE,
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() => selectedMethod = value!);
                },
                title: const Text('Credit/Debit Card'),
                subtitle: const Text('Pay via Stripe'),
                secondary: const Icon(Icons.credit_card, color: Colors.blue),
              ),

              // Razorpay
              RadioListTile<String>(
                value: RAZORPAY,
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() => selectedMethod = value!);
                },
                title: const Text('UPI / Wallet'),
                subtitle: const Text('Pay via Razorpay'),
                secondary: const Icon(Icons.account_balance_wallet, color: Colors.purple),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context, true);
                
                // Show processing dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing payment...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Process payment
                final result = await processPayment(
                  context: context,
                  amount: price,
                  method: selectedMethod,
                  productId: productId,
                  productName: productName,
                );

                // Close processing dialog
                if (context.mounted) {
                  Navigator.pop(context);
                }

                // Show result
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(
                            result['success'] ? Icons.check_circle : Icons.error,
                            color: result['success'] ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(result['success'] ? 'Success!' : 'Failed'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result['message']),
                          if (result['transactionId'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Transaction ID: ${result['transactionId']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.payment),
              label: const Text('Pay Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  // Get payment history
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }
}