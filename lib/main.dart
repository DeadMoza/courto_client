import 'package:client_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'pages/fields_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await initializeDateFormatting('ar', null);
  
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!); 

  // Ask for permission
  await OneSignal.Notifications.requestPermission(true);

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
