import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../pages/fields_page.dart'; // make sure this exists

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;
  String? errorMessage;

  Future<void> login() async {
    FocusScope.of(context).unfocus(); // dismiss keyboard
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final url = Uri.parse("http://192.168.3.180:3000/api/clients/login"); // adjust for device

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "phone_number": phoneController.text,
          "password": passController.text,
        }),
      );

      setState(() => loading = false);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        // Store session info
        AuthService.isLoggedIn = true;
        AuthService.clientData = data["client"];
        AuthService.token = data["token"];

        // Save token persistently
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwtToken", data["token"]);

        // Navigate to FieldsPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FieldsPage()),
        );
      } else {
        String message = "Login failed";
        try {
          final data = json.decode(res.body);
          if (data["error"] != null) message = data["error"];
        } catch (_) {}
        setState(() {
          errorMessage = message;
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = "Network error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_soccer, size: 100, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  "Football Field Manager",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red),
                ),
                const SizedBox(height: 40),

                // Phone field
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    prefixIcon: const Icon(Icons.phone),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password field
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Error message
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Text(
                      "Login",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
