import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// loan_history_screen.dart  —  Loan / Advance History
// ═══════════════════════════════════════════════════════════════════════════

// ── Model ──────────────────────────────────────────────────────────────────
class LoanRecord {
  final String empId;
  final String empName;
  final String companyCode;
  final int    loanAmount;
  final String deductionMethod;
  final String reason;
  final String requestDate;
  final String time;
  final String customMethod;
  final String installmentAmount;
  final String status;

  const LoanRecord({
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.loanAmount,
    required this.deductionMethod,
    required this.reason,
    required this.requestDate,
    required this.time,
    required this.customMethod,
    required this.installmentAmount,
    required this.status,
  });

  factory LoanRecord.fromJson(Map<String, dynamic> j) {
    int parseAmt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString().replaceAll(',', '')) ?? 0;
    }
    String s(dynamic v) => v?.toString().trim() ?? '';

    return LoanRecord(
      empId:             s(j['EMP_ID']            ?? j['emp_id']),
      empName:           s(j['EMP_NAME']          ?? j['emp_name']),
      companyCode:       s(j['COMPANY_CODE']      ?? j['company_code']),
      loanAmount:        parseAmt(j['LOAN_AMOUNT'] ?? j['loan_amount']),
      deductionMethod:   s(j['DEDUCTION_METHOD']  ?? j['deduction_method']),
      reason:            s(j['REASON']            ?? j['reason']),
      requestDate:       s(j['REQUEST_DATE']      ?? j['request_date']),
      time:              s(j['TIME']              ?? j['time']),
      customMethod:      s(j['CUSTOM_METHOD']     ?? j['custom_method']),
      installmentAmount: s(j['INSTALLMENT_AMOUNT'] ?? j['installment_amount']),
      status:            s(j['STATUS']            ?? j['status'] ?? 'Pending'),
    );
  }

  // ── Computed date/time display ──────────────────────────────────────────
  String get _datePart {
    if (requestDate.isEmpty) return '';
    // Oracle ORDS may return "2026-02-10T11:00:00" or plain "2026-02-10"
    return requestDate.contains('T') ? requestDate.split('T')[0] : requestDate;
  }

  String get _timePart {
    if (time.isNotEmpty) return time;
    // Fallback: extract HH:MM from ISO datetime
    if (requestDate.contains('T')) {
      final t = requestDate.split('T')[1];
      final parts = t.split(':');
      if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    }
    return '';
  }

  String get displayDateTime {
    final d = _datePart;
    final t = _timePart;
    if (d.isEmpty) return '—';
    return t.isNotEmpty ? '$d $t' : d;
  }
}

// ── Service ────────────────────────────────────────────────────────────────
class LoanHistoryService {
  static const _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/loan/get/';

