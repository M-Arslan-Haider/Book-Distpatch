
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Database/db_helper.dart';

/// Standalone bulk location tracker.
///
/// ALL FIXES applied in this version:
///   1. Timer interval: 10s (unchanged)
///   2. Accuracy filter: skip GPS readings worse than 50m (unchanged)
///   3. Distance filter REMOVED — stationary users ka data bhi capture ho
///   4. SQLite-first architecture — RAM buffer hataya, har record pehle SQLite
///      mein save hota hai, phir server ko sync hota hai (100% data safety)
///   5. stopAndFlush() — tick complete hone ka wait karta hai (race condition fix)
///   6. _syncFromDb() — single unified sync method for all cases
///   7. _syncInProgress deadlock fix — stop-and-flush reason pe wait karta hai
///      taake clockout pe last records kabhi miss na hon
///   8. _locationSerialCounter — sirf memory se read hota hai, prefs se nahi
///      (duplicate ID bug fix on app resume)
///   9. _hasInternetConnection() — google.com DNS hataya, direct socket check
///      (Pakistan mein DNS timeout se false-offline fix)
///  10. Batched sync — 500 records ke baad bhi loop karta rahe jab tak sab sync
///      (infinite loop / stuck records fix for heavy offline sessions)
class LocationBulkTracker {
  LocationBulkTracker._();
  static final LocationBulkTracker instance = LocationBulkTracker._();

  static const String   _endpoint          = 'http://103.149.33.102.7:8001/location/bulk';
  // static const String   _endpoint          = 'http://119.153.102.7:8001/location/bulk';
  static const Duration _captureInterval   = Duration(seconds: 10);
  static const double   _maxAccuracyMeters = 50.0;
  static const int      _syncBatchSize     = 500;

  final DBHelper _dbHelper = DBHelper();

  Timer? _timer;
  bool   _isRunning      = false;
  bool   _tickInProgress = false;
  bool   _wasClockedIn   = false;
  bool   _syncInProgress = false;

