import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// expense_history_screen.dart
//
// Expense Claim History — fetched from:
// GET http://oracle.metaxperts.net/ords/gps_workforce/gpsexpense/get/
//     ?company_code=:company_code&emp_id=:emp_id
// ═══════════════════════════════════════════════════════════════════════════

// ── Data Model ───────────────────────────────────────────────────────────────
class ExpenseRecord {
  final String empId;
  final String empName;
  final String companyCode;
  final String expenseType;
  final String claimPeriod;
  final double amount;
  final String requestDate;
  final String description;
  final String timestamp;
  final String status;

  const ExpenseRecord({
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.expenseType,
    required this.claimPeriod,
    required this.amount,
    required this.requestDate,
    required this.description,
    required this.timestamp,
    required this.status,
  });

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    empId:       (json['emp_id']       ?? '').toString(),
    empName:     (json['emp_name']      ?? '').toString(),
    companyCode: (json['company_code']  ?? '').toString(),
    expenseType: (json['expense_type']  ?? '').toString(),
    claimPeriod: (json['claim_period']  ?? '').toString(),
    amount:      double.tryParse(
        (json['amount'] ?? 0).toString()) ?? 0.0,
    requestDate: (json['request_date']  ?? '').toString(),
    description: (json['description']   ?? '').toString(),
    timestamp:   (json['timestamp']     ?? '').toString(),
    status:      (json['status']        ?? '').toString(),
  );
}

// ── GET Service ───────────────────────────────────────────────────────────────
class ExpenseHistoryService {
  static const _url =
      'http://oracle.metaxperts.net/ords/gps_workforce/gpsexpense/get/';

