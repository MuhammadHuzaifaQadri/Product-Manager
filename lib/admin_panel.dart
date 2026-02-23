import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crud/user_role_manager.dart';
import 'package:firebase_crud/csv_exporter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({Key? key}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  
  // Stats
  int _totalProducts = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
    _checkAdminAndLoadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    } catch (e) {
      print('Error loading orders: $e');
    }
  }

  // ============ USER MANAGEMENT FUNCTIONS ============

  Future<void> _changeUserRole(String uid, String currentRole) async {
    final newRole = currentRole == UserRoleManager.ROLE_ADMIN 
        ? UserRoleManager.ROLE_USER 
        : UserRoleManager.ROLE_ADMIN;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              newRole == UserRoleManager.ROLE_ADMIN ? Icons.admin_panel_settings : Icons.person,
              color: Colors.purple,
            ),
            const SizedBox(width: 8),
            Text('Change User Role'),
          ],
        ),
        content: Text(
          'Change role to: ${newRole == UserRoleManager.ROLE_ADMIN ? '👑 Admin' : '👤 User'}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await UserRoleManager.updateUserRole(uid, newRole);
      
      if (success) {
        _showToast('✅ Role changed to $newRole', Colors.green);
        await _loadUsers();
      } else {
        _showToast('❌ Failed to change role', Colors.red);
      }
    }
  }

  Future<void> _blockUser(String uid, String email, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Text('Block User'),
          ],
        ),
        content: Text(
          'Are you sure you want to block $name ($email)?\n\n'
          'This user will NOT be able to login until unblocked.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isBlocked': true,
          'blockedAt': FieldValue.serverTimestamp(),
          'blockedBy': FirebaseAuth.instance.currentUser?.uid,
        });

        _showToast('✅ User blocked successfully', Colors.green);
        await _loadUsers();
      } catch (e) {
        _showToast('❌ Error blocking user: $e', Colors.red);
      }
    }
  }

  Future<void> _unblockUser(String uid, String email, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.green),
            SizedBox(width: 8),
            Text('Unblock User'),
          ],
        ),
        content: Text('Allow $name ($email) to login again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isBlocked': false,
          'unblockedAt': FieldValue.serverTimestamp(),
          'unblockedBy': FirebaseAuth.instance.currentUser?.uid,
        });

        _showToast('✅ User unblocked successfully', Colors.green);
        await _loadUsers();
      } catch (e) {
        _showToast('❌ Error unblocking user: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteUser(String uid, String email, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
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
                    colors: [Colors.red, Colors.redAccent],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delete User Permanently',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to PERMANENTLY DELETE $name?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📧 Email: $email'),
                            const SizedBox(height: 4),
                            SelectableText(
                              '🆔 UID: $uid',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ This action CANNOT be undone!',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              '• All user data will be deleted\n'
                              '• All chats and messages will be deleted\n'
                              '• User can sign up again with same email',
                              style: TextStyle(fontSize: 13, color: Colors.red),
                            ),
                          ],
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
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('DELETE'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        _showLoadingDialog('Deleting user...');

        // Delete user's chats and messages
        try {
          final userChats = await FirebaseFirestore.instance
              .collection('chats')
              .where('userId', isEqualTo: uid)
              .get();
          
          for (var chat in userChats.docs) {
            final messages = await FirebaseFirestore.instance
                .collection('messages')
                .where('chatId', isEqualTo: chat.id)
                .get();
            
            for (var msg in messages.docs) {
              await msg.reference.delete();
            }
            
            await chat.reference.delete();
          }
        } catch (e) {
          print('Error deleting user chats: $e');
        }

        // Delete user's data from all collections
        await Future.wait([
          FirebaseFirestore.instance.collection('users').doc(uid).delete(),
          
          FirebaseFirestore.instance
              .collection('favorites')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
          
          FirebaseFirestore.instance
              .collection('reviews')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
          
          FirebaseFirestore.instance
              .collection('wishlists')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
          
          FirebaseFirestore.instance
              .collection('recently_viewed')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
          
          FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
          
          FirebaseFirestore.instance
              .collection('orders')
              .where('userId', isEqualTo: uid)
              .get()
              .then((snapshot) => Future.wait(snapshot.docs.map((doc) => doc.reference.delete()))),
        ]);

        // Mark user as deleted
        await FirebaseFirestore.instance.collection('deleted_users').doc(uid).set({
          'email': email,
          'name': name,
          'uid': uid,
          'deletedAt': FieldValue.serverTimestamp(),
          'deletedBy': FirebaseAuth.instance.currentUser?.uid,
          'deletedByEmail': FirebaseAuth.instance.currentUser?.email,
        });

        if (mounted) Navigator.pop(context); // Close loading
        _showToast('✅ User completely deleted!', Colors.green);
        await _loadUsers();
        
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showToast('❌ Error deleting user: $e', Colors.red);
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: Colors.purple,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============ BROADCAST DIALOG ============
  void _showBroadcastDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.purpleAccent],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Broadcast Notification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          hintText: 'e.g., New Arrivals',
                          prefixIcon: const Icon(Icons.title, color: Colors.purple),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.purple, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: messageController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Message',
                          hintText: 'Enter your notification message...',
                          prefixIcon: const Icon(Icons.message, color: Colors.purple),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.purple, width: 2),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.purple),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This notification will be sent to ALL users except blocked ones.',
                                style: TextStyle(fontSize: 12, color: Colors.purple),
                              ),
                            ),
                          ],
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
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty ||
                              messageController.text.trim().isEmpty) {
                            _showToast('Please fill all fields', Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          await _sendBroadcast(
                            titleController.text.trim(),
                            messageController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendBroadcast(String title, String message) async {
    try {
      _showLoadingDialog('Sending broadcast...');

      final users = await FirebaseFirestore.instance.collection('users').get();
      
      int sent = 0;
      int skipped = 0;
      
      for (var user in users.docs) {
        final userData = user.data();
        
        if (userData['isBlocked'] == true) {
          skipped++;
          continue;
        }
        
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': user.id,
          'title': '📢 $title',
          'body': message,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        sent++;
      }
      
      if (mounted) Navigator.pop(context);
      _showToast('✅ Broadcast sent to $sent users! ($skipped blocked skipped)', Colors.green);
      
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showToast('❌ Error: $e', Colors.red);
    }
  }

  // ============ ORDER HISTORY DIALOG ============
  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Order History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
              
              // Orders List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .orderBy('createdAt', descending: true)
                        .limit(50)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  size: 60,
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No orders yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final order = snapshot.data!.docs[index];
                          final data = order.data() as Map<String, dynamic>;
                          
                          String formattedDate = '';
                          if (data['createdAt'] != null) {
                            final date = (data['createdAt'] as Timestamp).toDate();
                            formattedDate = '${date.day}/${date.month}/${date.year}';
                          }
                          
                          num? amount = data['totalAmount'] ?? data['amount'] ?? 0;
                          double orderAmount = amount?.toDouble() ?? 0;
                          
                          final isCompleted = data['status'] == 'completed';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCompleted ? Colors.green.shade200 : Colors.orange.shade200,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCompleted ? Colors.green : Colors.orange).withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Order #${order.id.substring(0, 6)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isCompleted ? Icons.check_circle : Icons.pending,
                                              size: 12,
                                              color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              data['status'] ?? 'pending',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['productTitle'] ?? 'Unknown Product',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.person, size: 10, color: Colors.grey[500]),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    data['userEmail'] ?? 'Unknown User',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.numbers, size: 10, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Qty: ${data['quantity'] ?? 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.payment, size: 10, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              data['paymentMethod'] ?? 'Cash',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const Spacer(),
                                      
                                      Text(
                                        '\$${orderAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedDate.isNotEmpty ? formattedDate : 'Date not available',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
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
        ),
      ),
    );
  }

  void _showExportOptions() {
    CSVExporter.showExportDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _showBroadcastDialog,
              icon: const Icon(Icons.campaign),
              tooltip: 'Broadcast to All',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.purple,
              ),
            )
          : !_isAdmin
              ? Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock,
                            size: 80,
                            color: Colors.purple.shade200,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Access Denied',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Only admins can access this panel',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  color: Colors.purple,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 🔥 FINAL FIXED: Stats Grid - No Overflow
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.9, // 👈 INCREASED from 1.7 to 1.9
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _buildStatCard(
                                icon: Icons.people,
                                title: 'Total Users',
                                value: _users.length.toString(),
                                color: Colors.blue,
                              ),
                              _buildStatCard(
                                icon: Icons.shopping_bag,
                                title: 'Products',
                                value: _totalProducts.toString(),
                                color: Colors.green,
                              ),
                              _buildStatCard(
                                icon: Icons.admin_panel_settings,
                                title: 'Admins',
                                value: _users.where((u) => u['role'] == UserRoleManager.ROLE_ADMIN).length.toString(),
                                color: Colors.purple,
                              ),
                              _buildStatCard(
                                icon: Icons.payment,
                                title: 'Orders',
                                value: _totalOrders.toString(),
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),

                          // Revenue Card
                          _buildRevenueCard(),
                          const SizedBox(height: 24),

                          // Admin Features
                          const Text(
                            'Admin Features',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildFeatureCard(
                            icon: Icons.analytics,
                            title: 'Analytics',
                            subtitle: 'View charts and insights',
                            color: Colors.green,
                            onTap: () => Navigator.pushNamed(context, '/analytics'),
                          ),
                          
                          _buildFeatureCard(
                            icon: Icons.history,
                            title: 'Order History',
                            subtitle: 'View all orders',
                            color: Colors.orange,
                            onTap: _showOrderHistory,
                          ),
                          
                          _buildFeatureCard(
                            icon: Icons.qr_code,
                            title: 'QR Codes',
                            subtitle: 'Generate product QR codes',
                            color: Colors.purple,
                            onTap: () => Navigator.pushNamed(context, '/qr_codes'),
                          ),
                          
                          _buildFeatureCard(
                            icon: Icons.download,
                            title: 'Export Data',
                            subtitle: 'Download CSV reports',
                            color: Colors.teal,
                            onTap: _showExportOptions,
                          ),
                          
                          _buildFeatureCard(
                            icon: Icons.campaign,
                            title: 'Broadcast',
                            subtitle: 'Send notifications to all users',
                            color: Colors.red,
                            onTap: _showBroadcastDialog,
                          ),
                          
                          const SizedBox(height: 24),

                          // User Management Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'User Management',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_users.length} total',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Users List
                          if (_users.isEmpty)
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.people_outline,
                                      size: 60,
                                      color: Colors.purple.shade200,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Users Found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _users.length,
                              itemBuilder: (context, index) => _buildUserCard(_users[index]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  // 🔥 ULTRA COMPACT stat card - FINAL FIX
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // 👈 REDUCED from 10 to 8
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4), // 👈 REDUCED from 5 to 4
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(5), // 👈 REDUCED from 6 to 5
              ),
              child: Icon(icon, color: Colors.white, size: 16), // 👈 REDUCED from 18 to 16
            ),
            const SizedBox(height: 4), // 👈 REDUCED from 6 to 4
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16, // 👈 REDUCED from 18 to 16
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: TextStyle(
                fontSize: 9, // 👈 REDUCED from 10 to 9
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.trending_up, color: Colors.white, size: 24),
          ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 13,
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
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isAdmin = user['role'] == UserRoleManager.ROLE_ADMIN;
    final isBlocked = user['isBlocked'] == true;
    final roleColor = isAdmin ? Colors.purple : (isBlocked ? Colors.red : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isBlocked ? Colors.red.shade50 : Colors.white,
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked 
              ? Colors.red.shade300 
              : (isAdmin ? Colors.purple.shade200 : Colors.blue.shade200),
          width: isBlocked ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: roleColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor, roleColor.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? Colors.red : Colors.black87,
                          ),
                        ),
                      ),
                      if (isBlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'BLOCKED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? 'No email',
                    style: TextStyle(
                      fontSize: 13,
                      color: isBlocked ? Colors.red.shade700 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
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
                          isAdmin ? 'ADMIN' : 'USER',
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
            ),

            // Menu Button
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: roleColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                switch (value) {
                  case 'make_admin':
                  case 'make_user':
                    await _changeUserRole(user['id'], user['role']);
                    break;
                  case 'block':
                    await _blockUser(user['id'], user['email'], user['name']);
                    break;
                  case 'unblock':
                    await _unblockUser(user['id'], user['email'], user['name']);
                    break;
                  case 'delete':
                    await _deleteUser(user['id'], user['email'], user['name']);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: isAdmin ? 'make_user' : 'make_admin',
                  child: Row(
                    children: [
                      Icon(
                        isAdmin ? Icons.person : Icons.admin_panel_settings,
                        size: 18,
                        color: isAdmin ? Colors.blue : Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Text(isAdmin ? 'Make User' : 'Make Admin'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: isBlocked ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        isBlocked ? Icons.lock_open : Icons.block,
                        size: 18,
                        color: isBlocked ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(isBlocked ? 'Unblock User' : 'Block User'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Delete User'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}