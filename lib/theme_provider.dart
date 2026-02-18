import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme Provider - Manages Light/Dark mode
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  /// Get light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ).copyWith(
        surface: Colors.white,
        surfaceContainerHighest: Colors.grey[50],
      ),
      cardTheme: const CardThemeData(  // ✅ FIXED: CardTheme -> CardThemeData
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[300]!,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        tileColor: Colors.transparent,
      ),
    );
  }

  /// Get dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF1E1E1E),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        primary: Colors.blue.shade300,
        secondary: Colors.orange.shade300,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: const CardThemeData(  // ✅ FIXED: CardTheme -> CardThemeData
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Color(0xFF1E1E1E),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[800]!,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        tileColor: Colors.transparent,
        iconColor: Colors.blue.shade300,
        textColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.blue.shade300,
        unselectedItemColor: Colors.grey[500],
      ),
      tabBarTheme: const TabBarThemeData(  // ✅ FIXED: TabBarTheme -> TabBarThemeData
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.blue,
      ),
    );
  }

  /// Get current theme colors based on mode
  Color get primaryColor => _isDarkMode ? Colors.blue.shade300 : Colors.blue;
  Color get backgroundColor => _isDarkMode ? const Color(0xFF121212) : Colors.grey[50]!;
  Color get cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor => _isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  Color get dividerColor => _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
  Color get iconColor => _isDarkMode ? Colors.blue.shade300 : Colors.blue;
  Color get surfaceColor => _isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
}