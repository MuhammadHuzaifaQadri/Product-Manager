import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instance;

  // Toggle favorite
  Future<void> toggleFavorite(String productId, bool isFavorite) async {
    if (user == null) return;

    try {
      if (isFavorite) {
        // Remove from favorites
        final favDocs = await firestore
            .collection('favorites')
            .where('userId', isEqualTo: user!.uid)
            .where('productId', isEqualTo: productId)
            .get();

        for (var doc in favDocs.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Add to favorites
        await firestore.collection('favorites').add({
          'userId': user!.uid,
          'productId': productId,
          'addedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  // Check if product is favorite
  Future<bool> isFavorite(String productId) async {
    if (user == null) return false;

    try {
      final favDocs = await firestore
          .collection('favorites')
          .where('userId', isEqualTo: user!.uid)
          .where('productId', isEqualTo: productId)
          .get();

      return favDocs.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please login to view favorites'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('favorites')
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
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No favorites yet',
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

          final favoriteIds = snapshot.data!.docs
              .map((doc) => (doc.data() as Map)['productId'] as String)
              .toList();

          return StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('products').snapshots(),
            builder: (context, productSnapshot) {
              if (!productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Get all existing product IDs
              final existingProductIds = productSnapshot.data!.docs
                  .map((doc) => doc.id)
                  .toSet();

              // Filter favorites to only include existing products
              final validFavoriteIds = favoriteIds
                  .where((id) => existingProductIds.contains(id))
                  .toList();

              // Clean up orphaned favorites (products that don't exist anymore)
              final orphanedIds = favoriteIds
                  .where((id) => !existingProductIds.contains(id))
                  .toList();
              
              if (orphanedIds.isNotEmpty) {
                // Delete orphaned favorites in background
                Future.microtask(() async {
                  for (var productId in orphanedIds) {
                    final orphanedDocs = await firestore
                        .collection('favorites')
                        .where('userId', isEqualTo: user!.uid)
                        .where('productId', isEqualTo: productId)
                        .get();
                    
                    for (var doc in orphanedDocs.docs) {
                      await doc.reference.delete();
                    }
                  }
                });
              }

              final favoriteProducts = productSnapshot.data!.docs
                  .where((doc) => validFavoriteIds.contains(doc.id))
                  .toList();

              if (favoriteProducts.isEmpty) {
                return const Center(child: Text('No favorite products found'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85, // Much taller - no overflow!
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: favoriteProducts.length,
                itemBuilder: (context, index) {
                  final product = favoriteProducts[index];
                  final productData = product.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, '/products'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Image
                          SizedBox(
                            height: 120, // Smaller image
                            width: double.infinity,
                            child: Stack(
                              children: [
                                productData['images'] != null &&
                                        productData['images'].isNotEmpty
                                    ? Image.memory(
                                        _decodeBase64(productData['images']),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 120,
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image, size: 40),
                                      ),
                                // Heart
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: InkWell(
                                    onTap: () => toggleFavorite(product.id, true),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.red,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Info
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  productData['title'] ?? 'No Title',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${productData['price'] ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  width: double.infinity,
                                  height: 24,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/products'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text('View', style: TextStyle(fontSize: 9.5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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