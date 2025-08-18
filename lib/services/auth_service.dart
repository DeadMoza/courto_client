import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static bool isLoggedIn = false;
  static Map<String, dynamic>? clientData;
  static String? token;

  // Save token and client data persistently
  static Future<void> saveSession(Map<String, dynamic> client, String jwtToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessionToken', jwtToken);
    await prefs.setString('clientData', client.toString());
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
      isLoggedIn = true;
      clientData = _parseClientString(clientString);
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

  // Helper to convert string back to map
  static Map<String, dynamic> _parseClientString(String clientString) {
    // crude but works for simple flat map; replace with jsonDecode if stored as JSON
    final map = <String, dynamic>{};
    clientString.substring(1, clientString.length - 1).split(', ').forEach((pair) {
      final kv = pair.split(': ');
      map[kv[0]] = kv[1];
    });
    return map;
  }
}