  static Future<List<LoanRecord>> fetchHistory({
    required String empId,
    required String companyCode,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'emp_id': empId, 'company_code': companyCode},
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return _parseBody(response.body);
    }
    throw Exception('Server returned ${response.statusCode}');
  }

  static List<LoanRecord> _parseBody(String body) {
    final data = jsonDecode(body);
    List<dynamic> items;

    if (data is Map<String, dynamic>) {
      // Oracle ORDS standard: {"items":[...], "hasMore":false, ...}
      final raw = data['items'] ?? data['data'] ?? data['rows'];
      if (raw is List) {
        items = raw;
      } else {
        // Fallback: single object returned
        items = [data];
      }
    } else if (data is List) {
      items = data;
    } else {
      return [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(LoanRecord.fromJson)
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════
class LoanHistoryScreen extends StatefulWidget {
  const LoanHistoryScreen({super.key});

  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
  static const _bg      = AppColors.surface;
  static const _primary = AppColors.cyan;

  String           _empId       = '';
  String           _companyCode = '';
  List<LoanRecord> _records     = [];
  bool             _loading     = true;
  String?          _error;

  // ── View state ─────────────────────────────────────────────────────────
  bool   _simpleView       = true;
  bool   _filtersExpanded  = false;
  String _statusFilter     = 'All';

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  // ── SharedPreferences helpers ──────────────────────────────────────────
  static String? _safeGet(SharedPreferences p, String key) {
    try {
      final v = p.get(key)?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) { return null; }
  }

  static String _fallback(SharedPreferences p, List<String> keys) {
    for (final k in keys) {
      final v = _safeGet(p, k);
      if (v != null) return v;
    }
    return '';
  }

  Future<void> _loadAndFetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs  = await SharedPreferences.getInstance();
      _empId       = _fallback(prefs, ['userId', 'emp_id', 'employeeId']);
      _companyCode = _fallback(prefs, ['companyCode', 'company_code']);
      final list   = await LoanHistoryService.fetchHistory(
        empId: _empId, companyCode: _companyCode,
      );
      setState(() { _records = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Filtered list ──────────────────────────────────────────────────────
  List<LoanRecord> get _filtered {
    if (_statusFilter == 'All') return _records;
    return _records
        .where((r) => r.status.toLowerCase() == _statusFilter.toLowerCase())
        .toList();
  }

  // ── Amount formatter ───────────────────────────────────────────────────
  String _fmtAmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) b.write(',');
      b.write(s[i]);
      c++;
    }
    return b.toString().split('').reversed.join();
  }

  // ── Status colours ─────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFF16A34A);
      case 'rejected':  return AppColors.error;
      case 'completed': return AppColors.cyan;
      case 'cancelled': return AppColors.textSecondary;
      default:          return AppColors.warning;          // Pending
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFFDCFCE7);
      case 'rejected':  return const Color(0xFFFFEBEB);
      case 'completed': return AppColors.cyanLight;
      case 'cancelled': return const Color(0xFFF3F4F6);
      default:          return const Color(0xFFFFF3E0);    // Pending
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _error != null
                  ? _buildError()
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loan & Advance History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, letterSpacing: -0.4),
                ),
                Text('Your past loan & advance requests',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loading ? null : _loadAndFetch,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.cyanLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: _loading
                  ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
              )
                  : const Icon(Icons.refresh_rounded, size: 18, color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main body (toggle + filters + list) ────────────────────────────────
  Widget _buildBody() {
    final list = _filtered;
    return Column(
      children: [
        // ── Toggle + Filters ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              _buildViewToggle(),
              const SizedBox(height: 10),
              _buildFiltersSection(),
            ],
          ),
        ),
        // ── List or empty ─────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? _buildEmpty()
              : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _simpleView
                ? _buildSimpleCard(list[i])
                : _buildFullCard(list[i]),
          ),
        ),
      ],
    );
  }

  // ── View toggle ────────────────────────────────────────────────────────
  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(
            icon: Icons.remove_red_eye_outlined,
            label: 'Simple View',
            active: _simpleView,
            onTap: () => setState(() => _simpleView = true),
          )),
          Expanded(child: _tab(
            icon: Icons.table_rows_outlined,
            label: 'Full Detail View',
            active: !_simpleView,
            onTap: () => setState(() => _simpleView = false),
          )),
        ],
      ),
    );
  }

  Widget _tab({
    required IconData icon,
    required String   label,
    required bool     active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? _primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: _primary.withOpacity(0.25)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15,
                color: active ? _primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────
  Widget _buildFiltersSection() {
    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _filtersExpanded = !_filtersExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: _filtersExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.filter_alt_outlined, size: 18,
                    color: AppColors.textPrimary),
                const SizedBox(width: 8),
                const Text('Filters',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _filtersExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        // ── Chips ─────────────────────────────────────────────────────
        if (_filtersExpanded)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
              border: Border(
                left:   BorderSide(color: AppColors.divider),
                right:  BorderSide(color: AppColors.divider),
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: ['All', 'Approved', 'Pending', 'Rejected', 'Completed']
                  .map(_filterChip)
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final active = _statusFilter == label;
    final color  = label == 'All' ? _primary : _statusColor(label);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? color.withOpacity(0.4) : AppColors.divider),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Simple Card (matches Screenshot 1) ─────────────────────────────────
  Widget _buildSimpleCard(LoanRecord r) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: title + subtitle ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loan / Advance',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(r.displayDateTime,
                        style: const TextStyle(fontSize: 13,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (r.loanAmount > 0) ...[
                      const Text('  ·  ',
                          style: TextStyle(fontSize: 13,
                              color: AppColors.textSecondary)),
                      Text('PKR ${_fmtAmt(r.loanAmount)}',
                        style: const TextStyle(fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Right: status badge + "View Details" ───────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg(r.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.status,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: _statusColor(r.status)),
                ),
              ),
              const SizedBox(height: 7),
              // View Details button
              GestureDetector(
                onTap: () => _showDetails(r),
                child: const Text('View Details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Full Detail Card ───────────────────────────────────────────────────
  Widget _buildFullCard(LoanRecord r) {
    final isCustom = r.deductionMethod.toLowerCase() == 'custom';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loan / Advance',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(r.displayDateTime,
                        style: const TextStyle(fontSize: 12.5,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusBg(r.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.status,
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(r.status)),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Divider(color: AppColors.divider, height: 1),
          ),
          // ── Detail rows ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                _inlineRow('Amount',
                    'PKR ${_fmtAmt(r.loanAmount)}'),
                _inlineRow('Reason',
                    r.reason.isNotEmpty ? r.reason : '—', maxLines: 2),
                _inlineRow('Return Policy',
                    r.deductionMethod.isNotEmpty ? r.deductionMethod : '—'),
                if (isCustom) ...[
                  _inlineRow('Installment',
                      r.installmentAmount.isNotEmpty
                          ? 'PKR ${r.installmentAmount}'
                          : '—'),
                  _inlineRow('Paid Every',
                      r.customMethod.isNotEmpty ? r.customMethod : '—'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: const TextStyle(fontSize: 12.5,
                  color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value,
              style: const TextStyle(fontSize: 12.5,
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── View Details bottom sheet ──────────────────────────────────────────
  void _showDetails(LoanRecord r) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailsSheet(record: r, fmtAmt: _fmtAmt),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: AppColors.cyanLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: _primary, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Loading records...',
              style: TextStyle(fontSize: 14,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text('Could not load history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(fontSize: 13,
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadAndFetch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: _primary.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: AppColors.textOnDark, size: 18),
                    SizedBox(width: 8),
                    Text('Try Again',
                      style: TextStyle(color: AppColors.textOnDark,
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: AppColors.cyanLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _primary.withOpacity(0.15), width: 1.5),
            ),
            child: const Icon(Icons.history_rounded,
                size: 38, color: _primary),
          ),
          const SizedBox(height: 16),
          const Text('No records found',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your loan and advance requests\nwill appear here.',
            style: TextStyle(fontSize: 13.5,
                color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Details Bottom Sheet  (matches Screenshot 2 exactly)
// ═══════════════════════════════════════════════════════════════════════════
class _DetailsSheet extends StatelessWidget {
  final LoanRecord record;
  final String Function(int) fmtAmt;

  const _DetailsSheet({required this.record, required this.fmtAmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Color(0xFFFCFAF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Grab handle ─────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                const Text('Loan / Advance Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2340),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFECE6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF1C2340)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E3DC)),
          // ── Rows ────────────────────────────────────────────────────
          _row('Reason',
              record.reason.isNotEmpty ? record.reason : '—'),
          const Divider(height: 1, color: Color(0xFFE8E3DC)),
          _row('Amount',
              'PKR ${fmtAmt(record.loanAmount)}'),
          const Divider(height: 1, color: Color(0xFFE8E3DC)),
          _row('Return Policy',
              record.deductionMethod.isNotEmpty
                  ? record.deductionMethod
                  : '—'),
          const Divider(height: 1, color: Color(0xFFE8E3DC)),
          _row('Status', record.status),
          const Divider(height: 1, color: Color(0xFFE8E3DC)),
          _row('Submitted', record.displayDateTime),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C2340),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}