// ═══════════════════════════════════════════════════════════════════════════
// navigation_screen.dart
//
// Google Maps-style real-time navigation screen.
// Called from ScheduleScreen when user taps "Start Route".
//
// Features:
//   • Full-screen OSM map with road polyline (OSRM)
//   • Waypoint stops shown as numbered pins on map
//   • Live location tracking via Geolocator
//   • Bottom sheet: step-by-step stops list (collapsible)
//   • Top instruction banner: next stop name
//   • Recenter, zoom controls
//   • ETA / distance chips that update as route progresses
//
// ── pubspec.yaml dependencies ──────────────────────────────────────────────
//   flutter_map:        ^7.0.2
//   latlong2:           ^0.9.0
//   http:               ^1.2.0
//   geolocator:         ^12.0.0
//   shared_preferences: ^2.2.0
//
// ── AndroidManifest.xml permissions ───────────────────────────────────────
//   <uses-permission android:name="android.permission.INTERNET"/>
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'WidgetDesignes/route_status_helper.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Waypoint model
// ─────────────────────────────────────────────────────────────────────────────
class _Waypoint {
  final int    index;
  final LatLng position;
  final String name;
  final String address;
  bool         visited;

  _Waypoint({
    required this.index,
    required this.position,
    required this.name,
    required this.address,
    this.visited = false,
  });

