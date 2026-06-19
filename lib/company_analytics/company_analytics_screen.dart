import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'attendance_analytics_service_screen.dart';
import 'daily_attendance_report_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// company_analytics_screen.dart
//
// Shown inside CompanyScreen when the "Analytics" segment is selected.
// Fetches real attendance data from API and displays it with:
// - Sub-tabs: Attendance / Compliance / Tasks
// - Month selector with navigation
// - Simple View / Full Detail View toggle
// - Attendance stat cards (Present, Late Arrivals, On-Time, Early Exit, Half Days, Leaves)
// - Attendance Score card with main issue and suggested action
// - Full Detail View with comprehensive breakdown
// ═══════════════════════════════════════════════════════════════════════════

enum _AnalyticsSubTab { attendance, compliance, tasks }

enum _AnalyticsView { simple, full }

class _AttendanceStat {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;
  final String subtitle;

  const _AttendanceStat({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    this.subtitle = '— -',
  });
}

class CompanyAnalyticsTab extends StatefulWidget {
  const CompanyAnalyticsTab({super.key});

  @override
  State<CompanyAnalyticsTab> createState() => _CompanyAnalyticsTabState();
}

class _CompanyAnalyticsTabState extends State<CompanyAnalyticsTab> {
  // ── Design tokens (kept in sync with company_screen.dart) ───────────────
  static const _bgCream = Color(0xFFFCF3E7);
  static const _borderColor = Color(0xFFEAE0CF);
  static const _teal = Color(0xFF14B8A6);
  static const _tealDark = Color(0xFF0F766E);
  static const _textDark = Color(0xFF1F2A37);
  static const _textGray = Color(0xFF6B7280);
  static const _lowBg = Color(0xFFE5E7EB);

  // ── Colours specific to the Attendance stat cards / score card ──────────
  static const _presentGreen = Color(0xFF1FAA59);
  static const _lateOrange = Color(0xFFF2994A);
  static const _onTimeBlue = Color(0xFF3B82F6);
  static const _earlyExitPink = Color(0xFFEC4899);
  static const _halfDayPurple = Color(0xFF8B5CF6);
  static const _leavesPurple = Color(0xFF6366F1);
  static const _scoreOrange = Color(0xFFEA8C3A);
  static const _scoreTrack = Color(0xFFE5E1D8);
  static const _suggestedBg = Color(0xFFF5ECDA);

  // ── Colours for the Daily Attendance list (status pills) ────────────────
  static const _absentRed = Color(0xFFDC2626);
  static const _dailyCardTimeBg = Color(0xFFF7F1E5);

  // ── Colours for the Compliance cards ─────────────────────────────────────
  static const _geoViolationRed = Color(0xFFEF4444);

  _AnalyticsSubTab _analyticsSubTab = _AnalyticsSubTab.attendance;
  _AnalyticsView _analyticsView = _AnalyticsView.simple;
  DateTime _analyticsMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // ── API Service ────────────────────────────────────────────────────────
  late AttendanceAnalyticsService _analyticsService;
  AttendanceAnalyticsData? _currentAnalyticsData;
  bool _isLoading = false;

  // ── Daily Attendance report (real data, shown inside Full Detail View) ──
  late DailyAttendanceReportService _dailyReportService;
  List<DailyAttendanceRecord> _dailyRecords = [];
  bool _isDailyLoading = false;
  final TextEditingController _dailySearchController = TextEditingController();
  String _dailySearchQuery = '';
  String _dailyStatusFilter = 'All';
  static const List<String> _dailyStatusFilters = [
    'All',
    'Present',
    'Late',
    'Absent',
    'Leave',
    'Holiday',
    'Half Day',
  ];

  @override
  void initState() {
    super.initState();
    _analyticsService = AttendanceAnalyticsService();
    _dailyReportService = DailyAttendanceReportService();
    _fetchAnalyticsData();
    _fetchDailyAttendanceData();
  }

  @override
  void dispose() {
    _dailySearchController.dispose();
    super.dispose();
  }

  // ── Fetch attendance data from API ─────────────────────────────────────
  Future<void> _fetchAnalyticsData() async {
    setState(() => _isLoading = true);

    final monthStr = DateFormat('yyyy-MM').format(_analyticsMonth);
    final data = await _analyticsService.fetchAttendanceData(month: monthStr);

    setState(() {
      _currentAnalyticsData = data;
      _isLoading = false;
    });
  }

