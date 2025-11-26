import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// IMPORTANT: Adjust this import to match your actual file structure
import 'create_case.dart'; 

// --- MODELS (Defined here to be accessible) ---

class CaseRecord {
  final String caseId;
  final String firNumber;
  final String complainantName;
  final String accusedName;
  final String incidentDate;
  final String registrationDate;
  final String firSummary;
  final String status; // 'under_investigation', 'chargesheet_filed', 'closed', 'pending'
  final String officerInCharge;
  final List<PredictedSection> predictedSections;
  final List<String> appliedSections;
  final String? remarks;

  CaseRecord({
    required this.caseId,
    required this.firNumber,
    required this.complainantName,
    required this.accusedName,
    required this.incidentDate,
    required this.registrationDate,
    required this.firSummary,
    required this.status,
    required this.officerInCharge,
    required this.predictedSections,
    required this.appliedSections,
    this.remarks,
  });
}

class PredictedSection {
  final String sectionId;
  final String sectionText;
  final double similarity;
  final List<String> triggers;

  PredictedSection({
    required this.sectionId,
    required this.sectionText,
    required this.similarity,
    required this.triggers,
  });
}

// --- MAIN PAGE ---

class CaseManagementPage extends StatefulWidget {
  const CaseManagementPage({super.key});

  @override
  State<CaseManagementPage> createState() => _CaseManagementPageState();
}

