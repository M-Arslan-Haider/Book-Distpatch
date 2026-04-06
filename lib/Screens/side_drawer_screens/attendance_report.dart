

import '../../AppColors.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../Database/util.dart';

// Navigate simply:  Get.to(() => const AttendanceReportScreen());

class AttendanceReportScreen extends StatefulWidget {
  final String? empId;
  const AttendanceReportScreen({Key? key, this.empId}) : super(key: key);

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with SingleTickerProviderStateMixin {

  List<Map<String, dynamic>> records   = [];
  List<Map<String, dynamic>> _filtered = [];

  bool   isLoading    = true;
  String errorMessage = '';
  String _resolvedId  = '';

  DateTime? _fromDate;
  DateTime? _toDate;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/attendancedata1/get';

  // ── FIX 2: Only specific known keys — no random int fallback ──────────────
  static const List<String> _possibleIdKeys = [
    'emp_id', 'user_id', 'userId', 'employee_id', 'employeeId',
    'id', 'ID', 'EMP_ID', 'USER_ID', 'prefUserId', 'employeeCode',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _initAndFetch();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── FIX 2: Safe _resolveEmpId — no dangerous random-int fallback ──────────

  Future<String> _resolveEmpId() async {
    // 1. Passed directly from navigation
    if (widget.empId != null && widget.empId!.trim().isNotEmpty) {
      debugPrint('=== AttendanceScreen: empId from widget = "${widget.empId}"');
      return widget.empId!.trim();
    }

    // 2. Try util.dart global variable
    await loadEmployeeData();
    if (emp_id.trim().isNotEmpty) {
      debugPrint('=== AttendanceScreen: empId from util = "$emp_id"');
      return emp_id.trim();
    }

    // 3. SharedPreferences — specific keys only, NO random int fallback
    final prefs = await SharedPreferences.getInstance();
    for (final key in _possibleIdKeys) {
      final val = prefs.get(key)?.toString().trim() ?? '';
      if (val.isNotEmpty) {
        debugPrint('=== AttendanceScreen: empId from prefs["$key"] = "$val"');
        return val;
      }
    }

    debugPrint('=== AttendanceScreen: empId not found in any source!');
    return ''; // fail cleanly — don't guess
  }

  Future<void> _initAndFetch() async {
    _resolvedId = await _resolveEmpId();
    await _fetchAttendance();
  }

  // ── FIX 1 + FIX 3: API call with company_code + better empty handling ─────

  Future<void> _fetchAttendance() async {
    setState(() {
      isLoading    = true;
      errorMessage = '';
      records      = [];
      _filtered    = [];
    });
    _animController.reset();

    try {
      if (_resolvedId.isEmpty) {
        throw Exception(
            'Could not find Employee ID.\nPlease log out and log in again.');
      }

      // FIX 1: Read company_code from SharedPreferences and send it
      final prefs       = await SharedPreferences.getInstance();
      final companyCode = prefs.getString('companyCode')
          ?? prefs.getString('company_code')
          ?? prefs.getString('COMPANY_CODE')
          ?? '';

      debugPrint('>>> SENDING emp_id: $_resolvedId  company_code: $companyCode');

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'emp_id':       _resolvedId,
        'company_code': companyCode,   // FIX 1: was missing entirely
      });

      debugPrint('Attendance URL: $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('Attendance status: ${response.statusCode}');
      debugPrint('Attendance body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic raw = json.decode(response.body);
        List<Map<String, dynamic>> parsed = [];

        if (raw is Map<String, dynamic>) {
          if (raw.containsKey('items') && raw['items'] is List) {
            parsed = (raw['items'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (raw.containsKey('data') && raw['data'] is List) {
            parsed = (raw['data'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (raw.containsKey('rows') && raw['rows'] is List) {
            parsed = (raw['rows'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (raw.containsKey('results') && raw['results'] is List) {
            parsed = (raw['results'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else {
            // Fallback: find any list value in the map
            for (final val in raw.values) {
              if (val is List && val.isNotEmpty) {
                parsed = val.map((e) => Map<String, dynamic>.from(e)).toList();
                break;
              }
            }
          }
        } else if (raw is List) {
          parsed = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        debugPrint('=== AttendanceScreen: parsed ${parsed.length} records');

        // FIX 3: Show useful debug info when 0 records returned
        if (parsed.isEmpty) {
          setState(() {
            errorMessage =
            'API returned 0 records.\n\n'
                'emp_id sent : $_resolvedId\n'
                'company_code: $companyCode\n\n'
                'Raw response:\n'
                '${response.body.length > 400 ? response.body.substring(0, 400) + "\n…(truncated)" : response.body}';
            isLoading = false;
          });
          return;
        }

        // Debug: print all keys from first record
        debugPrint('API keys: ${parsed.first.keys.toList()}');
        debugPrint('First record: ${parsed.first}');

        setState(() {
          records   = parsed;
          _filtered = parsed;
          isLoading = false;
        });
        _animController.forward();

      } else {
        throw Exception('Server error: HTTP ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading    = false;
      });
    }
  }

  // ── Date filter logic ──────────────────────────────────────────────────────

  void _applyFilter() {
    setState(() {
      if (_fromDate == null && _toDate == null) {
        _filtered = records;
        return;
      }
      _filtered = records.where((r) {
        final raw = _dateOnly(_inDate(r));
        if (raw == '—') return false;
        final d = DateTime.tryParse(raw);
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (_fromDate != null && day.isBefore(_fromDate!)) return false;
        if (_toDate   != null && day.isAfter(_toDate!))    return false;
        return true;
      }).toList();
    });
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate   = null;
      _filtered = records;
    });
  }

  bool get _isFiltered => _fromDate != null || _toDate != null;

  String _fmt(DateTime? d) {
    if (d == null) return 'Select';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: DateTime(2000),
      lastDate: _toDate ?? now,
      builder: _datePickerTheme,
    );
    if (picked != null) {
      _fromDate = DateTime(picked.year, picked.month, picked.day);
      _applyFilter();
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: _fromDate ?? DateTime(2000),
      lastDate: now,
      builder: _datePickerTheme,
    );
    if (picked != null) {
      _toDate = DateTime(picked.year, picked.month, picked.day);
      _applyFilter();
    }
  }

  Widget _datePickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.cyan,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
      ),
      child: child!,
    );
  }

  // ── Field helpers ──────────────────────────────────────────────────────────

  String _v(Map<String, dynamic> row, List<String> keys) {
    for (final k in keys) {
      final v = row[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '—';
  }

  String _empId(Map<String, dynamic> r) => _v(r, [
    'EMP_ID', 'emp_id', 'emp_ID', 'Emp_Id', 'empId',
  ]);

  String _empName(Map<String, dynamic> r) => _v(r, [
    'EMP_NAME', 'emp_name', 'emp_NAME', 'Emp_Name', 'empName',
  ]);

  String _inDate(Map<String, dynamic> r) => _v(r, [
    'ATTENDANCE_IN_DATE', 'attendance_in_date', 'Attendance_In_Date',
  ]);

  String _inTime(Map<String, dynamic> r) => _v(r, [
    'ATTENDANCE_IN_TIME', 'attendance_in_time', 'Attendance_In_Time',
  ]);

  String _outTime(Map<String, dynamic> r) => _v(r, [
    'ATTENDANCE_OUT_TIME', 'attendance_out_time', 'Attendance_Out_Time',
  ]);

  String _totalTime(Map<String, dynamic> r) => _v(r, [
    'TOTAL_TIME', 'total_time', 'Total_Time', 'totalTime',
  ]);

  String _totalDist(Map<String, dynamic> r) => _v(r, [
    'TOTAL_DISTANCE', 'total_distance', 'Total_Distance', 'totalDistance',
  ]);

  String _address(Map<String, dynamic> r) => _v(r, [
    'ADDRESS', 'address', 'Address',
    'ATTENDANCE_ADDRESS', 'attendance_address',
    'LOCATION', 'location', 'Location',
    'ADDR', 'addr',
  ]);

  String _dailyTotal(Map<String, dynamic> r) => _v(r, [
    'TOTAL_TIME_FOR_THE_DAY', 'total_time_for_the_day',
    'Total_Time_For_The_Day', 'totalTimeForTheDay',
  ]);

  String _dateOnly(String raw) =>
      (raw == '—' || raw.length < 10) ? raw : raw.substring(0, 10);

  String _formatTime(String raw) {
    if (raw == '—') return '—';
    try {
      final parts = raw.split(':');
      if (parts.length < 2) return raw;
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      if (h == 0) h = 12;
      else if (h > 12) h -= 12;
      return '$h:${m.toString().padLeft(2, '0')} $period';
    } catch (_) { return raw; }
  }

  String _formatDateHeader(String raw) {
    if (raw == '—') return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  int _toMinutes(String raw) {
    if (raw == '—') return 0;
    try {
      final cp = raw.split(':');
      if (cp.length >= 2) {
        return (int.tryParse(cp[0]) ?? 0) * 60 + (int.tryParse(cp[1]) ?? 0);
      }
      final h = RegExp(r'(\d+)h').firstMatch(raw);
      final m = RegExp(r'(\d+)m').firstMatch(raw);
      return (h != null ? int.parse(h.group(1)!) : 0) * 60
          + (m != null ? int.parse(m.group(1)!) : 0);
    } catch (_) { return 0; }
  }

  String _minutesToLabel(int min) {
    if (min <= 0) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _formatDuration(String raw) {
    if (raw == '—') return '—';
    final mins = _toMinutes(raw);
    if (mins <= 0) return raw;
    return _minutesToLabel(mins);
  }

  // ── Group by date ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _groupByDate() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final r in _filtered) {
      grouped.putIfAbsent(_dateOnly(_inDate(r)), () => []).add(r);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys.map((k) => {'date': k, 'records': grouped[k]!}).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 155,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _initAndFetch,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(fit: StackFit.expand, children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -50, right: -30,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.greenTeal.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -40, left: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Column(children: [
              const Text(
                'Attendance Report',
                style: TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700, letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              if (_resolvedId.isNotEmpty)
                Text(
                  isLoading
                      ? 'ID: $_resolvedId'
                      : 'ID: $_resolvedId  •  ${_filtered.length} of ${records.length} records',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60), fontSize: 11,
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading)               return _stateLoading();
    if (errorMessage.isNotEmpty) return _stateError();
    if (records.isEmpty)         return _stateEmpty();
    return _buildListWithFilter();
  }

  Widget _stateLoading() => SizedBox(
    height: 400,
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 44, height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanBright),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Loading attendance...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ]),
    ),
  );

  Widget _stateError() => SizedBox(
    height: 500,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withOpacity(0.08),
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 34),
          ),
          const SizedBox(height: 20),
          const Text(
            'Could not load attendance',
            style: TextStyle(
              color: AppColors.textPrimary, fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // FIX 3: Show full error/debug message so you can see what went wrong
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withOpacity(0.15)),
            ),
            child: Text(
              errorMessage,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 24),
          _btn('Try Again', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
        ]),
      ),
    ),
  );

  Widget _stateEmpty() => SizedBox(
    height: 400,
    child: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_rounded, size: 64, color: AppColors.cyanMid),
        const SizedBox(height: 16),
        Text(
          'No records found for ID: $_resolvedId',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        _btn('Refresh', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
      ]),
    ),
  );

  Widget _buildListWithFilter() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filterBar(),
              const SizedBox(height: 12),
              if (_filtered.isEmpty)
                _noFilterResults()
              else
                _buildGroupedList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupByDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.map((group) {
        final dateKey = group['date'] as String;
        final recs    = group['records'] as List<Map<String, dynamic>>;

        final dailyTotalRaw   = _dailyTotal(recs.first);
        final dailyTotalLabel = dailyTotalRaw != '—'
            ? _formatDuration(dailyTotalRaw)
            : _minutesToLabel(
            recs.fold<int>(0, (s, r) => s + _toMinutes(_totalTime(r))));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dateHeaderRow(_formatDateHeader(dateKey), dailyTotalLabel),
            const SizedBox(height: 6),
            ...recs.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _recordCard(r),
            )),
            const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }

  Widget _dateHeaderRow(String dateLabel, String totalLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, letterSpacing: 0.1,
            ),
          ),
          Text(
            totalLabel,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> row) {
    final addr      = _address(row);
    final empId     = _empId(row);
    final empName   = _empName(row);
    final inT       = _formatTime(_inTime(row));
    final outT      = _formatTime(_outTime(row));
    final rawTotal  = _totalTime(row);
    final duration  = _formatDuration(rawTotal);
    final timeRange = '${inT != '—' ? inT : '?'}  -  ${outT != '—' ? outT : '?'}';

    final primaryLabel =
    addr != '—' ? addr : (empName != '—' ? empName : 'Unknown');

    final subLabel = addr != '—' && empName != '—'
        ? '$empName  ·  $empId'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                duration,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: duration != '—'
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noFilterResults() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Icon(Icons.search_off_rounded, size: 48, color: AppColors.cyanMid),
        const SizedBox(height: 12),
        const Text(
          'No records in selected range',
          style: TextStyle(
            color: AppColors.textSecondary, fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _clearFilter,
          child: const Text(
            'Clear filter',
            style: TextStyle(
              color: AppColors.cyan, fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFiltered
              ? AppColors.cyan.withOpacity(0.6)
              : AppColors.divider,
          width: _isFiltered ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: AppColors.greenTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.filter_alt_outlined,
                  size: 14, color: AppColors.greenTeal),
            ),
            const SizedBox(width: 8),
            const Text(
              'Filter by Date',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.greenTeal, letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            if (_isFiltered)
              GestureDetector(
                onTap: _clearFilter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.close_rounded, size: 11, color: AppColors.error),
                    SizedBox(width: 4),
                    Text('Clear', style: TextStyle(
                      fontSize: 10, color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    )),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _datePicker(
              label: 'FROM',
              value: _fmt(_fromDate),
              active: _fromDate != null,
              onTap: _pickFrom,
            )),
            const SizedBox(width: 10),
            Expanded(child: _datePicker(
              label: 'TO',
              value: _fmt(_toDate),
              active: _toDate != null,
              onTap: _pickTo,
            )),
          ]),
          if (_isFiltered) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.skyBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.skyBlue.withOpacity(0.20)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: AppColors.skyBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing ${_filtered.length} of ${records.length} records'
                        '${_fromDate != null ? '  •  From ${_fmt(_fromDate)}' : ''}'
                        '${_toDate   != null ? '  •  To ${_fmt(_toDate)}' : ''}',
                    style: const TextStyle(
                      fontSize: 10, color: AppColors.skyBlueDk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required String value,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.cyan.withOpacity(0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active
                ? AppColors.cyan.withOpacity(0.35)
                : AppColors.divider,
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded, size: 13,
              color: active ? AppColors.cyan : AppColors.textSecondary),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: active ? AppColors.cyan : AppColors.textSecondary,
                fontWeight: FontWeight.w700, letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? AppColors.cyan : AppColors.textSecondary,
              ),
            ),
          ]),
          const Spacer(),
          Icon(Icons.arrow_drop_down_rounded, size: 16,
              color: active ? AppColors.cyan : AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cyanGlow,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}