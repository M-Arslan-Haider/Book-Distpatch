import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'schedule_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
// schedule_hub_screen.dart
//
// Opens when the user taps "Schedule" in the bottom navigation bar.
//
// Matches the provided screenshots:
//   - "Schedule" title
//   - Daily / Weekly / Monthly / Kanban segmented tabs  -> DUMMY (UI only,
//     no logic, same as the screenshot)
//   - Locations / Routes toggle buttons
//       • Locations (default/active) -> shows the dummy location cards
//         exactly as in the screenshot (pure UI, no API calls)
//       • Routes -> shows the EXISTING ScheduleScreen (schedule_screen.dart)
//         INLINE, right below the title/tabs/toggle (which stay visible),
//         exactly like the second screenshot. ScheduleScreen still fetches
//         real route data from the GPS Workforce ORDS API — NO LOGIC CHANGE,
//         it is just rendered with showAppBar: false so it has no duplicate
//         "Schedule" app bar of its own.
//
// NOTE: adjust the `widgets/app_bottom_navbar.dart` import path below if the
// actual project structure differs.
// ═══════════════════════════════════════════════════════════════════════════

class ScheduleHubScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const ScheduleHubScreen({
    super.key,
    this.currentIndex = 2,
    this.chatBadgeCount = 0,
    required this.onNavTap,
  });

  @override
  State<ScheduleHubScreen> createState() => _ScheduleHubScreenState();
}

