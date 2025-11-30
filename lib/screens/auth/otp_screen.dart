import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/auth_service.dart';
import '../../screens/home/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final SharedPreferences prefs;
  final VoidCallback onThemeToggle;
  const OtpScreen(
      {super.key,
      required this.email,
      required this.prefs,
      required this.onThemeToggle});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  late final AuthService _authService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(widget.prefs);
  }

  void _verify() async {
    setState(() => _isLoading = true);
    final success = await _authService.verifyOtp(
      widget.email,
      _otpController.text,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      // Chuyển đến trang chủ và xóa hết stack cũ
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            prefs: widget.prefs,
            onThemeToggle: widget.onThemeToggle,
          ),
        ),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP sai hoặc hết hạn')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xác thực OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("Mã OTP đã được gửi đến ${widget.email}"),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: "Nhập mã OTP"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verify,
                    child: const Text("Xác nhận"),
                  ),
          ],
        ),
      ),
    );
  }
}
