import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  // ============ NEW ORDER NOTIFICATION ============
  static Future<void> newOrderNotification(
    String productTitle, 
    int quantity, 
    double total,
    String orderId,
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '🛒 New Order',
          'body': '$productTitle x$quantity = \$${total.toStringAsFixed(2)}',
          'type': 'order',
          'orderId': orderId,
          'productTitle': productTitle,
          'quantity': quantity,
          'total': total,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ New order notification sent');
    } catch (e) {
      print('Error sending new order notification: $e');
    }
  }

  // ============ LOW STOCK NOTIFICATION ============
  static Future<void> sendLowStockNotification(
    String productTitle, 
    int stock, 
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '⚠️ Low Stock Alert',
          'body': '$productTitle is running low! Only $stock left.',
          'type': 'low_stock',
          'productTitle': productTitle,
          'stock': stock,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Low stock notification sent');
    } catch (e) {
      print('Error sending low stock notification: $e');
    }
  }

  // ============ OUT OF STOCK NOTIFICATION ============
  static Future<void> outOfStockAlert(
    String productTitle, 
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '❌ Out of Stock',
          'body': '$productTitle is now out of stock!',
          'type': 'out_of_stock',
          'productTitle': productTitle,
          'stock': 0,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Out of stock notification sent');
    } catch (e) {
      print('Error sending out of stock notification: $e');
    }
  }

  // ============ PRICE CHANGE NOTIFICATION ============
  static Future<void> priceChangeAlert(
    String productTitle, 
    String oldPrice, 
    String newPrice, 
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '💰 Price Updated',
          'body': '$productTitle price changed from \$$oldPrice to \$$newPrice',
          'type': 'price_change',
          'productTitle': productTitle,
          'oldPrice': oldPrice,
          'newPrice': newPrice,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Price change notification sent');
    } catch (e) {
      print('Error sending price change notification: $e');
    }
  }

  // ============ RESTOOK NOTIFICATION ============
  static Future<void> sendRestockNotification(
    String productTitle, 
    int newStock, 
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '📦 Product Restocked',
          'body': '$productTitle is now back in stock! Available: $newStock',
          'type': 'restock',
          'productTitle': productTitle,
          'stock': newStock,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Restock notification sent');
    } catch (e) {
      print('Error sending restock notification: $e');
    }
  }

  // ============ PRODUCT ADDED NOTIFICATION (NEW) ============
  static Future<void> sendProductAddedNotification(
    String productTitle,
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '➕ New Product Added',
          'body': '$productTitle has been added to inventory',
          'type': 'product_added',
          'productTitle': productTitle,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Product added notification sent');
    } catch (e) {
      print('Error sending product added notification: $e');
    }
  }

  // ============ PRODUCT DELETED NOTIFICATION (NEW) ============
  static Future<void> sendProductDeletedNotification(
    String productTitle,
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '➖ Product Deleted',
          'body': '$productTitle has been removed from inventory',
          'type': 'product_deleted',
          'productTitle': productTitle,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Product deleted notification sent');
    } catch (e) {
      print('Error sending product deleted notification: $e');
    }
  }

  // ============ GENERAL PRODUCT UPDATE NOTIFICATION (NEW) ============
  static Future<void> sendProductUpdatedNotification(
    String productTitle,
    String updatedField,
    BuildContext context
  ) async {
    try {
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '📝 Product Updated',
          'body': '$productTitle $updatedField has been updated',
          'type': 'product_updated',
          'productTitle': productTitle,
          'updatedField': updatedField,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      print('✅ Product updated notification sent');
    } catch (e) {
      print('Error sending product updated notification: $e');
    }
  }
}