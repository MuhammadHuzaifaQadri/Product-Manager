import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 🔥 REAL GOOGLE SVG
  static const String _googleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.18 1.48-4.97 2.31-8.16 2.31-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    else if (hour < 17) return 'Good Afternoon 🌤️';
    else if (hour < 21) return 'Good Evening 🌙';
    else return 'Good Night ✨';
  }

  Future<bool> _isFirstTimeLogin(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(userId).get();
      final lastLogin = userDoc.data()?['lastLogin'];
      final loginCount = userDoc.data()?['loginCount'] ?? 0;
      return lastLogin == null || loginCount <= 1;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateLastLogin(String userId, String userName) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        int loginCount = userDoc.data()?['loginCount'] ?? 0;
        await userRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'lastLoginFormatted': DateTime.now().toString(),
          'loginCount': loginCount + 1,
        });
      } else {
        await userRef.set({
          'email': _emailController.text.trim(),
          'name': userName,
          'lastLogin': FieldValue.serverTimestamp(),
          'lastLoginFormatted': DateTime.now().toString(),
          'loginCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
          'isBlocked': false,
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    else if (difference.inHours > 0) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    else if (difference.inMinutes > 0) return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    else return 'just now';
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await GoogleSignIn(
        clientId: '1061045299900-6im7b6b71ftbbt242qmcamsn9sbq6hoc.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      ).signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        clientId: '1061045299900-6im7b6b71ftbbt242qmcamsn9sbq6hoc.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      ).signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      final isBlocked = userDoc.data()?['isBlocked'] == true;

      if (isBlocked) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        if (mounted) {
          _showDialog(
            title: 'Account Blocked',
            content: 'Your account has been blocked by the administrator.',
            icon: Icons.block,
            color: Colors.red,
          );
        }
        setState(() => _isGoogleLoading = false);
        return;
      }

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'role': 'user',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'loginCount': 1,
          'lastLogin': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL ?? '',
          'loginMethod': 'google',
        });
      } else {
        int loginCount = userDoc.data()?['loginCount'] ?? 0;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': loginCount + 1,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Welcome, ${user.displayName ?? 'User'}! 🎉'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pushReplacementNamed(context, '/products');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final user = userCredential.user!;

        final deletedUserDoc = await FirebaseFirestore.instance
            .collection('deleted_users').doc(user.uid).get();
        if (deletedUserDoc.exists) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showDialog(
              title: 'Account Deleted',
              content: 'This account has been deleted by admin.',
              icon: Icons.delete_forever,
              color: Colors.red,
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        final isBlocked = userDoc.data()?['isBlocked'] == true;
        if (isBlocked) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            _showDialog(
              title: 'Account Blocked',
              content: 'Your account has been blocked by the administrator.',
              icon: Icons.block,
              color: Colors.red,
              extra: 'Email: ${_emailController.text}',
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          _showVerificationDialog(user);
          setState(() => _isLoading = false);
          return;
        }

        String userName = 'User';
        if (userDoc.exists) {
          userName = userDoc.data()?['name'] ?? user.displayName ?? user.email?.split('@')[0] ?? 'User';
        } else {
          userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        }

        final bool isFirstLogin = await _isFirstTimeLogin(user.uid);
        await _updateLastLogin(user.uid, userName);

        Timestamp? lastLoginTimestamp = userDoc.data()?['lastLogin'];
        String lastLoginMessage = '';
        if (lastLoginTimestamp != null) {
          final lastLoginDate = lastLoginTimestamp.toDate();
          lastLoginMessage = 'Last login: ${_formatDateTime(lastLoginDate)}';
        }

        if (mounted) {
          final greeting = _getTimeBasedGreeting();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(isFirstLogin ? Icons.emoji_people : Icons.favorite, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isFirstLogin ? '👋 Welcome, $userName!' : '🎉 Welcome Back, $userName!',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          lastLoginMessage.isNotEmpty ? lastLoginMessage : '$greeting! Great to see you.',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: isFirstLogin ? Colors.green : Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pushReplacementNamed(context, '/products');
        }
      } on FirebaseAuthException catch (e) {
        String message = '';
        if (e.code == 'user-not-found') message = 'No user found with this email.';
        else if (e.code == 'wrong-password') message = 'Wrong password provided.';
        else if (e.code == 'invalid-email') message = 'Invalid email address.';
        else if (e.code == 'too-many-requests') message = 'Too many attempts. Try again later.';
        else message = e.message ?? 'An error occurred';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showDialog({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    String? extra,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 16),
            Text(content, textAlign: TextAlign.center),
            if (extra != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(extra, style: TextStyle(color: color)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Email Not Verified'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.email, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text('Please verify your email before logging in.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(_emailController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Also check your SPAM folder', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await user.sendEmailVerification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email resent!'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Resend Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.mark_email_read, color: Colors.green),
              SizedBox(width: 8),
              Text('Password Reset'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.email, size: 40, color: Colors.green),
                ),
                const SizedBox(height: 16),
                const Text('Reset email sent!'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(_emailController.text),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error sending reset email';
      if (e.code == 'user-not-found') message = 'No user found with this email';
      else if (e.code == 'invalid-email') message = 'Invalid email address';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3C72).withOpacity(0.95),
              const Color(0xFF2A5298).withOpacity(0.95),
              const Color(0xFF1E3C72).withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E3C72).withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.shopping_bag_rounded, size: 50, color: Colors.white),
                            ),
                            const SizedBox(height: 30),
                            const Text('Welcome Back!',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72))),
                            const SizedBox(height: 8),
                            Text(_getTimeBasedGreeting(),
                                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            const SizedBox(height: 30),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E3C72)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF1E3C72), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your email';
                                if (!value.contains('@')) return 'Please enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1E3C72)),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF1E3C72), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your password';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3C72)),
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3C72),
                                  foregroundColor: Colors.white,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // 🔥 GOOGLE BUTTON REAL ICON
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: OutlinedButton(
                                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: _isGoogleLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.string(
                                            _googleSvg,
                                            width: 24,
                                            height: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Continue with Google',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3C72)),
                                  child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}