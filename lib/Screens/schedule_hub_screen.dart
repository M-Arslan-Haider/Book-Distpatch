import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: _routesActive
                  ? const ScheduleScreen(showAppBar: false)
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

    return RefreshIndicator(
      color: _teal,
      onRefresh: _fetchLocations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _locations.length + 1, // +1 for the page indicator
        itemBuilder: (context, index) {
          if (index == _locations.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const _PageIndicator(),
            );
          }

          final loc    = _locations[index];
          final status = _getLocationStatus(loc);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LocationCard(
              date:      _getScheduleDate(loc),
              status:    status,
              title:     _getLocationTitle(loc),
              time:      _getLocationTimeRange(loc),
              showStart: status.toLowerCase() != 'approved',
            ),
          );
        },
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
// Dummy Location Card  —  visual match of the screenshot
// ─────────────────────────────────────────────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final String date;
  final String status;
  final String title;
  final String time;
  final bool showStart;

  const _LocationCard({
    required this.date,
    required this.status,
    required this.title,
    required this.time,
    required this.showStart,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    final isApproved = status.toLowerCase() == 'approved';

    return Container(
      padding: const EdgeInsets.all(12),
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
          // ── Date badge + status badge ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isApproved
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Title ───────────────────────────────────────────────────
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 8),

          // ── Time row ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 16, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Action buttons (dummy — visual only) ───────────────────────
          Row(
            children: [
              const _PillButton(
                icon: Icons.map_rounded,
                label: 'GPS View',
                filled: true,
              ),
              if (showStart) const SizedBox(width: 10),
              if (showStart)
                const _PillButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  filled: false,
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

  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
  });

  static const _teal     = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
          colors: [_teal, _tealDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
            : null,
        color: filled ? null : const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: filled ? Colors.white : _tealDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : _tealDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