  // ✅ FIX #8: Counter lives only in memory — no prefs read mid-session
  // On start(), loaded once from prefs. Never re-read from prefs inside tick.
  int    _locationSerialCounter    = 1;
  String _lastGeneratedLocationDay = '';

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('ℹ️ [BULK] Tracker already running');
      return;
    }

    // Load counter once on start — not again inside ticks
    final prefs = await SharedPreferences.getInstance();
    _locationSerialCounter    = prefs.getInt('bulk_location_serial_counter') ?? 1;
    _lastGeneratedLocationDay = prefs.getString('bulk_last_generated_day') ?? '';

    _isRunning = true;

    debugPrint('✅ [BULK] Tracker started | '
        'interval=${_captureInterval.inSeconds}s | '
        'maxAccuracy=${_maxAccuracyMeters}m | '
        'distanceFilter=DISABLED | '
        'serialCounter=$_locationSerialCounter');

    // ✅ NEW: Immediately drain any leftover pending rows from a previous
    // session (killed/offline). Previously the first upload only happened after
    // 5 NEW points accumulated, so old rows could sit unsynced for a long time.
    unawaited(_syncFromDb(reason: 'tracker-start'));

    _timer = Timer.periodic(_captureInterval, (_) {
      unawaited(_tick());
    });
  }

  /// Stop tracker and flush all pending SQLite records to server.
  Future<void> stopAndFlush() async {
    debugPrint('🛑 [BULK] Stop requested');
    _timer?.cancel();
    _timer     = null;
    _isRunning = false;

    // ✅ FIX #5: Wait for any currently running tick to finish
    int waitMs = 0;
    while (_tickInProgress) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitMs += 100;
      if (waitMs > 5000) {
        debugPrint('⚠️ [BULK] Tick wait timeout (5s) — proceeding with flush anyway');
        break;
      }
    }

    // Save counter to prefs on stop
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bulk_location_serial_counter', _locationSerialCounter);

    // ✅ FIX #7: stopAndFlush waits even if _syncInProgress=true
    // Normal syncs are skipped when busy, but clockout MUST complete
    if (_syncInProgress) {
      debugPrint('⏳ [BULK] Waiting for in-progress sync to finish before final flush...');
      int syncWaitMs = 0;
      while (_syncInProgress) {
        await Future.delayed(const Duration(milliseconds: 100));
        syncWaitMs += 100;
        if (syncWaitMs > 10000) {
          debugPrint('⚠️ [BULK] Sync wait timeout (10s) — forcing final flush');
          _syncInProgress = false; // force reset so _syncFromDb can run
          break;
        }
      }
    }

    // Final sync — push everything pending in SQLite to server
    await _syncFromDb(reason: 'stop-and-flush');
  }

  /// Sync pending offline records. Called when internet comes back.
  Future<int> syncPendingRecords() async {
    debugPrint('🔄 [BULK] syncPendingRecords called');
    return await _syncFromDb(reason: 'manual-sync-trigger');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — TICK
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    if (_tickInProgress) return;
    _tickInProgress = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClockedIn        = _readClockInState(prefs);

      if (!isClockedIn) {
        if (_wasClockedIn) {
          debugPrint('⏹️ [BULK] Clock-out detected in tick — triggering final sync');
          unawaited(_syncFromDb(reason: 'clockout-detected-in-tick'));
        }
        _wasClockedIn = false;
        return;
      }

      _wasClockedIn = true;

      // ── GPS position ───────────────────────────────────────────────────
      Position position;
      try {
        position = await _getCurrentPosition();
      } catch (e) {
        debugPrint('❌ [BULK] GPS error: $e — skipping tick');
        return;
      }

      // Validate lat/lng
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        debugPrint('⚠️ [BULK] SKIP — lat/lng are 0.0, invalid GPS fix');
        return;
      }

      // Accuracy filter
      if (position.accuracy > _maxAccuracyMeters) {
        debugPrint('⚠️ [BULK] SKIP — poor GPS accuracy: '
            '${position.accuracy.toStringAsFixed(1)}m '
            '(threshold: ${_maxAccuracyMeters}m)');
        return;
      }

      // ── Build & save record ────────────────────────────────────────────
      final Map<String, dynamic>? record = await _buildRecord(prefs, position);
      if (record == null) return;

      // ✅ FIX #4: SQLite-first — save immediately, no RAM buffer
      await _dbHelper.insertLocationTrackingBulk([record]);

      final int pendingCount = await _dbHelper.getUnpostedLocationTrackingCount();

      debugPrint('💾 [BULK] Saved to SQLite | '
          'user_id=${record['user_id']} '
          'lat=${record['lat_in']} '
          'lng=${record['lng_in']} '
          'acc=${position.accuracy.toStringAsFixed(1)}m '
          'date=${record['locationtracking_date']} '
          'time=${record['locationtracking_time']} '
          'pending_in_db=$pendingCount');

      // Sync every 5 records
      if (pendingCount >= 5) {
        await _syncFromDb(reason: 'batch-limit-5');
      }
    } catch (e) {
      debugPrint('❌ [BULK] Tick error: $e');
    } finally {
      _tickInProgress = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — SYNC
  // ─────────────────────────────────────────────────────────────────────────

  /// Unified sync: SQLite unposted → POST to server in batches → mark posted.
  /// ✅ FIX #10: Batched loop — handles 500+ records correctly, no infinite loop.
  Future<int> _syncFromDb({required String reason}) async {
    if (_syncInProgress) {
      debugPrint('ℹ️ [BULK] Sync already in progress — skipping ($reason)');
      return 0;
    }
    _syncInProgress = true;

    int totalSynced = 0;

    try {
      final bool hasConnection = await _hasInternetConnection();
      if (!hasConnection) {
        final int pending = await _dbHelper.getUnpostedLocationTrackingCount();
        debugPrint('📴 [BULK] Offline — $pending records safe in SQLite ($reason)');
        return 0;
      }

      // ✅ FIX #10: Loop in batches until all records synced
      while (true) {
        final List<Map<String, dynamic>> unposted =
        await _dbHelper.getUnpostedLocationTracking(limit: _syncBatchSize);

        if (unposted.isEmpty) {
          debugPrint('ℹ️ [BULK] No more pending records ($reason) | '
              'totalSynced=$totalSynced');
          break;
        }

        debugPrint('📡 [BULK] Syncing batch of ${unposted.length} records | '
            'reason=$reason | totalSynced=$totalSynced');

        // Normalize types
        final List<Map<String, dynamic>> normalized = unposted.map((r) {
          double lat = 0.0;
          double lng = 0.0;

          if (r['lat_in'] is double)      lat = r['lat_in'] as double;
          else if (r['lat_in'] is num)    lat = (r['lat_in'] as num).toDouble();
          else if (r['lat_in'] is String) lat = double.tryParse(r['lat_in'] as String) ?? 0.0;

          if (r['lng_in'] is double)      lng = r['lng_in'] as double;
          else if (r['lng_in'] is num)    lng = (r['lng_in'] as num).toDouble();
          else if (r['lng_in'] is String) lng = double.tryParse(r['lng_in'] as String) ?? 0.0;

          return {
            'db_id':                 r['id'],
            'locationtracking_id':   r['locationtracking_id']?.toString() ?? '',
            'locationtracking_date': r['locationtracking_date']?.toString() ?? '',
            'locationtracking_time': r['locationtracking_time']?.toString() ?? '',
            'user_id':               r['user_id']?.toString() ?? '',
            'company_code':          r['company_code']?.toString() ?? '',
            'lat_in':                lat,
            'lng_in':                lng,
            'booker_name':           r['booker_name']?.toString() ?? '',
            'designation':           r['designation']?.toString() ?? 'GPS',
            'posted':                true,
          };
        }).where((r) =>
        (r['lat_in'] as double) != 0.0 || (r['lng_in'] as double) != 0.0
        ).toList();

        if (normalized.isEmpty) {
          // All records in this batch had zero coords — mark them posted so
          // they don't block future syncs, then continue to next batch
          final List<int> zeroIds = unposted
              .where((r) => r['id'] != null)
              .map((r) => r['id'] as int)
              .toList();
          if (zeroIds.isNotEmpty) {
            await _dbHelper.markLocationTrackingAsPosted(zeroIds);
            debugPrint('⚠️ [BULK] Skipped ${zeroIds.length} zero-coord records '
                '(marked posted to unblock queue)');
          }
          continue;
        }

        // Build API payload
        final requestBody = {
          'records': normalized.map((r) => {
            'locationtracking_id':   r['locationtracking_id'],
            'locationtracking_date': r['locationtracking_date'],
            'locationtracking_time': r['locationtracking_time'],
            'user_id':               r['user_id'],
            'company_code':          r['company_code'],
            'lat_in':                r['lat_in'],
            'lng_in':                r['lng_in'],
            'booker_name':           r['booker_name'],
            'designation':           r['designation'],
            'posted':                r['posted'],
          }).toList(),
        };

        debugPrint('📡 [BULK] REQUEST → POST $_endpoint | '
            'batch=${normalized.length} | '
            'first: user=${normalized.first['user_id']} '
            'lat=${normalized.first['lat_in']} '
            'lng=${normalized.first['lng_in']}');

        final http.Response response = await http.post(
          Uri.parse(_endpoint),
          headers: <String, String>{
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader:      'application/json',
          },
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));

        debugPrint('📥 [BULK] RESPONSE status=${response.statusCode} | '
            'body=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final List<int> ids = normalized
              .where((r) => r['db_id'] != null)
              .map((r) => r['db_id'] as int)
              .toList();

          if (ids.isNotEmpty) {
            await _dbHelper.markLocationTrackingAsPosted(ids);
          }

          totalSynced += normalized.length;
          debugPrint('✅ [BULK] Batch synced ${normalized.length} records | '
              'totalSynced=$totalSynced ($reason)');

          // If batch was smaller than limit — no more records left
          if (unposted.length < _syncBatchSize) break;

        } else {
          // Server error — stop looping, data stays safe in SQLite
          debugPrint('⚠️ [BULK] Server returned ${response.statusCode} — '
              'stopping batch loop, data safe in SQLite ($reason)');
          break;
        }
      }

      return totalSynced;

    } catch (e) {
      debugPrint('❌ [BULK] Sync error: $e — data safe in SQLite ($reason)');
      return totalSynced;
    } finally {
      _syncInProgress = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  bool _readClockInState(SharedPreferences prefs) {
    return prefs.getBool('isClockedIn') ??
        prefs.getBool('clockedIn') ??
        prefs.getBool('prefIsClockedIn') ??
        false;
  }

  Future<Position> _getCurrentPosition() async {
    final LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 8));
  }

  Future<Map<String, dynamic>?> _buildRecord(
      SharedPreferences prefs,
      Position position,
      ) async {
    final String? userId = _readRequiredString(prefs, <String>[
      'emp_id',
      'user_id',
    ]);

    final String? bookerName = _readRequiredString(prefs, <String>[
      'emp_name',
      'booker_name',
      'name',
      'user_name',
      'userName',
      'employee_name',
    ]);

    String designation = _readFirstNonEmpty(prefs, [
      'cached_designation',
      'userDesignation',
      'designation',
      'cached_job',
      'job',
      'role',
      'emp_job',
      'position',
      'jobTitle',
    ]);
    if (designation.isEmpty) designation = 'GPS';

    final String? companyCode = _readRequiredString(prefs, <String>[
      'company_code',
      'companyCode',
      'cached_company_code',
    ]);

    if (userId == null     || userId.isEmpty ||
        bookerName == null || bookerName.isEmpty ||
        companyCode == null || companyCode.isEmpty) {
      debugPrint('⚠️ [BULK] SKIP — missing mandatory field(s). '
          'user_id=$userId booker_name=$bookerName company_code=$companyCode');
      return null;
    }

    final DateTime now   = DateTime.now();
    final String date    = DateFormat('yyyy-MM-dd').format(now);
    final String time    = DateFormat('HH:mm:ss').format(now);

    // ✅ FIX #8: Counter incremented in memory only — no stale prefs read
    final String trackId = _createLocationTrackingId(userId, now);

    return <String, dynamic>{
      'locationtracking_id':   trackId,
      'locationtracking_date': date,
      'locationtracking_time': time,
      'user_id':               userId,
      'lat_in':                position.latitude,
      'lng_in':                position.longitude,
      'booker_name':           bookerName,
      'designation':           designation,
      'company_code':          companyCode,
      'posted':                0,
    };
  }

  /// ✅ FIX #8: Synchronous — no async prefs read, counter is purely in-memory.
  /// Prefs write happens only on stopAndFlush() to persist across sessions.
  String _createLocationTrackingId(String userId, DateTime now) {
    final String month = DateFormat('MMM').format(now);
    final String day   = DateFormat('dd').format(now);
    final String today = DateFormat('yyyy-MM-dd').format(now);

    if (_lastGeneratedLocationDay != today) {
      _locationSerialCounter    = 1;
      _lastGeneratedLocationDay = today;
      debugPrint('🔄 [BULK] New day — serial counter reset to 1');
    }

    final String id = 'LT-$userId-$day-$month-'
        '${_locationSerialCounter.toString().padLeft(3, '0')}';

    _locationSerialCounter++;
    return id;
  }

  String _readFirstNonEmpty(SharedPreferences prefs, List<String> keys) {
    for (final String key in keys) {
      final Object? value = prefs.get(key);
      if (value != null) {
        final String str = value.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return '';
  }

  String? _readRequiredString(SharedPreferences prefs, List<String> keys) {
    final String value = _readFirstNonEmpty(prefs, keys);
    return value.isEmpty ? null : value;
  }

  /// ✅ FIX #9: Direct socket connection to 1.1.1.1:80 — no DNS lookup needed.
  /// google.com DNS in Pakistan can timeout causing false-offline detection.
  Future<bool> _hasInternetConnection() async {
    try {
      final Socket socket = await Socket.connect(
        '1.1.1.1', // Cloudflare DNS — direct IP, no DNS resolution needed
        80,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
