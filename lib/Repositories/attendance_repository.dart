//
// import 'dart:convert';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:sqflite/sqflite.dart' show Sqflite;
// import 'package:uuid/uuid.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/attendance_Model.dart';
//
// class AttendanceRepository {
//   final DBHelper _dbHelper = DBHelper();
//
//   static const String _postApiUrl =
//   // 'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
//       'http://oracle.metaxperts.net/ords/gps_workforce/attendanceinpost/post/';
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // Oracle UTL_RAW.CAST_TO_RAW limit = 32 767 bytes.
//   // Base64 inflates by ~33 %, so raw bytes must stay under 24 500 bytes
//   // to keep the base64 string safely under 32 767 chars.
//   // We target 22 000 raw bytes to leave a comfortable margin.
//   // ─────────────────────────────────────────────────────────────────────────
//   static const int _maxApiBytes    = 22000; // raw byte ceiling before base64
//   static const int _maxBase64Chars = 24000; // base64 string ceiling (≈ _maxApiBytes × 1.34)
//
//   // ─────────────────────────────────────────────
//   // READ – all records
//   // ─────────────────────────────────────────────
//   Future<List<AttendanceModel>> getAll() async {
//     final rows = await _dbHelper.getAll(DBHelper.attendanceTable);
//     return rows.map((row) => AttendanceModel.fromMap(row)).toList();
//   }
//
//   // ─────────────────────────────────────────────
//   // READ – unposted records only
//   // ─────────────────────────────────────────────
//   Future<List<AttendanceModel>> getUnposted() async {
//     final rows = await _dbHelper.getUnposted(DBHelper.attendanceTable);
//     return rows.map((row) => AttendanceModel.fromMap(row)).toList();
//   }
//
//   // ─────────────────────────────────────────────
//   // INSERT
//   // ─────────────────────────────────────────────
//   Future<int> add(AttendanceModel model) async {
//     model.attendance_in_id ??= const Uuid().v4();
//     return await _dbHelper.insert(
//       DBHelper.attendanceTable,
//       model.toMap(),
//     );
//   }
//
//   // ─────────────────────────────────────────────
//   // MARK AS POSTED (local DB)
//   // ─────────────────────────────────────────────
//   Future<int> markAsPosted(String id) async {
//     return await _dbHelper.markAsPosted(
//       DBHelper.attendanceTable,
//       'attendance_in_id',
//       id,
//     );
//   }
//
//   // ─────────────────────────────────────────────
//   // DELETE
//   // ─────────────────────────────────────────────
//   Future<int> delete(String id) async {
//     return await _dbHelper.delete(
//       DBHelper.attendanceTable,
//       'attendance_in_id',
//       id,
//     );
//   }
//
//   // ─────────────────────────────────────────────
//   // CHECK IF ID EXISTS
//   // ─────────────────────────────────────────────
//   Future<bool> idExists(String id) async {
//     try {
//       final db = await _dbHelper.database;
//       final result = await db.rawQuery(
//         'SELECT COUNT(*) as cnt FROM ${DBHelper.attendanceTable} '
//             'WHERE attendance_in_id = ?',
//         [id],
//       );
//       final count = Sqflite.firstIntValue(result) ?? 0;
//       return count > 0;
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] idExists error: $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // CLEANUP – wipe oversized profile blobs
//   // ─────────────────────────────────────────────
//   Future<void> cleanupLargeProfiles() async {
//     try {
//       final db = await _dbHelper.database;
//
//       final posted = await db.rawUpdate(
//         "UPDATE ${DBHelper.attendanceTable} "
//             "SET profile = NULL "
//             "WHERE posted = 1 AND profile IS NOT NULL",
//       );
//
//       final unposted = await db.rawUpdate(
//         "UPDATE ${DBHelper.attendanceTable} "
//             "SET profile = NULL "
//             "WHERE posted = 0 AND profile IS NOT NULL "
//             "AND length(profile) > 50000",
//       );
//
//       debugPrint(
//         '🧹 [AttendanceRepo] cleanupLargeProfiles: '
//             'cleared $posted posted rows + $unposted unposted rows',
//       );
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] cleanupLargeProfiles error: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // COMPRESS FOR API
//   //
//   // Oracle's UTL_RAW.CAST_TO_RAW() hard limit is 32 767 bytes.
//   // Base64 encoding inflates size by ~33%, so we must keep raw bytes
//   // under ~24 500 to be safe. This method shrinks the image iteratively:
//   //
//   //   Step 1 – Try decreasing dimensions: 200→150→120→100→80→64 px
//   //   Step 2 – If still over limit at 64px, encode anyway (edge case)
//   //
//   // The full-res bytes passed in are NEVER stored in the DB — only this
//   // compressed version is sent to the Oracle API.
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<Uint8List?> _compressForApi(Uint8List original) async {
//     // If already small enough, use as-is
//     if (original.length <= _maxApiBytes) {
//       debugPrint('📸 [AttendanceRepo] Image already small (${original.length} B) — no compression needed');
//       return original;
//     }
//
//     // Candidate sizes to try, from largest to smallest
//     const List<int> sizes = [200, 150, 120, 100, 80, 64];
//
//     for (final size in sizes) {
//       try {
//         final ui.Codec codec = await ui.instantiateImageCodec(
//           original,
//           targetWidth: size,
//           targetHeight: size,
//         );
//         final ui.FrameInfo frame = await codec.getNextFrame();
//         final ByteData? byteData = await frame.image.toByteData(
//           format: ui.ImageByteFormat.png,
//         );
//         frame.image.dispose();
//         codec.dispose();
//
//         if (byteData == null) continue;
//
//         final Uint8List compressed = byteData.buffer.asUint8List();
//         final String b64 = base64Encode(compressed);
//
//         debugPrint(
//           '🗜️ [AttendanceRepo] Tried ${size}x$size → '
//               '${compressed.length} B raw / ${b64.length} chars base64',
//         );
//
//         if (b64.length <= _maxBase64Chars) {
//           debugPrint(
//             '✅ [AttendanceRepo] Compression OK at ${size}x$size — '
//                 'original: ${original.length} B → compressed: ${compressed.length} B '
//                 '→ base64: ${b64.length} chars (limit: $_maxBase64Chars)',
//           );
//           return compressed;
//         }
//       } catch (e) {
//         debugPrint('⚠️ [AttendanceRepo] Compression attempt ${size}x$size failed: $e');
//       }
//     }
//
//     // Last resort: return the 64×64 result even if slightly over — better
//     // than sending nothing. The DBA fix (chunked CLOB decode) will handle it.
//     debugPrint('⚠️ [AttendanceRepo] All sizes tried — sending smallest available (64x64)');
//     try {
//       final ui.Codec codec = await ui.instantiateImageCodec(
//         original,
//         targetWidth: 64,
//         targetHeight: 64,
//       );
//       final ui.FrameInfo frame = await codec.getNextFrame();
//       final ByteData? byteData = await frame.image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );
//       frame.image.dispose();
//       codec.dispose();
//       if (byteData != null) return byteData.buffer.asUint8List();
//     } catch (_) {}
//
//     return null;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // POST – Single JSON method
//   //
//   // Oracle ORDS bind variables (from handler source):
//   //   :attendance_in_id   → attendance_in_id
//   //   :attendance_in_date → attendance_in_date  (TO_DATE with 'MM/DD/YYYY')
//   //   :attendance_in_time → attendance_in_time
//   //   :emp_id             → emp_id
//   //   :emp_name           → emp_name
//   //   :job                → job
//   //   :lat_in             → lat_in
//   //   :lng_in             → lng_in
//   //   :city               → city
//   //   :address            → address
//   //   :profile            → profile (base64 CLOB → decoded to BLOB in PL/SQL)
//   //   :company_code       → company_code
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<bool> _postToApi(AttendanceModel model) async {
//     if (model.attendance_in_id == null ||
//         model.attendance_in_id.toString().isEmpty) {
//       model.attendance_in_id = const Uuid().v4();
//       debugPrint('⚠️ [AttendanceRepo] Generated new ID: ${model.attendance_in_id}');
//     }
//
//     try {
//       final String dateStr = _getDateString(model.attendance_in_date);
//       final String timeStr = _getTimeString(model.attendance_in_time);
//
//       debugPrint('🌐 [AttendanceRepo] POST → $_postApiUrl');
//       debugPrint('🆔 ID   : ${model.attendance_in_id}');
//       debugPrint('📅 Date : $dateStr');
//       debugPrint('🕐 Time : $timeStr');
//       debugPrint('👤 Emp  : ${model.emp_id} | ${model.emp_name}');
//       debugPrint('🏢 Co   : ${model.company_code}');
//
//       final Map<String, dynamic> payload = {
//         'attendance_in_id'  : model.attendance_in_id?.toString() ?? '',
//         'attendance_in_date': dateStr,
//         'attendance_in_time': timeStr,
//         'emp_id'            : model.emp_id?.toString() ?? '',
//         'emp_name'          : model.emp_name?.toString() ?? '',
//         'job'               : model.job?.toString() ?? '',
//         'lat_in'            : model.lat_in?.toString() ?? '',
//         'lng_in'            : model.lng_in?.toString() ?? '',
//         'city'              : model.city?.toString() ?? '',
//         'address'           : model.address?.toString() ?? '',
//         'location_name'     : model.location_name?.toString() ?? '', // geofenced: selected name; non-geofenced: empty
//         'company_code'      : model.company_code ?? '',
//       };
//
//       // ── Profile image ──────────────────────────────────────────────────────
//       // Oracle's UTL_RAW.CAST_TO_RAW() limit = 32 767 bytes.
//       // We compress iteratively until base64 length ≤ _maxBase64Chars (24 000).
//       // Bind variable is :profile (matches PL/SQL handler: v_clob CLOB := :profile)
//       // ──────────────────────────────────────────────────────────────────────
//       final Uint8List? rawProfileBytes = _getProfileBytes(model.profile);
//       if (rawProfileBytes != null && rawProfileBytes.isNotEmpty) {
//         final Uint8List? apiBytes = await _compressForApi(rawProfileBytes);
//         if (apiBytes != null && apiBytes.isNotEmpty) {
//           final String b64 = base64Encode(apiBytes);
//           payload['profile'] = b64;
//           debugPrint(
//             '📸 [AttendanceRepo] Profile → "profile": '
//                 '${rawProfileBytes.length} B original → '
//                 '${apiBytes.length} B compressed → '
//                 '${b64.length} chars base64',
//           );
//         } else {
//           debugPrint('📸 [AttendanceRepo] Compression returned null — sending without profile');
//         }
//       } else {
//         debugPrint('📸 [AttendanceRepo] No profile image');
//       }
//
//       debugPrint('📦 [AttendanceRepo] Payload keys: ${payload.keys.toList()}');
//
//       final response = await http.post(
//         Uri.parse(_postApiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept'      : 'application/json',
//         },
//         body: jsonEncode(payload),
//       );
//
//       debugPrint('📡 [AttendanceRepo] Response ${response.statusCode}: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [AttendanceRepo] Posted: ${model.attendance_in_id}');
//         return true;
//       }
//
//       // Duplicate key → already on server, treat as success
//       if (response.body.contains('ORA-00001') ||
//           response.body.contains('unique constraint')) {
//         debugPrint('⚠️ [AttendanceRepo] Already exists — marking posted');
//         return true;
//       }
//
//       debugPrint('❌ [AttendanceRepo] Failed: ${response.statusCode}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] Exception: $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // SYNC – push all unposted records to API
//   // ─────────────────────────────────────────────
//   Future<void> syncUnposted() async {
//     await syncUnpostedWithBytes({});
//   }
//
//   Future<void> syncUnpostedWithBytes(Map<String, Uint8List> bytesCache) async {
//     final unposted = await getUnposted();
//
//     if (unposted.isEmpty) {
//       debugPrint('ℹ️ [AttendanceRepo] No unposted records to sync.');
//       return;
//     }
//
//     debugPrint('🔄 [AttendanceRepo] Syncing ${unposted.length} unposted record(s)...');
//
//     for (final model in unposted) {
//       final String id = model.attendance_in_id?.toString() ?? '';
//
//       // Use full-res photo bytes if available (fresh clock-in).
//       // _compressForApi inside _postToApi will shrink it to fit Oracle's limit.
//       if (bytesCache.containsKey(id)) {
//         model.profile = base64Encode(bytesCache[id]!);
//         debugPrint('📸 [AttendanceRepo] Using full-res bytes for $id (${bytesCache[id]!.length} B)');
//       }
//
//       final success = await _postToApi(model);
//
//       if (success) {
//         await markAsPosted(id);
//         debugPrint('✅ [AttendanceRepo] Marked posted: $id');
//       } else {
//         debugPrint('⚠️ [AttendanceRepo] Skipped (will retry later): $id');
//       }
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // HELPER – Date → "MM/dd/yyyy" zero-padded
//   // Matches Oracle: TO_DATE(:attendance_in_date, 'MM/DD/YYYY')
//   // Examples: "04/03/2026", "12/31/2026"
//   // ─────────────────────────────────────────────
//   String _getDateString(dynamic value) {
//     final fmt = DateFormat('MM/dd/yyyy');
//     if (value == null) return '';
//     if (value is DateTime) return fmt.format(value);
//     if (value is String && value.isNotEmpty) {
//       try {
//         fmt.parse(value);
//         return value;
//       } catch (_) {}
//       try {
//         return fmt.format(DateFormat('dd-MMM-yyyy').parse(value));
//       } catch (_) {}
//       try {
//         return fmt.format(DateTime.parse(value));
//       } catch (_) {}
//       return value;
//     }
//     return '';
//   }
//
//   // ─────────────────────────────────────────────
//   // HELPER – Time → "HH:mm:ss"
//   // ─────────────────────────────────────────────
//   String _getTimeString(dynamic value) {
//     if (value == null) return '';
//     if (value is DateTime) {
//       return '${value.hour.toString().padLeft(2, '0')}:'
//           '${value.minute.toString().padLeft(2, '0')}:'
//           '${value.second.toString().padLeft(2, '0')}';
//     }
//     return value.toString();
//   }
//
//   // ─────────────────────────────────────────────
//   // HELPER – Profile: Uint8List or base64 String
//   // ─────────────────────────────────────────────
//   Uint8List? _getProfileBytes(dynamic profile) {
//     if (profile == null) return null;
//     if (profile is Uint8List) return profile;
//     if (profile is List<int>) return Uint8List.fromList(profile);
//     if (profile is String && profile.isNotEmpty) {
//       try {
//         return base64Decode(profile);
//       } catch (_) {
//         return null;
//       }
//     }
//     return null;
//   }
// }

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:uuid/uuid.dart';

import '../Database/db_helper.dart';
import '../Models/attendance_Model.dart';

class AttendanceRepository {
  final DBHelper _dbHelper = DBHelper();

  static const String _postApiUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/attendanceinpost/post/';

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH MAX SERIAL NUMBER FROM SERVER
  // API: GET /attendanceinserial/get/:emp_id?company_code=xxx
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> fetchMaxSerialFromServer({
    required String empId,
    required String companyCode,
  }) async {
    try {
      final uri = Uri.parse(
          'http://oracle.metaxperts.net/ords/gps_workforce'
              '/attendanceinserial/get/$empId'
      ).replace(queryParameters: {
        'company_code': companyCode,
      });

      debugPrint('📡 [AttendanceRepo] fetchMaxSerial → $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [AttendanceRepo] fetchMaxSerial status: ${response.statusCode}');
      debugPrint('📡 [AttendanceRepo] fetchMaxSerial body: ${response.body}');

      if (response.statusCode != 200) return 0;

      final decoded = jsonDecode(response.body);
      String? maxId;

      if (decoded is Map<String, dynamic>) {
        if (decoded['items'] is List && decoded['items'].isNotEmpty) {
          final items = decoded['items'] as List;
          if (items.isNotEmpty && items.first is Map) {
            final firstItem = items.first as Map<String, dynamic>;
            maxId = firstItem['max(attendance_in_id)']?.toString();
          }
        }
      }

      if (maxId == null || maxId.isEmpty || maxId == 'null') {
        debugPrint('ℹ️ [AttendanceRepo] fetchMaxSerial: no records yet → serial starts at 0');
        return 0;
      }

      final parts = maxId.split('-');
      if (parts.isNotEmpty) {
        final lastPart = parts.last.trim();
        final serial = int.tryParse(lastPart);
        if (serial != null) {
          debugPrint('✅ [AttendanceRepo] fetchMaxSerial → maxId=$maxId serial=$serial');
          return serial;
        }
      }

      debugPrint('⚠️ [AttendanceRepo] fetchMaxSerial: could not parse serial from "$maxId"');
      return 0;
    } catch (e) {
      debugPrint('⚠️ [AttendanceRepo] fetchMaxSerial error: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK IF EMPLOYEE HAS ANY ATTENDANCE RECORDS
  // Uses attendanceinserial API - if max ID is null, no records exist
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> employeeHasAttendance({
    required String empId,
    required String companyCode,
  }) async {
    try {
      final uri = Uri.parse(
          'http://oracle.metaxperts.net/ords/gps_workforce'
              '/attendanceinserial/get/$empId'
      ).replace(queryParameters: {
        'company_code': companyCode,
      });

      debugPrint('📡 [AttendanceRepo] employeeHasAttendance → $uri');

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (decoded['items'] is List && decoded['items'].isNotEmpty) {
          final items = decoded['items'] as List;
          if (items.isNotEmpty && items.first is Map) {
            final firstItem = items.first as Map<String, dynamic>;
            final maxId = firstItem['max(attendance_in_id)']?.toString();
            if (maxId != null && maxId.isNotEmpty && maxId != 'null') {
              debugPrint('✅ [AttendanceRepo] Employee has existing records: $maxId');
              return true;
            }
          }
        }
      }

      debugPrint('ℹ️ [AttendanceRepo] No existing records for employee');
      return false;
    } catch (e) {
      debugPrint('⚠️ [AttendanceRepo] employeeHasAttendance error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH LATEST ATTENDANCE RECORD FROM SERVER
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchLatestAttendance({
    required String empId,
    required String companyCode,
  }) async {
    try {
      final maxSerial = await fetchMaxSerialFromServer(
        empId: empId,
        companyCode: companyCode,
      );

      if (maxSerial == 0) return null;

      final now = DateTime.now();
      final day = DateFormat('dd').format(now);
      final month = DateFormat('MMM').format(now);
      final serial = maxSerial.toString().padLeft(3, '0');
      final latestId = '$companyCode-ATD-EMP-${empId.padLeft(2, '0')}-$day-$month-$serial';

      debugPrint('📡 [AttendanceRepo] Latest attendance ID: $latestId');

      return {
        'attendance_in_id': latestId,
        'attendance_in_date': DateFormat('MM/dd/yyyy').format(now),
        'attendance_in_time': '00:00:00',
      };
    } catch (e) {
      debugPrint('⚠️ [AttendanceRepo] fetchLatestAttendance error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Oracle UTL_RAW.CAST_TO_RAW limit = 32 767 bytes.
  // Base64 inflates by ~33 %, so raw bytes must stay under 24 500 bytes
  // ─────────────────────────────────────────────────────────────────────────
  static const int _maxApiBytes = 22000;
  static const int _maxBase64Chars = 24000;

  // ─────────────────────────────────────────────
  // READ – all records
  // ─────────────────────────────────────────────
  Future<List<AttendanceModel>> getAll() async {
    final rows = await _dbHelper.getAll(DBHelper.attendanceTable);
    return rows.map((row) => AttendanceModel.fromMap(row)).toList();
  }

  // ─────────────────────────────────────────────
  // READ – unposted records only
  // ─────────────────────────────────────────────
  Future<List<AttendanceModel>> getUnposted() async {
    final rows = await _dbHelper.getUnposted(DBHelper.attendanceTable);
    return rows.map((row) => AttendanceModel.fromMap(row)).toList();
  }

  // ─────────────────────────────────────────────
  // INSERT
  // ─────────────────────────────────────────────
  Future<int> add(AttendanceModel model) async {
    model.attendance_in_id ??= const Uuid().v4();
    return await _dbHelper.insert(
      DBHelper.attendanceTable,
      model.toMap(),
    );
  }

  // ─────────────────────────────────────────────
  // MARK AS POSTED (local DB)
  // ─────────────────────────────────────────────
  Future<int> markAsPosted(String id) async {
    return await _dbHelper.markAsPosted(
      DBHelper.attendanceTable,
      'attendance_in_id',
      id,
    );
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────
  Future<int> delete(String id) async {
    return await _dbHelper.delete(
      DBHelper.attendanceTable,
      'attendance_in_id',
      id,
    );
  }

  // ─────────────────────────────────────────────
  // CHECK IF ID EXISTS
  // ─────────────────────────────────────────────
  Future<bool> idExists(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.attendanceTable} '
            'WHERE attendance_in_id = ?',
        [id],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      return count > 0;
    } catch (e) {
      debugPrint('❌ [AttendanceRepo] idExists error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // CLEANUP – wipe oversized profile blobs
  // ─────────────────────────────────────────────
  Future<void> cleanupLargeProfiles() async {
    try {
      final db = await _dbHelper.database;

      final posted = await db.rawUpdate(
        "UPDATE ${DBHelper.attendanceTable} "
            "SET profile = NULL "
            "WHERE posted = 1 AND profile IS NOT NULL",
      );

      final unposted = await db.rawUpdate(
        "UPDATE ${DBHelper.attendanceTable} "
            "SET profile = NULL "
            "WHERE posted = 0 AND profile IS NOT NULL "
            "AND length(profile) > 50000",
      );

      debugPrint(
        '🧹 [AttendanceRepo] cleanupLargeProfiles: '
            'cleared $posted posted rows + $unposted unposted rows',
      );
    } catch (e) {
      debugPrint('❌ [AttendanceRepo] cleanupLargeProfiles error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPRESS FOR API
  // ─────────────────────────────────────────────────────────────────────────
  Future<Uint8List?> _compressForApi(Uint8List original) async {
    if (original.length <= _maxApiBytes) {
      debugPrint('📸 [AttendanceRepo] Image already small (${original.length} B) — no compression needed');
      return original;
    }

    const List<int> sizes = [200, 150, 120, 100, 80, 64];

    for (final size in sizes) {
      try {
        final ui.Codec codec = await ui.instantiateImageCodec(
          original,
          targetWidth: size,
          targetHeight: size,
        );
        final ui.FrameInfo frame = await codec.getNextFrame();
        final ByteData? byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        frame.image.dispose();
        codec.dispose();

        if (byteData == null) continue;

        final Uint8List compressed = byteData.buffer.asUint8List();
        final String b64 = base64Encode(compressed);

        debugPrint(
          '🗜️ [AttendanceRepo] Tried ${size}x$size → '
              '${compressed.length} B raw / ${b64.length} chars base64',
        );

        if (b64.length <= _maxBase64Chars) {
          debugPrint(
            '✅ [AttendanceRepo] Compression OK at ${size}x$size — '
                'original: ${original.length} B → compressed: ${compressed.length} B '
                '→ base64: ${b64.length} chars',
          );
          return compressed;
        }
      } catch (e) {
        debugPrint('⚠️ [AttendanceRepo] Compression attempt ${size}x$size failed: $e');
      }
    }

    debugPrint('⚠️ [AttendanceRepo] All sizes tried — sending smallest available (64x64)');
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        original,
        targetWidth: 64,
        targetHeight: 64,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      if (byteData != null) return byteData.buffer.asUint8List();
    } catch (_) {}

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST – Single JSON method
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> _postToApi(AttendanceModel model) async {
    if (model.attendance_in_id == null ||
        model.attendance_in_id.toString().isEmpty) {
      model.attendance_in_id = const Uuid().v4();
      debugPrint('⚠️ [AttendanceRepo] Generated new ID: ${model.attendance_in_id}');
    }

    try {
      final String dateStr = _getDateString(model.attendance_in_date);
      final String timeStr = _getTimeString(model.attendance_in_time);

      debugPrint('🌐 [AttendanceRepo] POST → $_postApiUrl');
      debugPrint('🆔 ID: ${model.attendance_in_id}');
      debugPrint('📅 Date: $dateStr');
      debugPrint('🕐 Time: $timeStr');
      debugPrint('👤 Emp: ${model.emp_id} | ${model.emp_name}');
      debugPrint('🏢 Co: ${model.company_code}');

      final Map<String, dynamic> payload = {
        'attendance_in_id': model.attendance_in_id?.toString() ?? '',
        'attendance_in_date': dateStr,
        'attendance_in_time': timeStr,
        'emp_id': model.emp_id?.toString() ?? '',
        'emp_name': model.emp_name?.toString() ?? '',
        'job': model.job?.toString() ?? '',
        'lat_in': model.lat_in?.toString() ?? '',
        'lng_in': model.lng_in?.toString() ?? '',
        'city': model.city?.toString() ?? '',
        'address': model.address?.toString() ?? '',
        'location_name': model.location_name?.toString() ?? '',
        'company_code': model.company_code ?? '',
      };

      final Uint8List? rawProfileBytes = _getProfileBytes(model.profile);
      if (rawProfileBytes != null && rawProfileBytes.isNotEmpty) {
        final Uint8List? apiBytes = await _compressForApi(rawProfileBytes);
        if (apiBytes != null && apiBytes.isNotEmpty) {
          final String b64 = base64Encode(apiBytes);
          payload['profile'] = b64;
          debugPrint(
            '📸 [AttendanceRepo] Profile: ${rawProfileBytes.length} B → '
                '${apiBytes.length} B compressed → ${b64.length} chars base64',
          );
        } else {
          debugPrint('📸 [AttendanceRepo] Compression returned null — sending without profile');
        }
      } else {
        debugPrint('📸 [AttendanceRepo] No profile image');
      }

      debugPrint('📦 [AttendanceRepo] Payload keys: ${payload.keys.toList()}');

      final response = await http.post(
        Uri.parse(_postApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📡 [AttendanceRepo] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [AttendanceRepo] Posted: ${model.attendance_in_id}');
        return true;
      }

      if (response.body.contains('ORA-00001') ||
          response.body.contains('unique constraint')) {
        debugPrint('⚠️ [AttendanceRepo] Already exists — marking posted');
        return true;
      }

      debugPrint('❌ [AttendanceRepo] Failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [AttendanceRepo] Exception: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // SYNC – push all unposted records to API
  // ─────────────────────────────────────────────
  Future<void> syncUnposted() async {
    await syncUnpostedWithBytes({});
  }

  Future<void> syncUnpostedWithBytes(Map<String, Uint8List> bytesCache) async {
    final unposted = await getUnposted();

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [AttendanceRepo] No unposted records to sync.');
      return;
    }

    debugPrint('🔄 [AttendanceRepo] Syncing ${unposted.length} unposted record(s)...');

    for (final model in unposted) {
      final String id = model.attendance_in_id?.toString() ?? '';

      if (bytesCache.containsKey(id)) {
        model.profile = base64Encode(bytesCache[id]!);
        debugPrint('📸 [AttendanceRepo] Using full-res bytes for $id (${bytesCache[id]!.length} B)');
      }

      final success = await _postToApi(model);

      if (success) {
        await markAsPosted(id);
        debugPrint('✅ [AttendanceRepo] Marked posted: $id');
      } else {
        debugPrint('⚠️ [AttendanceRepo] Skipped (will retry later): $id');
      }
    }
  }

  // ─────────────────────────────────────────────
  // HELPER – Date → "MM/dd/yyyy"
  // ─────────────────────────────────────────────
  String _getDateString(dynamic value) {
    final fmt = DateFormat('MM/dd/yyyy');
    if (value == null) return '';
    if (value is DateTime) return fmt.format(value);
    if (value is String && value.isNotEmpty) {
      try {
        fmt.parse(value);
        return value;
      } catch (_) {}
      try {
        return fmt.format(DateFormat('dd-MMM-yyyy').parse(value));
      } catch (_) {}
      try {
        return fmt.format(DateTime.parse(value));
      } catch (_) {}
      return value;
    }
    return '';
  }

  // ─────────────────────────────────────────────
  // HELPER – Time → "HH:mm:ss"
  // ─────────────────────────────────────────────
  String _getTimeString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}:'
          '${value.second.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }

  // ─────────────────────────────────────────────
  // HELPER – Profile: Uint8List or base64 String
  // ─────────────────────────────────────────────
  Uint8List? _getProfileBytes(dynamic profile) {
    if (profile == null) return null;
    if (profile is Uint8List) return profile;
    if (profile is List<int>) return Uint8List.fromList(profile);
    if (profile is String && profile.isNotEmpty) {
      try {
        return base64Decode(profile);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}