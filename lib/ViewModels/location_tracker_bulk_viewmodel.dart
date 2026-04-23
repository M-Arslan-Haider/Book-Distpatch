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
/// POLYLINE FIXES applied in this version:
///   1. Timer interval: 1s → 10s  (reduces noisy overlapping points)
///   2. Accuracy filter: skip GPS readings worse than 50m accuracy
///   3. Minimum distance filter: skip if moved < 10m from last point
///   4. Batch flush limit: 30 → 5 (more frequent upload with 10s timer)
///   5. All offline SQLite logic preserved unchanged
///   6. Comprehensive debug logs for every decision
class LocationBulkTracker {
  LocationBulkTracker._();
  static final LocationBulkTracker instance = LocationBulkTracker._();

  static const String _endpoint = 'http://103.149.33.102:8001/location/bulk';

  // ✅ FIX #1: Timer interval increased from 1s → 10s to reduce polyline noise
  static const Duration _captureInterval = Duration(seconds: 10);

  // ✅ FIX #2: GPS accuracy threshold — skip readings worse than this
  static const double _maxAccuracyMeters = 50.0;

  // ✅ FIX #3: Minimum movement required between consecutive points
  static const double _minDistanceMeters = 10.0;

  Timer? _timer;
  bool _isRunning      = false;
  bool _tickInProgress = false;
  bool _wasClockedIn   = false;
  bool _flushInProgress = false;

  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];

  // ✅ FIX #3: Track last accepted GPS position to filter stationary noise
  double _lastAcceptedLat = 0.0;
  double _lastAcceptedLng = 0.0;

  int    _locationSerialCounter       = 1;
  String _lastGeneratedLocationDay    = '';

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('ℹ️ [BULK] Tracker already running');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _locationSerialCounter    = prefs.getInt('bulk_location_serial_counter') ?? 1;
    _lastGeneratedLocationDay = prefs.getString('bulk_last_generated_day') ?? '';

    // Reset last accepted position on start so first point is always accepted
    _lastAcceptedLat = 0.0;
    _lastAcceptedLng = 0.0;

    _isRunning = true;

    debugPrint('✅ [BULK] Tracker started | '
        'interval=${_captureInterval.inSeconds}s | '
        'maxAccuracy=${_maxAccuracyMeters}m | '
        'minDistance=${_minDistanceMeters}m');

    // ✅ FIX #1: Timer now fires every 10 seconds (was 1 second)
    _timer = Timer.periodic(_captureInterval, (_) {
      unawaited(_tick());
    });
  }

  Future<void> stopAndFlush() async {
    debugPrint('🛑 [BULK] Stop requested — flushing remaining buffer');
    _timer?.cancel();
    _timer     = null;
    _isRunning = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bulk_location_serial_counter', _locationSerialCounter);

    await _flushBuffer(reason: 'manual-stop');
  }

  Future<void> _tick() async {
    if (_tickInProgress) return;
    _tickInProgress = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClockedIn        = _readClockInState(prefs);

      if (!isClockedIn) {
        if (_wasClockedIn && _buffer.isNotEmpty) {
          debugPrint('⏹️ [BULK] Clock-out detected, flushing remaining buffer');
          await _flushBuffer(reason: 'clockout-detected');
        }
        _wasClockedIn = false;
        return;
      }

      _wasClockedIn = true;

      // ── Get current GPS position ──────────────────────────────────────────
      Position position;
      try {
        position = await _getCurrentPosition();
      } catch (e) {
        debugPrint('❌ [BULK] GPS error: $e — skipping tick');
        return;
      }

      // ✅ FIX: Validate lat/lng — never allow 0.0 or empty
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        debugPrint('⚠️ [BULK] SKIP — lat/lng are 0.0, invalid GPS fix');
        return;
      }

      // ✅ FIX #2: Accuracy filter — skip noisy GPS readings
      if (position.accuracy > _maxAccuracyMeters) {
        debugPrint('⚠️ [BULK] SKIP — poor GPS accuracy: '
            '${position.accuracy.toStringAsFixed(1)}m '
            '(threshold: ${_maxAccuracyMeters}m)');
        return;
      }

      // ✅ FIX #3: Minimum distance filter — skip stationary/near-stationary
      if (_lastAcceptedLat != 0.0 && _lastAcceptedLng != 0.0) {
        final double movedMeters = Geolocator.distanceBetween(
          _lastAcceptedLat,
          _lastAcceptedLng,
          position.latitude,
          position.longitude,
        );
        if (movedMeters < _minDistanceMeters) {
          debugPrint('⏭️ [BULK] SKIP — moved only ${movedMeters.toStringAsFixed(1)}m '
              '(min: ${_minDistanceMeters}m) — no new point added');
          return;
        }
        debugPrint('📏 [BULK] Moved ${movedMeters.toStringAsFixed(1)}m from last point — recording');
      }

      // Accept this position
      _lastAcceptedLat = position.latitude;
      _lastAcceptedLng = position.longitude;

      // ── Build record ────────────────────────────────────────────────────
      final Map<String, dynamic>? record = await _buildRecord(prefs, position);
      if (record == null) return;

      _buffer.add(record);

      debugPrint('✅ [BULK] Buffered #${_buffer.length} | '
          'user_id=${record['user_id']} '
          'lat=${record['lat_in']} '
          'lng=${record['lng_in']} '
          'acc=${position.accuracy.toStringAsFixed(1)}m '
          'designation=${record['designation']} '
          'date=${record['locationtracking_date']} '
          'time=${record['locationtracking_time']}');

      // ✅ FIX #4: Batch flush limit reduced to 5 (was 30)
      // With 10s interval, 5 records = ~50 seconds between flushes
      if (_buffer.length >= 5) {
        await _flushBuffer(reason: 'batch-limit-5');
      }
    } catch (e) {
      debugPrint('❌ [BULK] Tick error: $e');
    } finally {
      _tickInProgress = false;
    }
  }

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

    if (userId == null || userId.isEmpty ||
        bookerName == null || bookerName.isEmpty ||
        companyCode == null || companyCode.isEmpty) {
      debugPrint('⚠️ [BULK] SKIP — missing mandatory field(s). '
          'user_id=$userId booker_name=$bookerName company_code=$companyCode');
      return null;
    }

    final DateTime now  = DateTime.now();
    final String date   = DateFormat('yyyy-MM-dd').format(now);
    final String time   = DateFormat('HH:mm:ss').format(now);
    final String trackId = await _createLocationTrackingId(userId, now);

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

  Future<String> _createLocationTrackingId(String userId, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final String month  = DateFormat('MMM').format(now);
    final String day    = DateFormat('dd').format(now);
    final String today  = DateFormat('yyyy-MM-dd').format(now);

    if (_lastGeneratedLocationDay != today) {
      _locationSerialCounter    = 1;
      _lastGeneratedLocationDay = today;
      await prefs.setString('bulk_last_generated_day', today);
      debugPrint('🔄 [BULK] New day — serial counter reset to 1');
    }

    final String id = 'LT-$userId-$day-$month-'
        '${_locationSerialCounter.toString().padLeft(3, '0')}';

    _locationSerialCounter++;
    await prefs.setInt('bulk_location_serial_counter', _locationSerialCounter);

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

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _flushBuffer({required String reason}) async {
    if (_flushInProgress) return;
    if (_buffer.isEmpty) {
      // Even if buffer is empty, check SQLite for any unsynced offline records
      final DBHelper dbHelper = DBHelper();
      final int pendingCount  = await dbHelper.getUnpostedLocationTrackingCount();
      if (pendingCount > 0) {
        debugPrint('📊 [BULK] Buffer empty but $pendingCount offline records pending in DB');
      }
      return;
    }

    _flushInProgress = true;

    try {
      final List<Map<String, dynamic>> payload =
      List<Map<String, dynamic>>.from(_buffer);
      final DBHelper dbHelper = DBHelper();

      debugPrint('📤 [BULK] Flushing ${payload.length} record(s) | reason=$reason');

      // Normalize records to ensure no null lat/lng
      final List<Map<String, dynamic>> records = payload.map((record) {
        double latDouble = 0.0;
        double lngDouble = 0.0;

        if (record['lat_in'] is double) {
          latDouble = record['lat_in'] as double;
        } else if (record['lat_in'] is num) {
          latDouble = (record['lat_in'] as num).toDouble();
        } else if (record['lat_in'] is String) {
          latDouble = double.tryParse(record['lat_in'] as String) ?? 0.0;
        }

        if (record['lng_in'] is double) {
          lngDouble = record['lng_in'] as double;
        } else if (record['lng_in'] is num) {
          lngDouble = (record['lng_in'] as num).toDouble();
        } else if (record['lng_in'] is String) {
          lngDouble = double.tryParse(record['lng_in'] as String) ?? 0.0;
        }

        // ✅ FIX: Final guard — skip records with invalid coordinates
        if (latDouble == 0.0 && lngDouble == 0.0) {
          debugPrint('⚠️ [BULK] Skipping record with zero lat/lng: ${record['locationtracking_id']}');
        }

        return {
          'locationtracking_id':   record['locationtracking_id']?.toString() ?? '',
          'locationtracking_date': record['locationtracking_date']?.toString() ?? '',
          'locationtracking_time': record['locationtracking_time']?.toString() ?? '',
          'user_id':               record['user_id']?.toString() ?? '',
          'company_code':          record['company_code']?.toString() ?? '',
          'lat_in':                latDouble,
          'lng_in':                lngDouble,
          'booker_name':           record['booker_name']?.toString() ?? '',
          'designation':           record['designation']?.toString() ?? 'GPS',
          'posted':                0,
        };
      })
      // ✅ FIX: Filter out any records that still have zero coordinates
          .where((r) => (r['lat_in'] as double) != 0.0 || (r['lng_in'] as double) != 0.0)
          .toList();

      if (records.isEmpty) {
        _buffer.clear();
        debugPrint('⚠️ [BULK] All records filtered out (zero coords) — buffer cleared');
        return;
      }

      final bool hasConnection = await _hasInternetConnection();

      if (hasConnection) {
        debugPrint('🌐 [BULK] Online — attempting API sync');

        // Fetch previously unsynced records from DB
        final List<Map<String, dynamic>> unpostedFromDb =
        await dbHelper.getUnpostedLocationTracking(limit: 500);

        final List<Map<String, dynamic>> allRecords = [
          ...unpostedFromDb,
          ...records,
        ];

        debugPrint('📊 [BULK] Total to sync: ${allRecords.length} '
            '(DB offline: ${unpostedFromDb.length}, new: ${records.length})');

        final requestBody = {
          'records': allRecords.map((r) => {
            'locationtracking_id':   r['locationtracking_id'],
            'locationtracking_date': r['locationtracking_date'],
            'locationtracking_time': r['locationtracking_time'],
            'user_id':               r['user_id'],
            'company_code':          r['company_code'],
            'lat_in':                r['lat_in'],
            'lng_in':                r['lng_in'],
            'booker_name':           r['booker_name'],
            'designation':           r['designation'] ?? 'GPS',
            'posted':                true,
          }).toList(),
        };

        debugPrint('📡 [BULK] REQUEST → POST $_endpoint | '
            'records=${allRecords.length} | '
            'first_record: user=${allRecords.first['user_id']} '
            'lat=${allRecords.first['lat_in']} lng=${allRecords.first['lng_in']}');

        try {
          final http.Response response = await http.post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader:      'application/json',
            },
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 30));

          debugPrint('📥 [BULK] RESPONSE status=${response.statusCode} | '
              'body_preview=${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

          if (response.statusCode >= 200 && response.statusCode < 300) {
            // ✅ Success
            _buffer.clear();

            final List<int> idsToMark = allRecords
                .where((r) => r['id'] != null)
                .map((r) => r['id'] as int)
                .toList();

            if (idsToMark.isNotEmpty) {
              await dbHelper.markLocationTrackingAsPosted(idsToMark);
              debugPrint('🗑️ [BULK] Marked ${idsToMark.length} DB records as posted');
            }

            debugPrint('✅ [BULK] Successfully synced ${allRecords.length} records to server');
          } else {
            // API failed — save new records to SQLite
            debugPrint('⚠️ [BULK] API returned ${response.statusCode} — '
                'saving ${records.length} new records to local DB');
            await dbHelper.insertLocationTrackingBulk(records);
            _buffer.clear();
            debugPrint('💾 [BULK] Saved ${records.length} records locally (API error)');
          }
        } catch (e) {
          debugPrint('❌ [BULK] API network error: $e — saving to local DB');
          await dbHelper.insertLocationTrackingBulk(records);
          _buffer.clear();
          debugPrint('💾 [BULK] Saved ${records.length} records locally (network error)');
        }
      } else {
        // ✅ OFFLINE MODE — save every record to SQLite, zero data loss
        debugPrint('📴 [BULK] Offline — saving ${records.length} records to local DB');
        final int inserted = await dbHelper.insertLocationTrackingBulk(records);
        _buffer.clear();

        final int totalPending =
        await dbHelper.getUnpostedLocationTrackingCount();
        debugPrint('💾 [BULK] Inserted $inserted records | '
            'Total pending in DB: $totalPending');
      }
    } catch (e) {
      debugPrint('❌ [BULK] Flush error: $e');
    } finally {
      _flushInProgress = false;
    }
  }

  /// Sync pending offline records from DB to server.
  /// Called from TimerCard._triggerAutoSync() when internet comes back.
  Future<int> syncPendingRecords() async {
    final DBHelper dbHelper = DBHelper();

    final bool hasConnection = await _hasInternetConnection();
    if (!hasConnection) {
      debugPrint('📴 [BULK] syncPendingRecords — offline, skipping');
      return 0;
    }

    final List<Map<String, dynamic>> unposted =
    await dbHelper.getUnpostedLocationTracking(limit: 500);

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [BULK] syncPendingRecords — no pending records');
      return 0;
    }

    debugPrint('🔄 [BULK] Syncing ${unposted.length} pending offline records');

    final requestBody = {
      'records': unposted.map((r) => {
        'locationtracking_id':   r['locationtracking_id'],
        'locationtracking_date': r['locationtracking_date'],
        'locationtracking_time': r['locationtracking_time'],
        'user_id':               r['user_id'],
        'company_code':          r['company_code'],
        'lat_in':                r['lat_in'],
        'lng_in':                r['lng_in'],
        'booker_name':           r['booker_name'],
        'designation':           r['designation'] ?? 'GPS',
        'posted':                true,
      }).toList(),
    };

    debugPrint('📡 [BULK SYNC] REQUEST → POST $_endpoint | records=${unposted.length}');

    try {
      final http.Response response = await http.post(
        Uri.parse(_endpoint),
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader:      'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📥 [BULK SYNC] RESPONSE status=${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<int> ids =
        unposted.map((r) => r['id'] as int).toList();
        await dbHelper.markLocationTrackingAsPosted(ids);

        debugPrint('✅ [BULK SYNC] Synced ${unposted.length} pending records to server');
        return unposted.length;
      } else {
        debugPrint('⚠️ [BULK SYNC] API returned ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      debugPrint('❌ [BULK SYNC] Error: $e');
      return 0;
    }
  }
}