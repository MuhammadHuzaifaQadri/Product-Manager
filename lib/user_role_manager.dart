import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// User Role Manager - Handles Admin/User role management
class UserRoleManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // User roles
  static const String ROLE_ADMIN = 'admin';
  static const String ROLE_USER = 'user';

  /// Get current user's role
  static Future<String> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return ROLE_USER;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (userDoc.exists) {
        return userDoc.data()?['role'] ?? ROLE_USER;
      }
      
      // If user doc doesn't exist, create it with default role
      await createUserDoc(user.uid, ROLE_USER);
      return ROLE_USER;
    } catch (e) {
      print('Error getting user role: $e');
      return ROLE_USER;
    }
  }

  /// Check if current user is admin
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == ROLE_ADMIN;
  }

  /// Create user document in Firestore
  static Future<void> createUserDoc(String uid, String role, {String? name, String? email}) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'role': role,
        'name': name ?? 'User',
        'email': email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ User document created: $uid with role: $role');
    } catch (e) {
      print('❌ Error creating user doc: $e');
    }
  }

  /// Update user role (Admin only)
  static Future<bool> updateUserRole(String uid, String newRole) async {
    try {
      // Check if current user is admin
      final isCurrentUserAdmin = await isAdmin();
      if (!isCurrentUserAdmin) {
        print('❌ Permission denied: Only admins can change roles');
        return false;
      }

      await _firestore.collection('users').doc(uid).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ User role updated: $uid → $newRole');
      return true;
    } catch (e) {
      print('❌ Error updating user role: $e');
      return false;
    }
  }

  /// Get all users (Admin only)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final isCurrentUserAdmin = await isAdmin();
      if (!isCurrentUserAdmin) {
        print('❌ Permission denied: Only admins can view all users');
        return [];
      }

      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  /// Initialize user on signup
  static Future<void> initializeUser(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        // Check if this is the first user (make them admin)
        final allUsers = await _firestore.collection('users').get();
        final role = allUsers.docs.isEmpty ? ROLE_ADMIN : ROLE_USER;
        
        await createUserDoc(
          user.uid,
          role,
          name: user.displayName ?? 'User',
          email: user.email ?? '',
        );
        
        print('✅ Initialized user: ${user.uid} as $role');
      }
    } catch (e) {
      print('❌ Error initializing user: $e');
    }
  }

  /// Get user display name
  static Future<String> getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Guest';

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['name'] ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  /// Update user name
  static Future<bool> updateUserName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('❌ Error updating user name: $e');
      return false;
    }
  }
}