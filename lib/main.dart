import 'dart:io';
import 'package:client_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/fields_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting('ar', null);
  
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!); 
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  // Ask for permission
  await OneSignal.Notifications.requestPermission(true);

// get OneSignal player id
final id = await OneSignal.User.getOnesignalId();
if (id != null && id.isNotEmpty) {
  AuthService.playerId = id;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('playerId', id);
}

// Detect platform early
AuthService.platform = Platform.isAndroid
    ? 'android'
    : Platform.isIOS
        ? 'ios'
        : 'unknown';

final prefs = await SharedPreferences.getInstance();
await prefs.setString('platform', AuthService.platform!);

  await AuthService.loadSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'courto manager',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        fontFamily: 'Changa',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
      ),

      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'), 
        Locale('en'), 
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },

      home: AuthService.isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}
