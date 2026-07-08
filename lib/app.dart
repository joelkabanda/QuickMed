import 'package:flutter/material.dart';
import 'features/authentication/screens/splash_screen.dart';

class QuickMedApp extends StatelessWidget {
  const QuickMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Quick Med",
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
