import 'package:client_app/pages/invoices_page.dart';
import 'package:client_app/pages/policy_page.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionsPage extends StatelessWidget {
  const OptionsPage({super.key});

  void _showLogoutConfirmation(BuildContext parentContext) {
    showDialog(
      context: parentContext,
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
                _logout(parentContext);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _callSupport() async {
  final Uri phoneUri = Uri(scheme: 'tel', path: '0928082025');

  if (await canLaunchUrl(phoneUri)) {
    await launchUrl(phoneUri);
  }
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
          backgroundColor: Colors.redAccent[50],
  floatingActionButton: FloatingActionButton.extended(
    onPressed: _callSupport,
    backgroundColor: Colors.redAccent,
    icon: const Icon(Icons.phone, color: Colors.white),
    label: const Text(
      "الدعم الفني",
      style: TextStyle(color: Colors.white),
    ),
  ),
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
              leading: const Icon(Icons.receipt_long, color: Colors.redAccent),
              title: const Text("الفواتير"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesPage()));

              },
            ),
            ListTile(
              leading: const Icon(Icons.policy, color: Colors.redAccent),
              title: const Text("شروط الاستخدام"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyPage()));
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
