import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/fields_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ar', null);
  await AuthService.loadSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Changa',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),

      // 🌍 دعم اللغة العربية
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'), // العربية
        Locale('en'), // الإنجليزية
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: AuthService.isLoggedIn ? const FieldsPage() : const LoginPage(),
    );
  }
}
