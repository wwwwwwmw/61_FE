import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';

class ProfileEditScreen extends StatefulWidget {
  final SharedPreferences prefs;
  const ProfileEditScreen({super.key, required this.prefs});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _avatarPath;
  String? _avatarUrl; // server avatar

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.prefs.getString(AppConstants.userNameKey) ?? '',
    );
    _avatarPath = widget.prefs.getString('user_avatar_path');
    _avatarUrl = widget.prefs.getString('user_avatar_url');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    // Let user choose camera or gallery
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Chọn từ thư viện'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Chụp bằng camera'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
        ]),
      ),
    );

    if (choice == null) return;
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      setState(() {
        _avatarPath = image.path;
        // When picking a new local image, ignore server avatar preview
        _avatarUrl = null;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      await widget.prefs.setString(AppConstants.userNameKey, name);

      // Upload avatar to backend (Postgres-first); fallback: store local path
      if (_avatarPath != null && _avatarPath!.isNotEmpty) {
        try {
          final api = ApiClient(widget.prefs);
          final formData = await api.multipart(
            path: '${AppConstants.apiPrefix}/users/me/avatar',
            filePath: _avatarPath!,
            fieldName: 'avatar',
          );
          final resp = await api.patchMultipart(
            '${AppConstants.apiPrefix}/users/me/avatar',
            formData,
          );
          final data = (resp.data is Map && resp.data['data'] != null)
              ? resp.data['data']
              : resp.data;
          final avatarUrl = (data is Map) ? data['avatarUrl'] : null;
          if (avatarUrl is String && avatarUrl.isNotEmpty) {
            await widget.prefs.setString('user_avatar_url', avatarUrl);
            await widget.prefs.remove('user_avatar_path');
            _avatarUrl = avatarUrl;
          } else {
            await widget.prefs.setString('user_avatar_path', _avatarPath!);
          }
        } catch (_) {
          await widget.prefs.setString('user_avatar_path', _avatarPath!);
        }
      }

      // Refresh user profile to ensure consistency
      try {
        final api = ApiClient(widget.prefs);
        final me = await api.get('${AppConstants.apiPrefix}/users/me');
        if (me.data is Map && me.data['success'] == true) {
          final d = me.data['data'];
          if (d is Map) {
            if (d['name'] is String) {
              await widget.prefs.setString(AppConstants.userNameKey, d['name']);
            }
            if (d['email'] is String) {
              await widget.prefs
                  .setString(AppConstants.userEmailKey, d['email']);
            }
            if (d['avatarUrl'] is String &&
                (d['avatarUrl'] as String).isNotEmpty) {
              await widget.prefs.setString('user_avatar_url', d['avatarUrl']);
              await widget.prefs.remove('user_avatar_path');
              _avatarUrl = d['avatarUrl'];
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật hồ sơ'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa hồ sơ'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: (() {
                      if (_avatarPath != null && _avatarPath!.isNotEmpty) {
                        return FileImage(File(_avatarPath!)) as ImageProvider<Object>;
                      }
                      if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
                        return NetworkImage(
                          '${AppConstants.baseUrl}${_avatarUrl!}',
                        ) as ImageProvider<Object>;
                      }
                      return null;
                    })(),
                    child: (_avatarPath == null || _avatarPath!.isEmpty) &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ tên',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập họ tên'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (tuỳ chọn)',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}