  factory _Waypoint.fromJson(Map<String, dynamic> j, int idx) {
    final lat = double.tryParse(
        (j['LAT'] ?? j['lat'] ?? j['LATITUDE'] ?? j['latitude'] ?? '').toString()) ??
        0.0;
    final lng = double.tryParse(
        (j['LNG'] ?? j['lng'] ?? j['LON'] ?? j['lon'] ??
            j['LONGITUDE'] ?? j['longitude'] ?? '').toString()) ??
        0.0;
    return _Waypoint(
      index:    idx,
      position: LatLng(lat, lng),
      name:     (j['NAME']    ?? j['name']    ?? j['WAYPOINT_NAME'] ??
          j['waypoint_name'] ?? 'Stop ${idx + 1}').toString(),
      address:  (j['ADDRESS'] ?? j['address'] ?? j['WAYPOINT_ADDRESS'] ??
          j['waypoint_address'] ?? '').toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Turn step model (from OSRM steps)
// ─────────────────────────────────────────────────────────────────────────────
class _TurnStep {
  final LatLng   location;   // intersection point
  final String   type;       // "turn", "depart", "arrive", "continue", etc.
  final String   modifier;   // "left", "right", "straight", "slight left", etc.
  final String   streetName; // road name to show
  final double   distanceM;  // distance of this step in metres

  const _TurnStep({
    required this.location,
    required this.type,
    required this.modifier,
    required this.streetName,
    required this.distanceM,
  });

  /// Flutter icon that matches the maneuver
  IconData get icon {
    final t = type.toLowerCase();
    final m = modifier.toLowerCase();

    if (t == 'depart')  return Icons.navigation_rounded;
    if (t == 'arrive')  return Icons.flag_rounded;

    if (m.contains('uturn'))        return Icons.u_turn_left_rounded;
    if (m == 'sharp left')          return Icons.turn_sharp_left_rounded;
    if (m == 'left')                return Icons.turn_left_rounded;
    if (m == 'slight left')         return Icons.turn_slight_left_rounded;
    if (m == 'sharp right')         return Icons.turn_sharp_right_rounded;
    if (m == 'right')               return Icons.turn_right_rounded;
    if (m == 'slight right')        return Icons.turn_slight_right_rounded;
    if (t == 'roundabout' ||
        t == 'rotary')              return Icons.roundabout_left_rounded;
    return Icons.straight_rounded;  // straight / continue
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NavigationScreen
// ─────────────────────────────────────────────────────────────────────────────
class NavigationScreen extends StatefulWidget {
  final Map<String, dynamic> route;
  const NavigationScreen({super.key, required this.route});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {

  // ── Tokens ────────────────────────────────────────────────────────────────
  static const _teal      = Color(0xFF0C9E8E);
  static const _tealDark  = Color(0xFF0C6B64);
  static const _navBlue   = Color(0xFF1A73E8);
  static const _bgDark    = Color(0xFF1A1A2E);

  // ── Controllers ───────────────────────────────────────────────────────────
  final MapController        _mapCtrl      = MapController();
  late AnimationController   _pulseCtrl;
  late Animation<double>     _pulseAnim;

  // ── Route data ────────────────────────────────────────────────────────────
  late LatLng  _origin;
  late LatLng  _destination;
  late Color   _routeColor;
  late String  _routeName;
  late String  _routeId;
  late String  _travelMode;
  late String  _totalDistance;
  late String  _totalDuration;
  late String  _originAddress;
  late String  _destAddress;

  // ── Waypoints ─────────────────────────────────────────────────────────────
  List<_Waypoint> _waypoints = [];
  int _currentStopIndex = 0;           // 0 = heading to first waypoint/dest

  // ── Polyline / routing ────────────────────────────────────────────────────
  List<LatLng>    _polylinePoints  = [];
  bool            _isLoadingRoute  = true;
  String?         _warningMsg;

  // ── Turn-by-turn steps ────────────────────────────────────────────────────
  List<_TurnStep> _turnSteps       = [];
  int             _currentStepIdx  = 0;   // which step we are on
  double          _distToNextStep  = 0;   // metres to next maneuver

  // ── On-route / off-route status ───────────────────────────────────────────
  RouteStatus? _routeStatus;

  // ── On-route / off-route time tracking (for API post) ─────────────────────
  String  _empId       = '';
  String  _empName     = '';
  String  _companyCode = '';
  Duration _onRouteDuration  = Duration.zero;
  Duration _offRouteDuration = Duration.zero;
  bool?     _lastOnRouteFlag;    // last known on-route state (for accumulation)

  // ── Route completion tracking ─────────────────────────────────────────────
  bool _destinationReached = false; // true when user comes within 30 m of destination

  // ── User location ─────────────────────────────────────────────────────────
  LatLng? _userLocation;
  StreamSubscription<Position>? _locationSub;
  Timer?                         _routeStatusTimer; // accumulates on/off-route duration every second
  bool    _locationGranted   = false;
  bool    _followUser        = true;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool    _sheetExpanded     = true;
  bool    _navigationStarted = false;
  double  _currentZoom       = 15.0;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _parseRoute();
    _loadEmployeeInfo();
    _requestLocationAndListen();
    _fetchOsrmRoute();
  }

  // ── Load employee info (same keys as ScheduleScreen / LeaveViewModel) ────
  Future<void> _loadEmployeeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _empId = prefs.getString('userId')      ??
        prefs.getString('user_id')     ??
        prefs.getString('emp_id')      ??
        prefs.getString('empId')       ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId')  ?? '';

    _empName = prefs.getString('empName')      ??
        prefs.getString('emp_name')     ??
        prefs.getString('userName')     ??
        prefs.getString('user_name')    ??
        prefs.getString('name')         ?? '';

    _companyCode = prefs.getString('companyCode')   ??
        prefs.getString('company_code')  ??
        prefs.getString('COMPANY_CODE')  ?? '';

    debugPrint('🧭 [Nav] empId      : "$_empId"');
    debugPrint('🧭 [Nav] empName    : "$_empName"');
    debugPrint('🧭 [Nav] companyCode: "$_companyCode"');
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _routeStatusTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Parse route fields ───────────────────────────────────────────────────
  void _parseRoute() {
    final r = widget.route;
    _origin = LatLng(
      _asDouble(r['ORIGIN_LAT'] ?? r['origin_lat']),
      _asDouble(r['ORIGIN_LNG'] ?? r['origin_lng']),
    );
    _destination = LatLng(
      _asDouble(r['DEST_LAT'] ?? r['dest_lat']),
      _asDouble(r['DEST_LNG'] ?? r['dest_lng']),
    );
    _routeColor     = _hexColor(r['ROUTE_COLOR']?.toString() ?? '#1A73E8');
    _routeName      = (r['ROUTE_NAME']     ?? r['route_name']     ?? 'Navigation').toString();
    _routeId        = (r['ROUTE_ID']       ?? r['route_id']       ?? '').toString();
    _travelMode     = (r['TRAVEL_MODE']    ?? r['travel_mode']    ?? 'DRIVING').toString();
    _totalDistance  = (r['TOTAL_DISTANCE'] ?? r['total_distance'] ?? '').toString().trim();
    _totalDuration  = (r['TOTAL_DURATION'] ?? r['total_duration'] ?? '').toString().trim();
    _originAddress  = (r['ORIGIN_ADDRESS'] ?? r['origin_address'] ?? '').toString().trim();
    _destAddress    = (r['DEST_ADDRESS']   ?? r['dest_address']   ?? '').toString().trim();

    // ── Parse WAYPOINTS ──────────────────────────────────────────────────
    final wpRaw = r['WAYPOINTS'] ?? r['waypoints'] ?? '';
    if (wpRaw != null && wpRaw.toString().isNotEmpty) {
      try {
        final parsed = jsonDecode(wpRaw.toString());
        if (parsed is List) {
          _waypoints = parsed
              .asMap()
              .entries
              .map((e) => _Waypoint.fromJson(
            Map<String, dynamic>.from(e.value as Map),
            e.key,
          ))
              .toList();
        }
      } catch (e) {
        debugPrint('⚠️ [Nav] Waypoints parse error: $e');
      }
    }
  }

  double _asDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _navBlue;
    }
  }

  // ── Location permission + stream ─────────────────────────────────────────
  Future<void> _requestLocationAndListen() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        debugPrint('⚠️ [Nav] Location permission denied');
        return;
      }
      setState(() => _locationGranted = true);

      // Get initial position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _onPositionUpdate(pos);

      // Stream updates
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy:          LocationAccuracy.high,
          distanceFilter:    5,
        ),
      ).listen(_onPositionUpdate);
    } catch (e) {
      debugPrint('❌ [Nav] Location error: $e');
    }
  }

  void _onPositionUpdate(Position pos) {
    if (!mounted) return;
    final newLoc = LatLng(pos.latitude, pos.longitude);
    setState(() => _userLocation = newLoc);

    if (_followUser && _navigationStarted) {
      _mapCtrl.move(newLoc, _currentZoom);
    }

    // ── Auto-advance turn steps ────────────────────────────────────────────
    if (_navigationStarted && _turnSteps.isNotEmpty) {
      _advanceTurnStep(newLoc);
    }

    // ── On-route / off-route check (20 m threshold) ────────────────────────
    if (_polylinePoints.length >= 2) {
      final status = RouteStatusHelper.getStatus(
        userLocation: newLoc,
        polyline:     _polylinePoints,
        thresholdMeters: 20,
      );
      setState(() => _routeStatus = status);

      // Keep the latest on-route flag in sync; actual duration accumulation
      // happens every second via _routeStatusTimer (so it works even if
      // GPS updates are infrequent / device is stationary).
      _lastOnRouteFlag = status.isOnRoute;
    }

    // Auto-mark waypoints as visited when within 30 m
    if (_navigationStarted) {
      for (final wp in _waypoints) {
        if (!wp.visited) {
          final dist = const Distance().as(
            LengthUnit.Meter, newLoc, wp.position,
          );
          if (dist < 30) {
            setState(() => wp.visited = true);
          }
        }
      }

      // Auto-mark destination as reached when within 30 m
      if (!_destinationReached) {
        final destDist = const Distance().as(
          LengthUnit.Meter, newLoc, _destination,
        );
        if (destDist < 30) {
          setState(() => _destinationReached = true);
        }
      }
    }
  }

  /// Advance to next turn step when user is within 20 m of the step location
  void _advanceTurnStep(LatLng userLoc) {
    if (_currentStepIdx >= _turnSteps.length) return;
    final step = _turnSteps[_currentStepIdx];
    final dist = const Distance().as(
      LengthUnit.Meter, userLoc, step.location,
    );
    setState(() => _distToNextStep = dist);

    // Auto-advance when within 20 m of the maneuver point
    if (dist < 20 && _currentStepIdx < _turnSteps.length - 1) {
      setState(() => _currentStepIdx++);
    }
  }

  /// Called every 1 second while navigation is active.
  /// Adds 1 second to on-route or off-route duration based on the
  /// most recently known route status (_lastOnRouteFlag).
  void _tickRouteStatusDuration() {
    if (!mounted || !_navigationStarted) return;
    if (_lastOnRouteFlag == null) return;

    if (_lastOnRouteFlag == true) {
      _onRouteDuration  += const Duration(seconds: 1);
    } else {
      _offRouteDuration += const Duration(seconds: 1);
    }
  }

  // ── OSRM routing (origin → waypoints → destination) ─────────────────────
  Future<void> _fetchOsrmRoute() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRoute = true;
      _warningMsg     = null;
      _turnSteps      = [];
      _currentStepIdx = 0;
      _distToNextStep = 0;
    });

    final profile = _osrmProfile(_travelMode);

    // Build coordinate string: origin; waypoints; destination
    final coords = StringBuffer();
    coords.write('${_origin.longitude},${_origin.latitude}');
    for (final wp in _waypoints) {
      coords.write(';${wp.position.longitude},${wp.position.latitude}');
    }
    coords.write(';${_destination.longitude},${_destination.latitude}');

    // steps=true → get turn-by-turn maneuvers
    final uri = Uri.parse(
      'http://router.project-osrm.org/route/v1/$profile/$coords'
          '?geometries=geojson&overview=full&steps=true',
    );

    debugPrint('🗺️ [Nav] OSRM → $uri');

    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final body   = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route0 = routes[0] as Map<String, dynamic>;

          // ── Polyline ────────────────────────────────────────────────
          final coordsList =
          route0['geometry']['coordinates'] as List<dynamic>;
          final pts = coordsList
              .map((c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ))
              .toList();

          // ── Parse turn steps from all legs ──────────────────────────
          final steps = <_TurnStep>[];
          final legs  = route0['legs'] as List? ?? [];
          for (final leg in legs) {
            final legSteps = (leg as Map<String, dynamic>)['steps'] as List? ?? [];
            for (final s in legSteps) {
              final sm = s as Map<String, dynamic>;
              final maneuver  = sm['maneuver']  as Map<String, dynamic>? ?? {};
              final loc       = maneuver['location'] as List?;
              final type      = (maneuver['type']     ?? '').toString();
              final modifier  = (maneuver['modifier'] ?? 'straight').toString();
              final name      = (sm['name']            ?? '').toString();
              final distM     = (sm['distance']        as num?)?.toDouble() ?? 0;

              if (loc != null && loc.length >= 2) {
                steps.add(_TurnStep(
                  location:   LatLng(
                    (loc[1] as num).toDouble(),
                    (loc[0] as num).toDouble(),
                  ),
                  type:       type,
                  modifier:   modifier,
                  streetName: name,
                  distanceM:  distM,
                ));
              }
            }
          }

          _applyPolylineAndSteps(pts, steps);
          return;
        }
      }
      _useStraightLine('Road routing unavailable — showing straight line.');
    } catch (e) {
      debugPrint('❌ [Nav] OSRM error: $e');
      _useStraightLine('Routing service unreachable — showing straight line.');
    }
  }

  String _osrmProfile(String mode) {
    final m = mode.toLowerCase();
    if (m == 'walking' || m == 'walk')   return 'foot';
    if (m == 'cycling' || m == 'cycle')  return 'cycling';
    return 'driving';
  }

  // ── Format Duration as "HH:MM:SS" ─────────────────────────────────────────
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Post on-route / off-route summary to API (called when nav stops) ────
  Future<void> _postRouteStatusSummary() async {
    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/gpsnavigation/post/',
      );

      // Stops visited count
      final stopsVisited = _waypoints.where((w) => w.visited).length;
      final totalStops   = _waypoints.length;

      // Route considered complete only if destination reached AND
      // every intermediate stop was visited
      final routeCompleted =
          _destinationReached && stopsVisited == totalStops;

      // Navigation date — current date as YYYY-MM-DD
      final now = DateTime.now();
      final navigationDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final payload = {
        'emp_id':          _empId,
        'emp_name':        _empName,
        'company_code':    _companyCode,
        'route_id':        _routeId,
        'on_route_time':   _formatDuration(_onRouteDuration),
        'off_route_time':  _formatDuration(_offRouteDuration),
        'on_route_seconds':  _onRouteDuration.inSeconds,
        'off_route_seconds': _offRouteDuration.inSeconds,
        'total_distance':  _totalDistance,
        'total_duration':  _totalDuration,
        'travel_mode':     _travelMode,
        'stops_reached':     stopsVisited,
        'total_stops':       totalStops,
        'destination_reached': _destinationReached ? 'Y' : 'N',
        'route_completed':     routeCompleted ? 'Y' : 'N',
        'navigation_date':     navigationDate,
      };

      debugPrint('📤 [Nav] POST → $uri');
      debugPrint('📤 [Nav] Body : ${jsonEncode(payload)}');

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📤 [Nav] Status: ${res.statusCode}');
      debugPrint('📤 [Nav] Body  : ${res.body}');
    } catch (e) {
      debugPrint('❌ [Nav] Route status POST error: $e');
    }
  }

  void _applyPolylineAndSteps(List<LatLng> pts, List<_TurnStep> steps) {
    if (!mounted) return;
    setState(() {
      _polylinePoints  = pts;
      _turnSteps       = steps;
      _currentStepIdx  = 0;
      _distToNextStep  = steps.isNotEmpty ? steps[0].distanceM : 0;
      _isLoadingRoute  = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
  }

  void _useStraightLine(String warn) {
    if (!mounted) return;
    final all = [_origin, ..._waypoints.map((w) => w.position), _destination];
    setState(() {
      _polylinePoints = all;
      _isLoadingRoute = false;
      _warningMsg     = warn;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
  }

  void _fitAll() {
    final all = [
      _origin,
      ..._waypoints.map((w) => w.position),
      _destination,
      if (_userLocation != null) _userLocation!,
    ];
    if (all.isEmpty) return;
    try {
      _mapCtrl.fitCamera(
        CameraFit.coordinates(
          coordinates: all,
          padding: const EdgeInsets.fromLTRB(48, 130, 48, 360),
        ),
      );
    } catch (_) {}
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      setState(() => _followUser = true);
      _mapCtrl.move(_userLocation!, _currentZoom);
    }
  }

  // ── Current turn step helpers ─────────────────────────────────────────────
  _TurnStep? get _currentStep =>
      _turnSteps.isNotEmpty && _currentStepIdx < _turnSteps.length
          ? _turnSteps[_currentStepIdx]
          : null;

  /// Icon to show in green banner
  IconData get _bannerIcon {
    if (!_navigationStarted) return _travelIcon;
    return _currentStep?.icon ?? Icons.straight_rounded;
  }

  /// Top line in banner (small subtitle)
  String get _bannerSubtitle {
    if (!_navigationStarted) return 'Tap Start to begin navigation';
    final dist = _distToNextStep;
    if (dist <= 0) return '';
    if (dist < 1000) return '${dist.round()} m';
    return '${(dist / 1000).toStringAsFixed(1)} km';
  }

  /// Main street name shown in banner
  String get _bannerStreetName {
    if (!_navigationStarted) return _routeName;
    final step = _currentStep;
    if (step == null) return _destAddress.isNotEmpty ? _destAddress : 'Destination';
    if (step.streetName.isNotEmpty) return step.streetName;
    // fallback to next waypoint name
    final remaining = _waypoints.where((w) => !w.visited).toList();
    if (remaining.isNotEmpty) return remaining.first.name;
    return _destAddress.isNotEmpty ? _destAddress : 'Destination';
  }

  // ── Next stop label (for backwards compat) ────────────────────────────────
  String get _nextStopLabel {
    final remaining = _waypoints.where((w) => !w.visited).toList();
    if (remaining.isNotEmpty) return remaining.first.name;
    return _destAddress.isNotEmpty ? _destAddress : 'Destination';
  }

  IconData get _travelIcon {
    final m = _travelMode.toLowerCase();
    if (m == 'walking' || m == 'walk')  return Icons.directions_walk_rounded;
    if (m == 'cycling' || m == 'cycle') return Icons.directions_bike_rounded;
    return Icons.directions_car_rounded;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1 — Map
          _buildMap(),

          // 2 — Top nav bar (instruction)
          _buildTopBar(context),

          // 2b — On-route / off-route status badge
          if (_navigationStarted && _routeStatus != null)
            _buildRouteStatusBadge(context),

          // 3 — Loading overlay
          if (_isLoadingRoute) _buildLoadingOverlay(),

          // 4 — Warning banner
          if (_warningMsg != null && !_isLoadingRoute)
            _buildWarningBanner(context),

          // 5 — Right-side controls
          _buildSideControls(context),

          // 6 — Bottom sheet
          _buildBottomSheet(context),
        ],
      ),
    );
  }

  // ── 1. Map ────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: _origin,
        initialZoom:   _currentZoom,
        onMapEvent: (e) {
          if (e is MapEventMoveStart && e.source != MapEventSource.mapController) {
            setState(() => _followUser = false);
          }
          if (e is MapEventMove) {
            _currentZoom = e.camera.zoom;
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.metaxperts.gps_workforce',
          maxZoom: 19,
        ),

        // Polyline — shadow + main
        if (_polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points:      _polylinePoints,
                color:       Colors.black.withOpacity(0.22),
                strokeWidth: 11.0,
              ),
              Polyline(
                points:      _polylinePoints,
                color:       _navBlue,
                strokeWidth: 7.0,
              ),
              Polyline(
                points:      _polylinePoints,
                color:       Colors.white.withOpacity(0.30),
                strokeWidth: 2.5,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            // Origin pin
            Marker(
              point:     _origin,
              width:     44,
              height:    44,
              alignment: Alignment.center,
              child:     _OriginMarker(),
            ),

            // Waypoint stops
            ..._waypoints.map((wp) => Marker(
              point:     wp.position,
              width:     44,
              height:    56,
              alignment: Alignment.bottomCenter,
              child:     _WaypointMarker(
                index:   wp.index + 1,
                visited: wp.visited,
              ),
            )),

            // Destination pin
            Marker(
              point:     _destination,
              width:     44,
              height:    56,
              alignment: Alignment.bottomCenter,
              child:     _DestinationMarker(),
            ),

            // User location (pulsing)
            if (_userLocation != null)
              Marker(
                point:     _userLocation!,
                width:     56,
                height:    56,
                alignment: Alignment.center,
                child:     _UserLocationMarker(pulse: _pulseAnim),
              ),
          ],
        ),
      ],
    );
  }

  // ── 2. Top instruction bar — Google Maps style ───────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Green instruction banner
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E8A5E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Real turn-direction icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _bannerIcon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Street name + distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Distance to next maneuver (subtitle)
                            if (_bannerSubtitle.isNotEmpty)
                              Text(
                                _bannerSubtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            // Street / road name (main)
                            Text(
                              _bannerStreetName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Mic / voice button
              _GmapsCircleBtn(
                icon: Icons.mic_rounded,
                iconColor: const Color(0xFF1A73E8),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2b. On-route / off-route badge ────────────────────────────────────────
  Widget _buildRouteStatusBadge(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 78, left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RouteStatusBadge(status: _routeStatus!),
          ),
        ),
      ),
    );
  }

  // ── 3. Loading overlay ────────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.30),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _navBlue),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Building your route…',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Warning banner ─────────────────────────────────────────────────────
  Widget _buildWarningBanner(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 80, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _warningMsg!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _warningMsg = null),
              child: Icon(Icons.close_rounded,
                  size: 16, color: Colors.orange.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Side controls — Google Maps style ─────────────────────────────────
  Widget _buildSideControls(BuildContext context) {
    final bottomOffset = _sheetExpanded ? 310.0 : 120.0;
    return Positioned(
      right: 14,
      bottom: bottomOffset,
      child: Column(
        children: [
          // Search button
          _GmapsCircleBtn(
            icon: Icons.search_rounded,
            iconColor: const Color(0xFF374151),
            onTap: () {},
          ),
          const SizedBox(height: 10),
          // Sound / volume button
          _GmapsCircleBtn(
            icon: Icons.volume_up_rounded,
            iconColor: const Color(0xFF374151),
            onTap: () {},
          ),
          const SizedBox(height: 10),
          // Recenter — only when not following user
          if (!_followUser && _locationGranted) ...[
            _GmapsCircleBtn(
              icon:  Icons.my_location_rounded,
              iconColor: _navBlue,
              onTap: _centerOnUser,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // ── 6. Bottom sheet — Google Maps style ──────────────────────────────────
  Widget _buildBottomSheet(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 24,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            GestureDetector(
              onTap: () => setState(() => _sheetExpanded = !_sheetExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Google Maps style ETA row — always visible
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // X (close) button
                  GestureDetector(
                    onTap: () {
                      if (_navigationStarted) {
                        _postRouteStatusSummary();
                      }
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.grey.shade700, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ETA info (center)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(
                              () => _sheetExpanded = !_sheetExpanded),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Duration — bold orange like Google Maps
                          Text(
                            _totalDuration.isNotEmpty
                                ? _totalDuration
                                : '—',
                            style: const TextStyle(
                              color: Color(0xFFE37400),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Distance · ETA time
                          Text(
                            [
                              if (_totalDistance.isNotEmpty) _totalDistance,
                              '· ${_etaString()}',
                            ].join(' '),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  // Route options button
                  GestureDetector(
                    onTap: _isLoadingRoute ? null : _fetchOsrmRoute,
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200, width: 1),
                      ),
                      child: Icon(Icons.alt_route_rounded,
                          color: Colors.grey.shade700, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Collapsible expanded content
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _sheetExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild:  _buildSheetContent(bottomPad),
              secondChild: SizedBox(
                width: double.infinity,
                height: bottomPad + 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ETA arrival time string
  String _etaString() {
    final now = DateTime.now();
    // Try to parse duration from _totalDuration (e.g. "25 mins", "1 hr 10 mins")
    int minutes = 0;
    final durStr = _totalDuration.toLowerCase();
    final hrMatch  = RegExp(r'(\d+)\s*h').firstMatch(durStr);
    final minMatch = RegExp(r'(\d+)\s*m').firstMatch(durStr);
    if (hrMatch  != null) minutes += int.parse(hrMatch.group(1)!)  * 60;
    if (minMatch != null) minutes += int.parse(minMatch.group(1)!);
    final eta = now.add(Duration(minutes: minutes));
    final h   = eta.hour   % 12 == 0 ? 12 : eta.hour   % 12;
    final m   = eta.minute.toString().padLeft(2, '0');
    final ampm = eta.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  Widget _buildSheetContent(double bottomPad) {
    final visitedCount = _waypoints.where((w) => w.visited).length;
    final totalStops   = _waypoints.length;

    return Padding(
      padding: EdgeInsets.only(
          left: 18, right: 18, bottom: bottomPad + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Route header ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 4, height: 22,
                decoration: BoxDecoration(
                  color: _navBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _routeName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Stop progress badge
              if (totalStops > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _navBlue.withOpacity(0.3), width: 1),
                  ),
                  child: Text(
                    '$visitedCount / $totalStops stops',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _navBlue,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Stats row ────────────────────────────────────────────────
          Row(
            children: [
              if (_totalDistance.isNotEmpty)
                _StatPill(
                  icon:  Icons.straighten_rounded,
                  label: _totalDistance,
                  color: _teal,
                ),
              if (_totalDistance.isNotEmpty && _totalDuration.isNotEmpty)
                const SizedBox(width: 8),
              if (_totalDuration.isNotEmpty)
                _StatPill(
                  icon:  Icons.schedule_rounded,
                  label: _totalDuration,
                  color: const Color(0xFF7C3AED),
                ),
              if (_totalDuration.isNotEmpty)
                const SizedBox(width: 8),
              _StatPill(
                icon:  _travelIcon,
                label: _travelMode[0].toUpperCase() +
                    _travelMode.substring(1).toLowerCase(),
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Stops list ───────────────────────────────────────────────
          if (_waypoints.isNotEmpty || true) ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Origin
                    _StopRow(
                      label:   'Start',
                      address: _originAddress.isNotEmpty
                          ? _originAddress
                          : '${_origin.latitude.toStringAsFixed(4)}, '
                          '${_origin.longitude.toStringAsFixed(4)}',
                      icon:    Icons.my_location_rounded,
                      iconBg:  const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      isFirst: true,
                      isDone:  _navigationStarted,
                    ),

                    // Intermediate waypoints
                    ..._waypoints.map((wp) => _StopRow(
                      label:     'Stop ${wp.index + 1}',
                      address:   wp.name.isNotEmpty ? wp.name : wp.address,
                      subLabel:  wp.address.isNotEmpty && wp.name.isNotEmpty
                          ? wp.address
                          : null,
                      icon:      Icons.location_on_rounded,
                      iconBg:    wp.visited
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFEFF6FF),
                      iconColor: wp.visited
                          ? const Color(0xFF059669)
                          : _navBlue,
                      isDone:    wp.visited,
                      stopNumber: wp.index + 1,
                    )),

                    // Destination
                    _StopRow(
                      label:   'Destination',
                      address: _destAddress.isNotEmpty
                          ? _destAddress
                          : '${_destination.latitude.toStringAsFixed(4)}, '
                          '${_destination.longitude.toStringAsFixed(4)}',
                      icon:    Icons.flag_rounded,
                      iconBg:  const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFDC2626),
                      isLast:  true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Action button ────────────────────────────────────────────
          _ActionButton(
            label: _navigationStarted ? 'Stop Navigation' : 'Start Navigation',
            icon:  _navigationStarted
                ? Icons.stop_circle_outlined
                : Icons.navigation_rounded,
            color: _navigationStarted
                ? const Color(0xFFDC2626)
                : _navBlue,
            onTap: () {
              final wasStarted = _navigationStarted;
              setState(() {
                _navigationStarted = !_navigationStarted;
                if (_navigationStarted) {
                  _followUser  = true;
                  _currentZoom = 16.0;
                  if (_userLocation != null) {
                    _mapCtrl.move(_userLocation!, 16.0);
                  } else {
                    _mapCtrl.move(_origin, 16.0);
                  }
                  // Reset on/off-route tracking for a fresh session
                  _onRouteDuration  = Duration.zero;
                  _offRouteDuration = Duration.zero;
                  _lastOnRouteFlag  = _routeStatus?.isOnRoute;
                  _destinationReached = false;
                  for (final wp in _waypoints) {
                    wp.visited = false;
                  }

                  // Start ticking on/off-route durations every second
                  _routeStatusTimer?.cancel();
                  _routeStatusTimer = Timer.periodic(
                    const Duration(seconds: 1),
                        (_) => _tickRouteStatusDuration(),
                  );
                } else {
                  _fitAll();
                  _routeStatusTimer?.cancel();
                  _routeStatusTimer = null;
                }
              });

              // Navigation just stopped → post on-route/off-route summary
              if (wasStarted && !_navigationStarted) {
                _postRouteStatusSummary();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Map Marker Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _OriginMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.my_location_rounded,
          color: Colors.white, size: 20),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.50),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.flag_rounded,
              color: Colors.white, size: 20),
        ),
        Container(
          width: 3, height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _WaypointMarker extends StatelessWidget {
  final int  index;
  final bool visited;
  const _WaypointMarker({required this.index, required this.visited});

  @override
  Widget build(BuildContext context) {
    final bg    = visited ? const Color(0xFF059669) : const Color(0xFF1A73E8);
    final label = index.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: bg.withOpacity(0.45),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: visited
              ? const Icon(Icons.check_rounded,
              color: Colors.white, size: 16)
              : Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Container(
          width: 2.5, height: 10,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  final Animation<double> pulse;
  const _UserLocationMarker({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          Container(
            width:  48 * pulse.value,
            height: 48 * pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A73E8).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFF1A73E8).withOpacity(0.35),
                width: 1.5,
              ),
            ),
          ),
          // Dot
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A73E8).withOpacity(0.50),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UI Components
// ═════════════════════════════════════════════════════════════════════════════

class _NavBtn extends StatelessWidget {
  final IconData    icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withOpacity(0.20), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// Google Maps style white circular button
class _GmapsCircleBtn extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final VoidCallback onTap;
  const _GmapsCircleBtn({
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _SideBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final Color        color;
  const _SideBtn({required this.icon, required this.onTap,
    this.color = const Color(0xFF374151)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String   label;
  final String   address;
  final String?  subLabel;
  final IconData icon;
  final Color    iconBg;
  final Color    iconColor;
  final bool     isFirst;
  final bool     isLast;
  final bool     isDone;
  final int?     stopNumber;

  const _StopRow({
    required this.label,
    required this.address,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.subLabel,
    this.isFirst  = false,
    this.isLast   = false,
    this.isDone   = false,
    this.stopNumber,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: icon + connector line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isDone && !isLast && !isFirst
                      ? Icon(Icons.check_rounded,
                      size: 14, color: const Color(0xFF059669))
                      : Icon(icon, size: 14, color: iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF059669).withOpacity(0.4)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Right: text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 8, bottom: 10, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDone && !isFirst
                          ? Colors.grey.shade400
                          : const Color(0xFF111827),
                      decoration: isDone && !isFirst && !isLast
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (subLabel != null && subLabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.80)],
            begin: Alignment.centerLeft,
            end:   Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final VoidCallback? onTap;
  const _IconActionButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: active
              ? color.withOpacity(0.10)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? color.withOpacity(0.30)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: active ? color : Colors.grey.shade400,
          size: 22,
        ),
      ),
    );
  }
}
