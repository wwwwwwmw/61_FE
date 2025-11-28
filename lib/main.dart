import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize date formatting
  await initializeDateFormatting('vi_VN', null);
  
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  
  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() {
    final theme = widget.prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = theme == 'dark'
          ? ThemeMode.dark
          : theme == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
    });
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        widget.prefs.setString('theme_mode', 'dark');
      } else {
        _themeMode = ThemeMode.light;
        widget.prefs.setString('theme_mode', 'light');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final accessToken = widget.prefs.getString('access_token');
    final isLoggedIn = accessToken != null && accessToken.isNotEmpty;

    return MaterialApp(
      title: 'Ứng Dụng Tiện Ích',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: isLoggedIn 
          ? HomeScreen(prefs: widget.prefs, onThemeToggle: _toggleTheme)
          : LoginScreen(prefs: widget.prefs),
    );
  }
}
