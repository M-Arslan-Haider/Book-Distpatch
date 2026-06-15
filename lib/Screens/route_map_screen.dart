// ═══════════════════════════════════════════════════════════════════════════
// route_map_screen.dart
//
// Opens when the driver taps "Start" on a ScheduleScreen card.
// Displays a real road route between Origin → Destination on OpenStreetMap.
//
// ── pubspec.yaml dependencies ──────────────────────────────────────────────
//   flutter_map: ^7.0.2
//   latlong2:    ^0.9.0
//   http:        ^1.2.0   (already present)
//
// ── AndroidManifest.xml permissions ───────────────────────────────────────
//   <uses-permission android:name="android.permission.INTERNET"/>
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class RouteMapScreen extends StatefulWidget {
  /// Full route map from API response.
  /// Expected keys: ROUTE_ID, ROUTE_NAME, ORIGIN_LAT, ORIGIN_LNG,
  ///                DEST_LAT, DEST_LNG, EMP_NAME, ROUTE_COLOR, TRAVEL_MODE
  final Map<String, dynamic> route;

  const RouteMapScreen({super.key, required this.route});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────────────────────
  static const _tealDark = Color(0xFF0C6B64);
  static const _teal     = Color(0xFF0C9E8E);

  // ── Controllers ────────────────────────────────────────────────────────
  final MapController _mapController = MapController();

  // ── Parsed route fields ────────────────────────────────────────────────
  late LatLng  _origin;
  late LatLng  _destination;
  late Color   _routeColor;
  late String  _routeName;
  late String  _empName;
  late String  _travelMode;
  late String  _routeId;

  // ── Routing state ──────────────────────────────────────────────────────
  List<LatLng> _polylinePoints = [];
  bool         _isLoading      = true;
  String?      _warningMsg;
  bool         _panelExpanded  = true;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _parseRouteData();
    _fetchOsrmRoute();
  }

  // ── Parse API data ─────────────────────────────────────────────────────
  void _parseRouteData() {
    final r = widget.route;
    _origin = LatLng(
      _asDouble(r['ORIGIN_LAT'] ?? r['origin_lat']),
      _asDouble(r['ORIGIN_LNG'] ?? r['origin_lng']),
    );
    _destination = LatLng(
      _asDouble(r['DEST_LAT'] ?? r['dest_lat']),
      _asDouble(r['DEST_LNG'] ?? r['dest_lng']),
    );
    _routeColor = _parseHexColor(
        r['ROUTE_COLOR']?.toString() ?? '#0C9E8E');
    _routeName  = r['ROUTE_NAME']?.toString()  ?? 'Route';
    _empName    = r['EMP_NAME']?.toString()    ?? '';
    _travelMode = r['TRAVEL_MODE']?.toString() ?? 'DRIVING';
    _routeId    = r['ROUTE_ID']?.toString()    ?? '';
  }

  double _asDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  Color _parseHexColor(String hex) {
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _teal;
    }
  }

  // ── OSRM road routing ──────────────────────────────────────────────────
  Future<void> _fetchOsrmRoute() async {
    if (!mounted) return;
    setState(() {
      _isLoading   = true;
      _warningMsg  = null;
    });

    // Map TRAVEL_MODE → OSRM profile
    final profile = _osrmProfile(_travelMode);

    final uri = Uri.parse(
      'http://router.project-osrm.org/route/v1/$profile/'
          '${_origin.longitude},${_origin.latitude};'
          '${_destination.longitude},${_destination.latitude}'
          '?geometries=geojson&overview=full&steps=false',
    );

    debugPrint('🗺️ [RouteMapScreen] OSRM → $uri');

    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final body   = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final coords =
          routes[0]['geometry']['coordinates'] as List<dynamic>;
          final pts = coords
              .map((c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ))
              .toList();

          _applyPoints(pts);
          return;
        }
      }
      debugPrint('⚠️ [RouteMapScreen] OSRM empty/error → straight line');
      _useStraightLine('Road routing unavailable — showing straight line.');
    } catch (e) {
      debugPrint('❌ [RouteMapScreen] OSRM exception: $e');
      _useStraightLine('Routing service unreachable — showing straight line.');
    }
  }

  String _osrmProfile(String mode) {
    final m = mode.toLowerCase();
    if (m == 'walking' || m == 'walk') return 'foot';
    if (m == 'cycling' || m == 'cycle') return 'cycling';
    return 'driving'; // default — most reliable on public OSRM
  }

  void _applyPoints(List<LatLng> pts) {
    if (!mounted) return;
    setState(() {
      _polylinePoints = pts;
      _isLoading      = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  void _useStraightLine(String warn) {
    if (!mounted) return;
    setState(() {
      _polylinePoints = [_origin, _destination];
      _isLoading      = false;
      _warningMsg     = warn;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  void _fitBounds() {
    if (_polylinePoints.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: _polylinePoints,
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 320),
        ),
      );
    } catch (_) {}
  }

  // ── Travel icon ────────────────────────────────────────────────────────
  IconData get _travelIcon {
    final m = _travelMode.toLowerCase();
    if (m == 'walking' || m == 'walk')   return Icons.directions_walk_rounded;
    if (m == 'cycling' || m == 'cycle')  return Icons.directions_bike_rounded;
    return Icons.directions_car_rounded;
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Map (bottom layer)
          _buildMap(),

          // 2. Top gradient app-bar
          _buildTopBar(context),

          // 3. Loading badge
          if (_isLoading) _buildLoadingBadge(context),

          // 4. Warning banner (straight-line fallback notice)
          if (_warningMsg != null && !_isLoading)
            _buildWarningBanner(context),

          // 5. Zoom controls (right side)
          _buildZoomControls(),

          // 6. Bottom route-detail panel
          _buildBottomPanel(context),
        ],
      ),
    );
  }

  // ── 1. Map ─────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _origin,
        initialZoom: 13.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // ── OSM Tile Layer ──────────────────────────────────────────────
        TileLayer(
          urlTemplate:
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.metaxperts.gps_workforce',
          maxZoom: 19,
        ),

        // ── Route Polyline (shadow + main) ──────────────────────────────
        if (_polylinePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              // Shadow
              Polyline(
                points:      _polylinePoints,
                color:       Colors.black.withOpacity(0.18),
                strokeWidth: 9.0,
              ),
              // Main route
              Polyline(
                points:      _polylinePoints,
                color:       _routeColor,
                strokeWidth: 5.5,
              ),
            ],
          ),

        // ── Markers ─────────────────────────────────────────────────────
        MarkerLayer(
          markers: [
            // Origin
            Marker(
              point:     _origin,
              width:     46,
              height:    46,
              alignment: Alignment.center,
              child:     _OriginPin(),
            ),
            // Destination
            Marker(
              point:     _destination,
              width:     46,
              height:    58,
              alignment: Alignment.bottomCenter,
              child:     _DestinationPin(),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Top gradient bar ────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
            top: top + 4, bottom: 14, left: 4, right: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              _tealDark.withOpacity(0.96),
              _tealDark.withOpacity(0.0),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),

            // Title block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _routeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 6)
                      ],
                    ),
                  ),
                  if (_empName.isNotEmpty)
                    Text(
                      _empName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Fit route button
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded,
                  color: Colors.white, size: 22),
              onPressed: _fitBounds,
              tooltip: 'Fit route',
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Loading badge ───────────────────────────────────────────────────
  Widget _buildLoadingBadge(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 72, left: 0, right: 0,
      child: Center(
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _teal),
              ),
              SizedBox(width: 10),
              Text(
                'Calculating road route…',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Warning banner ──────────────────────────────────────────────────
  Widget _buildWarningBanner(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 72, left: 16, right: 16,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade300),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
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
                  size: 16, color: Colors.orange.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Zoom controls ───────────────────────────────────────────────────
  Widget _buildZoomControls() {
    return Positioned(
      right: 14,
      // Float above the bottom panel
      bottom: _panelExpanded ? 310 : 88,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 260),
        child: Column(
          children: [
            _ZoomBtn(
              icon: Icons.add_rounded,
              onTap: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1),
            ),
            const SizedBox(height: 6),
            _ZoomBtn(
              icon: Icons.remove_rounded,
              onTap: () => _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Bottom detail panel ─────────────────────────────────────────────
  Widget _buildBottomPanel(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────
            GestureDetector(
              onTap: () =>
                  setState(() => _panelExpanded = !_panelExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Container(
                      width: 42, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedRotation(
                      turns:    _panelExpanded ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_up_rounded,
                          size: 20, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expandable content ────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState: _panelExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild:  _buildPanelContent(context),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, bottom: bottomPad + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Route name + color accent ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 5, height: 24,
                decoration: BoxDecoration(
                  color: _routeColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _routeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Info chips ────────────────────────────────────────────
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              if (_empName.isNotEmpty)
                _Chip(
                    icon: Icons.person_rounded,
                    label: _empName,
                    color: _teal),
              _Chip(
                  icon: _travelIcon,
                  label: _travelMode.toUpperCase(),
                  color: const Color(0xFF1a56db)),
              if (_routeId.isNotEmpty)
                _Chip(
                    icon: Icons.confirmation_number_outlined,
                    label: _routeId,
                    color: Colors.grey.shade600),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),

          // ── Origin ────────────────────────────────────────────────
          _LocationRow(
            icon:   Icons.my_location_rounded,
            color:  Colors.green.shade600,
            title:  'Start Point',
            coords: '${_origin.latitude.toStringAsFixed(5)}, '
                '${_origin.longitude.toStringAsFixed(5)}',
          ),

          // Dashed connector line
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 5, bottom: 5),
            child: Column(
              children: List.generate(4, (_) => Container(
                width: 2, height: 5,
                margin: const EdgeInsets.only(bottom: 3),
                color: Colors.grey.shade300,
              )),
            ),
          ),

          // ── Destination ───────────────────────────────────────────
          _LocationRow(
            icon:   Icons.flag_rounded,
            color:  Colors.red.shade600,
            title:  'Destination',
            coords: '${_destination.latitude.toStringAsFixed(5)}, '
                '${_destination.longitude.toStringAsFixed(5)}',
          ),

          const SizedBox(height: 16),

          // ── Recalculate button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchOsrmRoute,
              icon: _isLoading
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.route_rounded, size: 18),
              label: Text(
                  _isLoading ? 'Loading…' : 'Recalculate Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Origin Pin
// ═════════════════════════════════════════════════════════════════════════════
class _OriginPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.45),
              blurRadius: 10,
              spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.my_location_rounded,
          color: Colors.white, size: 22),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Destination Pin  (circle + stem)
// ═════════════════════════════════════════════════════════════════════════════
class _DestinationPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.flag_rounded,
              color: Colors.white, size: 20),
        ),
        Container(
          width: 2.5, height: 14,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Zoom Button
// ═════════════════════════════════════════════════════════════════════════════
class _ZoomBtn extends StatelessWidget {
  final IconData    icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF374151)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Info Chip
// ═════════════════════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Location Row
// ═════════════════════════════════════════════════════════════════════════════
class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   coords;
  const _LocationRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.coords,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              coords,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
