import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final user = FirebaseAuth.instance.currentUser;

  // Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // Mark all as read
  Future<void> _markAllAsRead() async {
    if (user == null) return;

    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'read': true});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All marked as read'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Delete notification
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Clear all notifications
  Future<void> _clearAll() async {
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Get notification color based on type/title
  Color _getNotificationColor(String title) {
    if (title.contains('🛒') || title.contains('Order')) return Colors.green;
    if (title.contains('⚠️') || title.contains('Stock')) return Colors.orange;
    if (title.contains('📢') || title.contains('Broadcast')) return Colors.purple;
    if (title.contains('💰') || title.contains('Price')) return Colors.amber;
    if (title.contains('👋') || title.contains('Welcome')) return Colors.blue;
    if (title.contains('Low Stock')) return Colors.orange;
    if (title.contains('Out of Stock')) return Colors.red;
    return Colors.indigo;
  }

  // Get notification icon based on type/title
  IconData _getNotificationIcon(String title) {
    if (title.contains('🛒') || title.contains('Order')) return Icons.shopping_cart;
    if (title.contains('⚠️') || title.contains('Stock')) return Icons.warning;
    if (title.contains('📢') || title.contains('Broadcast')) return Icons.campaign;
    if (title.contains('💰') || title.contains('Price')) return Icons.attach_money;
    if (title.contains('👋') || title.contains('Welcome')) return Icons.waving_hand;
    if (title.contains('Low Stock')) return Icons.inventory;
    if (title.contains('Out of Stock')) return Icons.remove_circle;
    return Icons.notifications;
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: Text('Please login to view notifications'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.teal, // Changed to teal for better look
        foregroundColor: Colors.white,
        actions: [
          // Mark all as read
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
          ),
          // Clear all
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user!.uid)
            .snapshots(), // NO orderBy - no index needed!
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('Error loading notifications'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
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
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Notifications will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Get notifications
          final notifications = snapshot.data!.docs.toList();

          // Sort manually by createdAt (newest first) - No index needed!
          notifications.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA = (dataA['createdAt'] as Timestamp?)?.toDate();
            final timeB = (dataB['createdAt'] as Timestamp?)?.toDate();
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Newest first
          });

          // Count unread
          final unreadCount = notifications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['read'] == false;
          }).length;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: Column(
              children: [
                // Unread count banner
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '$unreadCount new notification${unreadCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Notifications list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final doc = notifications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isRead = data['read'] == true;
                      final title = data['title'] ?? 'Notification';
                      final message = data['body'] ?? data['message'] ?? ''; // Support both body and message fields
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                      return Card(
                        elevation: isRead ? 0 : 2,
                        color: isRead ? Colors.grey[50] : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isRead ? Colors.grey[300]! : _getNotificationColor(title).withOpacity(0.3),
                            width: isRead ? 1 : 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _markAsRead(doc.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(title).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(title),
                                    color: _getNotificationColor(title),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: _getNotificationColor(title),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            createdAt != null ? timeago.format(createdAt) : 'Just now',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Delete button
                                PopupMenuButton(
                                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      onTap: () {
                                        Future.delayed(Duration.zero, () {
                                          _deleteNotification(doc.id);
                                        });
                                      },
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}