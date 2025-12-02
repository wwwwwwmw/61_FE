import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/login_screen.dart';
import '../categories/category_list_screen.dart'; // Import màn hình danh mục
import 'profile_edit_screen.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.prefs,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AuthService _authService;
  late bool _isDark;
  String? _avatarPath;
  String? _avatarUrl;
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _authService = AuthService(widget.prefs);
    _loadStateFromPrefs();
  }

  void _loadStateFromPrefs() {
    _isDark = widget.prefs.getString(AppConstants.themeKey) == 'dark';
    _userName = widget.prefs.getString(AppConstants.userNameKey) ?? 'User';
    _userEmail = widget.prefs.getString(AppConstants.userEmailKey) ?? '';
    _avatarPath = widget.prefs.getString('user_avatar_path');
    _avatarUrl = widget.prefs.getString('user_avatar_url');
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(prefs: widget.prefs)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh values from prefs in build in case external changes happened
    _loadStateFromPrefs();

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  (() {
                    ImageProvider<Object>? img;
                    if (_avatarPath != null && _avatarPath!.isNotEmpty) {
                      img = FileImage(File(_avatarPath!));
                    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
                      final bust = DateTime.now().millisecondsSinceEpoch;
                      img = NetworkImage(
                        '${AppConstants.baseUrl}${_avatarUrl!}?t=$bust',
                      );
                    }
                    return CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: img,
                      child: img == null
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    );
                  })(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _userEmail,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings Options
          const Text(
            'Chung',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Giao diện tối'),
                  trailing: Switch(
                    value: _isDark,
                    onChanged: (value) {
                      setState(() => _isDark = value);
                      // Đặt chế độ theo giá trị mới để tránh lệch với ThemeMode.system
                      widget.onThemeChanged(value);
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1),
                // [FIX] Mục Quản lý Danh mục
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Quản lý Danh mục'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryListScreen(prefs: widget.prefs),
                      ),
                    ).then((_) => setState(() {}));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Sửa hồ sơ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileEditScreen(prefs: widget.prefs),
                      ),
                    ).then((changed) {
                      if (changed == true) setState(() {});
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label:
                  const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
