import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'route_map_screen.dart';
import 'navigation_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// schedule_screen.dart
//
// Opens when user taps "Schedule" in the bottom nav bar.
// Reads empId and companyCode from SharedPreferences (same as LeaveViewModel).
// Fetches routes from:
//   GET http://oracle.metaxperts.net/ords/gps_workforce/gpsroute/get/
//   params: emp_id, company_code
//
// Displays cards exactly like the screenshot:
//   - Date badge (teal pill, top-left)
//   - Status badge (Approved/Pending, top-right)
//   - Route name (bold title)
//   - Clock icon + time range
//   - GPS View button (always shown)
//   - Start button (shown only when status is NOT Approved)
// ═══════════════════════════════════════════════════════════════════════════

class ScheduleScreen extends StatefulWidget {
  /// When false, the screen renders just its body content (no Scaffold /
  /// AppBar) so it can be embedded inline — e.g. inside ScheduleHubScreen's
  /// "Routes" tab. Default true keeps the original standalone behaviour.
  final bool showAppBar;

  const ScheduleScreen({super.key, this.showAppBar = true});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // ── Design tokens ──────────────────────────────────────────────────────
  static const _bgPage  = Color(0xFFF5F0E8);
  static const _teal    = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  // ── State ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _routes = [];
  bool    _isLoading = true;
  String? _error;

