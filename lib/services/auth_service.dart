import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuthService {
  static bool isLoggedIn = false;
  static Map<String, dynamic>? clientData;
  static String? token;
  static String? playerId;
  static String? platform;

  /// Save session after successful signup/login
static Future<void> saveSession(Map<String, dynamic> client, String jwtToken, String? deviceId, String? platform) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('sessionToken', jwtToken);
  await prefs.setString('clientData', jsonEncode(client));
  clientData = client;
  token = jwtToken;
  isLoggedIn = true;

  if (client['id'] != null) {

    playerId = deviceId;
    if (playerId != null) await prefs.setString('playerId', playerId!);

    // Detect platform (if not already set)
    platform ??= Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'unknown';
    await prefs.setString('platform', platform);
  }
}


  /// Load session from local storage
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('sessionToken');
    final clientString = prefs.getString('clientData');
    playerId = prefs.getString('playerId');
    platform = prefs.getString('platform');

    if (token != null && clientString != null) {
      clientData = jsonDecode(clientString) as Map<String, dynamic>;
      isLoggedIn = true;

      if (clientData?['id'] != null) {


        await refreshWalletBalance();
      }
    } else {
      await clearSession();
    }
  }

  /// Logout client and clear session
  static Future<void> clearSession() async {
    final apiUrl = dotenv.env['API_URL'];

    try {
      if (clientData!['id'] != null) {
        // ignore: unused_local_variable
        final res = await http.delete(
          Uri.parse("${apiUrl}clients/removeDevice"),
          headers: {"Content-Type": "application/json", "authorization": "Bearer $token", 'x-api-key': '${dotenv.env['API_KEY']}'},
          body: jsonEncode({
            "client_id": clientData!['id'],
            "device_id": playerId,
          }),
        ); 
      }
    // ignore: empty_catches
    } catch (e) {
     
    }

    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    await prefs.remove('clientData');

    token = null;
    clientData = null;
    isLoggedIn = false;

    await OneSignal.logout();
  }

    static double get walletBalance {
      if (clientData == null) return 0.0; 
      final balanceString = clientData?['wallet_balance']?.toString() ?? '0';
      return double.tryParse(balanceString) ?? 0.0;
    }

  static String get fullName {
    return clientData?['full_name']?.toString() ?? '';
  }


  static Future<void> refreshWalletBalance() async {
    final apiUrl = dotenv.env['API_URL'];

    if (clientData == null || token == null) return;

    try {
      final response = await http.post(
        Uri.parse("${apiUrl}clients/getClientWallet"),
        headers: {
          "Content-Type": "application/json",
          "authorization": "Bearer $token",
          'x-api-key': '${dotenv.env['API_KEY']}'
        },
        body: jsonEncode({
          "client_id": clientData!['id'],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = double.tryParse(data['balance'].toString()) ?? 0;

        // Update memory
        clientData!['wallet_balance'] = balance;

        // Save updated user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('clientData', jsonEncode(clientData));

      } 
    // ignore: empty_catches
    } catch (e) {

    }
  }

}
