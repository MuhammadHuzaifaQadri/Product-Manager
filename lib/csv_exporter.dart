import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// CSV Exporter - Export products to CSV file
class CSVExporter {
  /// Export all products to CSV
  static Future<void> exportProducts(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Preparing CSV export...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Fetch all products
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      
      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No products to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate CSV content
      final csvContent = _generateCSV(snapshot.docs);

      // Download file
      _downloadCSV(csvContent, 'products');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported ${snapshot.docs.length} products'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Export all users to CSV
  static Future<void> exportUsers(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Exporting users...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      
      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No users to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final csvContent = _generateUsersCSV(snapshot.docs);
      _downloadCSV(csvContent, 'users');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported ${snapshot.docs.length} users'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Export all orders to CSV
  static Future<void> exportOrders(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Exporting orders...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      
      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No orders to export'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final csvContent = _generateOrdersCSV(snapshot.docs);
      _downloadCSV(csvContent, 'orders');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Exported ${snapshot.docs.length} orders'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate CSV content from products
  static String _generateCSV(List<QueryDocumentSnapshot> products) {
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

  /// Format Firestore timestamp to readable date
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

  /// Download CSV file (Web)
  static void _downloadCSV(String csvContent, String type) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${type}_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    
    html.Url.revokeObjectUrl(url);
  }

  /// Show export dialog with options
  static Future<void> showExportDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.download, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Export Products'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export all products to CSV file?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CSV will include:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('• Product ID'),
                  _buildInfoRow('• Title & Category'),
                  _buildInfoRow('• Price & Stock'),
                  _buildInfoRow('• Rating & SKU'),
                  _buildInfoRow('• Description'),
                  _buildInfoRow('• Creation date'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              exportProducts(context);
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }
}