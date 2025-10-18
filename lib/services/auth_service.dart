import 'dart:convert';
import 'dart:io' show Platform;
import 'package:client_app/constants.dart';
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
static Future<void> saveSession(Map<String, dynamic> client, String jwtToken) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('sessionToken', jwtToken);
  await prefs.setString('clientData', jsonEncode(client));
  clientData = client;
  token = jwtToken;
  isLoggedIn = true;

  if (client['id'] != null) {
    await OneSignal.login(client['id'].toString());

    // Try to get playerId from OneSignal, fallback to existing value
    final oneSignalId = await OneSignal.User.getOnesignalId();
    playerId = oneSignalId ?? playerId; // keep main.dart value if OneSignal returns null
    if (playerId != null) await prefs.setString('playerId', playerId!);

    // Detect platform (if not already set)
    platform ??= Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : 'unknown';
    await prefs.setString('platform', platform!);
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
        await OneSignal.login(clientData!['id'].toString());

        // refresh playerId if missing
        if (playerId == null) {
          final id = await OneSignal.User.getOnesignalId();
          if (id != null) {
            playerId = id;
            await prefs.setString('playerId', playerId!);

            platform = Platform.isAndroid
                ? 'android'
                : Platform.isIOS
                    ? 'ios'
                    : 'unknown';
            await prefs.setString('platform', platform!);
          }
        }
      }
    } else {
      await clearSession();
    }
  }

  /// Logout client and clear session
static Future<void> clearSession() async {
  try {
    // Try removing device from backend before logout
    if (clientData!["id"] != null) {
      final url = Uri.parse('${apiUrl}clients/removeDevice');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'client_id': clientData!['id'],
        'device_id': playerId,
      });

      final _ = await http.delete(url, headers: headers, body: body);
    }

    // Unlink client from OneSignal
    await OneSignal.logout();

    // Clear local session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionToken');
    await prefs.remove('clientData');


    token = null;
    clientData = null;
    isLoggedIn = false;

  // ignore: empty_catches
  } catch (error) {
    
  }
}


  static double get walletBalance {
    if (clientData == null) return 0;
    return double.tryParse(clientData!['wallet_balance']?.toString() ?? '0') ?? 0;
  }

  static String get fullName {
    return clientData?['full_name']?.toString() ?? '';
  }
}
