import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecentlyViewedPage extends StatefulWidget {
  const RecentlyViewedPage({Key? key}) : super(key: key);

  @override
  State<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends State<RecentlyViewedPage> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instance;

  Uint8List _decodeBase64(String base64String) {
    try {
      String base64Data = base64String;
      if (base64String.contains('base64,')) {
        base64Data = base64String.split('base64,').last;
      }
      return base64Decode(base64Data);
    } catch (e) {
      return Uint8List(0);
    }
  }

  Future<void> _clearHistory() async {
    if (user == null) return;

    try {
      final historyDocs = await firestore
          .collection('recently_viewed')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (var doc in historyDocs.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recently Viewed'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please login to view history'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Viewed'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Remove all recently viewed products?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearHistory();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('recently_viewed')
            .where('userId', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No recently viewed products',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/products'),
                    child: const Text('Browse Products'),
                  ),
                ],
              ),
            );
          }

          // Get product IDs and sort by timestamp manually
          final viewedDocs = snapshot.data!.docs;
          
          // Sort manually by viewedAt
          viewedDocs.sort((a, b) {
            final timeA = (a.data() as Map)['viewedAt'] as Timestamp?;
            final timeB = (b.data() as Map)['viewedAt'] as Timestamp?;
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Newest first
          });
          
          final viewedProductIds = viewedDocs
              .map((doc) => (doc.data() as Map)['productId'] as String)
              .take(50)
              .toList();

          return StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('products').snapshots(),
            builder: (context, productSnapshot) {
              if (!productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final viewedProducts = productSnapshot.data!.docs
                  .where((doc) => viewedProductIds.contains(doc.id))
                  .toList();

              // Sort by view order
              viewedProducts.sort((a, b) {
                final indexA = viewedProductIds.indexOf(a.id);
                final indexB = viewedProductIds.indexOf(b.id);
                return indexA.compareTo(indexB);
              });

              if (viewedProducts.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: viewedProducts.length,
                itemBuilder: (context, index) {
                  final product = viewedProducts[index];
                  final productData = product.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: productData['images'] != null &&
                                  productData['images'].isNotEmpty
                              ? Image.memory(
                                  _decodeBase64(productData['images']),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image),
                                ),
                        ),
                      ),
                      title: Text(
                        productData['title'] ?? 'No Title',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '\$${productData['price'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () => Navigator.pushNamed(context, '/products'),
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
