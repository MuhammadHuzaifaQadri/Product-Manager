import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_crud/user_role_manager.dart';
import 'package:firebase_crud/voice_search_widget.dart';
import 'package:firebase_crud/notification_service.dart';

class Products extends StatefulWidget {
  const Products({Key? key}) : super(key: key);

  @override
  State<Products> createState() => _ProductsState();
}

class _ProductsState extends State<Products> {
  final products = FirebaseFirestore.instance.collection('products');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'none';
  
  int _totalProducts = 0;
  double _totalValue = 0;
  
  final user = FirebaseAuth.instance.currentUser;
  Map<String, bool> _favoriteStatus = {};

  final List<String> _categories = [
    'All',
    'Electronics',
    'Fashion',
    'Home & Kitchen',
    'Sports & Outdoors',
    'Books & Stationery',
    'Toys & Games',
    'Automotive',
    'Health & Beauty',
    'Grocery & Food',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (user == null) return;
    
    try {
      final favDocs = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user!.uid)
          .get();
      
      setState(() {
        _favoriteStatus = {
          for (var doc in favDocs.docs)
            (doc.data()['productId'] as String): true
        };
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add favorites'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final isFavorite = _favoriteStatus[productId] ?? false;

      if (isFavorite) {
        final favDocs = await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: user!.uid)
            .where('productId', isEqualTo: productId)
            .get();

        for (var doc in favDocs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          _favoriteStatus[productId] = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('favorites').add({
          'userId': user!.uid,
          'productId': productId,
          'addedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _favoriteStatus[productId] = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to favorites ❤️'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
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

  Future<void> _trackRecentlyViewed(String productId) async {
    if (user == null) return;

    try {
      final existing = await FirebaseFirestore.instance
          .collection('recently_viewed')
          .where('userId', isEqualTo: user!.uid)
          .where('productId', isEqualTo: productId)
          .get();

      for (var doc in existing.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance.collection('recently_viewed').add({
        'userId': user!.uid,
        'productId': productId,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error tracking view: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _calculateStats(List<QueryDocumentSnapshot> productList) {
    _totalProducts = productList.length;
    _totalValue = 0;
    
    for (var product in productList) {
      final data = product.data() as Map<String, dynamic>;
      final price = double.tryParse(data['price']?.toString() ?? '0') ?? 0;
      _totalValue += price;
    }
  }

  List<QueryDocumentSnapshot> _sortProducts(List<QueryDocumentSnapshot> productList) {
    if (_sortBy == 'none') return productList;
    
    List<QueryDocumentSnapshot> sorted = List.from(productList);
    
    switch (_sortBy) {
      case 'price_low':
        sorted.sort((a, b) {
          final priceA = double.tryParse((a.data() as Map)['price']?.toString() ?? '0') ?? 0;
          final priceB = double.tryParse((b.data() as Map)['price']?.toString() ?? '0') ?? 0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'price_high':
        sorted.sort((a, b) {
          final priceA = double.tryParse((a.data() as Map)['price']?.toString() ?? '0') ?? 0;
          final priceB = double.tryParse((b.data() as Map)['price']?.toString() ?? '0') ?? 0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'name_asc':
        sorted.sort((a, b) {
          final nameA = (a.data() as Map)['title']?.toString().toLowerCase() ?? '';
          final nameB = (b.data() as Map)['title']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });
        break;
      case 'name_desc':
        sorted.sort((a, b) {
          final nameA = (a.data() as Map)['title']?.toString().toLowerCase() ?? '';
          final nameB = (b.data() as Map)['title']?.toString().toLowerCase() ?? '';
          return nameB.compareTo(nameA);
        });
        break;
      case 'newest':
        sorted.sort((a, b) {
          final timeA = (a.data() as Map)['createdAt'] as Timestamp?;
          final timeB = (b.data() as Map)['createdAt'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA);
        });
        break;
    }
    
    return sorted;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort & Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Price: Low to High'),
              onTap: () {
                setState(() => _sortBy = 'price_low');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Price: High to Low'),
              onTap: () {
                setState(() => _sortBy = 'price_high');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Name: A to Z'),
              onTap: () {
                setState(() => _sortBy = 'name_asc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Name: Z to A'),
              onTap: () {
                setState(() => _sortBy = 'name_desc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases),
              title: const Text('Newest First'),
              onTap: () {
                setState(() => _sortBy = 'newest');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear Sort'),
              onTap: () {
                setState(() => _sortBy = 'none');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Dashboard'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(
              Icons.inventory_2,
              'Total Products',
              _totalProducts.toString(),
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.attach_money,
              'Total Value',
              '\$${_totalValue.toStringAsFixed(0)}',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.category,
              'Active Category',
              _selectedCategory,
              Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ REVIEWS SECTION ============
  Widget _buildReviewsSection(String productId) {
    return Column(
      key: ValueKey('reviews_$productId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddReviewDialog(productId),
              icon: const Icon(Icons.star, size: 16),
              label: const Text('Write Review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        StreamBuilder<QuerySnapshot>(
          key: Key('reviews_stream_$productId'),
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('productId', isEqualTo: productId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('Error loading reviews: ${snapshot.error}'),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No reviews yet. Be the first to review!'),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var review = snapshot.data!.docs[index];
                var data = review.data() as Map<String, dynamic>;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.amber.shade100,
                              child: Text(
                                (data['userName']?[0] ?? 'U').toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['userName'] ?? 'User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        i < data['rating'] ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 14,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _getTimeAgo(data['createdAt']),
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['comment'] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showAddReviewDialog(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to review')),
      );
      return;
    }

    double rating = 5;
    final commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Your review',
                  hintText: 'What do you think about this product?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (commentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please write something')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await FirebaseFirestore.instance.collection('reviews').add({
          'productId': productId,
          'userId': user.uid,
          'userName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'rating': rating,
          'comment': commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Review added! Thanks for your feedback.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {});
        }
      } catch (e) {
        print('Error adding review: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  // ============ WISHLIST FUNCTIONS ============
  Future<void> _showWishlistSelector(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save to wishlist')),
      );
      return;
    }

    final wishlists = await FirebaseFirestore.instance
        .collection('wishlists')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (wishlists.docs.isEmpty) {
      final createNew = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Wishlists'),
          content: const Text('Create a wishlist first?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (createNew == true) {
        final result = await Navigator.pushNamed(context, '/wishlists');
        setState(() {});
      }
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Wishlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: wishlists.docs.length,
            itemBuilder: (context, index) {
              var list = wishlists.docs[index];
              var data = list.data();
              return ListTile(
                title: Text(data['name'] ?? 'Unnamed'),
                subtitle: Text('${(data['productIds'] ?? []).length} items'),
                onTap: () => Navigator.pop(context, list.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context, 'new');
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New List'),
          ),
        ],
      ),
    );

    if (selected != null) {
      if (selected == 'new') {
        final result = await Navigator.pushNamed(context, '/wishlists');
        setState(() {});
        return;
      }

      try {
        var listDoc = wishlists.docs.firstWhere((doc) => doc.id == selected);
        var data = listDoc.data();
        var productIds = List<String>.from(data['productIds'] ?? []);
        
        if (!productIds.contains(productId)) {
          productIds.add(productId);
          await listDoc.reference.update({'productIds': productIds});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Added to ${data['name']}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {});
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Already in this list'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        print('Error adding to wishlist: $e');
      }
    }
  }

  // ============ PAYMENT FUNCTIONS ============
  void _showPaymentDialog(Map<String, dynamic> product) {
    final quantityController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final quantity = int.tryParse(quantityController.text) ?? 1;
          final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
          final total = price * quantity;
          final stock = product['stock'] ?? 0;
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payment, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Complete Purchase',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['title'] ?? 'Product',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Price:', style: TextStyle(color: Colors.grey[700])),
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Stock:', style: TextStyle(color: Colors.grey[700])),
                            Text(
                              '$stock units',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: stock > 10 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: quantity > stock || quantity < 1
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _processPayment(product, quantity, total);
                            },
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processPayment(
    Map<String, dynamic> product,
    int quantity,
    double total,
  ) async {
    try {
      print('🔵 PROCESS PAYMENT STARTED');
      print('User: ${user?.uid}');
      print('Product: ${product['title']}');
      print('Quantity: $quantity');
      print('Total: $total');
      
      final stock = product['stock'] ?? 0;
      
      if (quantity > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Not enough stock!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Create order
      print('📝 Creating order...');
      
      final orderData = {
        'userId': user!.uid,
        'userEmail': user!.email ?? 'no-email',
        'userName': user!.displayName ?? 'User',
        'productId': product['id'],
        'productTitle': product['title'],
        'productCategory': product['category'] ?? 'Other',
        'quantity': quantity,
        'pricePerUnit': product['price'],
        'totalAmount': total,
        'status': 'completed',
        'paymentMethod': 'Cash',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      print('Order Data: $orderData');
      
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      
      print('✅ Order created! ID: ${orderRef.id}');
      
      // Update stock
      print('📦 Updating stock...');
      await products.doc(product['id']).update({
        'stock': stock - quantity,
      });
      print('✅ Stock updated');
      
      // Notify admins
      await _notifyAdmins(product['title'], quantity, total, orderRef.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Order placed! ID: ${orderRef.id.substring(0, 8)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('❌ ERROR in _processPayment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _notifyAdmins(
    String productTitle,
    int quantity,
    double total,
    String orderId,
  ) async {
    try {
      print('📢 Notifying admins...');
      
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      
      print('Found ${admins.docs.length} admins');
      
      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': '🛒 New Order',
          'body': '$productTitle x$quantity = \$${total.toStringAsFixed(2)}',
          'type': 'order',
          'orderId': orderId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Admins notified successfully');
    } catch (e) {
      print('Error notifying admins: $e');
    }
  }

  void deleteProduct(String id, String title) async {
    try {
      await products.doc(id).delete();
      
      final favDocs = await FirebaseFirestore.instance
          .collection('favorites')
          .where('productId', isEqualTo: id)
          .get();
      
      for (var doc in favDocs.docs) {
        await doc.reference.delete();
      }
      
      final recentDocs = await FirebaseFirestore.instance
          .collection('recently_viewed')
          .where('productId', isEqualTo: id)
          .get();
      
      for (var doc in recentDocs.docs) {
        await doc.reference.delete();
      }
      
      setState(() {
        _favoriteStatus.remove(id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$title deleted successfully"),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show product details dialog
  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Wishlist button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Product Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Wishlist button for users
                    if (user != null)
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showWishlistSelector(product['id']);
                        },
                        icon: const Icon(Icons.favorite_border, color: Colors.white),
                        tooltip: 'Add to Wishlist',
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content - Scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        if (product['images'] != null && product['images'].isNotEmpty)
                          Center(
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _decodeBase64(product['images']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.broken_image, size: 60, color: Colors.red),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          product['title'] ?? 'No Title',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            product['category'] ?? 'Other',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info Grid (2x2)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.attach_money, color: Colors.green, size: 18),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${product['price']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const Text('Price', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product['rating'] ?? 0.0}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const Text('Rating', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.inventory_2, color: Colors.blue, size: 18),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product['stock'] ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Stock', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.qr_code, color: Colors.purple, size: 18),
                                    const SizedBox(height: 4),
                                    Text(
                                      product['sku']?.toString() ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Text('SKU', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Description
                        const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          product['description'] ?? 'No Description',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                        ),
                        
                        // Reviews Section
                        _buildReviewsSection(product['id']),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions - User Buy / Admin Edit
              Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<bool>(
                  future: UserRoleManager.isAdmin(),
                  builder: (context, snapshot) {
                    final isAdmin = snapshot.data == true;
                    
                    if (!isAdmin) {
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showPaymentDialog(product);
                              },
                              icon: const Icon(Icons.shopping_cart),
                              label: const Text('Buy Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                            ),
                          ),
                        ],
                      );
                    }
                    
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditDialog(product);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check),
                            label: const Text('Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show edit dialog
  void _showEditDialog(Map<String, dynamic> product) {
    final titleController = TextEditingController(text: product['title']);
    final descriptionController = TextEditingController(text: product['description']);
    final priceController = TextEditingController(text: product['price']);
    final stockController = TextEditingController(text: product['stock']?.toString() ?? '0');
    final skuController = TextEditingController(text: product['sku']?.toString() ?? '');
    String? selectedCategory = product['category'];
    String? currentImage = product['images'];
    double rating = (product['rating'] ?? 0.0).toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Edit Product',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            try {
                              final ImagePicker picker = ImagePicker();
                              final XFile? pickedFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 800,
                                maxHeight: 800,
                                imageQuality: 60,
                              );

                              if (pickedFile != null) {
                                final bytes = await pickedFile.readAsBytes();
                                
                                if (bytes.length > 800000) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Image too large! Please select smaller image.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                
                                final base64String = base64Encode(bytes);

                                setDialogState(() {
                                  currentImage = 'data:image/png;base64,$base64String';
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Image updated (${(bytes.length / 1024).toStringAsFixed(0)} KB)'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[400]!, width: 2),
                            ),
                            child: currentImage != null && currentImage!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _decodeBase64(currentImage!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                                            const SizedBox(height: 8),
                                            Text('Tap to change image', style: TextStyle(color: Colors.grey[600])),
                                          ],
                                        );
                                      },
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                                      const SizedBox(height: 8),
                                      Text('Tap to add image', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Product Title',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _categories
                              .where((cat) => cat != 'All')
                              .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value);
                          },
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Price',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Stock',
                                  prefixIcon: const Icon(Icons.inventory_2),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: skuController,
                                decoration: InputDecoration(
                                  labelText: 'SKU',
                                  prefixIcon: const Icon(Icons.qr_code),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Product Rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(5, (index) {
                                return GestureDetector(
                                  onTap: () => setDialogState(() => rating = index + 1.0),
                                  child: Icon(
                                    index < rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 32,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rating > 0 ? '${rating.toStringAsFixed(1)} stars' : 'No rating',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            prefixIcon: const Icon(Icons.description),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final oldStock = product['stock'] ?? 0;
                              final newStock = int.tryParse(stockController.text) ?? 0;
                              final oldPrice = product['price'] ?? '0';
                              final newPrice = priceController.text;
                              
                              await products.doc(product['id']).update({
                                'title': titleController.text,
                                'description': descriptionController.text,
                                'price': priceController.text,
                                'category': selectedCategory ?? 'Other',
                                'images': currentImage,
                                'stock': newStock,
                                'sku': skuController.text,
                                'rating': rating,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              
                              if (newStock == 0 && oldStock > 0) {
                                await NotificationService.outOfStockAlert(titleController.text, context);
                              } else if (newStock < 10 && newStock > 0 && oldStock >= 10) {
                                await NotificationService.lowStockAlert(titleController.text, newStock, context);
                              }
                              
                              if (oldPrice != newPrice) {
                                await NotificationService.priceChangeAlert(titleController.text, oldPrice, newPrice, context);
                              }
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Product updated!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Uint8List _decodeBase64(String base64String) {
    try {
      String base64Data = base64String;
      if (base64String.contains('base64,')) {
        base64Data = base64String.split('base64,').last;
      }
      return base64Decode(base64Data);
    } catch (e) {
      print('Error decoding base64: $e');
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              showVoiceSearchDialog(context, (text) {
                setState(() {
                  _searchController.text = text;
                  _searchQuery = text.toLowerCase();
                });
              });
            },
            icon: const Icon(Icons.mic),
            tooltip: "Voice Search",
          ),
          IconButton(
            onPressed: _showStatsDialog,
            icon: const Icon(Icons.analytics),
            tooltip: "Dashboard",
          ),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: "Sort & Filter",
          ),
          FutureBuilder<bool>(
            future: UserRoleManager.isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  onPressed: () => Navigator.pushNamed(context, "/add"),
                  icon: const Icon(Icons.add),
                  tooltip: "Add Product",
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, "/profile"),
            icon: const Icon(Icons.person),
            tooltip: "Profile",
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          if (_sortBy != 'none')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Sorted by: ${_getSortLabel()}',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _sortBy = 'none'),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = category);
                    },
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: StreamBuilder<QuerySnapshot>(
                stream: products.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("No products found", style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  var productList = snapshot.data!.docs;

                  if (_selectedCategory != 'All') {
                    productList = productList.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['category'] == _selectedCategory;
                    }).toList();
                  }

                  if (_searchQuery.isNotEmpty) {
                    productList = productList.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title']?.toString().toLowerCase() ?? '';
                      final description = data['description']?.toString().toLowerCase() ?? '';
                      return title.contains(_searchQuery) || description.contains(_searchQuery);
                    }).toList();
                  }

                  productList = _sortProducts(productList);
                  _calculateStats(productList);

                  if (productList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No products found for "$_searchQuery"'
                                : 'No products in $_selectedCategory',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _selectedCategory = 'All';
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: productList.length,
                    itemBuilder: (context, index) {
                      final product = productList[index];
                      final productData = product.data() as Map<String, dynamic>;
                      final productWithId = {'id': product.id, ...productData};

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            _trackRecentlyViewed(product.id);
                            _showProductDetails(productWithId);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Image
                              SizedBox(
                                height: 140,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: Colors.grey[100],
                                      child: productData['images'] != null && productData['images'].isNotEmpty
                                          ? Image.memory(
                                              _decodeBase64(productData['images']),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
                                                );
                                              },
                                            )
                                          : Center(
                                              child: Icon(Icons.image_outlined, color: Colors.grey[400], size: 50),
                                            ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          productData['category'] ?? 'Other',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: InkWell(
                                        onTap: () => _toggleFavorite(product.id),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _favoriteStatus[product.id] == true
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Info
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      productData['title'] ?? 'No Title',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '\$${productData['price'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    FutureBuilder<bool>(
                                      future: UserRoleManager.isAdmin(),
                                      builder: (context, snapshot) {
                                        if (snapshot.data != true) {
                                          return const SizedBox(height: 8);
                                        }
                                        
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _showEditDialog(productWithId),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.orange.shade200),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.edit, size: 14, color: Colors.orange),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Edit',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.orange.shade700,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text("Delete Product"),
                                                      content: Text(
                                                        "Are you sure you want to delete '${productData['title']}'?",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text("Cancel"),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                            deleteProduct(
                                                              product.id,
                                                              productData['title'] ?? 'Product',
                                                            );
                                                          },
                                                          child: const Text(
                                                            "Delete",
                                                            style: TextStyle(color: Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.red.shade200),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      const Icon(Icons.delete, size: 14, color: Colors.red),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.red.shade700,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'price_low':
        return 'Price: Low to High';
      case 'price_high':
        return 'Price: High to Low';
      case 'name_asc':
        return 'Name: A to Z';
      case 'name_desc':
        return 'Name: Z to A';
      case 'newest':
        return 'Newest First';
      default:
        return '';
    }
  }
}