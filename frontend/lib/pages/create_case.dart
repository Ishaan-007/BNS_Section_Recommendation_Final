import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// IMPORTANT: Update this import to match where you stored case_management_page.dart
// This allows CreateCasePage to know what a "CaseRecord" class is.
import 'case_management_page.dart'; 

class CreateCasePage extends StatefulWidget {
  const CreateCasePage({super.key});

  @override
  State<CreateCasePage> createState() => _CreateCasePageState();
}

class _CreateCasePageState extends State<CreateCasePage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Form Controllers
  final _complainantController = TextEditingController();
  final _accusedController = TextEditingController();
  final _firSummaryController = TextEditingController();
  final _officerController = TextEditingController();
  final _remarksController = TextEditingController();
  
  DateTime? _incidentDate;
  String _selectedStatus = 'under_investigation';
  
  // AI Prediction State
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  List<Map<String, dynamic>> _predictedSections = [];
  Set<String> _selectedSections = {};
  double _topK = 4;
  
  final String backendUrl = "http://192.168.0.111:8001/predict";

  @override
  void dispose() {
    _complainantController.dispose();
    _accusedController.dispose();
    _firSummaryController.dispose();
    _officerController.dispose();
    _remarksController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF7C3AED),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _incidentDate = picked);
    }
  }

  Future<void> _analyzeWithAI() async {
    final firText = _firSummaryController.text.trim();
    if (firText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter FIR summary first')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _predictedSections = [];
      _selectedSections = {};
    });

    try {
      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"fir_text": firText, "top_k": _topK.toInt()}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        
        setState(() {
          _predictedSections = results.map((r) {
            return {
              'section_id': r['section_id']?.toString() ?? '',
              'section_text': r['section_text']?.toString() ?? '',
              'similarity': (r['similarity'] is num) ? (r['similarity'] as num).toDouble() : 0.0,
              'triggers': _parseTriggers(r['triggers']),
            };
          }).toList();
          _hasAnalyzed = true;
        });

        // Scroll to results
        Future.delayed(const Duration(milliseconds: 200), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
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

  void _saveCase() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedSections.isEmpty && _hasAnalyzed) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('No Sections Selected', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You haven\'t selected any BNS sections. Do you want to save the case without sections?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Go Back', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performSave();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      return;
    }

    _performSave();
  }

  void _performSave() {
    // Generate case ID
    final caseId = 'CASE-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final firNumber = 'FIR/${DateTime.now().year}/PS-STATION/${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    // --- CREATE THE NEW OBJECT ---
    // Convert the raw map data to actual PredictedSection objects
    final predictedObjs = _predictedSections.map((map) {
      return PredictedSection(
        sectionId: map['section_id'],
        sectionText: map['section_text'],
        similarity: map['similarity'],
        triggers: map['triggers'] as List<String>,
      );
    }).toList();

    final newCase = CaseRecord(
      caseId: caseId,
      firNumber: firNumber,
      complainantName: _complainantController.text,
      accusedName: _accusedController.text,
      incidentDate: _incidentDate?.toString().split(' ')[0] ?? DateTime.now().toString().split(' ')[0],
      registrationDate: DateTime.now().toString().split(' ')[0],
      firSummary: _firSummaryController.text,
      status: _selectedStatus,
      officerInCharge: _officerController.text,
      predictedSections: predictedObjs,
      appliedSections: _selectedSections.toList(),
      remarks: _remarksController.text,
    );

    // Show success and return data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Case Created Successfully!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                caseId,
                style: const TextStyle(
                  color: Color(0xFFA78BFA),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              firNumber,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_selectedSections.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _selectedSections.take(5).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '§$s',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close Dialog
                // --- PASS DATA BACK ---
                Navigator.pop(context, newCase); // Close Page and return data
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double sim) {
    if (sim >= 0.8) return const Color(0xFF10B981);
    if (sim >= 0.6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'under_investigation': return 'Under Investigation';
      case 'chargesheet_filed': return 'Chargesheet Filed';
      case 'closed': return 'Closed';
      case 'pending': return 'Pending';
      default: return status;
    }
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
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                      child: const Icon(Icons.add_circle, color: Color(0xFF7C3AED), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create New Case",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Register FIR with AI Analysis",
                          style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Case Details Section
                        _buildSectionHeader('Case Details', Icons.info_outline),
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          controller: _complainantController,
                          label: 'Complainant Name',
                          hint: 'Enter complainant\'s full name',
                          icon: Icons.person,
                          required: true,
                        ),
                        const SizedBox(height: 14),
                        
                        _buildTextField(
                          controller: _accusedController,
                          label: 'Accused Name(s)',
                          hint: 'Enter accused name(s) or "Unknown"',
                          icon: Icons.person_off,
                          required: true,
                        ),
                        const SizedBox(height: 14),

                        // Date Picker
                        _buildDatePicker(),
                        const SizedBox(height: 14),

                        // Status Dropdown
                        _buildStatusDropdown(),
                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _officerController,
                          label: 'Officer In-Charge',
                          hint: 'e.g., SI Pradeep Jadhav',
                          icon: Icons.badge,
                          required: true,
                        ),

                        const SizedBox(height: 24),

                        // FIR Summary Section
                        _buildSectionHeader('FIR Summary', Icons.description),
                        const SizedBox(height: 12),
                        
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _firSummaryController,
                                maxLines: 6,
                                style: const TextStyle(color: Colors.white, height: 1.5),
                                decoration: InputDecoration(
                                  hintText: 'Enter detailed FIR description: incident details, location, time, how it happened, items involved...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'FIR summary is required' : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Results: ${_topK.toInt()}',
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          activeTrackColor: const Color(0xFF7C3AED),
                                          inactiveTrackColor: Colors.white.withOpacity(0.1),
                                          thumbColor: const Color(0xFFA78BFA),
                                          overlayColor: const Color(0xFF7C3AED).withOpacity(0.2),
                                          trackHeight: 4,
                                        ),
                                        child: Slider(
                                          value: _topK,
                                          min: 1,
                                          max: 6,
                                          divisions: 5,
                                          onChanged: (v) => setState(() => _topK = v),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 40,
                                      child: ElevatedButton.icon(
                                        onPressed: _isAnalyzing ? null : _analyzeWithAI,
                                        icon: _isAnalyzing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.auto_awesome, size: 18),
                                        label: Text(_isAnalyzing ? 'Analyzing...' : 'AI Analyze'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C3AED),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.grey,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // AI Predicted Sections
                        if (_hasAnalyzed) ...[
                          _buildSectionHeader(
                            'AI Recommended Sections (${_predictedSections.length})',
                            Icons.auto_awesome,
                            iconColor: Colors.amber,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to select sections to apply to this case',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          
                          ..._predictedSections.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final ps = entry.value;
                            final sectionId = ps['section_id'] as String;
                            final sectionText = ps['section_text'] as String;
                            final similarity = ps['similarity'] as double;
                            final triggers = ps['triggers'] as List<String>;
                            final isSelected = _selectedSections.contains(sectionId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF10B981).withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedSections.remove(sectionId);
                                      } else {
                                        _selectedSections.add(sectionId);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF10B981)
                                                      : Colors.white.withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                                                ),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '§$sectionId',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getConfidenceColor(similarity).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${(similarity * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  color: _getConfidenceColor(similarity),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 36),
                                          child: Text(
                                            sectionText,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (triggers.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 36),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: triggers.take(5).map((t) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    t.length > 25 ? '${t.substring(0, 23)}...' : t,
                                                    style: TextStyle(
                                                      color: Colors.amber[300],
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Selected Sections Summary
                          if (_selectedSections.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.gavel, color: const Color(0xFF10B981), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Selected: ${_selectedSections.length} sections',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () => setState(() => _selectedSections.clear()),
                                        child: Text(
                                          'Clear All',
                                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _selectedSections.map((s) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '§$s',
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            GestureDetector(
                                              onTap: () => setState(() => _selectedSections.remove(s)),
                                              child: const Icon(Icons.close, size: 14, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                        ],

                        // Remarks Section
                        _buildSectionHeader('Remarks (Optional)', Icons.notes),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _remarksController,
                          label: '',
                          hint: 'Add investigation notes, CCTV status, witness details...',
                          icon: Icons.edit_note,
                          maxLines: 3,
                          required: false,
                        ),

                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _saveCase,
                            icon: const Icon(Icons.save, size: 22),
                            label: const Text(
                              'Create Case',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildSectionHeader(String title, IconData icon, {Color? iconColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF3B82F6)).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor ?? const Color(0xFF60A5FA), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, height: 1.5),
        decoration: InputDecoration(
          labelText: label.isNotEmpty ? label : null,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null
            : null,
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.5), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _incidentDate != null
                    ? '${_incidentDate!.day.toString().padLeft(2, '0')}-${_incidentDate!.month.toString().padLeft(2, '0')}-${_incidentDate!.year}'
                    : 'Select Incident Date *',
                style: TextStyle(
                  color: _incidentDate != null ? Colors.white : Colors.white.withOpacity(0.4),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: Colors.white.withOpacity(0.5), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                dropdownColor: const Color(0xFF1E293B),
                isExpanded: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.5)),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                items: [
                  DropdownMenuItem(
                    value: 'under_investigation',
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Under Investigation'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Pending'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'chargesheet_filed',
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Chargesheet Filed'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'closed',
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Closed'),
                      ],
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'under_investigation'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}