// predict_page.dart
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
  int? _selectedResultIndex;
  Set<String> _highlightedPhrases = {};

  final String backendUrl = "http://192.168.0.111:8001/predict";
  List<bool> _expanded = [];

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
      _expanded = [];
      _selectedResultIndex = null;
      _highlightedPhrases = {};
    });

    try {
      final response = await http
          .post(Uri.parse(backendUrl),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"fir_text": firText, "top_k": _topK.toInt()}))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] ?? [];
        setState(() {
          _results = results;
          _expanded = List<bool>.filled(_results.length, false);
        });
      } else {
        final msg = response.body.isNotEmpty ? response.body : "Server error (${response.statusCode})";
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
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: full * pct,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF10B981), // green for high confidence
                    Color(0xFFF59E0B), // amber for medium
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<String> _parseTriggers(dynamic triggersField) {
    if (triggersField == null) return [];
    if (triggersField is List) {
      return triggersField.map((e) => e?.toString() ?? "").where((s) => s.isNotEmpty).toList();
    }
    final s = triggersField.toString();
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? "").where((t) => t.isNotEmpty).toList();
      }
    } catch (_) {}
    return [s];
  }

  bool _hasParseWarning(List<String> triggers) {
    return triggers.any((t) =>
        t.toLowerCase().contains("could_not_parse_groq_output") ||
        t.toLowerCase().startsWith("groq_error") ||
        t.toLowerCase().contains("could_not_parse") ||
        t.toLowerCase().contains("groq_not_installed"));
  }

  // Build highlighted FIR text
  Widget _buildHighlightedFIR() {
    final firText = _firController.text;
    if (firText.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_highlightedPhrases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          firText,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            height: 1.5,
            fontSize: 14,
          ),
        ),
      );
    }

    // === FIX: Handle overlapping phrases correctly ===
    // 1) Find all occurrences (case-insensitive)
    // 2) Sort by phrase length desc (prefer long), start asc
    // 3) Greedily select non-overlapping matches
    final lowerFir = firText.toLowerCase();
    final List<Map<String, dynamic>> allMatches = [];

    for (final rawPhrase in _highlightedPhrases) {
      final phrase = rawPhrase.trim();
      if (phrase.isEmpty) continue;
      final lowerPhrase = phrase.toLowerCase();

      int startIndex = lowerFir.indexOf(lowerPhrase);
      while (startIndex != -1) {
        final endIndex = startIndex + lowerPhrase.length;
        allMatches.add({
          'start': startIndex,
          'end': endIndex,
          'phrase': phrase,
          'length': lowerPhrase.length,
        });
        startIndex = lowerFir.indexOf(lowerPhrase, startIndex + 1);
      }
    }

    if (allMatches.isEmpty) {
      // nothing found in text
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          firText,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            height: 1.5,
            fontSize: 14,
          ),
        ),
      );
    }

    // Sort by length desc, then start asc so longer phrases win
    allMatches.sort((a, b) {
      final lenCmp = (b['length'] as int).compareTo(a['length'] as int);
      if (lenCmp != 0) return lenCmp;
      return (a['start'] as int).compareTo(b['start'] as int);
    });

    // Greedy selection: keep non-overlapping matches
    final List<Map<String, dynamic>> selected = [];
    for (final m in allMatches) {
      final int s = m['start'] as int;
      final int e = m['end'] as int;
      bool overlaps = false;
      for (final sel in selected) {
        final int ss = sel['start'] as int;
        final int ee = sel['end'] as int;
        if (!(e <= ss || s >= ee)) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) selected.add(m);
    }

    // Now sort selected matches by start for rendering in order
    selected.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    // Build TextSpans from selected matches
    final List<TextSpan> spans = [];
    int cursor = 0;
    for (final m in selected) {
      final int start = m['start'] as int;
      final int end = m['end'] as int;
      final String phrase = m['phrase'] as String;

      if (start > cursor) {
        spans.add(TextSpan(
          text: firText.substring(cursor, start),
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ));
      }

      // Use original casing in the substring for display
      final displayed = firText.substring(start, end);

      spans.add(TextSpan(
        text: displayed,
        style: const TextStyle(
          backgroundColor: Color(0xFFFBBF24), // amber highlight
          color: Color(0xFF0F172A), // dark text for contrast
          fontWeight: FontWeight.w700,
        ),
      ));

      cursor = end;
    }

    if (cursor < firText.length) {
      spans.add(TextSpan(
        text: firText.substring(cursor),
        style: TextStyle(color: Colors.white.withOpacity(0.85)),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.highlight, color: Colors.amber[400], size: 18),
              const SizedBox(width: 8),
              Text(
                "Key phrases highlighted",
                style: TextStyle(
                  color: Colors.amber[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white60,
                onPressed: () {
                  setState(() {
                    _highlightedPhrases.clear();
                    _selectedResultIndex = null;
                  });
                },
                tooltip: "Clear highlights",
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText.rich(
            TextSpan(children: spans),
            style: const TextStyle(height: 1.6, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggersSection(List<String> triggers, int resultIndex) {
    if (triggers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.white.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              "No specific trigger phrases identified",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final hasWarning = _hasParseWarning(triggers);
    final visible = triggers.where((t) =>
        !t.toLowerCase().startsWith("could_not_parse_groq_output") &&
        !t.toLowerCase().startsWith("groq_error") &&
        !t.toLowerCase().startsWith("groq_not_installed")).toList();

    if (visible.isEmpty && !hasWarning) return const SizedBox.shrink();

    final isSelected = _selectedResultIndex == resultIndex;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected 
            ? Colors.amber.withOpacity(0.15) 
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected 
              ? Colors.amber.withOpacity(0.4) 
              : Colors.white.withOpacity(0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Colors.amber[300]),
                    const SizedBox(width: 6),
                    Text(
                      "XAI Triggers",
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (visible.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        _selectedResultIndex = null;
                        _highlightedPhrases.clear();
                      } else {
                        _selectedResultIndex = resultIndex;
                        _highlightedPhrases = visible.toSet();
                      }
                    });

                    // Scroll to top to show FIR text
                    if (!isSelected) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        Scrollable.ensureVisible(
                          context,
                          duration: const Duration(milliseconds: 300),
                        );
                      });
                    }
                  },
                  icon: Icon(
                    isSelected ? Icons.highlight_off : Icons.highlight,
                    size: 16,
                    color: Colors.amber[400],
                  ),
                  label: Text(
                    isSelected ? "Clear" : "Highlight in FIR",
                    style: TextStyle(
                      color: Colors.amber[400],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          if (visible.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible.map((phrase) {
                final label = phrase.length > 35 ? "${phrase.substring(0, 33)}…" : phrase;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.amber[400]),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          if (hasWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "XAI returned non-standard output",
                      style: TextStyle(
                        color: Colors.orange[300],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Raw XAI Output"),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ').convert(triggers),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("Close"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text("View", style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double sim) {
    if (sim >= 0.5) return const Color(0xFF10B981); // green
    if (sim >= 0.3) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFEF4444); // red
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom AppBar
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(Icons.balance, color: Color(0xFF1E40AF), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quick Recommendations",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "FIR Analysis",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // FIR Input Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E40AF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.description,
                                  color: Color(0xFF60A5FA),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "FIR Description",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _firController,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white, height: 1.5),
                            decoration: InputDecoration(
                              hintText: "Enter FIR details: incident description, location, parties involved...",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Results: ${_topK.toInt()}",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: const Color(0xFF60A5FA),
                                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                                        thumbColor: const Color(0xFF3B82F6),
                                        overlayColor: const Color(0xFF3B82F6).withOpacity(0.2),
                                      ),
                                      child: Slider(
                                        value: _topK,
                                        min: 1,
                                        max: 6,
                                        divisions: 5,
                                        onChanged: (v) => setState(() => _topK = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: "Clear",
                                onPressed: () => setState(() {
                                  _firController.clear();
                                  _results.clear();
                                  _highlightedPhrases.clear();
                                  _selectedResultIndex = null;
                                }),
                                icon: const Icon(Icons.clear, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _getRecommendations,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E40AF),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
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
                                    const Icon(Icons.analytics, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLoading ? "Analyzing..." : "Analyze FIR",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Highlighted FIR section (shows when triggers are selected)
                    if (_highlightedPhrases.isNotEmpty) ...[
                      _buildHighlightedFIR(),
                      const SizedBox(height: 24),
                    ],

                    // Results Section
                    if (_results.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF10B981),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${_results.length} Matches Found",
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: jsonEncode(_results)));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Results copied to clipboard")),
                              );
                            },
                            icon: const Icon(Icons.copy_all, color: Colors.white70),
                            tooltip: "Copy all results",
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Results List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, idx) {
                          final r = _results[idx] ?? {};
                          final sim = (r['similarity'] is num)
                              ? (r['similarity'] as num).toDouble()
                              : 0.0;
                          final sectionId = r['section_id']?.toString() ?? "—";
                          final sectionText = r['section_text']?.toString() ?? "";
                          final triggers = _parseTriggers(r['triggers']);

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1E40AF),
                                            Color(0xFF3B82F6),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "§ $sectionId",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        sectionText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _similarityBar(sim),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getConfidenceColor(sim).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _getConfidenceColor(sim).withOpacity(0.4),
                                        ),
                                      ),
                                      child: Text(
                                        "${(sim * 100).toStringAsFixed(1)}% Match",
                                        style: TextStyle(
                                          color: _getConfidenceColor(sim),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: "Copy section",
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: "§$sectionId: $sectionText"),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Section copied")),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.copy,
                                        color: Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _expanded[idx] ? "Hide details" : "Show details",
                                      onPressed: () {
                                        setState(() {
                                          _expanded[idx] = !_expanded[idx];
                                        });
                                      },
                                      icon: Icon(
                                        _expanded[idx]
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_expanded[idx]) _buildTriggersSection(triggers, idx),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    if (!_isLoading && _results.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No results yet",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Enter FIR details and tap Analyze to get started",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Loading overlay
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF1E40AF),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Analyzing FIR...",
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Please wait",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
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
