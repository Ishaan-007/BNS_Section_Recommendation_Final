import 'package:fir_bns_app_frontend/pages/home_page.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gavel_rounded, size: 100, color: Colors.indigo),
              const SizedBox(height: 20),
              Text(
                'FIR → BNS Recommender',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Get the best matching legal sections by simply describing the FIR.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Get Started'),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const HomePage()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
