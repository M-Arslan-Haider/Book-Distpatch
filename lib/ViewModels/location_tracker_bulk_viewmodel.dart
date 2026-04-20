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
/// Intended usage with the existing TimerCard file:
/// 1) add: `import 'location_bulk_tracker.dart';`
/// 2) in initState(): `LocationBulkTracker.instance.start();`
/// 3) in dispose(): `LocationBulkTracker.instance.stopAndFlush();`
///
/// It does NOT change your current UI, architecture, or existing clock-in/
/// clock-out logic. It only watches the same session flags and buffers GPS
/// points while the user is clocked in.
class LocationBulkTracker {
  LocationBulkTracker._();
  static final LocationBulkTracker instance = LocationBulkTracker._();

  static const String _endpoint = 'http://103.149.33.102:8001/location/bulk';

  Timer? _timer;
  bool _isRunning = false;
  bool _tickInProgress = false;
  bool _wasClockedIn = false;
  bool _flushInProgress = false;


  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];

  // Serial counter for location tracking ID (matches LocationTrackingService)
  int _locationSerialCounter = 1;
  String _lastGeneratedLocationDay = '';

  Future<void> start() async {
    if (_isRunning) {
      debugPrint('ℹ️ [BULK] Tracker already running');
      return;
    }

    // Load serial counter from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _locationSerialCounter = prefs.getInt('bulk_location_serial_counter') ?? 1;
    _lastGeneratedLocationDay = prefs.getString('bulk_last_generated_day') ?? '';

    _isRunning = true;
    debugPrint('✅ [BULK] Tracker started');

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick());
    });
  }

  Future<void> stopAndFlush() async {
    debugPrint('🛑 [BULK] Stop requested');
    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    // Save serial counter before stopping
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bulk_location_serial_counter', _locationSerialCounter);

    await _flushBuffer(reason: 'manual-stop');
  }

  Future<void> _tick() async {
    if (_tickInProgress) return;
    _tickInProgress = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClockedIn = _readClockInState(prefs);

      if (!isClockedIn) {
        if (_wasClockedIn && _buffer.isNotEmpty) {
          debugPrint('⏹️ [BULK] Clock-out detected, flushing remaining buffer');
          await _flushBuffer(reason: 'clockout-detected');
        }
        _wasClockedIn = false;
        return;
      }

      _wasClockedIn = true;

      final Position position = await _getCurrentPosition();
      final Map<String, dynamic>? record = await _buildRecord(prefs, position);
      if (record == null) return;

      _buffer.add(record);

      debugPrint(
        '📍 [BULK] buffered=${_buffer.length} '
            'user_id=${record['user_id']} '
            'lat_in=${record['lat_in']} lng_in=${record['lng_in']} '
            'designation=${record['designation']} '
            'date=${record['locationtracking_date']} '
            'time=${record['locationtracking_time']}',
      );

      // Optional safety flush to avoid very large local memory use.
      if (_buffer.length >= 30) {
        await _flushBuffer(reason: 'batch-limit-30');
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

    // ✅ FIX: Get designation with 'GPS' as fallback (NOT mandatory)
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

    // If empty, use 'GPS' as static value
    if (designation.isEmpty) {
      designation = 'GPS';
    }

    final String? companyCode = _readRequiredString(prefs, <String>[
      'company_code',
      'companyCode',
      'cached_company_code',
    ]);

    // ✅ REMOVED designation from mandatory check
    if (userId == null || userId.isEmpty ||
        bookerName == null || bookerName.isEmpty ||
        companyCode == null || companyCode.isEmpty) {
      debugPrint(
        '⚠️ [BULK] Missing mandatory session field(s). '
            'user_id=$userId, booker_name=$bookerName, '
            'company_code=$companyCode',
      );
      return null;
    }

    final DateTime now = DateTime.now();
    final String date = DateFormat('yyyy-MM-dd').format(now);
    final String time = DateFormat('HH:mm:ss').format(now);

    final String locationTrackingId = await _createLocationTrackingId(userId, now);

    return <String, dynamic>{
      'locationtracking_id': locationTrackingId,
      'locationtracking_date': date,
      'locationtracking_time': time,
      'user_id': userId,
      'lat_in': position.latitude,
      'lng_in': position.longitude,
      'booker_name': bookerName,
      'designation': designation,  // ✅ Will always have a value (never null)
      'company_code': companyCode,
      'posted': 0,
    };
  }
  // Generate ID matching LocationTrackingService format: LT-{userId}-{day}-{month}-{serial}
  Future<String> _createLocationTrackingId(String userId, DateTime now) async {
    final prefs = await SharedPreferences.getInstance();

    final String month = DateFormat('MMM').format(now);
    final String day = DateFormat('dd').format(now);
    final String today = DateFormat('yyyy-MM-dd').format(now);

    // Reset counter if it's a new day
    if (_lastGeneratedLocationDay != today) {
      _locationSerialCounter = 1;
      _lastGeneratedLocationDay = today;
      await prefs.setString('bulk_last_generated_day', today);
      debugPrint("🔄 [BULK] New day - Counter reset to: $_locationSerialCounter");
    }

    final String locationId = "LT-$userId-$day-$month-${_locationSerialCounter.toString().padLeft(3, '0')}";

    debugPrint("🆔 [BULK] ID Generated: $locationId (Serial: $_locationSerialCounter)");

    // Increment counter for next use
    _locationSerialCounter++;
    await prefs.setInt('bulk_location_serial_counter', _locationSerialCounter);

    return locationId;
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
      debugPrint('ℹ️ [BULK] Flush skipped — buffer empty ($reason)');
      return;
    }

    _flushInProgress = true;

    try {
      final List<Map<String, dynamic>> payload = List<Map<String, dynamic>>.from(_buffer);
      final DBHelper dbHelper = DBHelper();

      debugPrint('📤 [BULK] Processing ${payload.length} record(s) | reason=$reason');

      // Format records for storage
      final List<Map<String, dynamic>> records = payload.map((record) {
        double latDouble = 0.0;
        double lngDouble = 0.0;

        if (record['lat_in'] is double) {
          latDouble = record['lat_in'] as double;
        } else if (record['lat_in'] is String) {
          latDouble = double.tryParse(record['lat_in'] as String) ?? 0.0;
        } else if (record['lat_in'] is num) {
          latDouble = (record['lat_in'] as num).toDouble();
        }

        if (record['lng_in'] is double) {
          lngDouble = record['lng_in'] as double;
        } else if (record['lng_in'] is String) {
          lngDouble = double.tryParse(record['lng_in'] as String) ?? 0.0;
        } else if (record['lng_in'] is num) {
          lngDouble = (record['lng_in'] as num).toDouble();
        }

        return {
          'locationtracking_id': record['locationtracking_id']?.toString() ?? '',
          'locationtracking_date': record['locationtracking_date']?.toString() ?? '',
          'locationtracking_time': record['locationtracking_time']?.toString() ?? '',
          'user_id': record['user_id']?.toString() ?? '',
          'company_code': record['company_code']?.toString() ?? '',
          'lat_in': latDouble,
          'lng_in': lngDouble,
          'booker_name': record['booker_name']?.toString() ?? '',
          'designation': record['designation']?.toString() ?? 'GPS',
          'posted': 0,
        };
      }).toList();

      // Check connectivity
      final hasConnection = await _hasInternetConnection();

      if (hasConnection) {
        debugPrint('🌐 [BULK] Online — attempting API sync');

        // First, get any unposted records from DB and add to current payload
        final List<Map<String, dynamic>> unpostedFromDb = await dbHelper.getUnpostedLocationTracking(limit: 500);
        final List<Map<String, dynamic>> allRecords = [...unpostedFromDb, ...records];

        debugPrint('📊 [BULK] Total records to sync: ${allRecords.length} (DB: ${unpostedFromDb.length}, Buffer: ${records.length})');

        // Try to send all records to API
        final requestBody = {'records': allRecords.map((r) {
          return {
            'locationtracking_id': r['locationtracking_id'],
            'locationtracking_date': r['locationtracking_date'],
            'locationtracking_time': r['locationtracking_time'],
            'user_id': r['user_id'],
            'company_code': r['company_code'],
            'lat_in': r['lat_in'],
            'lng_in': r['lng_in'],
            'booker_name': r['booker_name'],
            'designation': r['designation'] ?? 'GPS',
            'posted': true,
          };
        }).toList()};

        try {
          final http.Response response = await http.post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.acceptHeader: 'application/json',
            },
            body: jsonEncode(requestBody),
          ).timeout(const Duration(seconds: 30));

          debugPrint('📥 [BULK] API Response status: ${response.statusCode}');

          if (response.statusCode >= 200 && response.statusCode < 300) {
            // Success — clear buffer and mark DB records as posted
            _buffer.clear();

            // Mark all synced records as posted in DB
            final List<int> idsToMark = allRecords
                .where((r) => r['id'] != null)
                .map((r) => r['id'] as int)
                .toList();

            if (idsToMark.isNotEmpty) {
              await dbHelper.markLocationTrackingAsPosted(idsToMark);
            }

            debugPrint('✅ [BULK] Synced ${allRecords.length} records successfully');
            debugPrint('🎉 [BULK] ✅ Successfully synced ${allRecords.length} location records to server');
          } else {
            // API failed — save to local DB
            debugPrint('⚠️ [BULK] API failed (${response.statusCode}) — saving to local DB');
            await dbHelper.insertLocationTrackingBulk(records);
            _buffer.clear();
            debugPrint('💾 [BULK] 📴 Saved ${records.length} records locally (API failed)');
          }
        } catch (e) {
          // Network error — save to local DB
          debugPrint('❌ [BULK] API error: $e — saving to local DB');
          await dbHelper.insertLocationTrackingBulk(records);
          _buffer.clear();
          debugPrint('💾 [BULK] 📴 Saved ${records.length} records locally (network error)');
        }
      } else {
        // Offline — save to local DB
        debugPrint('📴 [BULK] Offline — saving ${records.length} records to local DB');
        await dbHelper.insertLocationTrackingBulk(records);
        _buffer.clear();

        final int pendingCount = await dbHelper.getUnpostedLocationTrackingCount();
        debugPrint('📊 [BULK] Total pending records in DB: $pendingCount');
        debugPrint('💾 [BULK] 📴 Saved ${records.length} location records locally (offline)');
      }
    } catch (e) {
      debugPrint('❌ [BULK] Flush error: $e');
    } finally {
      _flushInProgress = false;
    }
  }

  /// Sync pending location tracking records from DB to server
  /// Returns number of records synced
  Future<int> syncPendingRecords() async {
    final DBHelper dbHelper = DBHelper();

    final bool hasConnection = await _hasInternetConnection();
    if (!hasConnection) {
      debugPrint('📴 [BULK] Cannot sync — offline');
      return 0;
    }

    final List<Map<String, dynamic>> unposted = await dbHelper.getUnpostedLocationTracking(limit: 500);
    if (unposted.isEmpty) {
      debugPrint('ℹ️ [BULK] No pending records to sync');
      return 0;
    }

    debugPrint('🔄 [BULK] Attempting to sync ${unposted.length} pending records');

    final requestBody = {'records': unposted.map((r) {
      return {
        'locationtracking_id': r['locationtracking_id'],
        'locationtracking_date': r['locationtracking_date'],
        'locationtracking_time': r['locationtracking_time'],
        'user_id': r['user_id'],
        'company_code': r['company_code'],
        'lat_in': r['lat_in'],
        'lng_in': r['lng_in'],
        'booker_name': r['booker_name'],
        'designation': r['designation'] ?? 'GPS',
        'posted': true,
      };
    }).toList()};

    try {
      final http.Response response = await http.post(
        Uri.parse(_endpoint),
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<int> ids = unposted.map((r) => r['id'] as int).toList();
        await dbHelper.markLocationTrackingAsPosted(ids);

        debugPrint('✅ [BULK] Synced ${unposted.length} pending records');
        debugPrint('🎉 [BULK] ✅ Successfully synced ${unposted.length} pending location records to server');
        return unposted.length;
      } else {
        debugPrint('⚠️ [BULK] Sync failed: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      debugPrint('❌ [BULK] Sync error: $e');
      return 0;
    }
  }
}