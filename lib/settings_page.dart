import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crud/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  String _displayName = 'User';
  bool _isAdmin = false;
  
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
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        setState(() {
          _displayName = doc.data()?['name'] ?? user?.displayName ?? 'User';
          _isAdmin = doc.data()?['role'] == 'admin';
        });
      } else {
        setState(() {
          _displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
      });
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showError('No phone app found');
      }
    } catch (e) {
      print('Error launching phone: $e');
      _showError('Could not open phone app');
    }
  }

  Future<void> _clearCache() async {
    if (_isAdmin) {
      _showAdminCacheDialog();
    } else {
      _showUserCacheDialog();
    }
  }

  void _showUserCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear App Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'This will reset the following:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('Recently viewed products'),
            _buildBulletPoint('Search history'),
            _buildBulletPoint('App preferences'),
            _buildBulletPoint('Cache files'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'Your account, orders, and favorites will NOT be affected.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _performClearCache();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _showAdminCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.purple),
            SizedBox(width: 8),
            Text('Clear Cache'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Admin cache will be cleared:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('Temporary files'),
            _buildBulletPoint('App cache'),
            _buildBulletPoint('Search history'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: const Text(
                'All admin privileges and data remain intact.',
                style: TextStyle(color: Colors.purple, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _performClearCache();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _performClearCache() async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF1E3C72),
            ),
          ),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!_isAdmin && user != null) {
        try {
          final recentViews = await FirebaseFirestore.instance
              .collection('recently_viewed')
              .where('userId', isEqualTo: user!.uid)
              .get();
          
          for (var doc in recentViews.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          print('Error clearing recently viewed: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_isAdmin 
                      ? '✅ Cache cleared successfully' 
                      : '✅ App data reset successfully. You can start fresh!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showError('Error clearing cache: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDarkMode ? Colors.grey[900]! : Colors.grey.shade50,
                isDarkMode ? Colors.grey[850]! : Colors.white,
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3C72).withOpacity(0.1),
                        const Color(0xFF2A5298).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1E3C72).withOpacity(0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3C72).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            _displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? 'No email',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              if (_isAdmin) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.purple.shade400, Colors.purple.shade700],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Dark Mode Toggle
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDarkMode ? Colors.amber.withOpacity(0.1) : Colors.amber.shade50,
                        isDarkMode ? Colors.amber.withOpacity(0.05) : Colors.amber.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.amber.withOpacity(0.3) : Colors.amber.shade200,
                    ),
                  ),
                  child: SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.amber.withOpacity(0.2) : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    value: isDarkMode,
                    activeColor: Colors.amber.shade700,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Clear Cache Option
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDarkMode ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                        isDarkMode ? Colors.orange.withOpacity(0.05) : Colors.orange.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cleaning_services,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    title: Text(
                      _isAdmin ? 'Clear Cache' : 'Reset App Data',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _isAdmin 
                          ? 'Clear temporary files and cache' 
                          : 'Start fresh - clear all app data',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ),
                    onTap: _clearCache,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Help & Support Section
                _buildSectionHeader(
                  'Help & Support', 
                  Icons.help,
                  isDarkMode,
                ),
                const SizedBox(height: 12),
                
                // Phone
                _buildContactItem(
                  icon: Icons.phone,
                  color: Colors.green,
                  label: 'Phone',
                  value: '+92 300 1234567',
                  onTap: () => _launchPhone('+923001234567'),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                
                // Hours
                _buildContactItem(
                  icon: Icons.access_time,
                  color: Colors.orange,
                  label: 'Hours',
                  value: '24/7 Support Available',
                  onTap: null,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                
                // Location
                _buildContactItem(
                  icon: Icons.location_on,
                  color: Colors.teal,
                  label: 'Location',
                  value: 'Karachi, Pakistan',
                  onTap: null,
                  isDarkMode: isDarkMode,
                ),
                
                const SizedBox(height: 20),
                
                // Chat Support Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.teal, Colors.tealAccent],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/chat-support');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent),
                        const SizedBox(width: 8),
                        Text(
                          'Customer Support Chat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // FAQ Section
                _buildSectionHeader(
                  'Frequently Asked Questions', 
                  Icons.question_answer,
                  isDarkMode,
                ),
                const SizedBox(height: 12),
                
                _buildFAQItem(
                  question: 'How do I contact support?',
                  answer: 'You can reach us via phone or use the Customer Support Chat feature. Our team is available 24/7.',
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildFAQItem(
                  question: 'How do I reset my password?',
                  answer: 'Go to Login page and tap on "Forgot Password". Follow the instructions sent to your email.',
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildFAQItem(
                  question: 'How do I track my order?',
                  answer: 'Go to Profile > My Orders to view your order history and tracking information.',
                  isDarkMode: isDarkMode,
                ),
                
                const SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader(
                  'About', 
                  Icons.info,
                  isDarkMode,
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                        isDarkMode ? Colors.blue.withOpacity(0.05) : Colors.blue.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildAboutItem(
                        icon: Icons.info,
                        color: Colors.blue,
                        title: 'App Version',
                        value: '1.0.0+1',
                        isDarkMode: isDarkMode,
                      ),
                      const Divider(height: 1, indent: 60),
                      _buildAboutItem(
                        icon: Icons.update,
                        color: Colors.green,
                        title: 'Last Updated',
                        value: 'February 22, 2026',
                        isDarkMode: isDarkMode,
                      ),
                      const Divider(height: 1, indent: 60),
                      _buildAboutItem(
                        icon: Icons.code,
                        color: Colors.purple,
                        title: 'Developed By',
                        value: 'Huzaifa & Team',
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'Logout',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.purple.withOpacity(0.2) : Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              size: 20, 
              color: isDarkMode ? Colors.purple.shade200 : Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback? onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isDarkMode ? color.withOpacity(0.1) : color.withOpacity(0.05),
              isDarkMode ? color.withOpacity(0.05) : color.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? color.withOpacity(0.3) : color.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isDarkMode ? color : color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
            isDarkMode ? Colors.blue.withOpacity(0.05) : Colors.blue.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.blue.withOpacity(0.2) : Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.help,
              color: Colors.blue,
              size: 16,
            ),
          ),
          title: Text(
            question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }
}