import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../screens/home/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService(); // Giả sử bạn đã khởi tạo đúng
  bool _isLoading = false;

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
        MaterialPageRoute(builder: (_) => const HomeScreen(prefs: null,, onThemeToggle: () {  },)),
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