  // ── Fetch the day-by-day attendance report (real data, Full Detail View) ─
  Future<void> _fetchDailyAttendanceData() async {
    setState(() => _isDailyLoading = true);

    final monthStr = DateFormat('yyyy-MM').format(_analyticsMonth);
    final records =
    await _dailyReportService.fetchDailyAttendance(month: monthStr);

    setState(() {
      _dailyRecords = records ?? [];
      _isDailyLoading = false;
    });
  }

  // ── Daily records after applying the search box + status filter chip ───
  List<DailyAttendanceRecord> get _filteredDailyRecords {
    final query = _dailySearchQuery.trim().toLowerCase();
    return _dailyRecords.where((record) {
      final matchesStatus = _dailyStatusFilter == 'All' ||
          record.statusText.toLowerCase() == _dailyStatusFilter.toLowerCase();
      final matchesSearch = query.isEmpty ||
          record.workDate.toLowerCase().contains(query) ||
          record.dayName.toLowerCase().contains(query) ||
          record.statusText.toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAnalyticsSubTabs(),
        const SizedBox(height: 12),
        _buildMonthSelector(),
        const SizedBox(height: 12),
        _buildViewToggle(),
        const SizedBox(height: 12),
        Expanded(child: _buildAnalyticsContent()),
      ],
    );
  }

