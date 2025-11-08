import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/section_card.dart';

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final TextEditingController _firController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _results = [];

  Future<void> _getRecommendations() async {
    final firText = _firController.text.trim();
    if (firText.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    final url = Uri.parse("http://192.168.0.111:8000/predict"); //CHANGE THIS TO YOUR BACKEND URL
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"fir_text": firText, "top_k": 3}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _results = data['results'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching results")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BNS Section Recommender')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _firController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Enter FIR text here...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Get Recommendations'),
              onPressed: _isLoading ? null : _getRecommendations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return SectionCard(
                      sectionId: r['section_id'],
                      sectionText: r['section_text'],
                      similarity: r['similarity'],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
