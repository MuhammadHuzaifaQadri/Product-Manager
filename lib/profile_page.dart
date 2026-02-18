import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crud/user_role_manager.dart';
import 'package:firebase_crud/csv_exporter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  String _userName = 'User';
  String _userRole = 'user';
  bool _isAdmin = false;
  int _productsCount = 0;
  int _favoritesCount = 0;
  int _wishlistsCount = 0;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    try {
      _userName = await UserRoleManager.getUserName();
      _userRole = await UserRoleManager.getUserRole();
      _isAdmin = await UserRoleManager.isAdmin();

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      _productsCount = productsSnapshot.docs.length;

      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: user!.uid)
          .get();
      _favoritesCount = favoritesSnapshot.docs.length;

      final wishlistsSnapshot = await FirebaseFirestore.instance
          .collection('wishlists')
          .where('userId', isEqualTo: user!.uid)
          .get();
      _wishlistsCount = wishlistsSnapshot.docs.length;

      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: user!.uid)
          .get();
      _reviewsCount = reviewsSnapshot.docs.length;

      setState(() {});
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      final success = await UserRoleManager.updateUserName(newName.trim());
      if (success) {
        setState(() => _userName = newName.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await user!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.blue),
              title: const Text('Export Products'),
              subtitle: const Text('Download all products as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportProducts();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.green),
              title: const Text('Export Users'),
              subtitle: const Text('Download all users as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.orange),
              title: const Text('Export Orders'),
              subtitle: const Text('Download order history'),
              onTap: () {
                Navigator.pop(context);
                _exportOrders();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportProducts() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting products...'), duration: Duration(seconds: 1)),
      );
      
      await CSVExporter.exportProducts(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Products exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  Future<void> _exportUsers() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting users...'), duration: Duration(seconds: 1)),
      );
      
      await CSVExporter.exportUsers(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Users exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  Future<void> _exportOrders() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting orders...'), duration: Duration(seconds: 1)),
      );
      
      await CSVExporter.exportOrders(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Orders exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Profile Avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        if (_isAdmin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.purple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Name with edit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _editName,
                          icon: const Icon(Icons.edit, size: 20, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Email
                    Text(
                      user!.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Admin Badge
                    if (_isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Email verification warning
                    if (!user!.emailVerified)
                      Container(
                        margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email not verified',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Please verify your email',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _resendVerificationEmail,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Resend'),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Stats Cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildStatCard('📦', _productsCount.toString(), 'Products', Colors.blue),
                    _buildStatCard('❤️', _favoritesCount.toString(), 'Favorites', Colors.red),
                    _buildStatCard('📋', _wishlistsCount.toString(), 'Wishlists', Colors.pink),
                    _buildStatCard('⭐', _reviewsCount.toString(), 'Reviews', Colors.amber),
                  ],
                ),
              ),

              const Divider(),

              // Menu Items Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // PRODUCTS OPTION - Added for navigation to products page
                    _buildMenuItem(
                      Icons.shopping_bag,
                      'Products',
                      'View all products',
                      Colors.blue,
                      () => Navigator.pushNamed(context, '/products'),
                    ),
                    
                    _buildMenuItem(
                      Icons.favorite,
                      'Favorites',
                      'View saved items',
                      Colors.red,
                      () => Navigator.pushNamed(context, '/favorites'),
                    ),
                    
                    _buildMenuItem(
                      Icons.history,
                      'Recently Viewed',
                      'Check your history',
                      Colors.orange,
                      () => Navigator.pushNamed(context, '/recently_viewed'),
                    ),
                    
                    _buildMenuItem(
                      Icons.favorite,
                      'Wishlists',
                      'Save products in multiple lists',
                      Colors.pink,
                      () => Navigator.pushNamed(context, '/wishlists'),
                    ),
                    
                    _buildMenuItem(
                      Icons.support_agent,
                      'Customer Support',
                      'Chat with support team',
                      Colors.teal,
                      () => Navigator.pushNamed(context, '/chat-support'),
                    ),
                    
                    _buildMenuItem(
                      Icons.settings,
                      'Settings',
                      'App preferences',
                      Colors.grey,
                      () => Navigator.pushNamed(context, '/settings'),
                    ),
                    
                    _buildMenuItem(
                      Icons.notifications,
                      'Notifications',
                      'View all notifications',
                      Colors.teal,
                      () => Navigator.pushNamed(context, '/notifications'),
                    ),

                    // ADMIN ONLY EXTRAS
                    if (_isAdmin) ...[
                      const Divider(height: 32),
                      
                      _buildMenuItem(
                        Icons.download,
                        'Export Data',
                        'Download products as CSV',
                        Colors.green,
                        _showExportOptions,
                      ),
                      
                      _buildMenuItem(
                        Icons.analytics,
                        'Analytics',
                        'View charts & insights',
                        Colors.purple,
                        () => Navigator.pushNamed(context, '/analytics'),
                      ),
                      
                      _buildMenuItem(
                        Icons.qr_code,
                        'QR Codes',
                        'Generate product QR codes',
                        Colors.indigo,
                        () => Navigator.pushNamed(context, '/qr_codes'),
                      ),
                      
                      _buildMenuItem(
                        Icons.admin_panel_settings,
                        'Admin Panel',
                        'Manage users and roles',
                        Colors.purple,
                        () => Navigator.pushNamed(context, '/admin'),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // LOGOUT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }
}