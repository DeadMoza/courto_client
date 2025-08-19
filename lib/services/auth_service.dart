import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static bool isLoggedIn = false;
  static Map<String, dynamic>? clientData;
  static String? token;

  // Save token and client data persistently
  static Future<void> saveSession(Map<String, dynamic> client, String jwtToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionToken', jwtToken);
    await prefs.setString('clientData', jsonEncode(client));
    clientData = client;
    token = jwtToken;
    isLoggedIn = true;
  }

  // Load token and client data on app start
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('sessionToken');
    final clientString = prefs.getString('clientData');

    if (token != null && clientString != null) {
      clientData = jsonDecode(clientString) as Map<String, dynamic>;
      isLoggedIn = true;
    } else {
      isLoggedIn = false;
    }
  }

  // Clear session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    await prefs.remove('clientData');
    token = null;
    clientData = null;
    isLoggedIn = false;
  }
}
