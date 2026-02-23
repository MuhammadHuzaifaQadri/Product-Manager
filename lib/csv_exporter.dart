import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// CSV Exporter - Export products to CSV file (Android compatible)
class CSVExporter {
  // ============ PUBLIC METHODS ============
  
  /// Export all products to CSV
  static Future<void> exportProducts(BuildContext context) async {
    await _exportData(
      context: context,
      collection: 'products',
      fileName: 'products',
      generateCSV: _generateProductsCSV,
      successMessage: (count) => '✅ Exported $count products',
      loadingMessage: 'Preparing products export...',
    );
  }

  /// Export all users to CSV
  static Future<void> exportUsers(BuildContext context) async {
    await _exportData(
      context: context,
      collection: 'users',
      fileName: 'users',
      generateCSV: _generateUsersCSV,
      successMessage: (count) => '✅ Exported $count users',
      loadingMessage: 'Exporting users...',
    );
  }

  /// Export all orders to CSV
  static Future<void> exportOrders(BuildContext context) async {
    await _exportData(
      context: context,
      collection: 'orders',
      fileName: 'orders',
      generateCSV: _generateOrdersCSV,
      successMessage: (count) => '✅ Exported $count orders',
      loadingMessage: 'Exporting orders...',
    );
  }

  /// Show export dialog with options
  static Future<void> showExportDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Export Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildExportOption(
                      icon: Icons.inventory,
                      color: Colors.blue,
                      title: 'Export Products',
                      subtitle: 'Download all products as CSV',
                      onTap: () {
                        Navigator.pop(context);
                        exportProducts(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildExportOption(
                      icon: Icons.people,
                      color: Colors.green,
                      title: 'Export Users',
                      subtitle: 'Download all users as CSV',
                      onTap: () {
                        Navigator.pop(context);
                        exportUsers(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildExportOption(
                      icon: Icons.payment,
                      color: Colors.orange,
                      title: 'Export Orders',
                      subtitle: 'Download order history as CSV',
                      onTap: () {
                        Navigator.pop(context);
                        exportOrders(context);
                      },
                    ),
                  ],
                ),
              ),

              // Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ PRIVATE METHODS ============

  /// Generic export function
  static Future<void> _exportData({
    required BuildContext context,
    required String collection,
    required String fileName,
    required String Function(List<QueryDocumentSnapshot>) generateCSV,
    required String Function(int count) successMessage,
    required String loadingMessage,
  }) async {
    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(loadingMessage)),
              ],
            ),
            backgroundColor: const Color(0xFF1E3C72),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Fetch data
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .get();
      
      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          _showToast(
            context,
            message: 'No $collection to export',
            color: Colors.orange,
          );
        }
        return;
      }

      // Generate CSV
      final csvContent = generateCSV(snapshot.docs);

      // Save and share
      await _shareCSV(csvContent, fileName);

      if (context.mounted) {
        _showToast(
          context,
          message: successMessage(snapshot.docs.length),
          color: Colors.green,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(
          context,
          message: 'Export failed: ${e.toString()}',
          color: Colors.red,
        );
      }
    }
  }

  /// Share CSV file
  static Future<void> _shareCSV(String csvContent, String filename) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename.csv';
      final file = File(filePath);
      
      await file.writeAsString(csvContent);
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '$filename export - Product Manager App',
      );
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }

  /// Generate Products CSV
  static String _generateProductsCSV(List<QueryDocumentSnapshot> products) {
    final headers = [
      'ID',
      'Title',
      'Category',
      'Price',
      'Rating',
      'Stock',
      'SKU',
      'Description',
      'Created At',
    ];

    final csv = StringBuffer();
    csv.writeln(headers.map((h) => _escapeCSV(h)).join(','));

    for (var product in products) {
      final data = product.data() as Map<String, dynamic>;
      
      final row = [
        product.id,
        data['title'] ?? '',
        data['category'] ?? '',
        data['price']?.toString() ?? '0',
        data['rating']?.toString() ?? '0',
        data['stock']?.toString() ?? '0',
        data['sku'] ?? '',
        data['description'] ?? '',
        _formatDate(data['createdAt']),
      ];

      csv.writeln(row.map((r) => _escapeCSV(r.toString())).join(','));
    }

    return csv.toString();
  }

  /// Generate Users CSV
  static String _generateUsersCSV(List<QueryDocumentSnapshot> users) {
    final headers = ['ID', 'Name', 'Email', 'Role', 'Created At'];
    final csv = StringBuffer();
    csv.writeln(headers.map((h) => _escapeCSV(h)).join(','));

    for (var user in users) {
      final data = user.data() as Map<String, dynamic>;
      final row = [
        user.id,
        data['name'] ?? '',
        data['email'] ?? '',
        data['role'] ?? 'user',
        _formatDate(data['createdAt']),
      ];
      csv.writeln(row.map((r) => _escapeCSV(r.toString())).join(','));
    }
    return csv.toString();
  }

  /// Generate Orders CSV
  static String _generateOrdersCSV(List<QueryDocumentSnapshot> orders) {
    final headers = ['ID', 'Product', 'User', 'Quantity', 'Amount', 'Status', 'Date'];
    final csv = StringBuffer();
    csv.writeln(headers.map((h) => _escapeCSV(h)).join(','));

    for (var order in orders) {
      final data = order.data() as Map<String, dynamic>;
      final row = [
        order.id,
        data['productTitle'] ?? '',
        data['userEmail'] ?? '',
        data['quantity']?.toString() ?? '0',
        data['totalAmount']?.toString() ?? '0',
        data['status'] ?? '',
        _formatDate(data['createdAt']),
      ];
      csv.writeln(row.map((r) => _escapeCSV(r.toString())).join(','));
    }
    return csv.toString();
  }

  /// Escape CSV special characters
  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Format Firestore timestamp
  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  /// Show toast message
  static void _showToast(
    BuildContext context, {
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green 
                  ? Icons.check_circle 
                  : (color == Colors.orange 
                      ? Icons.warning 
                      : Icons.error),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Build export option tile
  static Widget _buildExportOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}