  static Future<List<ExpenseRecord>> fetchHistory({
    required String empId,
    required String companyCode,
  }) async {
    final uri = Uri.parse(_url).replace(
      queryParameters: {
        'company_code': companyCode,
        'emp_id':       empId,
      },
    );

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load expense history (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> items =
    data is List ? data : ((data['items'] ?? []) as List<dynamic>);

    return items
        .map((e) => ExpenseRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Main Screen
// ═══════════════════════════════════════════════════════════════════════════
class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  static const _bgColor  = AppColors.surface;
  static const _primary  = AppColors.cyan;

  // ── State ──────────────────────────────────────────────────────────────
  List<ExpenseRecord> _records   = [];
  bool   _loading    = true;
  String? _error;
  String _empId       = '';
  String _companyCode = '';
  bool   _isSimpleView = true;
  // Filter state: null = All
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs  = await SharedPreferences.getInstance();
    _empId       = prefs.getString('userId')      ?? '';
    _companyCode = prefs.getString('companyCode') ?? '';

    if (_empId.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = 'User ID not found.'; });
      return;
    }

    try {
      final records = await ExpenseHistoryService.fetchHistory(
        empId:       _empId,
        companyCode: _companyCode,
      );
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Stats helpers ──────────────────────────────────────────────────────
  int    get _totalCount    => _records.length;
  int    get _pendingCount  => _records.where((r) => r.status.toLowerCase() == 'pending').length;
  int    get _approvedCount => _records.where((r) => r.status.toLowerCase() == 'approved').length;
  double get _totalAmount   => _records.fold(0.0, (s, r) => s + r.amount);

  // ── Filtered records ───────────────────────────────────────────────────
  List<ExpenseRecord> get _filteredRecords {
    if (_activeFilter == null) return _records;
    return _records
        .where((r) => r.status.toLowerCase() == _activeFilter!.toLowerCase())
        .toList();
  }

  // ── Filter Bottom Sheet ────────────────────────────────────────────────
  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _activeFilter,
        onSelected: (val) {
          setState(() => _activeFilter = val);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Expense Claim',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.info_outline_rounded,
                          size: 17, color: AppColors.textSecondary),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() { _loading = true; _error = null; });
                          _loadAndFetch();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              size: 17, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 28),
                    child: Text(
                      'Submit expense claim with receipts. Finance reviews and reimburses approved amounts.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Tab Bar ─────────────────────────────────────────────────

            const SizedBox(height: 16),

            // ── Body ───────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
      );
    }
    if (_error != null) return _ErrorView(message: _error!, onRetry: () {
      setState(() { _loading = true; _error = null; });
      _loadAndFetch();
    });
    if (_records.isEmpty) return const _EmptyView();

    final displayed = _filteredRecords;

    return Column(
      children: [
        // ── Simple / Full Detail Toggle ──────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EFE7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAE4DC)),
            ),
            child: Row(
              children: [
                _ViewToggleBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Simple View',
                  active: _isSimpleView,
                  onTap: () => setState(() => _isSimpleView = true),
                ),
                _ViewToggleBtn(
                  icon: Icons.table_rows_outlined,
                  label: 'Full Detail View',
                  active: !_isSimpleView,
                  onTap: () => setState(() => _isSimpleView = false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Filters Button ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _activeFilter != null
                    ? AppColors.cyan.withOpacity(0.08)
                    : const Color(0xFFF5EFE7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _activeFilter != null
                      ? AppColors.cyan.withOpacity(0.4)
                      : const Color(0xFFEAE4DC),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_rounded,
                      size: 18,
                      color: _activeFilter != null
                          ? AppColors.cyan
                          : AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    _activeFilter != null
                        ? 'Filter: $_activeFilter'
                        : 'Filters',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _activeFilter != null
                          ? AppColors.cyan
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (_activeFilter != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _activeFilter = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.cyan),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Records List ─────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() { _loading = true; _error = null; });
              await _loadAndFetch();
            },
            color: _primary,
            child: displayed.isEmpty
                ? ListView(
              children: const [
                SizedBox(height: 60),
                _EmptyFilterView(),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: displayed.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _isSimpleView
                    ? _SimpleCard(record: displayed[i])
                    : _DetailCard(record: displayed[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════
class _FilterSheet extends StatelessWidget {
  final String?          current;
  final void Function(String?) onSelected;

  const _FilterSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = ['All', 'Approved', 'Pending', 'Rejected'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Filter by Status',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final isAll      = opt == 'All';
            final filterVal  = isAll ? null : opt;
            final isSelected = current == filterVal;

            Color chipFg = AppColors.textSecondary;
            Color chipBg = const Color(0xFFF5EFE7);
            if (!isAll) {
              switch (opt.toLowerCase()) {
                case 'approved':
                  chipFg = AppColors.greenTeal;
                  chipBg = const Color(0xFFE8F5E9);
                case 'pending':
                  chipFg = AppColors.warning;
                  chipBg = const Color(0xFFFFF3E0);
                case 'rejected':
                  chipFg = AppColors.error;
                  chipBg = const Color(0xFFFFEBEE);
              }
            }

            return GestureDetector(
              onTap: () => onSelected(filterVal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? chipBg : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? chipFg.withOpacity(0.4)
                        : const Color(0xFFEAE4DC),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isAll ? AppColors.cyan : chipFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isAll ? AppColors.cyan : chipFg)
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_rounded,
                          size: 18,
                          color: isAll ? AppColors.cyan : chipFg),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab Button
// ═══════════════════════════════════════════════════════════════════════════
class _TabBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? Colors.white : AppColors.textPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// View Toggle Button
// ═══════════════════════════════════════════════════════════════════════════
class _ViewToggleBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _ViewToggleBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? AppColors.cyan : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Simple Card
// ═══════════════════════════════════════════════════════════════════════════
class _SimpleCard extends StatelessWidget {
  final ExpenseRecord record;
  const _SimpleCard({required this.record});

  Color get _statusFg {
    switch (record.status.toLowerCase()) {
      case 'approved': return AppColors.greenTeal;
      case 'rejected': return AppColors.error;
      case 'pending':  return AppColors.warning;
      default:         return AppColors.textSecondary;
    }
  }

  Color get _statusBg {
    switch (record.status.toLowerCase()) {
      case 'approved': return const Color(0xFFE8F5E9);
      case 'rejected': return const Color(0xFFFFEBEE);
      case 'pending':  return const Color(0xFFFFF3E0);
      default:         return AppColors.cyanLight;
    }
  }

  void _showDetails(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ExpenseDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAE4DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: expense type (bold) + timestamp · PKR amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.expenseType,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        TextSpan(text: record.timestamp),
                        const TextSpan(
                          text: '  ·  ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: 'PKR ${_formatAmount(record.amount)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right: status badge + "View Details"
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _statusFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    final int value = amount.toInt();
    if (value >= 1000) {
      final String s = value.toString();
      final int firstGroup = s.length % 3 == 0 ? 3 : s.length % 3;
      final StringBuffer buf = StringBuffer(s.substring(0, firstGroup));
      for (int i = firstGroup; i < s.length; i += 3) {
        buf.write(',');
        buf.write(s.substring(i, i + 3));
      }
      return buf.toString();
    }
    return value.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Expense Detail Bottom Sheet  (shown on "View Details" tap)
// ═══════════════════════════════════════════════════════════════════════════
class _ExpenseDetailSheet extends StatelessWidget {
  final ExpenseRecord record;
  const _ExpenseDetailSheet({required this.record});

  Color get _statusFg {
    switch (record.status.toLowerCase()) {
      case 'approved': return AppColors.greenTeal;
      case 'rejected': return AppColors.error;
      case 'pending':  return AppColors.warning;
      default:         return AppColors.textSecondary;
    }
  }

  Color get _statusBg {
    switch (record.status.toLowerCase()) {
      case 'approved': return const Color(0xFFE8F5E9);
      case 'rejected': return const Color(0xFFFFEBEE);
      case 'pending':  return const Color(0xFFFFF3E0);
      default:         return AppColors.cyanLight;
    }
  }

  IconData get _typeIcon {
    final t = record.expenseType.toLowerCase();
    if (t.contains('travel') || t.contains('mileage'))  return Icons.directions_car_rounded;
    if (t.contains('fuel'))                              return Icons.local_gas_station_rounded;
    if (t.contains('meal')   || t.contains('food'))     return Icons.restaurant_rounded;
    if (t.contains('hotel')  || t.contains('accomm'))   return Icons.hotel_rounded;
    if (t.contains('medical')|| t.contains('health'))   return Icons.medical_services_rounded;
    if (t.contains('comm')   || t.contains('phone'))    return Icons.phone_rounded;
    if (t.contains('train')  || t.contains('course'))   return Icons.school_rounded;
    if (t.contains('supply') || t.contains('office'))   return Icons.inventory_2_rounded;
    return Icons.receipt_rounded;
  }

  String _formatAmount(double amount) {
    final int value = amount.toInt();
    if (value >= 1000) {
      final String s = value.toString();
      final int firstGroup = s.length % 3 == 0 ? 3 : s.length % 3;
      final StringBuffer buf = StringBuffer(s.substring(0, firstGroup));
      for (int i = firstGroup; i < s.length; i += 3) {
        buf.write(',');
        buf.write(s.substring(i, i + 3));
      }
      return buf.toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8D0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header row: icon + title + status ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.cyanLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                ),
                child: Icon(_typeIcon, size: 24, color: AppColors.cyan),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.expenseType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _statusFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${_formatAmount(record.amount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFEAE4DC), height: 1),
          const SizedBox(height: 20),

          // ── Detail rows ────────────────────────────────────────────
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Employee ID',
            value: record.empId.isNotEmpty ? record.empId : '—',
          ),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Employee Name',
            value: record.empName.isNotEmpty ? record.empName : '—',
          ),
          _DetailRow(
            icon: Icons.business_outlined,
            label: 'Company Code',
            value: record.companyCode.isNotEmpty ? record.companyCode : '—',
          ),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Request Date',
            value: record.requestDate.isNotEmpty ? record.requestDate : '—',
          ),
          _DetailRow(
            icon: Icons.access_time_rounded,
            label: 'Timestamp',
            value: record.timestamp.isNotEmpty ? record.timestamp : '—',
          ),
          _DetailRow(
            icon: Icons.date_range_rounded,
            label: 'Claim Period',
            value: record.claimPeriod.isNotEmpty ? record.claimPeriod : '—',
          ),

          if (record.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Divider(color: Color(0xFFEAE4DC), height: 1),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Close button ───────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEAE4DC)),
              ),
              child: const Center(
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single detail row inside the sheet ───────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Detail Card  ←  full info + expandable description (Full Detail View)
// ═══════════════════════════════════════════════════════════════════════════
class _DetailCard extends StatelessWidget {
  final ExpenseRecord record;
  const _DetailCard({required this.record});

  Color get _statusFg {
    switch (record.status.toLowerCase()) {
      case 'approved': return AppColors.greenTeal;
      case 'rejected': return AppColors.error;
      case 'pending':  return AppColors.warning;
      default:         return AppColors.textSecondary;
    }
  }

  Color get _statusBg {
    switch (record.status.toLowerCase()) {
      case 'approved': return const Color(0xFFE8F5E9);
      case 'rejected': return const Color(0xFFFFEBEE);
      case 'pending':  return const Color(0xFFFFF3E0);
      default:         return AppColors.cyanLight;
    }
  }

  IconData get _typeIcon {
    final t = record.expenseType.toLowerCase();
    if (t.contains('travel') || t.contains('mileage'))  return Icons.directions_car_rounded;
    if (t.contains('fuel'))                              return Icons.local_gas_station_rounded;
    if (t.contains('meal')   || t.contains('food'))     return Icons.restaurant_rounded;
    if (t.contains('hotel')  || t.contains('accomm'))   return Icons.hotel_rounded;
    if (t.contains('medical')|| t.contains('health'))   return Icons.medical_services_rounded;
    if (t.contains('comm')   || t.contains('phone'))    return Icons.phone_rounded;
    if (t.contains('train')  || t.contains('course'))   return Icons.school_rounded;
    if (t.contains('supply') || t.contains('office'))   return Icons.inventory_2_rounded;
    return Icons.receipt_rounded;
  }

  String _formatAmount(double amount) {
    final int value = amount.toInt();
    if (value >= 1000) {
      final String s = value.toString();
      final int firstGroup = s.length % 3 == 0 ? 3 : s.length % 3;
      final StringBuffer buf = StringBuffer(s.substring(0, firstGroup));
      for (int i = firstGroup; i < s.length; i += 3) {
        buf.write(',');
        buf.write(s.substring(i, i + 3));
      }
      return buf.toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAE4DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + type + amount + status ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.cyanLight,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                ),
                child: Icon(_typeIcon, size: 22, color: AppColors.cyan),
              ),
              const SizedBox(width: 12),

              // Type + status badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.expenseType,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.status,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _statusFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount (right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${_formatAmount(record.amount)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEAE4DC), height: 1),
          const SizedBox(height: 14),

          // ── Info grid ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _InfoCell(
                  icon: Icons.badge_outlined,
                  label: 'Emp ID',
                  value: record.empId.isNotEmpty ? record.empId : '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCell(
                  icon: Icons.person_outline_rounded,
                  label: 'Name',
                  value: record.empName.isNotEmpty ? record.empName : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoCell(
                  icon: Icons.calendar_today_rounded,
                  label: 'Request Date',
                  value: record.requestDate.isNotEmpty ? record.requestDate : '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCell(
                  icon: Icons.date_range_rounded,
                  label: 'Claim Period',
                  value: record.claimPeriod.isNotEmpty ? record.claimPeriod : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoCell(
                  icon: Icons.access_time_rounded,
                  label: 'Timestamp',
                  value: record.timestamp.isNotEmpty ? record.timestamp : '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCell(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: record.companyCode.isNotEmpty ? record.companyCode : '—',
                ),
              ),
            ],
          ),

          if (record.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEAE4DC), height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESCRIPTION',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.description,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info cell used inside Detail Card grid ───────────────────────────────────
class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAE4DC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.cyanLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 38, color: AppColors.cyan),
            ),
            const SizedBox(height: 18),
            const Text('No Expense Claims Yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'Your submitted expense claims\nwill appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty Filter State
// ═══════════════════════════════════════════════════════════════════════════
class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.filter_alt_off_rounded,
                  size: 34, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('No Results',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'No records match the selected filter.\nTry a different status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error State
// ═══════════════════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 52, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Could not load history',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}