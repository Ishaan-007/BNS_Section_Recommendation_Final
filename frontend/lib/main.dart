import 'package:fir_bns_app_frontend/pages/case_management_page.dart';
import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/predict_page.dart';
import 'pages/bns_search_page.dart';

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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/home': (context) => const HomePage(),
        '/predict': (context) => const PredictPage(),
        '/bns_search': (context) => const BnsSearchPage(),
        '/case_management_page': (context) => const CaseManagementPage(), // Placeholder for Case Management Page
      },
    );
  }
}
