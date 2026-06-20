import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../AppColors.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'HomeScreenComponents/navbar.dart';
import 'schedule_screen.dart';

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
  static const _bgPage = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);
  static const _pillBg = Color(0xFFEDE3D2);

  // ✅ GPS-accuracy tolerance for rectangle/polygon geofence checks (meters)
  static const double _geofenceBufferMeters = 10.0;

  static const _periodTabs = ['Daily', 'Weekly', 'Monthly'];
  String _selectedPeriod = 'Daily';
  DateTime _selectedFilterDate = DateTime.now();

  List<Map<String, dynamic>> _routesForCalendar = [];
  bool _routesActive = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _empName = 'Employee';
  String _empInitials = '??';

  List<Map<String, dynamic>> _locations = [];
  bool _isLoadingLocations = true;
  String? _locationsError;

  String _empId = '';
  String _companyCode = '';

  static const String _PENDING_ACTIONS_KEY = 'pending_schedule_actions';

  // API Endpoints
  static const String _POST_API =
      'http://oracle.metaxperts.net/ords/gps_workforce/shedulelocation/post/';
  static const String _UPDATE_API =
      'http://oracle.metaxperts.net/ords/gps_workforce/sheduleupdate/put/';

  static const String _STATUS_GET_API =
      'http://oracle.metaxperts.net/ords/gps_workforce/schedulelocationget/get/';

  // Cache for location statuses - key is SCHEDULE_NO (e.g., "SCH-000021")
  final Map<String, Map<String, String>> _statusCache = {};

  @override
  void initState() {
    super.initState();
    _loadEmployeeAndFetchLocations();
  }

  String _formatOracleDateTime(DateTime dateTime) {
    final monthNames = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute:$second';
  }

  Future<void> _loadEmployeeAndFetchLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ?? '';

    _companyCode = prefs.getString('companyCode') ??
        prefs.getString('company_code') ??
        prefs.getString('COMPANY_CODE') ?? '';

    final name = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('empName') ??
        'Employee';
    setState(() {
      _empName = name;
      _empInitials = _getInitials(name);
    });

    debugPrint('📍 [ScheduleHubScreen] empId: "$_empId"');
    debugPrint('📍 [ScheduleHubScreen] companyCode: "$_companyCode"');

    await _fetchLocations();
    await _fetchLocationStatuses();
    await _syncPendingActions();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ✅ Get SCHEDULE_NO from location data
  String _getScheduleNo(Map<String, dynamic> r) =>
      (r['schedule_no'] ?? r['SCHEDULE_NO'] ?? '').toString();

  Future<void> _fetchLocationStatuses() async {
    try {
      final uri = Uri.parse(_STATUS_GET_API).replace(queryParameters: {
        'emp_id': _empId,
        'company_code': _companyCode,
      });

      debugPrint('📊 [STATUS] Fetching: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 [STATUS] Status: ${response.statusCode}');
      debugPrint('📊 [STATUS] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('items')) {
          items = decoded['items'] as List<dynamic>;
        }

        _statusCache.clear();

        for (final item in items) {
          // ✅ Use SCHEDULE_NO from STATUS API
          final scheduleNo = item['schedule_no']?.toString() ?? '';
          if (scheduleNo.isEmpty) continue;

          final completeAction = item['complete_action']?.toString() ?? '';
          final startAction = item['start_action']?.toString() ?? '';

          if (completeAction == 'COMPLETED' || completeAction == 'Y') {
            _statusCache[scheduleNo] = {
              'start_action': startAction,
              'start_action_time': item['start_action_time']?.toString() ?? '',
              'complete_action': 'COMPLETED',
              'complete_action_time': item['complete_action_time']?.toString() ?? '',
            };
            debugPrint('📊 [STATUS] ✅ COMPLETED for SCHEDULE_NO: $scheduleNo');
          } else if (!_statusCache.containsKey(scheduleNo)) {
            _statusCache[scheduleNo] = {
              'start_action': startAction,
              'start_action_time': item['start_action_time']?.toString() ?? '',
              'complete_action': completeAction,
              'complete_action_time': item['complete_action_time']?.toString() ?? '',
            };
            debugPrint('📊 [STATUS] ⏳ Status for SCHEDULE_NO: $scheduleNo');
          }
        }

        debugPrint('📊 [STATUS] Loaded ${_statusCache.length} status records');

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('❌ [STATUS] Fetch error: $e');
    }
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoadingLocations = true;
      _locationsError = null;
    });

    if (_empId.isEmpty) {
      setState(() {
        _locationsError = 'Employee info not found.\nPlease log out and log in again.';
        _isLoadingLocations = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/schedulelocation/get/',
      ).replace(queryParameters: {
        'emp_id': _empId,
        'company_code': _companyCode,
      });

      debugPrint('📍 [ScheduleHubScreen] Fetching: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📍 [ScheduleHubScreen] Status: ${response.statusCode}');
      debugPrint('📍 [ScheduleHubScreen] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded.containsKey('items')) {
          items = decoded['items'] as List<dynamic>;
        }

        setState(() {
          _locations = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoadingLocations = false;
        });

        debugPrint('📍 [ScheduleHubScreen] Loaded ${_locations.length} locations');
      } else {
        setState(() {
          _locationsError = 'Server error: ${response.statusCode}';
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] Fetch error: $e');
      setState(() {
        _locationsError = 'Failed to load locations.\nCheck your connection and try again.';
        _isLoadingLocations = false;
      });
    }
  }

  String _getScheduleDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'] ?? '';
    if (raw.toString().isEmpty) return '—';
    final s = raw.toString();
    if (s.contains('T')) {
      return s.substring(0, 10);
    }
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _getLocationTimeRange(Map<String, dynamic> r) {
    final start = r['START_TIME'] ?? r['start_time'] ?? '';
    final end = r['END_TIME'] ?? r['end_time'] ?? '';
    if (start.toString().isEmpty && end.toString().isEmpty) return '';
    return '${start.toString()} - ${end.toString()}';
  }

  String _getLocationTitle(Map<String, dynamic> r) =>
      (r['LOCATION_NAME'] ?? r['location_name'] ??
          r['BUILDING_OFFICE'] ?? r['building_office'] ?? 'Location').toString();

  String _getLocationStatus(Map<String, dynamic> r) {
    final scheduleNo = _getScheduleNo(r);

    // ✅ Check cache using SCHEDULE_NO
    if (_statusCache.containsKey(scheduleNo)) {
      final statusData = _statusCache[scheduleNo]!;
      final completeAction = statusData['complete_action'] ?? '';
      final startAction = statusData['start_action'] ?? '';

      if (completeAction == 'COMPLETED' || completeAction == 'Y') {
        return 'Completed';
      } else if (startAction == 'STARTED' || startAction == 'Y') {
        return 'Started';
      }
    }

    // Fallback: check local status
    final actionStatus = r['_local_status'];
    if (actionStatus != null) {
      return actionStatus.toString();
    }

    return 'Pending';
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  double? _getGeoLat(Map<String, dynamic> r) =>
      _toDouble(r['LAT_IN'] ?? r['lat_in'] ?? r['lat']);

  double? _getGeoLng(Map<String, dynamic> r) =>
      _toDouble(r['LNG_IN'] ?? r['lng_in'] ?? r['lng']);

  double? _getGeoRadius(Map<String, dynamic> r) =>
      _toDouble(r['RADIUS'] ?? r['radius']);

  // ✅ Geofence shape support (circle / rectangle / polygon)
  String? _getShapeType(Map<String, dynamic> r) {
    final v = r['SHAPE_TYPE'] ?? r['shape_type'];
    if (v == null) return null;
    final s = v.toString().trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic>? _getShapeCoords(Map<String, dynamic> r) {
    final raw = r['SHAPE_COORDS'] ?? r['shape_coords'];
    if (raw == null) return null;
    try {
      if (raw is String) {
        if (raw.trim().isEmpty) return null;
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return null;
      } else if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isPointInRectangle(double lat, double lng, Map<String, dynamic> coords) {
    try {
      final ne = coords['ne'] as Map;
      final sw = coords['sw'] as Map;
      final neLat = _toDouble(ne['lat']);
      final neLng = _toDouble(ne['lng']);
      final swLat = _toDouble(sw['lat']);
      final swLng = _toDouble(sw['lng']);
      if (neLat == null || neLng == null || swLat == null || swLng == null) {
        return false;
      }
      final minLat = swLat < neLat ? swLat : neLat;
      final maxLat = swLat < neLat ? neLat : swLat;
      final minLng = swLng < neLng ? swLng : neLng;
      final maxLng = swLng < neLng ? neLng : swLng;

      // ✅ Expand bounds slightly to tolerate normal GPS accuracy noise
      final centerLat = (minLat + maxLat) / 2;
      final latBufferDeg = _geofenceBufferMeters / 111320.0;
      final lngBufferDeg = _geofenceBufferMeters /
          (111320.0 * math.cos(centerLat * math.pi / 180.0));

      return lat >= (minLat - latBufferDeg) &&
          lat <= (maxLat + latBufferDeg) &&
          lng >= (minLng - lngBufferDeg) &&
          lng <= (maxLng + lngBufferDeg);
    } catch (_) {
      return false;
    }
  }

  /// Distance in meters from point to a line segment, using a flat-plane
  /// approximation (accurate enough for short geofence-scale distances).
  double _pointToSegmentDistanceMeters(
      double lat,
      double lng,
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      double refLat,
      ) {
    final mLat = 111320.0;
    final mLng = 111320.0 * math.cos(refLat * math.pi / 180.0);

    final px = (lng - lng1) * mLng;
    final py = (lat - lat1) * mLat;
    final dx = (lng2 - lng1) * mLng;
    final dy = (lat2 - lat1) * mLat;

    final lenSq = dx * dx + dy * dy;
    double t = lenSq == 0 ? 0 : ((px * dx + py * dy) / lenSq);
    t = t.clamp(0.0, 1.0);

    final ddx = px - (dx * t);
    final ddy = py - (dy * t);
    return math.sqrt(ddx * ddx + ddy * ddy);
  }

  bool _isPointInPolygon(double lat, double lng, Map<String, dynamic> coords) {
    try {
      final List pts = coords['coordinates'] as List;
      final List<List<double>> poly = [];
      for (final p in pts) {
        final m = p as Map;
        final plat = _toDouble(m['lat']);
        final plng = _toDouble(m['lng']);
        if (plat == null || plng == null) return false;
        poly.add([plat, plng]);
      }
      if (poly.length < 3) return false;

      bool inside = false;
      int j = poly.length - 1;
      for (int i = 0; i < poly.length; i++) {
        final yi = poly[i][0]; // lat
        final xi = poly[i][1]; // lng
        final yj = poly[j][0];
        final xj = poly[j][1];
        final intersect = ((yi > lat) != (yj > lat)) &&
            (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
        j = i;
      }

      if (inside) {
        debugPrint('🔷 [Polygon Check] userLat=$lat userLng=$lng result=true (inside)');
        return true;
      }

      // ✅ Just outside? Check distance to nearest polygon edge — if within
      // the GPS-accuracy buffer, still treat as inside.
      final refLat = poly[0][0];
      double minEdgeDist = double.infinity;
      int k = poly.length - 1;
      for (int i = 0; i < poly.length; i++) {
        final d = _pointToSegmentDistanceMeters(
          lat, lng, poly[k][0], poly[k][1], poly[i][0], poly[i][1], refLat,
        );
        if (d < minEdgeDist) minEdgeDist = d;
        k = i;
      }

      final withinBuffer = minEdgeDist <= _geofenceBufferMeters;
      debugPrint('🔷 [Polygon Check] userLat=$lat userLng=$lng nearestEdgeDist=${minEdgeDist.toStringAsFixed(1)}m buffer=${_geofenceBufferMeters}m result=$withinBuffer');
      return withinBuffer;
    } catch (e) {
      debugPrint('❌ [Polygon Check] Parse error: $e | coords=$coords');
      return false;
    }
  }

  /// ✅ Unified geofence check: handles circle (LAT_IN/LNG_IN/RADIUS),
  /// rectangle (NE/SW corners), and polygon (list of points) shapes.
  bool _isInsideGeofence({
    required double userLat,
    required double userLng,
    required Map<String, dynamic> loc,
    required double geoLat,
    required double geoLng,
    required double geoRadius,
  }) {
    final shapeType = _getShapeType(loc);
    final shapeCoords = _getShapeCoords(loc);

    // 🐛 DEBUG (temporary): log raw shape info to diagnose geofence mismatches
    debugPrint('🧭 [Geofence Check] shapeType=$shapeType userLat=$userLat userLng=$userLng raw_shape_coords=${loc['SHAPE_COORDS'] ?? loc['shape_coords']}');

    if (shapeType == 'rectangle' && shapeCoords != null) {
      return _isPointInRectangle(userLat, userLng, shapeCoords);
    } else if (shapeType == 'polygon' && shapeCoords != null) {
      return _isPointInPolygon(userLat, userLng, shapeCoords);
    }

    final distanceM = Geolocator.distanceBetween(userLat, userLng, geoLat, geoLng);
    return distanceM <= geoRadius;
  }

  DateTime? _getRawScheduleDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'];
    if (raw == null || raw.toString().isEmpty) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameWeek(DateTime a, DateTime b) {
    final weekStart = b.subtract(Duration(days: b.weekday - 1));
    final startDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endDay = startDay.add(const Duration(days: 6));
    final aDay = DateTime(a.year, a.month, a.day);
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
        default:
          return _isSameDay(d, today);
      }
    }).toList();
  }

  Future<void> _savePendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = _getPendingActionsFromPrefs(prefs);
      final actionToSave = Map<String, dynamic>.from(action);
      actionToSave['schedule_no'] = action['schedule_no']?.toString() ?? '';
      pendingActions.add(actionToSave);
      await prefs.setString(_PENDING_ACTIONS_KEY, jsonEncode(pendingActions));
      debugPrint('💾 [ScheduleHubScreen] Saved pending action: $actionToSave');
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] Error saving pending action: $e');
    }
  }

  List<Map<String, dynamic>> _getPendingActionsFromPrefs(SharedPreferences prefs) {
    final String? actionsJson = prefs.getString(_PENDING_ACTIONS_KEY);
    if (actionsJson == null || actionsJson.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(actionsJson);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _removePendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = _getPendingActionsFromPrefs(prefs);
      pendingActions.removeWhere((a) =>
      a['schedule_no'] == action['schedule_no'] &&
          a['action_type'] == action['action_type']);
      await prefs.setString(_PENDING_ACTIONS_KEY, jsonEncode(pendingActions));
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] Error removing pending action: $e');
    }
  }

  Future<void> _syncPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingActions = _getPendingActionsFromPrefs(prefs);
      if (pendingActions.isEmpty) return;

      debugPrint('🔄 [ScheduleHubScreen] Syncing ${pendingActions.length} pending actions...');

      final List<Map<String, dynamic>> actionsToRetry = [];
      for (final action in pendingActions) {
        final isComplete = action['action_type'] == 'complete';
        final success = isComplete
            ? await _updateToServer(action)
            : await _postToServer(action);

        if (success) {
          await _removePendingAction(action);
        } else {
          actionsToRetry.add(action);
        }
      }

      if (actionsToRetry.isNotEmpty) {
        debugPrint('⚠️ [ScheduleHubScreen] ${actionsToRetry.length} actions failed to sync');
      } else {
        debugPrint('✅ [ScheduleHubScreen] All pending actions synced successfully');
        await _fetchLocations();
        await _fetchLocationStatuses();
      }
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] Error syncing pending actions: $e');
    }
  }

  Future<bool> _postToServer(Map<String, dynamic> action) async {
    try {
      final url = Uri.parse(_POST_API);

      // ✅ Use SCHEDULE_NO directly
      final scheduleNo = action['schedule_no']?.toString() ?? '';
      final empId = int.tryParse(_empId) ?? 0;

      String startActionTime = '';
      if (action['start_action_time'] != null && action['start_action_time'].toString().isNotEmpty) {
        try {
          final parsed = DateTime.parse(action['start_action_time'].toString());
          startActionTime = _formatOracleDateTime(parsed);
        } catch (_) {
          startActionTime = action['start_action_time'].toString();
        }
      }

      final payload = {
        'emp_id': empId.toString(),
        'emp_name': _empName,
        'company_code': _companyCode,
        'schedule_no': scheduleNo,  // ✅ Use SCHEDULE_NO
        'location_name': action['location_name'] ?? '',
        'start_action': 'STARTED',
        'start_action_time': startActionTime,
        'complete_action': 'INCOMPLETE',
        'complete_action_time': '',
      };

      debugPrint('📤 [ScheduleHubScreen] POST Payload: $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📤 [ScheduleHubScreen] POST Status: ${response.statusCode}');
      debugPrint('📤 [ScheduleHubScreen] POST Response: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] POST error: $e');
      return false;
    }
  }

  Future<bool> _updateToServer(Map<String, dynamic> action) async {
    try {
      final url = Uri.parse(_UPDATE_API);

      // ✅ Use SCHEDULE_NO directly
      final scheduleNo = action['schedule_no']?.toString() ?? '';
      final empId = int.tryParse(_empId) ?? 0;

      String completeActionTime = '';
      if (action['complete_action_time'] != null && action['complete_action_time'].toString().isNotEmpty) {
        try {
          final parsed = DateTime.parse(action['complete_action_time'].toString());
          completeActionTime = _formatOracleDateTime(parsed);
        } catch (_) {
          completeActionTime = action['complete_action_time'].toString();
        }
      }

      final payload = {
        'emp_id': empId.toString(),
        'emp_name': _empName,
        'company_code': _companyCode,
        'schedule_no': scheduleNo,  // ✅ Use SCHEDULE_NO
        'location_name': action['location_name'] ?? '',
        'start_action': 'STARTED',
        'start_action_time': '',
        'complete_action': 'COMPLETED',
        'complete_action_time': completeActionTime,
      };

      debugPrint('📤 [ScheduleHubScreen] UPDATE Payload: $payload');

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📤 [ScheduleHubScreen] UPDATE Status: ${response.statusCode}');
      debugPrint('📤 [ScheduleHubScreen] UPDATE Response: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ [ScheduleHubScreen] UPDATE error: $e');
      return false;
    }
  }

  Future<bool> _isUserClockedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool('isClockedIn') ?? false;
    } catch (e) {
      debugPrint('❌ [CLOCK CHECK] Error: $e');
      return false;
    }
  }

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

  Future<void> _handleStartTap(Map<String, dynamic> loc) async {
    final isClockedIn = await _isUserClockedIn();
    if (!isClockedIn) {
      _showStatusSnackBar(
        title: '⛔ Not Clocked In',
        subtitle: 'Please clock in first before starting a location.',
        icon: Icons.timer_off_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    final name = _getLocationTitle(loc);
    final scheduleNo = _getScheduleNo(loc);
    final geoLat = _getGeoLat(loc);
    final geoLng = _getGeoLng(loc);
    final geoRadius = _getGeoRadius(loc);

    if (scheduleNo.isEmpty) {
      _showStatusSnackBar(
        title: 'Error',
        subtitle: 'Schedule No not found for this location.',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    if (geoLat == null || geoLng == null || geoRadius == null) {
      _showStatusSnackBar(
        title: 'Location Not Configured',
        subtitle: 'No geo-fence boundary is set up for "$name". Please contact your administrator.',
        icon: Icons.location_off_rounded,
        color: const Color(0xFF6B7280),
      );
      return;
    }

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

      final shapeType = _getShapeType(loc);
      final isInside = _isInsideGeofence(
        userLat: pos.latitude,
        userLng: pos.longitude,
        loc: loc,
        geoLat: geoLat,
        geoLng: geoLng,
        geoRadius: geoRadius,
      );

      if (isInside) {
        final now = DateTime.now().toIso8601String();
        final action = {
          'schedule_no': scheduleNo,  // ✅ Use SCHEDULE_NO
          'location_name': name,
          'start_action_time': now,
          'action_type': 'start',
          'timestamp': now,
        };

        final success = await _postToServer(action);

        if (success) {
          _showStatusSnackBar(
            title: 'Started Successfully',
            subtitle: 'You have checked in at "$name" on ${DateTime.now().toString().substring(0, 19)}.',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF1E8A5E),
          );
          _updateLocationStatus(loc, 'Started');
          await _fetchLocationStatuses();
        } else {
          await _savePendingAction(action);
          _showStatusSnackBar(
            title: 'Started (Offline)',
            subtitle: 'You have checked in at "$name". Your action will sync when online.',
            icon: Icons.cloud_off_rounded,
            color: const Color(0xFFF59E0B),
          );
          _updateLocationStatus(loc, 'Started');
        }
      } else {
        if (shapeType == 'rectangle' || shapeType == 'polygon') {
          _showStatusSnackBar(
            title: 'Outside Location Range',
            subtitle: 'You must be inside the marked boundary of "$name" to start.',
            icon: Icons.wrong_location_rounded,
            color: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          );
        } else {
          final distanceM = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, geoLat, geoLng,
          );
          _showStatusSnackBar(
            title: 'Outside Location Range',
            subtitle: 'You must be within ${geoRadius.toStringAsFixed(0)} m of "$name" to start. '
                'You are currently ${distanceM.toStringAsFixed(0)} m away.',
            icon: Icons.wrong_location_rounded,
            color: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          );
        }
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

  Future<void> _handleCompleteTap(Map<String, dynamic> loc) async {
    final isClockedIn = await _isUserClockedIn();
    if (!isClockedIn) {
      _showStatusSnackBar(
        title: '⛔ Not Clocked In',
        subtitle: 'Please clock in first before completing a location.',
        icon: Icons.timer_off_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    final name = _getLocationTitle(loc);
    final scheduleNo = _getScheduleNo(loc);

    if (scheduleNo.isEmpty) {
      _showStatusSnackBar(
        title: 'Error',
        subtitle: 'Schedule No not found for this location.',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Location?'),
        content: Text(
          'Are you sure you want to complete "$name"?\n\n'
              'This will mark your visit as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E8A5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final now = DateTime.now().toIso8601String();
    final action = {
      'schedule_no': scheduleNo,  // ✅ Use SCHEDULE_NO
      'location_name': name,
      'complete_action_time': now,
      'action_type': 'complete',
      'timestamp': now,
    };

    final success = await _updateToServer(action);

    if (success) {
      _showStatusSnackBar(
        title: 'Completed Successfully',
        subtitle: 'You have completed your visit to "$name" on ${DateTime.now().toString().substring(0, 19)}.',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF1E8A5E),
      );

      _updateLocationStatus(loc, 'Completed');
      await _fetchLocationStatuses();

      debugPrint('✅ [COMPLETE] Location completed successfully: $scheduleNo');

    } else {
      await _savePendingAction(action);
      _showStatusSnackBar(
        title: 'Completed (Offline)',
        subtitle: 'Your completion of "$name" will sync when online.',
        icon: Icons.cloud_off_rounded,
        color: const Color(0xFFF59E0B),
      );
      _updateLocationStatus(loc, 'Completed');
      if (mounted) {
        setState(() {
          _locations = List.from(_locations);
        });
      }
      debugPrint('💾 [COMPLETE] Saved offline: $scheduleNo');
    }
  }

  void _updateLocationStatus(Map<String, dynamic> loc, String newStatus) {
    final scheduleNo = _getScheduleNo(loc);
    setState(() {
      final index = _locations.indexWhere(
            (item) => _getScheduleNo(item) == scheduleNo,
      );
      if (index != -1) {
        final updatedLoc = Map<String, dynamic>.from(_locations[index]);
        updatedLoc['_local_status'] = newStatus;
        _locations[index] = updatedLoc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      appBar: Navbar(
        userName: _empName,
        userInitials: _empInitials,
        lastSync: 'Just now',
        scaffoldKey: _scaffoldKey,
      ),
      body: Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildPeriodTabs(),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildViewToggle(),
          ),
          const SizedBox(height: 16),
          if (_selectedPeriod == 'Weekly' || _selectedPeriod == 'Monthly') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCalendarPicker(),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: _routesActive
                ? ScheduleScreen(
              showAppBar: false,
              periodFilter: _selectedPeriod,
              referenceDate: _selectedFilterDate,
              onRoutesLoaded: (routes) {
                if (mounted) setState(() => _routesForCalendar = routes);
              },
            )
                : _buildLocationsList(),
          ),
        ],
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
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: isActive
                      ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isActive ? _teal : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

  DateTime? _getRawRouteDate(Map<String, dynamic> r) {
    final raw = r['SCHEDULE_DATE'] ?? r['schedule_date'] ??
        r['ROUTE_DATE'] ?? r['route_date'] ??
        r['DATE'] ?? r['date'];
    if (raw == null || raw.toString().isEmpty) return null;
    return DateTime.tryParse(raw.toString());
  }

  Widget _buildCalendarPicker() {
    final markedDates = <DateTime>{};
    for (final loc in _locations) {
      final d = _getRawScheduleDate(loc);
      if (d != null) markedDates.add(DateTime(d.year, d.month, d.day));
    }
    for (final r in _routesForCalendar) {
      final d = _getRawRouteDate(r);
      if (d != null) markedDates.add(DateTime(d.year, d.month, d.day));
    }

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
      child: _MiniCalendar(
        selectedDate: _selectedFilterDate,
        markedDates: markedDates,
        onDateSelected: (date) => setState(() => _selectedFilterDate = date),
      ),
    );
  }

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
      onRefresh: () async {
        await _fetchLocations();
        await _fetchLocationStatuses();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const _PageIndicator(),
            );
          }

          final loc = filtered[index];
          final scheduleNo = _getScheduleNo(loc);

          // ✅ Get status from cache using SCHEDULE_NO
          String status = 'Pending';
          if (_statusCache.containsKey(scheduleNo)) {
            final statusData = _statusCache[scheduleNo]!;
            final completeAction = statusData['complete_action'] ?? '';
            final startAction = statusData['start_action'] ?? '';

            if (completeAction == 'COMPLETED' || completeAction == 'Y') {
              status = 'Completed';
            } else if (startAction == 'STARTED' || startAction == 'Y') {
              status = 'Started';
            }
          } else {
            // ✅ Fallback to local status
            status = loc['_local_status'] ?? 'Pending';
          }

          final isStarted = status.toLowerCase() == 'started';
          final isCompleted = status.toLowerCase() == 'completed';
          final isApproved = status.toLowerCase() == 'approved';

          final showStart = !isStarted && !isCompleted && !isApproved;
          final showComplete = isStarted && !isCompleted && !isApproved;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LocationCard(
              date: _getScheduleDate(loc),
              status: status,
              title: _getLocationTitle(loc),
              time: _getLocationTimeRange(loc),
              scheduleId: scheduleNo,  // ✅ Display SCHEDULE_NO
              showStart: showStart,
              showComplete: showComplete,
              onStartTap: showStart ? () => _handleStartTap(loc) : null,
              onCompleteTap: showComplete ? () => _handleCompleteTap(loc) : null,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle Button
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
            colors: [AppColors.primary, AppColors.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: active ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: active ? null : Border.all(color: AppColors.divider),
          boxShadow: active
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
              color: active ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Card with Schedule Number, Start and Complete buttons
// ─────────────────────────────────────────────────────────────────────────────
class _LocationCard extends StatelessWidget {
  final String date;
  final String status;
  final String title;
  final String time;
  final String scheduleId;
  final bool showStart;
  final bool showComplete;
  final VoidCallback? onStartTap;
  final VoidCallback? onCompleteTap;

  const _LocationCard({
    required this.date,
    required this.status,
    required this.title,
    required this.time,
    required this.scheduleId,
    required this.showStart,
    required this.showComplete,
    this.onStartTap,
    this.onCompleteTap,
  });

  static const _teal = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    final isApproved = statusLower == 'approved';
    final isStarted = statusLower == 'started';
    final isCompleted = statusLower == 'completed';

    Color statusBg;
    Color statusFg;
    String statusLabel;

    switch (statusLower) {
      case 'approved':
        statusBg = const Color(0xFFD1FAE5);
        statusFg = const Color(0xFF065F46);
        statusLabel = 'Approved';
        break;
      case 'started':
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFF92400E);
        statusLabel = 'Started';
        break;
      case 'completed':
        statusBg = const Color(0xFFD1FAE5);
        statusFg = const Color(0xFF065F46);
        statusLabel = 'Completed';
        break;
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFF92400E);
        statusLabel = 'Pending';
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFFB91C1C);
        statusLabel = 'Rejected';
        break;
      case 'cancelled':
        statusBg = const Color(0xFFFEE2E2);
        statusFg = const Color(0xFFB91C1C);
        statusLabel = 'Cancelled';
        break;
      default:
        statusBg = const Color(0xFFF3F4F6);
        statusFg = const Color(0xFF6B7280);
        statusLabel = status;
    }

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
                  color: statusBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Schedule #${scheduleId.isEmpty ? 'N/A' : scheduleId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),

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
              if (showComplete) const SizedBox(width: 10),
              if (showComplete)
                _PillButton(
                  icon: Icons.check_circle_rounded,
                  label: 'Complete',
                  filled: false,
                  onTap: onCompleteTap,
                  iconColor: const Color(0xFF1E8A5E),
                  textColor: const Color(0xFF1E8A5E),
                  bgColor: const Color(0xFFD1FAE5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Button
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Color? bgColor;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isStart = label == 'Start';
    final isComplete = label == 'Complete';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled
              ? const LinearGradient(
            colors: [AppColors.primary, AppColors.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: filled
              ? null
              : (bgColor ?? (isStart
              ? AppColors.primary.withOpacity(0.10)
              : (isComplete
              ? const Color(0xFFD1FAE5)
              : AppColors.primary.withOpacity(0.10)))),
          borderRadius: BorderRadius.circular(11),
          boxShadow: filled
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: filled
                  ? Colors.white
                  : (iconColor ?? (isStart
                  ? AppColors.primary
                  : (isComplete
                  ? const Color(0xFF1E8A5E)
                  : AppColors.primary))),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? Colors.white
                    : (textColor ?? (isStart
                    ? AppColors.primary
                    : (isComplete
                    ? const Color(0xFF1E8A5E)
                    : AppColors.primary))),
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
// Page Indicator
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

// ─────────────────────────────────────────────────────────────────────────────
// Mini Calendar
// ─────────────────────────────────────────────────────────────────────────────
class _MiniCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDateSelected;

  const _MiniCalendar({
    required this.selectedDate,
    required this.markedDates,
    required this.onDateSelected,
  });

  @override
  State<_MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<_MiniCalendar> {
  static const _teal = Color(0xFF0C9E8E);
  static const _tealDark = Color(0xFF0C6B64);

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth =
        DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  @override
  void didUpdateWidget(covariant _MiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _visibleMonth =
          DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    }
  }

  void _goToPrevMonth() => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
  });

  void _goToNextMonth() => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasEvent(DateTime day) {
    for (final d in widget.markedDates) {
      if (_isSameDay(d, day)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goToPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                color: _tealDark,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                color: _tealDark,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: _weekdayLabels
                .map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 2),
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNumber = cellIndex - leadingBlanks + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 36));
                }

                final cellDate = DateTime(
                    _visibleMonth.year, _visibleMonth.month, dayNumber);
                final isSelected =
                _isSameDay(cellDate, widget.selectedDate);
                final isToday = _isSameDay(cellDate, today);
                final hasEvent = _hasEvent(cellDate);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onDateSelected(cellDate),
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 1),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                          colors: [_teal, _tealDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        shape: BoxShape.circle,
                        border: (!isSelected && isToday)
                            ? Border.all(color: _tealDark, width: 1.2)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                  ? _tealDark
                                  : const Color(0xFF374151)),
                            ),
                          ),
                          if (hasEvent)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                  isSelected ? Colors.white : _teal,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}
