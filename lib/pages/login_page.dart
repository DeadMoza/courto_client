import 'dart:convert';
import 'package:client_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;
  bool showPassword = false;
  final apiUrl = dotenv.env['API_URL'];

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    final url = Uri.parse("${apiUrl}clients/login");

    try {
      final deviceId = AuthService.playerId;
      final platform = AuthService.platform;
      String phone = phoneController.text.trim();

      if (phone.startsWith("09")) {
        phone = "218${phone.substring(1)}";
      } else if (phone.startsWith("9")) {
        phone = "218$phone";
      } else if (phone.startsWith("0")) {
        phone = "218${phone.substring(1)}";
      } else if (!phone.startsWith("218")) {
        phone = "218$phone";
      }

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", 'x-api-key': '${dotenv.env['API_KEY']}'},
        body: json.encode({
          "phone_number": phone,
          "password": passController.text,
          "device_id": deviceId,
          "platform": platform,
        }),
      );

      setState(() => loading = false);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        await AuthService.saveSession(data["client"], data["token"]);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        String message = "فشل تسجيل الدخول";
        try {
          final data = json.decode(res.body);
          if (data["error"] != null) message = data["error"];
        } catch (_) {}
        _showError(message);
      }
    } catch (_) {
      setState(() => loading = false);
      _showError("خطأ في الاتصال بالشبكة، يرجى التحقق من الاتصال بالإنترنت");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red[50],
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  Image.asset(
                    "assets/images/courto.png",
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 6),

                  const Text(
                    "مدير كورتو",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Phone field
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "رقم الهاتف",
                      prefixIcon: const Icon(Icons.phone, color: Colors.redAccent),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password field with toggle
                  TextField(
                    controller: passController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: "كلمة المرور",
                      prefixIcon: const Icon(Icons.lock, color: Colors.redAccent),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => showPassword = !showPassword);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        disabledBackgroundColor: Colors.red[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "تسجيل الدخول",
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "هل نسيت كلمة المرور؟",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
