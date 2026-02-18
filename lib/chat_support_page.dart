import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatSupportPage extends StatefulWidget {
  const ChatSupportPage({Key? key}) : super(key: key);

  @override
  State<ChatSupportPage> createState() => _ChatSupportPageState();
}

class _ChatSupportPageState extends State<ChatSupportPage> {
  User? _user;
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _chatId;
  bool _isAdmin = false;
  String? _selectedChatId;
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _checkAdmin();
    _getOrCreateChat();
  }

  Future<void> _checkAdmin() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      setState(() {
        _isAdmin = doc.data()?['role'] == 'admin';
      });
    } catch (e) {
      print('Error checking admin: $e');
    }
  }

  Future<void> _getOrCreateChat() async {
    if (_user == null || _isAdmin) return;

    try {
      final existingChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: _user!.uid)
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
            'userId': _user!.uid,
            'userName': _user!.displayName ?? _user!.email?.split('@')[0] ?? 'User',
            'userEmail': _user!.email,
            'adminId': admins.docs.first.id,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatId == null) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'chatId': _chatId,
        'senderId': _user!.uid,
        'senderName': _user!.displayName ?? _user!.email?.split('@')[0] ?? 'User',
        'senderRole': _isAdmin ? 'admin' : 'user',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return '';
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp.toDate();
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

  Future<void> _refreshData() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customer Support'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please login to use chat support'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'Support Chats' : 'Customer Support'),
        backgroundColor: Colors.teal,
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
        child: _isAdmin 
            ? _buildAdminChatList()
            : _buildUserChat(),
      ),
    );
  }

  Widget _buildAdminChatList() {
    return StreamBuilder<QuerySnapshot>(
      key: const Key('admin_chat_list'),
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('status', isEqualTo: 'active')
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
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
                const Text('Error loading chats'),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
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
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'No active chats',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When users start chatting, they will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chat = snapshot.data!.docs[index];
            var data = chat.data() as Map<String, dynamic>;
            bool isSelected = _selectedChatId == chat.id;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? Colors.teal.shade50 : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.teal : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    (data['userName']?[0] ?? 'U').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  data['userName'] ?? 'Unknown User',
                  style: TextStyle(
                    fontWeight: data['lastMessage'] != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['lastMessage'] ?? 'Tap to start chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data['lastMessageTime'] != null)
                      Text(
                        _getTimeAgo(data['lastMessageTime']),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/chat-detail',
                    arguments: {
                      'chatId': chat.id,
                      'userName': data['userName'],
                      'userId': data['userId'],
                      'userEmail': data['userEmail'],
                    },
                  ).then((_) {
                    setState(() {});
                  });
                },
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
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Connecting to support...'),
            const SizedBox(height: 8),
            Text(
              'Please wait while we connect you to an agent',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: Key('chat_messages_${_chatId ?? 'new'}'),
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where('chatId', isEqualTo: _chatId)
                .orderBy('timestamp')
                .snapshots(),
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
                      const Text('Error loading messages'),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                      Icon(Icons.chat, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Start a conversation',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Send a message to customer support',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var msg = snapshot.data!.docs[index];
                  var data = msg.data() as Map<String, dynamic>;
                  bool isMe = data['senderId'] == _user!.uid;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe)
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(Icons.support_agent, size: 16, color: Colors.teal),
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.teal : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['message'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(data['timestamp']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isMe) const SizedBox(width: 8),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.teal,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}