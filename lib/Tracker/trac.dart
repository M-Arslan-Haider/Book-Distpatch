
import 'dart:async' show Future, Timer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:gpx/gpx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ViewModels/location_view_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Singleton ViewModel reference (same pattern as original)
// ─────────────────────────────────────────────────────────────────────────────
final locationViewModel = Get.put(LocationViewModel());

// ─────────────────────────────────────────────────────────────────────────────
// SPEED THRESHOLD — raise to allow motorbike / car speeds.
// Original was 14 m/s (50 km/h).  New value: 33.3 m/s (120 km/h).
// Adjust as needed for your field-force use case.
// ─────────────────────────────────────────────────────────────────────────────
const double kMaxAllowedSpeedMs = 33.3; // 120 km/h

// ─────────────────────────────────────────────────────────────────────────────
// TIMER — starts / restores the elapsed-seconds counter
// ─────────────────────────────────────────────────────────────────────────────

/// Call this once when the user clocks in.
/// Saves the clock-in timestamp as an ISO-8601 string so the timer can be
/// restored correctly even after midnight or a force-kill.
Future<void> startTimer() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // ── FIX 1: persist clock-in time as ISO string, not HH:mm:ss ──────────────
  // Only write it if it isn't already there (so app-restart doesn't reset it)
  if (!prefs.containsKey('clockInTimestamp')) {
    await prefs.setString(
        'clockInTimestamp', DateTime.now().toIso8601String());
  }

  // Restore elapsed seconds from the saved timestamp on startup
  _restoreElapsedSeconds(prefs);

  // Tick every second
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    locationViewModel.secondsPassed.value++;

    // Persist every tick so a force-kill can restore the value
    final p = await SharedPreferences.getInstance();
    await p.setInt('secondsPassed', locationViewModel.secondsPassed.value);
  });

  if (kDebugMode) print('⏱ Timer started');
}

/// Computes elapsed seconds from the stored clock-in timestamp.
/// Works correctly across midnight and after app restarts.
void _restoreElapsedSeconds(SharedPreferences prefs) {
  final isoString = prefs.getString('clockInTimestamp');
  if (isoString == null) {
    // No saved timestamp — start from whatever was persisted
    locationViewModel.secondsPassed.value =
        prefs.getInt('secondsPassed') ?? 0;
    if (kDebugMode) print('⏱ No clock-in timestamp — using saved seconds');
    return;
  }

  final clockInTime = DateTime.tryParse(isoString);
  if (clockInTime == null) {
    locationViewModel.secondsPassed.value =
        prefs.getInt('secondsPassed') ?? 0;
    return;
  }

  final elapsed = DateTime.now().difference(clockInTime).inSeconds;
  locationViewModel.secondsPassed.value = elapsed < 0 ? 0 : elapsed;

  if (kDebugMode) {
    print('⏱ Restored elapsed: ${locationViewModel.secondsPassed.value}s '
        '(clock-in: $isoString)');
  }
}

/// Call when the user clocks out to clear the saved timestamp.
Future<void> clearTimer() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('clockInTimestamp');
  await prefs.setInt('secondsPassed', 0);
  locationViewModel.secondsPassed.value = 0;
  if (kDebugMode) print('⏱ Timer cleared');
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTANCE HELPERS — accurate both online and offline
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the current tracked distance in km.
///
/// • ONLINE (clocked-in, stream running): returns the in-memory accumulator
///   from LocationViewModel — already Kalman-smoothed, no file I/O needed.
///
/// • OFFLINE / after clock-out: reads the GPX file directly, skipping
///   heartbeat and stationary-forced points so they never inflate distance.
Future<double> getCurrentDistanceKm() async {
  // If the ViewModel is actively tracking, trust its in-memory value
  if (locationViewModel.isClockedIn.value) {
    return locationViewModel.totalDistance.value;
  }

  // Otherwise read from GPX file
  return readDistanceOffline();
}

/// Reads today's GPX file and calculates the real distance,
/// EXCLUDING 'heartbeat' and 'stationary' tagged points.
///
/// This is the authoritative offline distance calculation.
/// It is also useful if the app was force-killed mid-session.
Future<double> readDistanceOffline({DateTime? date}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Try both emp_id key names for compatibility
    String empId = prefs.getString('emp_id') ??
        prefs.getString('userId') ??
        prefs.getString('user_id') ??
        '';

    final dateStr =
    DateFormat('dd-MM-yyyy').format(date ?? DateTime.now());
    final dir = await getDownloadsDirectory();
    if (dir == null) return 0.0;

    // ── FIX: consistent file-path — matches LocationService naming ──────────
    final filePath = '${dir.path}/track_${empId}_$dateStr.gpx';
    final file = File(filePath);

    if (!await file.exists()) {
      if (kDebugMode) print('📂 GPX not found: $filePath');
      return 0.0;
    }

    final content = await file.readAsString();
    if (content.isEmpty) return 0.0;

    final gpx = GpxReader().fromString(content);
    double total = 0.0;

    for (final trk in gpx.trks) {
      for (final seg in trk.trksegs) {
        // ── FIX: exclude heartbeat and forced-stationary points ──────────────
        final realPoints = seg.trkpts
            .where((p) =>
        p.name != 'heartbeat' &&
            p.name != 'stationary' &&
            p.lat != null &&
            p.lon != null)
            .toList();

        for (int i = 0; i < realPoints.length - 1; i++) {
          final a = realPoints[i];
          final b = realPoints[i + 1];

          final distM = Geolocator.distanceBetween(
            a.lat!.toDouble(),
            a.lon!.toDouble(),
            b.lat!.toDouble(),
            b.lon!.toDouble(),
          );

          // ── FIX: speed-based sanity check (raised to 120 km/h) ──────────
          if (a.time != null && b.time != null) {
            final elapsedS =
                b.time!.difference(a.time!).inMilliseconds / 1000.0;
            if (elapsedS > 0.1) {
              final speedMs = distM / elapsedS;
              if (speedMs > kMaxAllowedSpeedMs) {
                if (kDebugMode) {
                  debugPrint('🚫 [offline] Skipping jump '
                      '${distM.toStringAsFixed(1)} m in '
                      '${elapsedS.toStringAsFixed(1)} s = '
                      '${(speedMs * 3.6).toStringAsFixed(1)} km/h');
                }
                continue; // skip this impossible segment
              }
            }
          }

          total += distM / 1000.0; // metres → km
        }
      }
    }

    if (kDebugMode) {
      print('📏 Offline distance: ${total.toStringAsFixed(3)} km '
          '(file: $filePath)');
    }
    return total;
  } catch (e) {
    debugPrint('❌ readDistanceOffline: $e');
    return 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGACY COMPAT — kept so existing callers don't break
// ─────────────────────────────────────────────────────────────────────────────

/// Retained for callers that used the old startTimerFromSavedTime() API.
/// Internally delegates to the fixed implementation.
void startTimerFromSavedTime() {
  SharedPreferences.getInstance().then((prefs) async {
    await prefs.reload();
    _restoreElapsedSeconds(prefs);
    if (kDebugMode) print('Loaded Saved Time');
  });
}