  // Employee info — loaded from SharedPreferences same as LeaveViewModel
  String _empId       = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    _loadEmployeeAndFetch();
  }

  // ── Load from SharedPreferences (same keys as LeaveViewModel) ──────────
  Future<void> _loadEmployeeAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _empId = prefs.getString('userId')      ??
        prefs.getString('user_id')     ??
        prefs.getString('emp_id')      ??
        prefs.getString('empId')       ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId')  ?? '';

    _companyCode = prefs.getString('companyCode')   ??
        prefs.getString('company_code')  ??
        prefs.getString('COMPANY_CODE')  ?? '';

    debugPrint('📅 [ScheduleScreen] empId      : "$_empId"');
    debugPrint('📅 [ScheduleScreen] companyCode: "$_companyCode"');

    await _fetchRoutes();
  }

  // ── API call ───────────────────────────────────────────────────────────
  Future<void> _fetchRoutes() async {
    setState(() {
      _isLoading = true;
      _error     = null;
    });

    if (_empId.isEmpty) {
      setState(() {
        _error     = 'Employee info not found.\nPlease log out and log in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/gpsroute/get/',
      ).replace(queryParameters: {
        'emp_id':       _empId,
        'company_code': _companyCode,
      });

      debugPrint('📅 [ScheduleScreen] Fetching: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📅 [ScheduleScreen] Status: ${response.statusCode}');
      debugPrint('📅 [ScheduleScreen] Body  : ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Handle Oracle ORDS {items:[]} or plain list
        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('items')) {
          items = decoded['items'] as List<dynamic>;
        } else if (decoded is Map && decoded.containsKey('routes')) {
          items = decoded['routes'] as List<dynamic>;
        }

        setState(() {
          _routes    = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error     = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ScheduleScreen] Fetch error: $e');
      setState(() {
        _error     = 'Failed to load schedule.\nCheck your connection and try again.';
        _isLoading = false;
      });
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────

  String _getDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'] ??
        r['ROUTE_DATE']    ?? r['route_date']    ??
        r['DATE']          ?? r['date']          ?? '';
    if (raw.toString().isEmpty) return '—';
    final s = raw.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _getTimeRange(Map<String, dynamic> r) {
    final start = r['START_TIME'] ?? r['start_time'] ??
        r['FROM_TIME']  ?? r['from_time']  ?? '';
    final end   = r['END_TIME']   ?? r['end_time']   ??
        r['TO_TIME']    ?? r['to_time']     ?? '';
    if (start.toString().isEmpty && end.toString().isEmpty) return '';
    return '${start.toString()} – ${end.toString()}';
  }

  String _getRouteName(Map<String, dynamic> r) =>
      (r['ROUTE_NAME'] ?? r['route_name'] ?? 'Route').toString();

  String _getStatus(Map<String, dynamic> r) =>
      (r['STATUS'] ?? r['status'] ??
          r['ROUTE_STATUS'] ?? r['route_status'] ?? 'Pending').toString();

  bool _isApproved(String status) => status.toLowerCase() == 'approved';

  String _getDesc(Map<String, dynamic> r) =>
      (r['ROUTE_DESC'] ?? r['route_desc'] ?? '').toString().trim();

  String _getOriginAddress(Map<String, dynamic> r) =>
      (r['ORIGIN_ADDRESS'] ?? r['origin_address'] ?? '').toString().trim();

  String _getDestAddress(Map<String, dynamic> r) =>
      (r['DEST_ADDRESS'] ?? r['dest_address'] ?? '').toString().trim();

  String _getTotalDistance(Map<String, dynamic> r) =>
      (r['TOTAL_DISTANCE'] ?? r['total_distance'] ?? '').toString().trim();

  String _getTotalDuration(Map<String, dynamic> r) =>
      (r['TOTAL_DURATION'] ?? r['total_duration'] ?? '').toString().trim();

  String _getTravelMode(Map<String, dynamic> r) =>
      (r['TRAVEL_MODE'] ?? r['travel_mode'] ?? '').toString().trim();

  String _getTotalWaypoints(Map<String, dynamic> r) =>
      (r['TOTAL_WAYPOINTS'] ?? r['total_waypoints'] ?? '').toString().trim();

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      // Embedded mode — body only (used inside ScheduleHubScreen's
      // "Routes" tab, which already shows its own title/tabs/toggle).
      return _buildBody();
    }

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _tealDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadEmployeeAndFetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0C9E8E),
          strokeWidth: 3,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEmployeeAndFetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                color: _teal.withOpacity(0.5), size: 56),
            const SizedBox(height: 16),
            const Text(
              'No routes scheduled',
              style: TextStyle(
                  color: Colors.black45,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      onRefresh: _loadEmployeeAndFetch,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final r = _routes[index];
          final status     = _getStatus(r);
          final isApproved = _isApproved(status);
          return _RouteCard(
            route:         r,
            date:          _getDate(r),
            timeRange:     _getTimeRange(r),
            routeName:     _getRouteName(r),
            status:        status,
            isApproved:    isApproved,
            desc:          _getDesc(r),
            originAddress: _getOriginAddress(r),
            destAddress:   _getDestAddress(r),
            totalDistance: _getTotalDistance(r),
            totalDuration: _getTotalDuration(r),
            travelMode:    _getTravelMode(r),
            totalWaypoints: _getTotalWaypoints(r),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Card  —  professional redesign
// ─────────────────────────────────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final String date;
  final String timeRange;
  final String routeName;
  final String status;
  final bool   isApproved;
  final String desc;
  final String originAddress;
  final String destAddress;
  final String totalDistance;
  final String totalDuration;
  final String travelMode;
  final String totalWaypoints;

  const _RouteCard({
    required this.route,
    required this.date,
    required this.timeRange,
    required this.routeName,
    required this.status,
    required this.isApproved,
    required this.desc,
    required this.originAddress,
    required this.destAddress,
    required this.totalDistance,
    required this.totalDuration,
    required this.travelMode,
    required this.totalWaypoints,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    // ── Build "4 Stops · 28 km · 1h 45m" style summary line ───────────────
    final statsParts = <String>[];
    if (totalWaypoints.isNotEmpty && totalWaypoints != '0') {
      statsParts.add('$totalWaypoints Stops');
    }
    if (totalDistance.isNotEmpty) statsParts.add(totalDistance);
    if (totalDuration.isNotEmpty) statsParts.add(totalDuration);
    final statsLine = statsParts.join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Date badge + status badge ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 12),

          // ── Route name ────────────────────────────────────────────────
          Text(
            routeName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // ── Time row ─────────────────────────────────────────────────
          if (timeRange.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // ── Stops · Distance · Duration row ─────────────────────────
          if (statsLine.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  travelMode.isNotEmpty
                      ? _travelModeIcon(travelMode)
                      : Icons.alt_route_rounded,
                  size: 16,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Text(
                  statsLine,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Action buttons ───────────────────────────────────────────
          Row(
            children: [
              _GpsViewButton(route: route),
              if (!isApproved) ...[
                const SizedBox(width: 10),
                Expanded(child: _StartButton(route: route)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static IconData _travelModeIcon(String mode) {
    final m = mode.toLowerCase();
    if (m == 'walking' || m == 'walk')  return Icons.directions_walk_rounded;
    if (m == 'cycling' || m == 'cycle') return Icons.directions_bike_rounded;
    return Icons.directions_car_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS View Button — opens RouteMapScreen for this route
// ─────────────────────────────────────────────────────────────────────────────
class _GpsViewButton extends StatelessWidget {
  final Map<String, dynamic> route;
  const _GpsViewButton({required this.route});

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteMapScreen(route: route),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_teal, _tealDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'GPS View',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge — light pill (used on white card background)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        bg    = const Color(0xFFD1FAE5);
        fg    = const Color(0xFF065F46);
        label = 'Approved';
        break;
      case 'pending':
        bg    = const Color(0xFFFEF3C7);
        fg    = const Color(0xFF92400E);
        label = 'Pending';
        break;
      case 'rejected':
        bg    = const Color(0xFFFEE2E2);
        fg    = const Color(0xFFB91C1C);
        label = 'Rejected';
        break;
      case 'cancelled':
        bg    = const Color(0xFFFEE2E2);
        fg    = const Color(0xFFB91C1C);
        label = 'Cancelled';
        break;
      default:
        bg    = const Color(0xFFF3F4F6);
        fg    = const Color(0xFF6B7280);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Button — compact pill, sits alongside GPS View
// ─────────────────────────────────────────────────────────────────────────────
class _StartButton extends StatelessWidget {
  final Map<String, dynamic> route;
  const _StartButton({required this.route});

  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationScreen(route: route),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: _tealDark, size: 16),
            SizedBox(width: 6),
            Text(
              'Start',
              style: TextStyle(
                color: _tealDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


