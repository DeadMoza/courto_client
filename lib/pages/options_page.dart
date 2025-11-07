import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("تسجيل الخروج؟"),
          actions: <Widget>[
            TextButton(
              child: const Text('لا'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('نعم', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _logout(context);
              },
            ),
          ],
        );
      },
    );
  }

    void _logout(BuildContext context) async {
    // Perform session clear
    await AuthService.clearSession();

    // Navigate to Signup and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red[50],
        appBar: AppBar(
          title: const Text(
            "الخيارات",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.support_agent_rounded, color: Colors.redAccent),
              title: const Text("المساعدة و الدعم"),
              onTap: () {
                // TODO: open profile page later
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy, color: Colors.redAccent),
              title: const Text("شروط الاستخدام"),
              onTap: () {
                
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("تسجيل الخروج"),
              onTap: () => _showLogoutConfirmation(context)
              ,
            ),
          ],
        ),
      ),
    );
  }
}
