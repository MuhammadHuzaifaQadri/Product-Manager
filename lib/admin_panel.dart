import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crud/user_role_manager.dart';
import 'package:firebase_crud/csv_exporter.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  
  // Stats
  int _totalProducts = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoadData();
  }

  Future<void> _checkAdminAndLoadData() async {
    setState(() => _isLoading = true);
    
    _isAdmin = await UserRoleManager.isAdmin();
    
    if (!_isAdmin) {
      setState(() => _isLoading = false);
      return;
    }

    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadUsers(),
      _loadProducts(),
      _loadOrders(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final users = await UserRoleManager.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      setState(() => _totalProducts = snapshot.docs.length);
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      setState(() {
        _totalOrders = snapshot.docs.length;
        _totalRevenue = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          _totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
        }
      });
      print('✅ Loaded $_totalOrders orders, revenue: $_totalRevenue');
    } catch (e) {
      print('Error loading orders: $e');
    }
  }

  Future<void> _changeUserRole(String uid, String currentRole) async {
    final newRole = currentRole == UserRoleManager.ROLE_ADMIN 
        ? UserRoleManager.ROLE_USER 
        : UserRoleManager.ROLE_ADMIN;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Text(
          'Change role to: ${newRole == UserRoleManager.ROLE_ADMIN ? '👑 Admin' : '👤 User'}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await UserRoleManager.updateUserRole(uid, newRole);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Role changed to $newRole'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadUsers();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to change role'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ============ EXPORT FUNCTIONS ============
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.teal),
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
      
      await CSVExporter.exportProducts(context);  // ✅ context passed
      
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
      
      await CSVExporter.exportUsers(context);  // ✅ context passed
      
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
      
      await CSVExporter.exportOrders(context);  // ✅ context passed
      
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showBroadcastDialog,
            icon: const Icon(Icons.campaign),
            tooltip: 'Broadcast to All',
          ),
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Access Denied',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Only admins can access this panel',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dashboard Overview
                        const Text(
                          'Dashboard',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Stats Row 1
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.people,
                                title: 'Total Users',
                                value: _users.length.toString(),
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.shopping_bag,
                                title: 'Products',
                                value: _totalProducts.toString(),
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stats Row 2
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.admin_panel_settings,
                                title: 'Admins',
                                value: _users.where((u) => u['role'] == UserRoleManager.ROLE_ADMIN).length.toString(),
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.payment,
                                title: 'Orders',
                                value: _totalOrders.toString(),
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Revenue Card
                        _buildRevenueCard(),
                        const SizedBox(height: 24),

                        // Admin Features
                        const Text(
                          'Admin Features',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Analytics
                        _buildFeatureCard(
                          icon: Icons.analytics,
                          title: 'Analytics',
                          subtitle: 'View charts and insights',
                          color: Colors.green,
                          onTap: () => Navigator.pushNamed(context, '/analytics'),
                        ),
                        const SizedBox(height: 12),

                        // Order History
                        _buildFeatureCard(
                          icon: Icons.history,
                          title: 'Order History',
                          subtitle: 'View all orders',
                          color: Colors.orange,
                          onTap: () => _showOrderHistory(),
                        ),
                        const SizedBox(height: 12),

                        // QR Codes
                        _buildFeatureCard(
                          icon: Icons.qr_code,
                          title: 'QR Codes',
                          subtitle: 'Generate product QR codes',
                          color: Colors.purple,
                          onTap: () => Navigator.pushNamed(context, '/qr_codes'),
                        ),
                        const SizedBox(height: 12),

                        // Export Data
                        _buildFeatureCard(
                          icon: Icons.download,
                          title: 'Export Data',
                          subtitle: 'Download CSV reports',
                          color: Colors.teal,
                          onTap: _showExportOptions,
                        ),
                        const SizedBox(height: 12),

                        // Send Notifications
                        _buildFeatureCard(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          subtitle: 'Send bulk notifications',
                          color: Colors.red,
                          onTap: _showBroadcastDialog,
                        ),
                        const SizedBox(height: 24),

                        // User Management Section
                        const Text(
                          'Users',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Users List
                        if (_users.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No Users Found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._users.map((user) => _buildUserCard(user)).toList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Revenue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${_totalRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: Colors.white, size: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
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
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isAdmin = user['role'] == UserRoleManager.ROLE_ADMIN;
    final roleColor = isAdmin ? Colors.purple : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAdmin ? Colors.purple.shade200 : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: roleColor.withOpacity(0.2),
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: roleColor,
            size: 28,
          ),
        ),
        title: Text(
          user['name'] ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user['email'] ?? 'No email'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    size: 14,
                    color: roleColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAdmin ? '👑 ADMIN' : '👤 USER',
                    style: TextStyle(
                      fontSize: 11,
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: () => _changeUserRole(user['id'], user['role']),
          icon: Icon(
            isAdmin ? Icons.person : Icons.admin_panel_settings,
            size: 16,
          ),
          label: Text(
            isAdmin ? 'Make User' : 'Make Admin',
            style: const TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isAdmin ? Colors.blue : Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(0, 36),
          ),
        ),
      ),
    );
  }

  // ============ ORDER HISTORY ============
  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.orange),
            SizedBox(width: 8),
            Text('Order History'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No orders yet'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final order = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final isCompleted = order['status'] == 'completed';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCompleted ? Colors.green : Colors.orange,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(order['productTitle'] ?? 'Unknown'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User: ${order['userEmail'] ?? 'Unknown'}'),
                          Text('Qty: ${order['quantity']} • ${order['paymentMethod'] ?? 'Cash'}'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${order['totalAmount']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            order['status'] ?? 'pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============ BROADCAST SYSTEM ============
  void _showBroadcastDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign, color: Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Broadcast Notification',
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
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  prefixIcon: const Icon(Icons.message),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
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
                        if (titleController.text.trim().isEmpty ||
                            messageController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fill all fields'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        await _sendBroadcast(
                          titleController.text.trim(),
                          messageController.text.trim(),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendBroadcast(String title, String message) async {
    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      
      int sent = 0;
      for (var user in users.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': user.id,
          'title': '📢 $title',
          'body': message,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        sent++;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Sent to $sent users!'),
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
}