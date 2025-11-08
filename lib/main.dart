import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/predict_page.dart';

void main() {
  runApp(const BnsApp());
}

class BnsApp extends StatelessWidget {
  const BnsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIR to BNS Recommender',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/home': (context) => const HomePage(),
        '/predict': (context) => const PredictPage(),
      },
    );
  }
}