class _ScheduleHubScreenState extends State<ScheduleHubScreen> {
  // ── Design tokens (matching schedule_screen.dart) ──────────────────────
  static const _bgPage   = Color(0xFFF5F0E8);
  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);
  static const _pillBg   = Color(0xFFEDE3D2);

  static const _periodTabs = ['Daily', 'Weekly', 'Monthly', 'Kanban'];
  String _selectedPeriod = 'Daily';

  // Date picked from the inline calendar shown under Weekly / Monthly tabs.
  // Defaults to today, so behaviour is unchanged until the user picks a
  // different date.
  DateTime _selectedFilterDate = DateTime.now();

  // false = Locations (API data, default) | true = Routes (embedded ScheduleScreen)
  bool _routesActive = false;

  // ── Locations tab — API state ──────────────────────────────────────────
  List<Map<String, dynamic>> _locations = [];
  bool    _isLoadingLocations = true;
  String? _locationsError;

  // Employee info — loaded from SharedPreferences same as ScheduleScreen
  String _empId       = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    _loadEmployeeAndFetchLocations();
  }

  // ── Load from SharedPreferences (same keys as ScheduleScreen) ──────────
  Future<void> _loadEmployeeAndFetchLocations() async {
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

    debugPrint('📍 [ScheduleHubScreen] empId      : "$_empId"');
    debugPrint('📍 [ScheduleHubScreen] companyCode: "$_companyCode"');

    await _fetchLocations();
  }

  // ── API call ───────────────────────────────────────────────────────────
  Future<void> _fetchLocations() async {
    setState(() {
      _isLoadingLocations = true;
      _locationsError     = null;
    });

    if (_empId.isEmpty) {
      setState(() {
        _locationsError      = 'Employee info not found.\nPlease log out and log in again.';
        _isLoadingLocations = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/schedulelocation/get/',
      ).replace(queryParameters: {
        'emp_id':       _empId,
        'company_code': _companyCode,
      });

      debugPrint('📍 [ScheduleHubScreen] Fetching: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📍 [ScheduleHubScreen] Status: ${response.statusCode}');
      debugPrint('📍 [ScheduleHubScreen] Body  : ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Handle Oracle ORDS {items:[]} or plain list
        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('items')) {
          items = decoded['items'] as List<dynamic>;
        }

        setState(() {
          _locations          = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoadingLocations = false;
        });
      } else {
        setState(() {
          _locationsError     = 'Server error: ${response.statusCode}';
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] Fetch error: $e');
      setState(() {
        _locationsError     = 'Failed to load locations.\nCheck your connection and try again.';
        _isLoadingLocations = false;
      });
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────
  String _getScheduleDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'] ?? '';
    if (raw.toString().isEmpty) return '—';
    final s = raw.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _getLocationTimeRange(Map<String, dynamic> r) {
    final start = r['START_TIME'] ?? r['start_time'] ?? '';
    final end   = r['END_TIME']   ?? r['end_time']   ?? '';
    if (start.toString().isEmpty && end.toString().isEmpty) return '';
    return '${start.toString()} - ${end.toString()}';
  }

  String _getLocationTitle(Map<String, dynamic> r) =>
      (r['LOCATION_NAME'] ?? r['location_name'] ??
          r['BUILDING_OFFICE'] ?? r['building_office'] ?? 'Location').toString();

  String _getLocationStatus(Map<String, dynamic> r) =>
      (r['STATUS'] ?? r['status'] ?? 'Pending').toString();

  // ── Geo-fence field helpers (from GEO_FENCING via schedulelocation API) ──
  double? _toDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  double? _getGeoLat(Map<String, dynamic> r) =>
      _toDouble(r['LAT_IN'] ?? r['lat_in']);

  double? _getGeoLng(Map<String, dynamic> r) =>
      _toDouble(r['LNG_IN'] ?? r['lng_in']);

  double? _getGeoRadius(Map<String, dynamic> r) =>
      _toDouble(r['RADIUS'] ?? r['radius']);

  // ── Period filter helpers (Daily / Weekly / Monthly / Kanban) ──────────
  // Daily / Weekly / Monthly filter _locations by SCHEDULE_DATE relative to
  // today. Kanban does not filter by date — it groups all locations by
  // status into board columns instead.
  DateTime? _getRawScheduleDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'];
    if (raw == null || raw.toString().isEmpty) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameWeek(DateTime a, DateTime b) {
    final weekStart = b.subtract(Duration(days: b.weekday - 1));
    final startDay  = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endDay    = startDay.add(const Duration(days: 6));
    final aDay      = DateTime(a.year, a.month, a.day);
    return !aDay.isBefore(startDay) && !aDay.isAfter(endDay);
  }

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  List<Map<String, dynamic>> _applyPeriodFilter(
      List<Map<String, dynamic>> items) {
    if (_selectedPeriod == 'Kanban') return items;
    final today = DateTime.now();
    return items.where((r) {
      final d = _getRawScheduleDate(r);
      if (d == null) return false;
      switch (_selectedPeriod) {
        case 'Weekly':
          return _isSameWeek(d, _selectedFilterDate);
        case 'Monthly':
          return _isSameMonth(d, _selectedFilterDate);
        default: // 'Daily'
          return _isSameDay(d, today);
      }
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupLocationsByStatus(
      List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final r in items) {
      final status = _getLocationStatus(r);
      groups.putIfAbsent(status, () => []).add(r);
    }
    return groups;
  }

  // ── Professional status snackbar ────────────────────────────────────────
  // Floating, rounded, icon + title/subtitle layout used for all start-flow
  // feedback (verifying / success / errors).
  void _showStatusSnackBar({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 6,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Start button handler ────────────────────────────────────────────────
  // Only allows "Start" if the user's current GPS location is within the
  // location's geo-fence radius (LAT_IN / LNG_IN / RADIUS from the
  // schedulelocation API). Otherwise shows a professional status message.
  Future<void> _handleStartTap(Map<String, dynamic> loc) async {
    final name      = _getLocationTitle(loc);
    final geoLat    = _getGeoLat(loc);
    final geoLng    = _getGeoLng(loc);
    final geoRadius = _getGeoRadius(loc);

    if (geoLat == null || geoLng == null || geoRadius == null) {
      _showStatusSnackBar(
        title: 'Location Not Configured',
        subtitle:
        'No geo-fence boundary is set up for "$name". Please contact your administrator.',
        icon: Icons.location_off_rounded,
        color: const Color(0xFF6B7280),
      );
      return;
    }

    // ── Location permission ────────────────────────────────────────────
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      _showStatusSnackBar(
        title: 'Location Permission Required',
        subtitle: 'Please allow location access so we can verify you are on-site.',
        icon: Icons.location_disabled_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showStatusSnackBar(
        title: 'Location Services Disabled',
        subtitle: 'Please turn on device location/GPS to continue.',
        icon: Icons.location_off_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    _showStatusSnackBar(
      title: 'Verifying Your Location',
      subtitle: 'Please wait while we confirm you are at "$name"...',
      icon: Icons.my_location_rounded,
      color: _tealDark,
      duration: const Duration(seconds: 2),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final distanceM = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, geoLat, geoLng,
      );

      if (distanceM <= geoRadius) {
        _showStatusSnackBar(
          title: 'Started Successfully',
          subtitle: 'You have checked in at "$name". Your shift has started.',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF1E8A5E),
        );
        // TODO: hook the actual "start" action here (e.g. API call / navigation)
      } else {
        _showStatusSnackBar(
          title: 'Outside Location Range',
          subtitle:
          'You must be within ${geoRadius.toStringAsFixed(0)} m of "$name" to start. '
              'You are currently ${distanceM.toStringAsFixed(0)} m away.',
          icon: Icons.wrong_location_rounded,
          color: const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      _showStatusSnackBar(
        title: 'Location Unavailable',
        subtitle: 'Unable to get your current location. Please try again.',
        icon: Icons.gps_off_rounded,
        color: const Color(0xFFDC2626),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: SafeArea(
        child: Column(
          children: [
            // ── Title ───────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ),

            // ── Daily / Weekly / Monthly / Kanban (dummy) ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildPeriodTabs(),
            ),

            const SizedBox(height: 14),

            // ── Locations / Routes toggle ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildViewToggle(),
            ),

            const SizedBox(height: 16),

            // ── Calendar — shown only for Weekly / Monthly so the user can
            //    pick which week/month to view ───────────────────────────
            if (_selectedPeriod == 'Weekly' || _selectedPeriod == 'Monthly') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildCalendarPicker(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: _routesActive
                  ? ScheduleScreen(
                showAppBar: false,
                periodFilter: _selectedPeriod,
                referenceDate: _selectedFilterDate,
              )
                  : _buildLocationsList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: (i) {
          Navigator.pop(context);
          widget.onNavTap(i);
        },
      ),
    );
  }

  // ── Daily / Weekly / Monthly / Kanban — dummy segmented control ────────
  Widget _buildPeriodTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _pillBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: _periodTabs.map((tab) {
          final isActive = tab == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                      : null,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Locations / Routes toggle buttons ───────────────────────────────────
  Widget _buildViewToggle() {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            icon: Icons.location_on_rounded,
            label: 'Locations',
            active: !_routesActive,
            onTap: () => setState(() => _routesActive = false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleButton(
            icon: Icons.alt_route_rounded,
            label: 'Routes',
            active: _routesActive,
            onTap: () => setState(() => _routesActive = true),
          ),
        ),
      ],
    );
  }

  // ── Inline calendar — lets the user pick the week/month to view ────────
  Widget _buildCalendarPicker() {
    final now = DateTime.now();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _tealDark,
            onPrimary: Colors.white,
            onSurface: const Color(0xFF1F2937),
          ),
        ),
        child: CalendarDatePicker(
          initialDate: _selectedFilterDate,
          firstDate: DateTime(now.year - 5, 1, 1),
          lastDate: DateTime(now.year + 5, 12, 31),
          onDateChanged: (date) => setState(() => _selectedFilterDate = date),
        ),
      ),
    );
  }

  // ── Locations list — now driven by the schedulelocation API ─────────────
  Widget _buildLocationsList() {
    if (_isLoadingLocations) {
      return const Center(
        child: CircularProgressIndicator(
          color: _teal,
          strokeWidth: 3,
        ),
      );
    }

    if (_locationsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _locationsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadEmployeeAndFetchLocations,
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

    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                color: _teal.withOpacity(0.5), size: 56),
            const SizedBox(height: 16),
            const Text(
              'No locations scheduled',
              style: TextStyle(
                  color: Colors.black45,
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // ── Kanban view — groups all locations by status into board columns ──
    if (_selectedPeriod == 'Kanban') {
      return _buildLocationsKanban();
    }

    // ── Daily / Weekly / Monthly — filter by SCHEDULE_DATE ────────────────
    final filtered = _applyPeriodFilter(_locations);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded,
                color: _teal.withOpacity(0.5), size: 56),
            const SizedBox(height: 16),
            Text(
              'No locations for ${_selectedPeriod.toLowerCase()} view',
              style: const TextStyle(
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
      onRefresh: _fetchLocations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: filtered.length + 1, // +1 for the page indicator
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const _PageIndicator(),
            );
          }

          final loc    = filtered[index];
          final status = _getLocationStatus(loc);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LocationCard(
              date:      _getScheduleDate(loc),
              status:    status,
              title:     _getLocationTitle(loc),
              time:      _getLocationTimeRange(loc),
              showStart: status.toLowerCase() != 'approved',
              onStartTap: () => _handleStartTap(loc),
            ),
          );
        },
      ),
    );
  }

  // ── Kanban board for Locations — grouped by status into columns ────────
  Widget _buildLocationsKanban() {
    final groups = _groupLocationsByStatus(_locations);
    const order  = ['Pending', 'Approved', 'Rejected', 'Cancelled'];
    final keys   = [
      ...order.where(groups.containsKey),
      ...groups.keys.where((k) => !order.contains(k)),
    ];

    return RefreshIndicator(
      color: _teal,
      onRefresh: _fetchLocations,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final key      = keys[i];
                final colItems = groups[key]!;
                return _KanbanColumn(
                  title: key,
                  count: colItems.length,
                  children: colItems.map((loc) {
                    final status = _getLocationStatus(loc);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LocationCard(
                        date:      _getScheduleDate(loc),
                        status:    status,
                        title:     _getLocationTitle(loc),
                        time:      _getLocationTimeRange(loc),
                        showStart: status.toLowerCase() != 'approved',
                        onStartTap: () => _handleStartTap(loc),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Locations / Routes toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? _tealDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: active ? null : Border.all(color: const Color(0xFFE5E0D5)),
          boxShadow: active
              ? [
            BoxShadow(
              color: _tealDark.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kanban column — fixed-width vertical lane used by the Kanban board view
// ─────────────────────────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _KanbanColumn({
    required this.title,
    required this.count,
    required this.children,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  Color get _dotColor {
    switch (title.toLowerCase()) {
      case 'approved':
        return const Color(0xFF1E8A5E);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return _tealDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE3D2).withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: children.isEmpty
                ? Center(
              child: Text(
                'Empty',
                style: TextStyle(
                  color: _teal.withOpacity(0.6),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : ListView(children: children),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dummy Location Card  —  visual match of the screenshot
// ─────────────────────────────────────────────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final String date;
  final String status;
  final String title;
  final String time;
  final bool showStart;
  final VoidCallback? onStartTap;

  const _LocationCard({
    required this.date,
    required this.status,
    required this.title,
    required this.time,
    required this.showStart,
    this.onStartTap,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    final isApproved = status.toLowerCase() == 'approved';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date badge + status badge ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_teal, _tealDark],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isApproved
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Title ───────────────────────────────────────────────────
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 6),

          // ── Time row ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 5),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Action buttons ──────────────────────────────────────────
          Row(
            children: [
              const _PillButton(
                icon: Icons.map_rounded,
                label: 'GPS View',
                filled: true,
              ),
              if (showStart) const SizedBox(width: 10),
              if (showStart)
                _PillButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  filled: false,
                  onTap: onStartTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill button (GPS View / Start) — dummy, visual only
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
            colors: [_teal, _tealDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : null,
          color: filled ? null : const Color(0xFFE6F4F1),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : _tealDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : _tealDark,
                fontSize: 12.5,
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
// Decorative page indicator (matches the small dot/bar under the cards
// in the screenshot) — purely cosmetic, dummy
// ─────────────────────────────────────────────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  const _PageIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF0C6B64),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD1D5DB),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
