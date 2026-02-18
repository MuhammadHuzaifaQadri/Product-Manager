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
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await NotificationService.initialize();
  
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          useInheritedMediaQuery: true,
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
          title: 'Product Manager',
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),  // 👈 SPLASH SCREEN LAGAO
          routes: {
            "/login": (context) => const Login(),
            "/signup": (context) => const Signup(),
            "/forgot-password": (context) => const ForgotPasswordPage(),
            "/products": (context) => Products(),
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