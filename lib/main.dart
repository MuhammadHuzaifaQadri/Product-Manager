import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crud/firebase_options.dart';
import 'package:firebase_crud/products.dart';
import 'package:firebase_crud/add_product.dart';
import 'package:firebase_crud/login.dart';
import 'package:firebase_crud/signup.dart';
import 'package:firebase_crud/profile_page.dart';
import 'package:firebase_crud/favorites_page.dart';
import 'package:firebase_crud/recently_viewed_page.dart';
import 'package:firebase_crud/settings_page.dart';
import 'package:firebase_crud/admin_panel.dart';
import 'package:firebase_crud/analytics_page.dart';
import 'package:firebase_crud/qr_code_page.dart';
import 'package:firebase_crud/notifications_page.dart';
import 'package:firebase_crud/theme_provider.dart';
import 'package:firebase_crud/notification_service.dart';
import 'package:firebase_crud/splash_screen.dart';
import 'package:firebase_crud/forgot_password.dart';
import 'package:firebase_crud/wishlists_page.dart';
import 'package:firebase_crud/wishlist_detail_page.dart';
import 'package:firebase_crud/chat_support_page.dart';
import 'package:firebase_crud/chat_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request microphone permission at start
  await [Permission.microphone].request();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await NotificationService.initialize();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sub;
  String? _initialLink;
  bool _isInitialLinkHandled = false;
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _handleDeepLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleDeepLinks() async {
    try {
      _appLinks = AppLinks();
      
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('✅ Initial link: $initialUri');
        _initialLink = initialUri.toString();
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }

    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        print('✅ Link received: $uri');
        _handleLink(uri.toString());
      }
    }, onError: (error) {
      print('❌ Link error: $error');
    });
  }

  void _handleLink(String link) {
    if (!mounted) return;

    try {
      final Uri uri = Uri.parse(link);
      
      if (uri.scheme == 'myapp' && uri.host == 'product') {
        final productId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        
        if (productId != null && productId.isNotEmpty) {
          print('✅ Opening product: $productId');
          
          Navigator.of(context).pushNamed(
            '/products',
            arguments: {'openProductId': productId},
          );
        }
      }
    } catch (e) {
      print('❌ Error parsing link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Product Manager',
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          // 🔥 SplashScreen as home
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_isInitialLinkHandled && _initialLink != null) {
                  _isInitialLinkHandled = true;
                  _handleLink(_initialLink!);
                }
              });
              return const SplashScreen();
            },
          ),
          
          // Routes
          routes: {
            "/login": (context) => const Login(),
            "/signup": (context) => const Signup(),
            "/forgot-password": (context) => const ForgotPasswordPage(),
            "/products": (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final openProductId = args?['openProductId'] as String?;
              return Products(initialProductId: openProductId);
            },
            "/add": (context) => AddProduct(),
            "/profile": (context) => const ProfilePage(),
            "/favorites": (context) => const FavoritesPage(),
            "/recently_viewed": (context) => const RecentlyViewedPage(),
            "/settings": (context) => const SettingsPage(),
            "/notifications": (context) => const NotificationsPage(),
            "/admin": (context) => const AdminPanel(),
            "/analytics": (context) => const AnalyticsPage(),
            "/qr_codes": (context) => const QRCodePage(),
            "/wishlists": (context) => const WishlistsPage(),
            "/wishlist-detail": (context) => const WishlistDetailPage(),
            "/chat-support": (context) => const ChatSupportPage(),
            "/chat-detail": (context) => const ChatDetailPage(),
          },
        );
      },
    );
  }
}