class _CaseManagementPageState extends State<CaseManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Sample realistic case data
  final List<CaseRecord> _cases = [
    CaseRecord(
      caseId: 'CASE-2024-0847',
      firNumber: 'FIR/2024/PS-ANDHERI/0847',
      complainantName: 'Rajesh Kumar Sharma',
      accusedName: 'Unknown (2-3 persons)',
      incidentDate: '2024-11-18',
      registrationDate: '2024-11-19',
      firSummary: 'Complainant was robbed at knifepoint near Andheri station at approximately 10:30 PM. Three unidentified males threatened with knife and took mobile phone, wallet containing Rs. 12,000 cash, and gold chain.',
      status: 'under_investigation',
      officerInCharge: 'SI Pradeep Jadhav',
      predictedSections: [
        PredictedSection(sectionId: '309(4)', sectionText: 'Robbery', similarity: 0.89, triggers: ['robbed', 'knifepoint', 'threatened']),
        PredictedSection(sectionId: '309(6)', sectionText: 'Robbery with attempt to cause death or grievous hurt', similarity: 0.72, triggers: ['knife', 'threatened']),
        PredictedSection(sectionId: '351(3)', sectionText: 'Criminal intimidation', similarity: 0.65, triggers: ['threatened', 'knifepoint']),
      ],
      appliedSections: ['309(4)', '351(3)'],
      remarks: 'CCTV footage obtained from nearby shop. Investigation ongoing.',
    ),
    CaseRecord(
      caseId: 'CASE-2024-0832',
      firNumber: 'FIR/2024/PS-ANDHERI/0832',
      complainantName: 'Sunita Devi Patel',
      accusedName: 'Manoj Patel (Husband)',
      incidentDate: '2024-11-15',
      registrationDate: '2024-11-15',
      firSummary: 'Complainant alleges physical assault and harassment by husband demanding additional dowry of Rs. 5 lakhs. Reports regular beatings over past 2 years. Medical examination confirms multiple injuries.',
      status: 'chargesheet_filed',
      officerInCharge: 'PSI Kavita Deshmukh',
      predictedSections: [
        PredictedSection(sectionId: '85', sectionText: 'Cruelty by husband or relatives', similarity: 0.94, triggers: ['harassment', 'husband', 'dowry', 'beatings']),
        PredictedSection(sectionId: '115(2)', sectionText: 'Voluntarily causing hurt', similarity: 0.78, triggers: ['physical assault', 'beatings', 'injuries']),
        PredictedSection(sectionId: '3(5)', sectionText: 'Dowry Prohibition Act', similarity: 0.82, triggers: ['dowry', 'demanding']),
      ],
      appliedSections: ['85', '115(2)', '3(5)'],
      remarks: 'Accused arrested on 16-Nov. Chargesheet submitted to court.',
    ),
    // ... (Your other sample cases remain here) ...
  ];

  List<CaseRecord> get _filteredCases {
    return _cases.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.firNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.complainantName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.accusedName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.caseId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || c.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'under_investigation': return const Color(0xFFF59E0B);
      case 'chargesheet_filed': return const Color(0xFF3B82F6);
      case 'closed': return const Color(0xFF10B981);
      case 'pending': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'under_investigation': return Icons.search;
      case 'chargesheet_filed': return Icons.description;
      case 'closed': return Icons.check_circle;
      case 'pending': return Icons.hourglass_empty;
      default: return Icons.help;
    }
  }

  void _showCaseDetails(CaseRecord caseRecord) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDetailPage(caseRecord: caseRecord),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const colorStart = Color(0xFF0F172A);
    const colorEnd = Color(0xFF1E293B);

    final stats = {
      'total': _cases.length,
      'investigation': _cases.where((c) => c.status == 'under_investigation').length,
      'chargesheet': _cases.where((c) => c.status == 'chargesheet_filed').length,
      'pending': _cases.where((c) => c.status == 'pending').length,
      'closed': _cases.where((c) => c.status == 'closed').length,
    };

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
                padding: const EdgeInsets.all(20.0),
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
                      child: const Icon(Icons.folder_open, color: Color(0xFF7C3AED), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Case Management",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "Track & Manage Cases",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        // --- UPDATED NAVIGATION LOGIC ---
                        final newCase = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateCasePage(),
                          ),
                        );

                        if (newCase != null && newCase is CaseRecord) {
                          setState(() {
                            _cases.insert(0, newCase);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Case ${newCase.caseId} added successfully'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ... (Rest of the file remains exactly the same as your code) ...
              // Stats Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _StatCard(label: 'Total', value: stats['total'].toString(), color: Colors.white, icon: Icons.folder),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Active', value: stats['investigation'].toString(), color: const Color(0xFFF59E0B), icon: Icons.search),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Filed', value: stats['chargesheet'].toString(), color: const Color(0xFF3B82F6), icon: Icons.description),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Closed', value: stats['closed'].toString(), color: const Color(0xFF10B981), icon: Icons.check_circle),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search and Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search cases...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                            prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          dropdownColor: const Color(0xFF1E293B),
                          icon: Icon(Icons.filter_list, color: Colors.white.withOpacity(0.7), size: 20),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'under_investigation', child: Text('Active')),
                            DropdownMenuItem(value: 'chargesheet_filed', child: Text('Filed')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'closed', child: Text('Closed')),
                          ],
                          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Cases List
              Expanded(
                child: _filteredCases.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_off, size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No cases found',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _filteredCases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final c = _filteredCases[idx];
                          return _CaseCard(
                            caseRecord: c,
                            statusColor: _getStatusColor(c.status),
                            statusLabel: _getStatusLabel(c.status),
                            statusIcon: _getStatusIcon(c.status),
                            onTap: () => _showCaseDetails(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... (Keep _StatCard, _CaseCard, CaseDetailPage, _SectionCard, _InfoRow classes exactly as they were in your code) ...
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final CaseRecord caseRecord;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final VoidCallback onTap;

  const _CaseCard({
    required this.caseRecord,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      caseRecord.caseId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                caseRecord.firNumber,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                caseRecord.firSummary,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'vs ${caseRecord.accusedName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    caseRecord.registrationDate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (caseRecord.appliedSections.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: caseRecord.appliedSections.take(4).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '§$s',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CaseDetailPage extends StatefulWidget {
  final CaseRecord caseRecord;

  const CaseDetailPage({super.key, required this.caseRecord});

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  late Set<String> _selectedSections;

  @override
  void initState() {
    super.initState();
    _selectedSections = widget.caseRecord.appliedSections.toSet();
  }

  Color _getConfidenceColor(double sim) {
    if (sim >= 0.8) return const Color(0xFF10B981);
    if (sim >= 0.6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'under_investigation': return const Color(0xFFF59E0B);
      case 'chargesheet_filed': return const Color(0xFF3B82F6);
      case 'closed': return const Color(0xFF10B981);
      case 'pending': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
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
    final c = widget.caseRecord;

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.caseId,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            c.firNumber,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(c.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getStatusColor(c.status).withOpacity(0.4)),
                      ),
                      child: Text(
                        _getStatusLabel(c.status),
                        style: TextStyle(
                          color: _getStatusColor(c.status),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Case Info Card
                      _SectionCard(
                        title: 'Case Information',
                        icon: Icons.info_outline,
                        child: Column(
                          children: [
                            _InfoRow(label: 'Complainant', value: c.complainantName),
                            _InfoRow(label: 'Accused', value: c.accusedName),
                            _InfoRow(label: 'Incident Date', value: c.incidentDate),
                            _InfoRow(label: 'Registration Date', value: c.registrationDate),
                            _InfoRow(label: 'Officer In-Charge', value: c.officerInCharge),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIR Summary
                      _SectionCard(
                        title: 'FIR Summary',
                        icon: Icons.description,
                        child: Text(
                          c.firSummary,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Predicted Sections with Selection
                      _SectionCard(
                        title: 'AI Predicted Sections',
                        icon: Icons.auto_awesome,
                        iconColor: Colors.amber,
                        headerAction: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_selectedSections.length == c.predictedSections.length) {
                                _selectedSections.clear();
                              } else {
                                _selectedSections = c.predictedSections.map((p) => p.sectionId).toSet();
                              }
                            });
                          },
                          icon: Icon(
                            _selectedSections.length == c.predictedSections.length
                                ? Icons.deselect
                                : Icons.select_all,
                            size: 16,
                            color: Colors.amber,
                          ),
                          label: Text(
                            _selectedSections.length == c.predictedSections.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                        child: Column(
                          children: c.predictedSections.map((ps) {
                            final isSelected = _selectedSections.contains(ps.sectionId);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : Colors.white.withOpacity(0.03),
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
                                        _selectedSections.remove(ps.sectionId);
                                      } else {
                                        _selectedSections.add(ps.sectionId);
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
                                                color: isSelected
                                                    ? const Color(0xFF10B981)
                                                    : Colors.transparent,
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
                                                '§${ps.sectionId}',
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
                                                color: _getConfidenceColor(ps.similarity).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${(ps.similarity * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  color: _getConfidenceColor(ps.similarity),
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
                                            ps.sectionText,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (ps.triggers.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 36),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: ps.triggers.map((t) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    t,
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
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Applied Sections Summary
                      _SectionCard(
                        title: 'Selected Sections (${_selectedSections.length})',
                        icon: Icons.gavel,
                        iconColor: const Color(0xFF10B981),
                        child: _selectedSections.isEmpty
                            ? Text(
                                'No sections selected. Tap on predicted sections above to select.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedSections.map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withOpacity(0.4),
                                      ),
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
                                          onTap: () {
                                            setState(() => _selectedSections.remove(s));
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: const Color(0xFF10B981).withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),

                      if (c.remarks != null && c.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Remarks',
                          icon: Icons.notes,
                          child: Text(
                            c.remarks!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final sectionsText = _selectedSections.join(', ');
                                Clipboard.setData(ClipboardData(
                                  text: 'Case: ${c.caseId}\nFIR: ${c.firNumber}\nSections: $sectionsText',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Case details copied')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sections updated: ${_selectedSections.join(", ")}',
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save, size: 18),
                              label: const Text('Save Sections'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? headerAction;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.child,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
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
                  color: (iconColor ?? const Color(0xFF3B82F6)).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor ?? const Color(0xFF60A5FA), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (headerAction != null) headerAction!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}