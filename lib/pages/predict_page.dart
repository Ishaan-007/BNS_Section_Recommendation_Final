import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final TextEditingController _firController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _results = [];
  double _topK = 3;

  final String backendUrl = "http://192.168.0.111:8000/predict";

  @override
  void dispose() {
    _firController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    final firText = _firController.text.trim();
    if (firText.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please enter FIR text")));
      return;
    }

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final response = await http
          .post(Uri.parse(backendUrl),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"fir_text": firText, "top_k": _topK.toInt()}))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _results = data['results'] ?? []);
      } else {
        final msg =
            response.body.isNotEmpty ? response.body : "Server error (${response.statusCode})";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
      }
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _similarityBar(double sim) {
    final pct = sim.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, constraints) {
      final full = constraints.maxWidth;
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: full * pct,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const colorStart = Color(0xFF0F172A);
    const colorEnd = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: colorStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [colorStart, colorEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom AppBar Logo
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.balance,
                            color: Color(0xFF1E40AF),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LegalLens",
                              style: TextStyle(
                                fontFamily: "Garamond",
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Legal Intelligence System",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "FIR to BNS",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Paste the FIR description below. LegalLens will recommend top matching BNS sections.",
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 18),

                    // FIR Input Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Enter FIR text",
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _firController,
                                maxLines: 6,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "e.g. A man assaulted another near the market...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.02),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // top_k slider + clear
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Results to show: ${_topK.toInt()}",
                                          style: TextStyle(color: Colors.white.withOpacity(0.85)),
                                        ),
                                        Slider(
                                          activeColor: const Color(0xFF6366F1),
                                          inactiveColor: Colors.white12,
                                          value: _topK,
                                          min: 1,
                                          max: 6,
                                          divisions: 5,
                                          label: "${_topK.toInt()}",
                                          onChanged: (v) => setState(() => _topK = v),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    tooltip: "Clear text",
                                    onPressed: () => setState(() => _firController.clear()),
                                    icon: const Icon(Icons.clear, color: Colors.white70),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Analyze FIR button
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: _isLoading ? null : _getRecommendations,
                                      child: Ink(
                                        height: 52,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF06B6D4), Color(0xFF6366F1)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.28),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (_isLoading)
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else
                                                const Icon(Icons.search, color: Colors.white),
                                              const SizedBox(width: 12),
                                              Text(
                                                _isLoading ? "Analyzing..." : "Analyze FIR",
                                                style: const TextStyle(
                                                    color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    tooltip: "Open API docs",
                                    onPressed: () {},
                                    icon: const Icon(Icons.info_outline, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Results
                    if (_results.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Text("Top matches",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text("${_results.length} shown",
                                style: TextStyle(color: Colors.white.withOpacity(0.8))),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: jsonEncode(_results)));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text("Results copied")));
                              },
                              icon: const Icon(Icons.copy_all, color: Colors.white70),
                            )
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final r = _results[idx];
                          final sim = (r['similarity'] is num) ? (r['similarity'] as num).toDouble() : 0.0;
                          final sectionId = r['section_id']?.toString() ?? "—";
                          final sectionText = r['section_text']?.toString() ?? "";

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "S$sectionId",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        sectionText,
                                        style: TextStyle(color: Colors.white.withOpacity(0.95)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _similarityBar(sim),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text("${(sim * 100).toStringAsFixed(1)}%",
                                        style: TextStyle(color: Colors.white70)),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: "Copy section text",
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: sectionText));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Section copied")));
                                      },
                                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                                    ),
                                    IconButton(
                                      tooltip: "View raw JSON",
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Raw Result"),
                                            content: SingleChildScrollView(
                                                child: Text(
                                                    const JsonEncoder.withIndent('  ').convert(r))),
                                            actions: [
                                              TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text("Close"))
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.code, color: Colors.white70, size: 20),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      )
                    ],

                    if (!_isLoading && _results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Center(
                          child: Text(
                            "No results yet — enter FIR text and tap Analyze.",
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Loading overlay
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.35),
                    child: const Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Card(
                          color: Colors.white,
                          elevation: 12,
                          child: Padding(
                            padding: EdgeInsets.all(18.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
