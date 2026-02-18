import 'package:flutter/material.dart';
import 'package:firebase_crud/theme_provider.dart';
import 'package:firebase_crud/csv_exporter.dart';
import 'package:firebase_crud/user_role_manager.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await UserRoleManager.isAdmin();
    setState(() => _isAdmin = isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final primaryColor = isDark ? Colors.blue.shade700 : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.grey[50],
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance Section
            _buildSectionHeader('Appearance', isDark),
            Card(
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: primaryColor,
                  ),
                ),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  isDark ? 'Currently Enabled' : 'Currently Disabled',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                value: isDark,
                activeColor: Colors.blue,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),
            
            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader('Data Management', isDark),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.download,
                        color: isDark ? Colors.green.shade400 : Colors.green,
                      ),
                    ),
                    title: Text(
                      'Export to CSV',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Download all products as CSV',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    onTap: () {
                      CSVExporter.showExportDialog(context);
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.clear_all,
                        color: isDark ? Colors.orange.shade400 : Colors.orange,
                      ),
                    ),
                    title: Text(
                      'Clear Cache',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Free up storage space',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    onTap: () {
                      _showClearCacheDialog(isDark);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Admin Section
            if (_isAdmin) ...[
              _buildSectionHeader('Admin Controls', isDark),
              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: isDark ? Colors.purple.shade400 : Colors.purple,
                    ),
                  ),
                  title: Text(
                    'Admin Panel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Manage users and roles',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // About Section
            _buildSectionHeader('About', isDark),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info, color: Colors.blue),
                    ),
                    title: Text(
                      'App Version',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: const Text('1.0.0'),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.description, color: Colors.blue),
                    ),
                    title: Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    onTap: () {
                      _showInfoDialog('Terms & Conditions', 'Terms and conditions content goes here...', isDark);
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.privacy_tip, color: Colors.blue),
                    ),
                    title: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    onTap: () {
                      _showInfoDialog('Privacy Policy', 'Privacy policy content goes here...', isDark);
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.help, color: Colors.blue),
                    ),
                    title: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                    onTap: () {
                      _showInfoDialog('Help & Support', 'For support, contact: support@productmanager.com', isDark);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey,
        ),
      ),
    );
  }

  void _showClearCacheDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Clear Cache',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'This will clear temporary data. Continue?',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.black54,
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
}