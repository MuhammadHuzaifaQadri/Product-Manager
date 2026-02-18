import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crud/products.dart';
import 'package:firebase_crud/login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => Products()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Login()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1976D2), // Darker blue
              Color(0xFF42A5F5), // Medium blue
              Color(0xFF90CAF9), // Light blue
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_rounded,
                size: 70,
                color: Color(0xFF1976D2),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // App Name
            const Text(
              'Product Manager',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Tagline
            const Text(
              'Manage Your Products with Ease',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Loading Indicator
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            
            const SizedBox(height: 20),
            
            // Version
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}