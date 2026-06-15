// ═══════════════════════════════════════════════════════════════════════════
// route_status_helper.dart
//
// Small helper used by NavigationScreen to detect whether the user's live
// location is "ON ROUTE" or "OFF ROUTE" relative to the active OSRM polyline,
// and a small badge widget to display that status on screen.
//
// Logic:
//   • For every consecutive pair of points in the route polyline, compute the
//     shortest distance from the user's current location to that segment.
//   • Take the minimum distance across all segments → "distance from route".
//   • If distance <= threshold (default 20 m) → ON ROUTE, else OFF ROUTE.
//
// Usage (inside NavigationScreen):
//
//   final status = RouteStatusHelper.getStatus(
//     userLocation: _userLocation!,
//     polyline:     _polylinePoints,
//     thresholdMeters: 20,
//   );
//
//   // status.isOnRoute   -> bool
//   // status.distanceM   -> double (metres from route)
//
//   RouteStatusBadge(status: status)   // draw on screen
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Result of an on-route / off-route check.
class RouteStatus {
  final bool   isOnRoute;
  final double distanceM;

  const RouteStatus({
    required this.isOnRoute,
    required this.distanceM,
  });
}

/// Pure helper class — no state, just static math.
class RouteStatusHelper {
  static const Distance _distCalc = Distance();

  /// Returns the on-route / off-route status for [userLocation] against
  /// the given [polyline].
  ///
  /// [thresholdMeters] — how far (in metres) the user can be from the
  /// polyline and still be considered "on route". Default = 20 m.
  static RouteStatus getStatus({
    required LatLng       userLocation,
    required List<LatLng> polyline,
    double thresholdMeters = 20,
  }) {
    if (polyline.length < 2) {
      return const RouteStatus(isOnRoute: false, distanceM: 0);
    }

    double minDist = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final segStart = polyline[i];
      final segEnd   = polyline[i + 1];

      final d = _distanceToSegmentMeters(
        userLocation,
        segStart,
        segEnd,
      );

      if (d < minDist) minDist = d;

      // Early exit — already well within threshold, no need to keep scanning
      if (minDist <= thresholdMeters) break;
    }

    return RouteStatus(
      isOnRoute: minDist <= thresholdMeters,
      distanceM: minDist,
    );
  }

  /// Shortest distance (in metres) from [point] to the line segment
  /// defined by [segStart] → [segEnd].
  ///
  /// Approach: project point onto the segment in a local equirectangular
  /// (flat-earth) frame centred on segStart — accurate enough for the small
  /// distances (tens/hundreds of metres) involved in route-deviation checks.
  static double _distanceToSegmentMeters(
      LatLng point,
      LatLng segStart,
      LatLng segEnd,
      ) {
    // Convert lat/lng degrees to local metre offsets relative to segStart.
    const metersPerDegLat = 111320.0;
    final cosLat = _cosDeg(segStart.latitude);
    final metersPerDegLng = 111320.0 * cosLat;

    double toX(LatLng p) => (p.longitude - segStart.longitude) * metersPerDegLng;
    double toY(LatLng p) => (p.latitude  - segStart.latitude)  * metersPerDegLat;

    final px = toX(point);
    final py = toY(point);
    final ax = 0.0;
    final ay = 0.0;
    final bx = toX(segEnd);
    final by = toY(segEnd);

    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;

    final abLenSq = abx * abx + aby * aby;

    double t = abLenSq > 0 ? (apx * abx + apy * aby) / abLenSq : 0.0;
    t = t.clamp(0.0, 1.0);

    final closestX = ax + t * abx;
    final closestY = ay + t * aby;

    final dx = px - closestX;
    final dy = py - closestY;

    return math.sqrt(dx * dx + dy * dy);
  }

  static double _cosDeg(double deg) => math.cos(deg * math.pi / 180.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// RouteStatusBadge — small pill shown on the map (top-right under the banner)
// ─────────────────────────────────────────────────────────────────────────────
class RouteStatusBadge extends StatelessWidget {
  final RouteStatus status;

  const RouteStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final onRoute = status.isOnRoute;

    final bgColor   = onRoute ? const Color(0xFF1E8A5E) : const Color(0xFFDC2626);
    final label     = onRoute ? 'ON ROUTE' : 'OFF ROUTE';
    final icon      = onRoute ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}