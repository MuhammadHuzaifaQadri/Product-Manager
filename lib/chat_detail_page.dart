import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({Key? key}) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String chatId;
  late String userName;
  late String userId;
  bool isAdmin = false;
  final user = FirebaseAuth.instance.currentUser;
  
  late AnimationController _animationController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    chatId = args['chatId'];
    userName = args['userName'] ?? 'User';
    userId = args['userId'] ?? '';
    isAdmin = args['isAdmin'] ?? false;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: user!.uid)
          .get();

      for (var msg in unreadMessages.docs) {
        await msg.reference.update({'isRead': true});
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'chatId': chatId,
        'senderId': user!.uid,
        'senderName': user!.displayName ?? user!.email?.split('@')[0] ?? 'User',
        'message': message,
        'type': 'text',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _updateChatLastMessage(message);
      _scrollToBottom();
      
      // Trigger animation
      _animationController.forward().then((_) {
        _animationController.reset();
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _updateChatLastMessage(String message) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.teal.shade100,
                child: Text(
                  userName[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAdmin ? Colors.purple : Colors.teal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAdmin 
                  ? [Colors.purple.shade400, Colors.purple.shade700]
                  : [Colors.teal.shade400, Colors.teal.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
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
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .where('chatId', isEqualTo: chatId)
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
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
                              color: isAdmin ? Colors.purple.shade50 : Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat,
                              size: 50,
                              color: isAdmin ? Colors.purple : Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send a message to start the conversation',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
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
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var msg = snapshot.data!.docs[index];
                      var data = msg.data() as Map<String, dynamic>;
                      bool isMe = data['senderId'] == user!.uid;
                      bool showAvatar = index == 0 || 
                          (snapshot.data!.docs[index - 1].data() as Map<String, dynamic>)['senderId'] != data['senderId'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: showAvatar
                                    ? CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.teal.shade100,
                                        child: Text(
                                          (data['senderName']?[0] ?? 'A').toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? Colors.purple : Colors.teal,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(width: 32),
                              ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isMe
                                        ? [Colors.teal.shade400, Colors.teal.shade600]
                                        : [Colors.grey.shade100, Colors.grey.shade200],
                                  ),
                                  borderRadius: BorderRadius.circular(20).copyWith(
                                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isMe ? Colors.teal : Colors.grey).withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showAvatar && !isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          data['senderName'] ?? 'User',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? Colors.purple.shade700 : Colors.teal.shade700,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      data['message'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isMe ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(data['timestamp']),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isMe ? Colors.white70 : Colors.grey[600],
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.done_all,
                                            size: 12,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: showAvatar
                                    ? CircleAvatar(
                                        radius: 16,
                                        backgroundColor: isAdmin ? Colors.purple.shade100 : Colors.teal.shade100,
                                        child: Text(
                                          user!.displayName?[0]?.toUpperCase() ?? 'U',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? Colors.purple : Colors.teal,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(width: 32),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAdmin 
                            ? [Colors.purple.shade400, Colors.purple.shade600]
                            : [Colors.teal.shade400, Colors.teal.shade600],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.emoji_emotions, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _messageController.text.isNotEmpty
                            ? [Colors.teal.shade400, Colors.teal.shade600]
                            : [Colors.grey.shade300, Colors.grey.shade400],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}