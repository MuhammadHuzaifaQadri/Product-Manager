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
  final String? initialProductId;
  
  const Products({Key? key, this.initialProductId}) : super(key: key);

  @override
  State<Products> createState() => _ProductsState();
}

class _ProductsState extends State<Products> with SingleTickerProviderStateMixin {
  final products = FirebaseFirestore.instance.collection('products');
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'none';
  
  int _totalProducts = 0;
  double _totalValue = 0;
  
  final user = FirebaseAuth.instance.currentUser;
  Map<String, bool> _favoriteStatus = {};
  bool _isAdmin = false;
  
  late AnimationController _animationController;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadFavorites();
    _checkAdmin();
    
    if (widget.initialProductId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openProductFromDeepLink(widget.initialProductId!);
      });
    }
  }

  // 🔥 FIX: Jab bhi page refresh ho, admin status dobara check karo
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAdmin();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openProductFromDeepLink(String productId) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        final productWithId = {'id': productDoc.id, ...productData};
        _showProductDetails(productWithId);
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final productDoc = querySnapshot.docs.first;
        final productData = productDoc.data() as Map<String, dynamic>;
        final productWithId = {'id': productDoc.id, ...productData};
        _showProductDetails(productWithId);
        return;
      }

      final skuSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sku', isEqualTo: productId)
          .limit(1)
          .get();

      if (skuSnapshot.docs.isNotEmpty) {
        final productDoc = skuSnapshot.docs.first;
        final productData = productDoc.data() as Map<String, dynamic>;
        final productWithId = {'id': productDoc.id, ...productData};
        _showProductDetails(productWithId);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Product not found with ID: $productId'),
          backgroundColor: Colors.red,
        ),
      );

    } catch (e) {
      print('Error opening product from deep link: $e');
    }
  }

  Future<void> _checkAdmin() async {
    bool adminStatus = await UserRoleManager.isAdmin();
    if (_isAdmin != adminStatus) {
      setState(() {
        _isAdmin = adminStatus;
      });
    }
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

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    Icon(Icons.analytics, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatCard(
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                      label: 'Total Products',
                      value: _totalProducts.toString(),
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      icon: Icons.attach_money,
                      color: Colors.green,
                      label: 'Total Value',
                      value: '\$${_totalValue.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard(
                      icon: Icons.category,
                      color: Colors.orange,
                      label: 'Active Category',
                      value: _selectedCategory,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort & Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort, color: Colors.blue),
              title: const Text('Price: Low to High'),
              onTap: () {
                setState(() => _sortBy = 'price_low');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort, color: Colors.blue),
              title: const Text('Price: High to Low'),
              onTap: () {
                setState(() => _sortBy = 'price_high');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha, color: Colors.green),
              title: const Text('Name: A to Z'),
              onTap: () {
                setState(() => _sortBy = 'name_asc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha, color: Colors.green),
              title: const Text('Name: Z to A'),
              onTap: () {
                setState(() => _sortBy = 'name_desc');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases, color: Colors.orange),
              title: const Text('Newest First'),
              onTap: () {
                setState(() => _sortBy = 'newest');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.clear, color: Colors.red),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Write a Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tap to rate:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: GestureDetector(
                                onTap: () => setState(() => rating = index + 1),
                                child: Icon(
                                  index < rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 36,
                                ),
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.amber, width: 2),
                            ),
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
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (commentController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please write something')),
                              );
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Submit'),
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

  // 🔥 FIXED: Payment Dialog with proper SingleChildScrollView
  void _showPaymentDialog(Map<String, dynamic> product) {
    final quantityController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.greenAccent],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payment, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Complete Purchase',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Info
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Price:', style: TextStyle(color: Colors.grey[700])),
                                Text(
                                  '\$${product['price'] ?? '0'}',
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
                                  '${product['stock'] ?? 0} units',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: (product['stock'] ?? 0) > 10 ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Quantity Field
                      StatefulBuilder(
                        builder: (context, setDialogState) {
                          final quantity = int.tryParse(quantityController.text) ?? 1;
                          final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
                          final total = price * quantity;
                          final stock = product['stock'] ?? 0;
                          
                          return Column(
                            children: [
                              TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Quantity',
                                  prefixIcon: const Icon(Icons.numbers, color: Colors.green),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.green, width: 2),
                                  ),
                                ),
                                onChanged: (value) => setDialogState(() {}),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Total
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green.shade50, Colors.green.shade100],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green, width: 2),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Pay Now Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: quantity > stock || quantity < 1
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          _processPayment(product, quantity, total);
                                        },
                                  icon: const Icon(Icons.payment),
                                  label: const Text('Pay Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(
    Map<String, dynamic> product,
    int quantity,
    double total,
  ) async {
    try {
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
      
      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(orderData);
      
      final newStock = stock - quantity;
      await products.doc(product['id']).update({
        'stock': newStock,
      });
      
      if (newStock < 10 && newStock > 0) {
        await NotificationService.sendLowStockNotification(
          product['title'], 
          newStock, 
          context
        );
        
        if (await UserRoleManager.isAdmin() && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${product['title']} is low on stock! Only $newStock left.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (newStock == 0) {
        await NotificationService.outOfStockAlert(product['title'], context);
      }
      
      await NotificationService.newOrderNotification(
        product['title'], 
        quantity, 
        total, 
        orderRef.id
      );
      
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
      
      await NotificationService.sendProductDeletedNotification(title, context);
      
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

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
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
                    if (user != null)
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showWishlistSelector(product['id']);
                        },
                        icon: const Icon(Icons.favorite_border, color: Colors.white),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product['images'] != null && product['images'].isNotEmpty)
                        Center(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                      Text(
                        product['title'] ?? 'No Title',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.attach_money,
                              label: 'Price',
                              value: '\$${product['price']?.toString() ?? 'N/A'}',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.star,
                              label: 'Rating',
                              value: '${product['rating'] ?? 0.0}',
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.inventory_2,
                              label: 'Stock',
                              value: '${product['stock'] ?? 0}',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.qr_code,
                              label: 'SKU',
                              value: product['sku']?.toString() ?? 'N/A',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        product['description'] ?? 'No Description',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                      ),
                      _buildReviewsSection(product['id']),
                    ],
                  ),
                ),
              ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteDialog(product['id'], product['title']);
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit Product',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await products.doc(product['id']).update({
                                'title': titleController.text,
                                'description': descriptionController.text,
                                'price': priceController.text,
                                'category': selectedCategory ?? 'Other',
                                'images': currentImage,
                                'stock': int.tryParse(stockController.text) ?? 0,
                                'sku': skuController.text,
                                'rating': rating,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                              
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
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

  void _showDeleteDialog(String productId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Product"),
        content: Text("Are you sure you want to delete '$title'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteProduct(productId, title);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
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
        title: const Text(
          "Products",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'voice':
                  showVoiceSearchDialog(context, (text) {
                    setState(() {
                      _searchController.text = text;
                      _searchQuery = text.toLowerCase();
                    });
                  });
                  break;
                case 'dashboard':
                  _showStatsDialog();
                  break;
                case 'filter':
                  _showFilterDialog();
                  break;
                case 'add_product':
                  Navigator.pushNamed(context, "/add");
                  break;
                case 'profile':
                  Navigator.pushNamed(context, "/profile");
                  break;
                case 'logout':
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'voice',
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Voice Search'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Dashboard'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Sort & Filter'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'add_product',
                  child: Row(
                    children: [
                      Icon(Icons.add, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Add Product'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3C72)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),

            if (_sortBy != 'none')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
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
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Categories
            Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = category);
                      },
                      selectedColor: const Color(0xFF1E3C72),
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Products Grid - RESPONSIVE CARDS
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                color: const Color(0xFF1E3C72),
                child: StreamBuilder<QuerySnapshot>(
                  stream: products.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E3C72),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Error: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No products found",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1E3C72),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: MediaQuery.of(context).size.width > 500 ? 0.9 : 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: productList.length,
                      itemBuilder: (context, index) {
                        final product = productList[index];
                        final productData = product.data() as Map<String, dynamic>;
                        final productWithId = {'id': product.id, ...productData};

                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _trackRecentlyViewed(product.id);
                                    _showProductDetails(productWithId);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Image Section
                                      Stack(
                                        children: [
                                          Container(
                                            height: 120,
                                            width: double.infinity,
                                            color: Colors.grey[100],
                                            child: productData['images'] != null && productData['images'].isNotEmpty
                                                ? Image.memory(
                                                    _decodeBase64(productData['images']),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Center(
                                                        child: Icon(
                                                          Icons.image_not_supported,
                                                          size: 30,
                                                          color: Colors.grey[400],
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Center(
                                                    child: Icon(
                                                      Icons.shopping_bag,
                                                      size: 30,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                          ),
                                          
                                          // Favorite Button
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: InkWell(
                                              onTap: () => _toggleFavorite(product.id),
                                              borderRadius: BorderRadius.circular(20),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.1),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _favoriteStatus[product.id] == true
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: Colors.red,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Category Chip
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF1E3C72).withOpacity(0.9),
                                                    const Color(0xFF2A5298).withOpacity(0.9),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                productData['category'] ?? 'Other',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Content Section - COMPACT
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Title
                                            Text(
                                              productData['title'] ?? 'No Title',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            
                                            const SizedBox(height: 6),
                                            
                                            // Price and Stock
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '\$${productData['price'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1E3C72),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: (productData['stock'] ?? 0) > 0
                                                        ? Colors.green.shade50
                                                        : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    (productData['stock'] ?? 0) > 0
                                                        ? 'In Stock'
                                                        : 'Out',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: (productData['stock'] ?? 0) > 0
                                                          ? Colors.green.shade700
                                                          : Colors.red.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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