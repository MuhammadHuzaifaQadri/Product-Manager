import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistDetailPage extends StatefulWidget {
  const WishlistDetailPage({Key? key}) : super(key: key);

  @override
  State<WishlistDetailPage> createState() => _WishlistDetailPageState();
}

class _WishlistDetailPageState extends State<WishlistDetailPage> {
  late String wishlistId;
  late String wishlistName;
  String? wishlistDesc;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    wishlistId = args['id'];
    wishlistName = args['name'] ?? 'Wishlist';
    wishlistDesc = args['description'];
  }

  Future<void> _removeFromWishlist(String productId) async {
    try {
      final wishlistRef = FirebaseFirestore.instance
          .collection('wishlists')
          .doc(wishlistId);
      
      final wishlist = await wishlistRef.get();
      final data = wishlist.data() as Map<String, dynamic>;
      final productIds = List<String>.from(data['productIds'] ?? []);
      
      productIds.remove(productId);
      await wishlistRef.update({'productIds': productIds});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Item removed from wishlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(wishlistName),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshData,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wishlists')
              .doc(wishlistId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            var productIds = List<String>.from(data['productIds'] ?? []);

            if (productIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'No items in this list',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add products from the products page',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/products');
                      },
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('Browse Products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: productIds.length,
              itemBuilder: (context, index) {
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('products')
                      .doc(productIds[index])
                      .get(),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: ListTile(
                          leading: CircularProgressIndicator(),
                          title: Text('Loading...'),
                        ),
                      );
                    }

                    if (!productSnapshot.hasData || !productSnapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    var productData = productSnapshot.data!.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.pink.shade100,
                          child: const Icon(Icons.favorite, color: Colors.pink, size: 16),
                        ),
                        title: Text(productData['title'] ?? 'Unknown'),
                        subtitle: Text('\$${productData['price'] ?? '0'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeFromWishlist(productIds[index]),
                          tooltip: 'Remove from wishlist',
                        ),
                        onTap: () {
                          // Show product details
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}