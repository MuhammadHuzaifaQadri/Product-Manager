import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatSupportPage extends StatefulWidget {
  const ChatSupportPage({Key? key}) : super(key: key);

  @override
  State<ChatSupportPage> createState() => _ChatSupportPageState();
}

class _ChatSupportPageState extends State<ChatSupportPage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  bool _isAdmin = false;
  String? _chatId;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  
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
    _checkAdminAndSetup();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndSetup() async {
    if (user == null) return;
    await _checkAdmin();
    if (!_isAdmin) {
      await _getOrCreateChat();
    }
  }

  Future<void> _checkAdmin() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      setState(() {
        _isAdmin = doc.data()?['role'] == 'admin';
      });
    } catch (e) {
      print('Error checking admin: $e');
    }
  }

  Future<void> _getOrCreateChat() async {
    try {
      final existingChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        setState(() {
          _chatId = existingChats.docs.first.id;
        });
      } else {
        final admins = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();

        if (admins.docs.isNotEmpty) {
          final chatRef = await FirebaseFirestore.instance.collection('chats').add({
            'userId': user!.uid,
            'userName': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
            'userEmail': user!.email,
            'adminId': admins.docs.first.id,
            'adminName': admins.docs.first.data()['name'] ?? 'Admin',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'userUnread': false,
            'adminUnread': false,
          });

          setState(() {
            _chatId = chatRef.id;
          });
        }
      }
    } catch (e) {
      print('Error creating chat: $e');
    }
  }

  Future<void> _markChatAsRead(String chatId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'adminUnread': false,
        'userUnread': false,
      });
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  Future<void> _deleteChat(String chatId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Chat'),
          ],
        ),
        content: Text('Delete chat with $userName? All messages will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final messages = await FirebaseFirestore.instance
            .collection('messages')
            .where('chatId', isEqualTo: chatId)
            .get();
        
        for (var msg in messages.docs) {
          await msg.reference.delete();
        }
        
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Chat with $userName deleted'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error deleting chat: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error deleting chat'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      return timeago.format(timestamp.toDate());
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Customer Support',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat,
                  size: 60,
                  color: Colors.blue.shade200,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Please login to use chat support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAdmin ? 'Support Chats' : 'Customer Support',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isAdmin 
                  ? [Colors.purple.shade400, Colors.purple.shade700]
                  : [Colors.teal.shade400, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshData,
        color: _isAdmin ? Colors.purple : Colors.teal,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
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
            child: _isAdmin ? _buildAdminChatList() : _buildUserChat(),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('status', isEqualTo: 'active')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.purple,
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
                const Text('Error loading chats'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.purple.shade200,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No active chats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When users start chatting, they will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chat = snapshot.data!.docs[index];
            var data = chat.data() as Map<String, dynamic>;
            bool hasUnread = data['adminUnread'] == true;
            
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
              child: Dismissible(
                key: Key(chat.id),
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white, size: 30),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Chat'),
                      content: Text('Delete chat with ${data['userName']}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
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
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  return confirm;
                },
                onDismissed: (direction) {
                  _deleteChat(chat.id, data['userName']);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasUnread
                          ? [Colors.purple.shade50, Colors.white]
                          : [Colors.white, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasUnread ? Colors.purple : Colors.grey.shade200,
                      width: hasUnread ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: hasUnread ? Colors.purple : Colors.purple.shade100,
                          child: Text(
                            (data['userName']?[0] ?? 'U').toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: hasUnread ? Colors.white : Colors.purple,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '',
                                style: TextStyle(fontSize: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      data['userName'] ?? 'Unknown User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                        color: hasUnread ? Colors.purple.shade700 : Colors.black87,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          data['lastMessage'] ?? 'Tap to start chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? Colors.purple.shade600 : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        if (data['lastMessageTime'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: hasUnread ? Colors.purple.shade400 : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getTimeAgo(data['lastMessageTime']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasUnread ? Colors.purple.shade400 : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      _markChatAsRead(chat.id);
                      Navigator.pushNamed(
                        context,
                        '/chat-detail',
                        arguments: {
                          'chatId': chat.id,
                          'userName': data['userName'],
                          'userId': data['userId'],
                          'userEmail': data['userEmail'],
                          'isAdmin': true,
                        },
                      ).then((_) => setState(() {}));
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserChat() {
    if (_chatId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connecting to support...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat,
              size: 60,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chat started!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You can now chat with support',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/chat-detail',
                arguments: {
                  'chatId': _chatId,
                  'userName': 'Support Agent',
                  'userId': user!.uid,
                  'userEmail': user!.email,
                  'isAdmin': false,
                },
              );
            },
            icon: const Icon(Icons.chat),
            label: const Text('Open Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
              shadowColor: Colors.teal.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}