  // ── Sub-tabs: Attendance / Compliance / Tasks ───────────────────────────
  Widget _buildAnalyticsSubTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: _analyticsSubTabButton(
                  _AnalyticsSubTab.attendance, 'Attendance', Icons.people_alt_rounded),
            ),
            Expanded(
              child: _analyticsSubTabButton(
                  _AnalyticsSubTab.compliance, 'Compliance', Icons.shield_outlined),
            ),
            Expanded(
              child: _analyticsSubTabButton(
                  _AnalyticsSubTab.tasks, 'Tasks', Icons.checklist_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsSubTabButton(_AnalyticsSubTab tab, String label, IconData icon) {
    final isActive = _analyticsSubTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _analyticsSubTab = tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: _teal.withOpacity(0.30),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: isActive ? Colors.white : _textDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month selector: "‹  📅 May 2026  ›" ──────────────────────────────────
  Widget _buildMonthSelector() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final label = '${months[_analyticsMonth.month - 1]} ${_analyticsMonth.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            _monthArrowButton(Icons.chevron_left_rounded, () {
              setState(() {
                _analyticsMonth =
                    DateTime(_analyticsMonth.year, _analyticsMonth.month - 1);
              });
              _fetchAnalyticsData();
              _fetchDailyAttendanceData();
            }),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 17, color: _textDark),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark),
                    ),
                  ],
                ),
              ),
            ),
            _monthArrowButton(Icons.chevron_right_rounded, () {
              setState(() {
                _analyticsMonth =
                    DateTime(_analyticsMonth.year, _analyticsMonth.month + 1);
              });
              _fetchAnalyticsData();
              _fetchDailyAttendanceData();
            }),
          ],
        ),
      ),
    );
  }

  Widget _monthArrowButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 52,
        child: Icon(icon, color: _textDark, size: 22),
      ),
    );
  }

  // ── Simple View / Full Detail View toggle ───────────────────────────────
  Widget _buildViewToggle() {
    // Compliance has no separate "full detail" breakdown — only show the
    // Simple View option for that sub-tab.
    final showFullDetailOption = _analyticsSubTab != _AnalyticsSubTab.compliance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _bgCream,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: _viewToggleButton(_AnalyticsView.simple, 'Simple View',
                  Icons.visibility_rounded),
            ),
            if (showFullDetailOption)
              Expanded(
                child: _viewToggleButton(_AnalyticsView.full, 'Full Detail View',
                    Icons.table_chart_rounded),
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewToggleButton(_AnalyticsView view, String label, IconData icon) {
    final isActive = _analyticsView == view;
    return GestureDetector(
      onTap: () => setState(() => _analyticsView = view),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: isActive ? _teal : _textGray),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? _teal : _textGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content area: switches on sub-tab + view ────────────────────────────
  Widget _buildAnalyticsContent() {
    if (_analyticsSubTab == _AnalyticsSubTab.tasks) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 46, color: _textGray.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text('Tasks analytics coming soon',
                style: TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }

    // Show loading spinner while fetching data
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _teal),
            const SizedBox(height: 10),
            const Text('Loading attendance data...',
                style: TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }

    // Show error if no data
    if (_currentAnalyticsData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 46, color: _textGray.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text('Failed to load attendance data',
                style: TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }

    if (_analyticsSubTab == _AnalyticsSubTab.compliance) {
      return _buildComplianceView(_currentAnalyticsData!);
    }

    return _analyticsView == _AnalyticsView.full
        ? _buildAttendanceFullDetailList()
        : _buildAttendanceSimpleView();
  }

  // ── Compliance view: Geo Fence / Device Offline / GPS Off / Mock Location
  // Sourced from the same attendanceanalytics API already used above.
  // (Shown for both Simple View and Full Detail View for now since no
  // separate detailed breakdown was requested yet.)
  Widget _buildComplianceView(AttendanceAnalyticsData data) {
    final complianceStats = [
      _AttendanceStat(
        icon: Icons.flag_rounded,
        iconBg: _geoViolationRed,
        label: 'GEO FENCE VIOLATIONS',
        value: '${data.totalGeoViolations}',
      ),
      _AttendanceStat(
        icon: Icons.smartphone_rounded,
        iconBg: _halfDayPurple,
        label: 'DEVICE OFFLINE',
        value: '${data.totalOfflineEvents}',
      ),
      _AttendanceStat(
        icon: Icons.gps_off_rounded,
        iconBg: _teal,
        label: 'GPS OFF EVENTS',
        value: '${data.totalGpsOffEvents}',
      ),
      _AttendanceStat(
        icon: Icons.theater_comedy_rounded,
        iconBg: _leavesPurple,
        label: 'MOCK LOCATION',
        value: '${data.totalMockLocationEvents}',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: complianceStats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) =>
              _buildAttendanceStatCard(complianceStats[index]),
        ),
        const SizedBox(height: 16),
        _buildComplianceRiskCard(data),
      ],
    );
  }

  // ── Risk level colours: Low / Medium / High ─────────────────────────────
  (Color, Color) _riskLevelColors(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return (const Color(0xFFFCE1E1), _absentRed);
      case 'medium':
        return (const Color(0xFFFCEAD9), _lateOrange);
      default:
        return (const Color(0xFFDCF5E6), _presentGreen);
    }
  }

  // ── Auto-computed Risk Level card (geo violations + offline + GPS-off) ──
  Widget _buildComplianceRiskCard(AttendanceAnalyticsData data) {
    final risk = data.complianceRiskLevel;
    final colors = _riskLevelColors(risk);
    final pillBg = colors.$1;
    final pillFg = colors.$2;

    // NOTE: BorderRadius + a Border whose sides have different colors is
    // not supported by Flutter (it throws "A borderRadius can only be
    // given on borders with uniform colors" during paint, which left this
    // card rendering as a blank white box). Fix: keep the outer Border
    // uniform (_borderColor on all 4 sides) and draw the colored left
    // accent as a separate 4px strip widget instead, clipped to match the
    // same rounded corners via ClipRRect. Visual result is unchanged.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _borderColor),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: pillFg),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: pillBg, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.shield_rounded, color: pillFg, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compliance Risk Level',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Based on geo-fence, offline & GPS-off events this month',
                              style: const TextStyle(fontSize: 11, color: _textGray),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          risk.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800, color: pillFg),
                        ),
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

  // ── Simple View: stat cards grid + Attendance Score card ────────────────
  Widget _buildAttendanceSimpleView() {
    if (_currentAnalyticsData == null) return const SizedBox.shrink();

    final data = _currentAnalyticsData!;

    // Build stat cards from API data
    final attendanceStats = [
      _AttendanceStat(
        icon: Icons.check_rounded,
        iconBg: _presentGreen,
        label: 'PRESENT',
        value: '${data.presentDays}',
      ),
      _AttendanceStat(
        icon: Icons.trending_up_rounded,
        iconBg: _onTimeBlue,
        label: 'ON-TIME',
        value: '${data.onTimeArrivalDays}',
      ),
      _AttendanceStat(
        icon: Icons.directions_run_rounded,
        iconBg: _lateOrange,
        label: 'LATE',
        value: '${data.lateArrivalDays}',
      ),
      _AttendanceStat(
        icon: Icons.logout_rounded,
        iconBg: _earlyExitPink,
        label: 'EARLY EXIT',
        value: '${data.earlyExitDays}',
      ),
      _AttendanceStat(
        icon: Icons.schedule_rounded,
        iconBg: _halfDayPurple,
        label: 'HALF DAY',
        value: '${data.halfDays}',
      ),
      _AttendanceStat(
        icon: Icons.beach_access_rounded,
        iconBg: _leavesPurple,
        label: 'LEAVES',
        value: '${data.totalLeaveDays}',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendanceStats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) =>
              _buildAttendanceStatCard(attendanceStats[index]),
        ),
        const SizedBox(height: 16),
        _buildAttendanceScoreCard(data),
      ],
    );
  }

  Widget _buildAttendanceStatCard(_AttendanceStat stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: stat.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(stat.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            stat.label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _textGray,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(stat.value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
          if (stat.subtitle != '— -')
            Text(stat.subtitle,
                style: const TextStyle(fontSize: 10, color: _textGray)),
        ],
      ),
    );
  }

  // ── Attendance Score card ────────────────────────────────────────────
  Widget _buildAttendanceScoreCard(AttendanceAnalyticsData data) {
    final progress = data.attendanceScore / 100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: const BorderSide(color: _borderColor),
          right: const BorderSide(color: _borderColor),
          bottom: const BorderSide(color: _borderColor),
          left: const BorderSide(color: _scoreOrange, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: _tealDark, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Attendance Score',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark),
              ),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 14,
                decoration:
                const BoxDecoration(color: _lowBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Text(
                  'i',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _textGray),
                ),
              ),
              const Spacer(),
              Text(
                '${data.attendanceScore}%',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _scoreOrange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _scoreTrack,
              valueColor:
              const AlwaysStoppedAnimation<Color>(_scoreOrange),
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 11, color: _textDark, height: 1.2),
              children: [
                const TextSpan(
                    text: 'Main Issue: ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: data.mainIssue),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _suggestedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded,
                    color: _tealDark, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: _textDark, height: 1.2),
                      children: [
                        const TextSpan(
                            text: 'Suggested Action: ',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: data.suggestedAction),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Full Detail View ──────────────────────────────────────────────────
  Widget _buildAttendanceFullDetailList() {
    if (_currentAnalyticsData == null) return const SizedBox.shrink();

    final data = _currentAnalyticsData!;

    final detailItems = [
      ('Present Days', '${data.presentDays}', Icons.check_rounded,
      _presentGreen),
      ('On-Time Arrivals', '${data.onTimeArrivalDays}',
      Icons.trending_up_rounded, _onTimeBlue),
      ('Late Arrivals', '${data.lateArrivalDays}',
      Icons.directions_run_rounded, _lateOrange),
      ('Early Exits', '${data.earlyExitDays}', Icons.logout_rounded,
      _earlyExitPink),
      ('Half Days', '${data.halfDays}', Icons.schedule_rounded,
      _halfDayPurple),
      ('Total Leave Days', '${data.totalLeaveDays}',
      Icons.beach_access_rounded, _leavesPurple),
      ('Total Late Time', data.totalLateTime, Icons.access_time_filled_rounded,
      _lateOrange),
      ('Total Early Exit Time', data.totalEarlyExitTime,
      Icons.access_time_outlined, _earlyExitPink),
      ('Total Working Hours', data.totalWorkingHours,
      Icons.schedule_rounded, _teal),
      ('Geo Violations', '${data.totalGeoViolations}',
      Icons.location_off_rounded, Colors.red),
      ('Offline Events', '${data.totalOfflineEvents}',
      Icons.cloud_off_rounded, Colors.grey),
      ('Total Holidays', '${data.totalHolidays}', Icons.event_rounded,
      Colors.amber),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(detailItems.length, (index) {
              final item = detailItems[index];
              final isLast = index == detailItems.length - 1;
              return Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(bottom: BorderSide(color: _borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: item.$4,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(item.$3, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textDark),
                      ),
                    ),
                    Text(item.$2,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _textDark)),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        _buildAttendanceScoreCard(data),
        const SizedBox(height: 24),
        _buildDailyAttendanceSection(),
      ],
    );
  }

  // ── Daily Attendance section (real data from gpsattendancereport API) ──
  Widget _buildDailyAttendanceSection() {
    final filtered = _filteredDailyRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Attendance',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: _textDark),
        ),
        const SizedBox(height: 12),
        _buildDailySearchAndExportRow(),
        const SizedBox(height: 10),
        _buildDailyFilterChips(),
        const SizedBox(height: 14),
        if (_isDailyLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5)),
          )
        else if (_dailyRecords.isEmpty)
          _buildDailyEmptyState('No attendance records found for this month')
        else if (filtered.isEmpty)
            _buildDailyEmptyState('No records match your search/filter')
          else
            Column(
              children:
              filtered.map((record) => _buildDailyRecordCard(record)).toList(),
            ),
      ],
    );
  }

  Widget _buildDailyEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 36, color: _textGray.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textGray, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Search box + export icon ────────────────────────────────────────────
  Widget _buildDailySearchAndExportRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: TextField(
              controller: _dailySearchController,
              onChanged: (value) => setState(() => _dailySearchQuery = value),
              style: const TextStyle(fontSize: 13.5, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: _textGray, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _textGray, size: 20),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export feature coming soon'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: _tealDark,
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: const Icon(Icons.ios_share_rounded,
                color: _textDark, size: 19),
          ),
        ),
      ],
    );
  }

  // ── Status filter chips (All / Present / Late / Absent / Leave / ...) ──
  Widget _buildDailyFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _dailyStatusFilters
            .map((status) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _dailyFilterChip(status),
        ))
            .toList(),
      ),
    );
  }

  Widget _dailyFilterChip(String status) {
    final isActive = _dailyStatusFilter == status;
    return GestureDetector(
      onTap: () => setState(() => _dailyStatusFilter = status),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isActive ? _teal : _borderColor),
          boxShadow: isActive
              ? [
            BoxShadow(
                color: _teal.withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]
              : [],
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : _textDark,
          ),
        ),
      ),
    );
  }

  // ── Status pill colours for the daily record cards ─────────────────────
  (Color, Color) _dailyStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return (const Color(0xFFDCF5E6), _presentGreen);
      case 'late':
        return (const Color(0xFFFCEAD9), _lateOrange);
      case 'absent':
        return (const Color(0xFFFCE1E1), _absentRed);
      case 'leave':
        return (const Color(0xFFE6E4FB), _leavesPurple);
      case 'holiday':
        return (const Color(0xFFDCEAFB), _onTimeBlue);
      case 'half day':
        return (const Color(0xFFEDE6FB), _halfDayPurple);
      default:
        return (_lowBg, _textGray);
    }
  }

  // ── A single day's attendance card ──────────────────────────────────────
  Widget _buildDailyRecordCard(DailyAttendanceRecord record) {
    final colors = _dailyStatusColors(record.statusText);
    final pillBg = colors.$1;
    final pillFg = colors.$2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      record.dayAbbrev,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      record.dayNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.workDate,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: _textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status: ${record.statusText}',
                      style: const TextStyle(fontSize: 12.5, color: _textGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.statusText,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pillFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dailyTimeBox('IN', record.displayFirstIn)),
              const SizedBox(width: 8),
              Expanded(
                  child: _dailyTimeBox('OUT', record.displayLastOut)),
              const SizedBox(width: 8),
              Expanded(
                  child: _dailyTimeBox('HOURS', record.displayHours)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  record.displayNote,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: _textGray),
                ),
              ),
              GestureDetector(
                onTap: () => _showDailyRecordDetails(record),
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More Details',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _tealDark),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: _tealDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyTimeBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _dailyCardTimeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _textGray,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: _textDark),
          ),
        ],
      ),
    );
  }

  // ── "More Details" bottom sheet with the remaining API columns ─────────
  void _showDailyRecordDetails(DailyAttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final detailRows = <(String, String, IconData, Color)>[
          ('Shift Time', '${record.shiftStart} - ${record.shiftEnd}',
          Icons.work_history_rounded, _teal),
          ('Total Logs', '${record.totalLogs}', Icons.list_alt_rounded,
          _onTimeBlue),
          ('Total Stay', record.totalStay, Icons.timelapse_rounded, _teal),
          ('Late Time', record.lateTime, Icons.access_time_filled_rounded,
          _lateOrange),
          ('Early Exit', record.earlyExit, Icons.access_time_outlined,
          _earlyExitPink),
          ('Grace Period', record.isGrace, Icons.shield_outlined,
          _halfDayPurple),
          ('Day Type', record.dayType, Icons.calendar_view_day_rounded,
          _leavesPurple),
          ('On Leave', record.onLeave, Icons.beach_access_rounded,
          _leavesPurple),
          ('Geo Violations', '${record.geoViolations}',
          Icons.location_off_rounded, Colors.red),
          ('Offline Events', '${record.offlineEvents}',
          Icons.cloud_off_rounded, Colors.grey),
        ];

        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          decoration: const BoxDecoration(
            color: _bgCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${record.dayName} • ${record.workDate}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
              ),
              const SizedBox(height: 2),
              Text(
                'Status: ${record.statusText}',
                style: const TextStyle(fontSize: 12.5, color: _textGray),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(detailRows.length, (index) {
                    final row = detailRows[index];
                    final isLast = index == detailRows.length - 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(
                            bottom: BorderSide(color: _borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: row.$4,
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(row.$3, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              row.$1,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark),
                            ),
                          ),
                          Text(row.$2,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
