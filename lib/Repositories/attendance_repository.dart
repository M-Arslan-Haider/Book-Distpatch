// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:uuid/uuid.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/attendance_Model.dart';
//
// class AttendanceRepository {
//   final DBHelper _dbHelper = DBHelper();
//
//   static const String _postApiUrl =
//       'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
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
//     // Auto-generate a UUID if no ID is provided
//     model.attendance_in_id ??= const Uuid().v4();
//
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
//   // POST single record to API
//   // ─────────────────────────────────────────────
//   Future<bool> _postToApi(AttendanceModel model) async {
//     try {
//       final response = await http.post(
//         Uri.parse(_postApiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: jsonEncode(model.toMap()),
//       );
//
//       debugPrint(
//           '📡 [AttendanceRepo] POST ${model.attendance_in_id} → ${response.statusCode}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint(
//             '✅ [AttendanceRepo] Posted successfully: ${model.attendance_in_id}');
//         return true;
//       }
//
//       // ── NEW: treat duplicate-key errors as already-posted ──────────────
//       if (response.statusCode == 555 || response.statusCode == 409) {
//         final body = response.body;
//         if (body.contains('ORA-00001') || body.contains('unique constraint')) {
//           debugPrint(
//               '⚠️ [AttendanceRepo] Already exists on server (duplicate key) — marking as posted: ${model.attendance_in_id}');
//           return true; // treat as success so it gets marked posted locally
//         }
//       }
//       // ───────────────────────────────────────────────────────────────────
//
//       debugPrint(
//           '❌ [AttendanceRepo] Server error ${response.statusCode}: ${response.body}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] Network error: $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // SYNC – push all unposted records to API
//   // ─────────────────────────────────────────────
//   Future<void> syncUnposted() async {
//     final unposted = await getUnposted();
//
//     if (unposted.isEmpty) {
//       debugPrint('ℹ️ [AttendanceRepo] No unposted records to sync.');
//       return;
//     }
//
//     debugPrint(
//         '🔄 [AttendanceRepo] Syncing ${unposted.length} unposted record(s)...');
//
//     for (final model in unposted) {
//       final success = await _postToApi(model);
//
//       if (success) {
//         await markAsPosted(model.attendance_in_id.toString());
//         debugPrint(
//             '✅ [AttendanceRepo] Marked as posted: ${model.attendance_in_id}');
//       } else {
//         debugPrint(
//             '⚠️ [AttendanceRepo] Skipped (will retry later): ${model.attendance_in_id}');
//       }
//     }
//   }
// }
//
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'package:uuid/uuid.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/attendance_Model.dart';
//
// class AttendanceRepository {
//   final DBHelper _dbHelper = DBHelper();
//
//   static const String _postApiUrl =
//       'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
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
//   // POST – Method 1: Multipart (same as leave)
//   // ─────────────────────────────────────────────
//   Future<bool> _postMethod1(AttendanceModel model) async {
//     try {
//       debugPrint('🌐 [AttendanceRepo] Method 1: Multipart → $_postApiUrl');
//
//       var request = http.MultipartRequest('POST', Uri.parse(_postApiUrl));
//
//       // ── TEXT FIELDS (UPPER_CASE — Oracle standard) ──
//       request.fields['ATTENDANCE_IN_ID']   = model.attendance_in_id?.toString() ?? '';
//       request.fields['ATTENDANCE_IN_DATE'] = _getDateString(model.attendance_in_date);
//       request.fields['ATTENDANCE_IN_TIME'] = _getTimeString(model.attendance_in_time);
//       request.fields['EMP_ID']             = model.emp_id?.toString() ?? '';
//       request.fields['EMP_NAME']           = model.emp_name?.toString() ?? '';
//       request.fields['JOB']                = model.job?.toString() ?? '';
//       request.fields['LAT_IN']             = model.lat_in?.toString() ?? '';
//       request.fields['LNG_IN']             = model.lng_in?.toString() ?? '';
//       request.fields['CITY']               = model.city?.toString() ?? '';
//       request.fields['ADDRESS']            = model.address?.toString() ?? '';
//
//       // ── TEXT FIELDS (lower_case — fallback) ──
//       request.fields['attendance_in_id']   = model.attendance_in_id?.toString() ?? '';
//       request.fields['attendance_in_date'] = _getDateString(model.attendance_in_date);
//       request.fields['attendance_in_time'] = _getTimeString(model.attendance_in_time);
//       request.fields['emp_id']             = model.emp_id?.toString() ?? '';
//       request.fields['emp_name']           = model.emp_name?.toString() ?? '';
//       request.fields['job']                = model.job?.toString() ?? '';
//       request.fields['lat_in']             = model.lat_in?.toString() ?? '';
//       request.fields['lng_in']             = model.lng_in?.toString() ?? '';
//       request.fields['city']               = model.city?.toString() ?? '';
//       request.fields['address']            = model.address?.toString() ?? '';
//
//       // ── PROFILE IMAGE ──
//       final Uint8List? profileBytes = _getProfileBytes(model.profile);
//       if (profileBytes != null && profileBytes.isNotEmpty) {
//         final String filename =
//             'profile_${model.emp_id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'PROFILE',
//           profileBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'profile',
//           profileBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'file',
//           profileBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         debugPrint('📸 [AttendanceRepo] Profile image added: $filename (${profileBytes.length} bytes)');
//       } else {
//         debugPrint('📸 [AttendanceRepo] No profile image');
//       }
//
//       debugPrint('📡 [AttendanceRepo] Fields: ${request.fields.length}, Files: ${request.files.length}');
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       debugPrint('📡 [AttendanceRepo] Method1 → ${response.statusCode}: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [AttendanceRepo] Method 1 successful!');
//         return true;
//       }
//
//       // Duplicate key → treat as already posted
//       if (response.statusCode == 555 || response.statusCode == 409) {
//         if (response.body.contains('ORA-00001') ||
//             response.body.contains('unique constraint')) {
//           debugPrint('⚠️ [AttendanceRepo] Duplicate key — marking as posted');
//           return true;
//         }
//       }
//
//       debugPrint('❌ [AttendanceRepo] Method 1 failed: ${response.statusCode}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] Method 1 error: $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // POST – Method 2: JSON + base64 (backup)
//   // ─────────────────────────────────────────────
//   Future<bool> _postMethod2(AttendanceModel model) async {
//     try {
//       debugPrint('🌐 [AttendanceRepo] Method 2: JSON backup → $_postApiUrl');
//
//       final Map<String, dynamic> jsonData = {
//         // UPPER_CASE
//         'ATTENDANCE_IN_ID'  : model.attendance_in_id?.toString() ?? '',
//         'ATTENDANCE_IN_DATE': _getDateString(model.attendance_in_date),
//         'ATTENDANCE_IN_TIME': _getTimeString(model.attendance_in_time),
//         'EMP_ID'            : model.emp_id?.toString() ?? '',
//         'EMP_NAME'          : model.emp_name?.toString() ?? '',
//         'JOB'               : model.job?.toString() ?? '',
//         'LAT_IN'            : model.lat_in?.toString() ?? '',
//         'LNG_IN'            : model.lng_in?.toString() ?? '',
//         'CITY'              : model.city?.toString() ?? '',
//         'ADDRESS'           : model.address?.toString() ?? '',
//
//         // lower_case
//         'attendance_in_id'  : model.attendance_in_id?.toString() ?? '',
//         'attendance_in_date': _getDateString(model.attendance_in_date),
//         'attendance_in_time': _getTimeString(model.attendance_in_time),
//         'emp_id'            : model.emp_id?.toString() ?? '',
//         'emp_name'          : model.emp_name?.toString() ?? '',
//         'job'               : model.job?.toString() ?? '',
//         'lat_in'            : model.lat_in?.toString() ?? '',
//         'lng_in'            : model.lng_in?.toString() ?? '',
//         'city'              : model.city?.toString() ?? '',
//         'address'           : model.address?.toString() ?? '',
//       };
//
//       // Profile as base64 string
//       final Uint8List? profileBytes2 = _getProfileBytes(model.profile);
//       if (profileBytes2 != null && profileBytes2.isNotEmpty) {
//         final String b64 = base64Encode(profileBytes2);
//         jsonData['PROFILE'] = b64;
//         jsonData['profile'] = b64;
//         debugPrint('📸 [AttendanceRepo] Profile base64 added (${profileBytes2.length} bytes)');
//       }
//
//       final response = await http.post(
//         Uri.parse(_postApiUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept'      : 'application/json',
//         },
//         body: jsonEncode(jsonData),
//       );
//
//       debugPrint('📡 [AttendanceRepo] Method2 → ${response.statusCode}: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [AttendanceRepo] Method 2 successful!');
//         return true;
//       }
//
//       if (response.statusCode == 555 || response.statusCode == 409) {
//         if (response.body.contains('ORA-00001') ||
//             response.body.contains('unique constraint')) {
//           debugPrint('⚠️ [AttendanceRepo] Duplicate key — marking as posted');
//           return true;
//         }
//       }
//
//       debugPrint('❌ [AttendanceRepo] Method 2 failed: ${response.statusCode}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [AttendanceRepo] Method 2 error: $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // POST – Main entry: Method1 → Method2
//   // ─────────────────────────────────────────────
//   Future<bool> _postToApi(AttendanceModel model) async {
//     // Method 1: Multipart (same as leave — most reliable)
//     debugPrint('\n=== [AttendanceRepo] METHOD 1: MULTIPART ===');
//     final m1 = await _postMethod1(model);
//     if (m1) return true;
//
//     // Method 2: JSON + base64 backup
//     debugPrint('\n=== [AttendanceRepo] METHOD 2: JSON BACKUP ===');
//     final m2 = await _postMethod2(model);
//     if (m2) return true;
//
//     debugPrint('❌ [AttendanceRepo] All methods failed for: ${model.attendance_in_id}');
//     return false;
//   }
//
//   // ─────────────────────────────────────────────
//   // SYNC – push all unposted records to API
//   // ─────────────────────────────────────────────
//   Future<void> syncUnposted() async {
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
//       final success = await _postToApi(model);
//
//       if (success) {
//         await markAsPosted(model.attendance_in_id.toString());
//         debugPrint('✅ [AttendanceRepo] Marked as posted: ${model.attendance_in_id}');
//       } else {
//         debugPrint('⚠️ [AttendanceRepo] Skipped (will retry later): ${model.attendance_in_id}');
//       }
//     }
//   }
//
//   // ─────────────────────────────────────────────
//   // HELPERS – Date / Time formatting
//   // ─────────────────────────────────────────────
//   String _getDateString(dynamic value) {
//     if (value == null) return '';
//     if (value is DateTime) {
//       return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
//     }
//     return value.toString().split('T')[0].split(' ')[0];
//   }
//
//   String _getTimeString(dynamic value) {
//     if (value == null) return '';
//     if (value is DateTime) {
//       return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
//     }
//     return value.toString();
//   }
//
//   // ─────────────────────────────────────────────
//   // HELPER – profile can be Uint8List OR base64 String
//   // handles both old (String) and new (Uint8List) model
//   // ─────────────────────────────────────────────
//   Uint8List? _getProfileBytes(dynamic profile) {
//     if (profile == null) return null;
//     if (profile is Uint8List) return profile;
//     if (profile is List<int>) return Uint8List.fromList(profile);
//     if (profile is String && profile.isNotEmpty) {
//       try {
//         return base64Decode(profile); // base64 String → bytes
//       } catch (_) {
//         return null;
//       }
//     }
//     return null;
//   }
// }

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:uuid/uuid.dart';

import '../Database/db_helper.dart';
import '../Models/attendance_Model.dart';

class AttendanceRepository {
  final DBHelper _dbHelper = DBHelper();

  static const String _postApiUrl =
      'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';

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
  // CHECK IF ID EXISTS (safe – no profile column)
  // Uses a COUNT query so it never reads the blob.
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
  //
  // Existing rows recorded BEFORE the compression fix have profile blobs of
  // ~1.8 MB. Any SELECT * on such a row crashes Android's SQLite CursorWindow
  // (2 MB limit). This method NULLs out those blobs so queries work again.
  //
  // Safe to call repeatedly — already-NULL rows are unchanged.
  // Runs at app startup (called from AttendanceViewModel.onInit).
  // ─────────────────────────────────────────────
  Future<void> cleanupLargeProfiles() async {
    try {
      final db = await _dbHelper.database;

      // NULL out profile on posted rows (server already has the image)
      final posted = await db.rawUpdate(
        "UPDATE ${DBHelper.attendanceTable} "
            "SET profile = NULL "
            "WHERE posted = 1 AND profile IS NOT NULL",
      );

      // NULL out profile on unposted rows that are oversized (>50 KB base64).
      // These were recorded before compression was added.  The server will
      // receive NULL profile on re-sync — acceptable vs a permanently broken DB.
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

  // ─────────────────────────────────────────────
  // POST – Method 1: Multipart (same as leave)
  // ─────────────────────────────────────────────
  Future<bool> _postMethod1(AttendanceModel model) async {
    try {
      debugPrint('🌐 [AttendanceRepo] Method 1: Multipart → $_postApiUrl');

      var request = http.MultipartRequest('POST', Uri.parse(_postApiUrl));

      // ── TEXT FIELDS (UPPER_CASE — Oracle standard) ──
      request.fields['ATTENDANCE_IN_ID']   = model.attendance_in_id?.toString() ?? '';
      request.fields['ATTENDANCE_IN_DATE'] = _getDateString(model.attendance_in_date);
      request.fields['ATTENDANCE_IN_TIME'] = _getTimeString(model.attendance_in_time);
      request.fields['EMP_ID']             = model.emp_id?.toString() ?? '';
      request.fields['EMP_NAME']           = model.emp_name?.toString() ?? '';
      request.fields['JOB']                = model.job?.toString() ?? '';
      request.fields['LAT_IN']             = model.lat_in?.toString() ?? '';
      request.fields['LNG_IN']             = model.lng_in?.toString() ?? '';
      request.fields['CITY']               = model.city?.toString() ?? '';
      request.fields['ADDRESS']            = model.address?.toString() ?? '';

      // ── TEXT FIELDS (lower_case — fallback) ──
      request.fields['attendance_in_id']   = model.attendance_in_id?.toString() ?? '';
      request.fields['attendance_in_date'] = _getDateString(model.attendance_in_date);
      request.fields['attendance_in_time'] = _getTimeString(model.attendance_in_time);
      request.fields['emp_id']             = model.emp_id?.toString() ?? '';
      request.fields['emp_name']           = model.emp_name?.toString() ?? '';
      request.fields['job']                = model.job?.toString() ?? '';
      request.fields['lat_in']             = model.lat_in?.toString() ?? '';
      request.fields['lng_in']             = model.lng_in?.toString() ?? '';
      request.fields['city']               = model.city?.toString() ?? '';
      request.fields['address']            = model.address?.toString() ?? '';

      // ── PROFILE IMAGE ──
      final Uint8List? profileBytes = _getProfileBytes(model.profile);
      if (profileBytes != null && profileBytes.isNotEmpty) {
        final String filename =
            'profile_${model.emp_id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        request.files.add(http.MultipartFile.fromBytes(
          'PROFILE',
          profileBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        request.files.add(http.MultipartFile.fromBytes(
          'profile',
          profileBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        request.files.add(http.MultipartFile.fromBytes(
          'file',
          profileBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        debugPrint('📸 [AttendanceRepo] Profile image added: $filename (${profileBytes.length} bytes)');
      } else {
        debugPrint('📸 [AttendanceRepo] No profile image');
      }

      debugPrint('📡 [AttendanceRepo] Fields: ${request.fields.length}, Files: ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📡 [AttendanceRepo] Method1 → ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [AttendanceRepo] Method 1 successful!');
        return true;
      }

      // Duplicate key → treat as already posted
      if (response.statusCode == 555 || response.statusCode == 409) {
        if (response.body.contains('ORA-00001') ||
            response.body.contains('unique constraint')) {
          debugPrint('⚠️ [AttendanceRepo] Duplicate key — marking as posted');
          return true;
        }
      }

      debugPrint('❌ [AttendanceRepo] Method 1 failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [AttendanceRepo] Method 1 error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // POST – Method 2: JSON + base64 (backup)
  // ─────────────────────────────────────────────
  Future<bool> _postMethod2(AttendanceModel model) async {
    try {
      debugPrint('🌐 [AttendanceRepo] Method 2: JSON backup → $_postApiUrl');

      final Map<String, dynamic> jsonData = {
        // UPPER_CASE
        'ATTENDANCE_IN_ID'  : model.attendance_in_id?.toString() ?? '',
        'ATTENDANCE_IN_DATE': _getDateString(model.attendance_in_date),
        'ATTENDANCE_IN_TIME': _getTimeString(model.attendance_in_time),
        'EMP_ID'            : model.emp_id?.toString() ?? '',
        'EMP_NAME'          : model.emp_name?.toString() ?? '',
        'JOB'               : model.job?.toString() ?? '',
        'LAT_IN'            : model.lat_in?.toString() ?? '',
        'LNG_IN'            : model.lng_in?.toString() ?? '',
        'CITY'              : model.city?.toString() ?? '',
        'ADDRESS'           : model.address?.toString() ?? '',

        // lower_case
        'attendance_in_id'  : model.attendance_in_id?.toString() ?? '',
        'attendance_in_date': _getDateString(model.attendance_in_date),
        'attendance_in_time': _getTimeString(model.attendance_in_time),
        'emp_id'            : model.emp_id?.toString() ?? '',
        'emp_name'          : model.emp_name?.toString() ?? '',
        'job'               : model.job?.toString() ?? '',
        'lat_in'            : model.lat_in?.toString() ?? '',
        'lng_in'            : model.lng_in?.toString() ?? '',
        'city'              : model.city?.toString() ?? '',
        'address'           : model.address?.toString() ?? '',
      };

      // Profile as base64 string
      final Uint8List? profileBytes2 = _getProfileBytes(model.profile);
      if (profileBytes2 != null && profileBytes2.isNotEmpty) {
        final String b64 = base64Encode(profileBytes2);
        jsonData['PROFILE'] = b64;
        jsonData['profile'] = b64;
        debugPrint('📸 [AttendanceRepo] Profile base64 added (${profileBytes2.length} bytes)');
      }

      final response = await http.post(
        Uri.parse(_postApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode(jsonData),
      );

      debugPrint('📡 [AttendanceRepo] Method2 → ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [AttendanceRepo] Method 2 successful!');
        return true;
      }

      if (response.statusCode == 555 || response.statusCode == 409) {
        if (response.body.contains('ORA-00001') ||
            response.body.contains('unique constraint')) {
          debugPrint('⚠️ [AttendanceRepo] Duplicate key — marking as posted');
          return true;
        }
      }

      debugPrint('❌ [AttendanceRepo] Method 2 failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [AttendanceRepo] Method 2 error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // POST – Main entry: Method1 → Method2
  // ─────────────────────────────────────────────
  Future<bool> _postToApi(AttendanceModel model) async {
    // Method 1: Multipart (same as leave — most reliable)
    debugPrint('\n=== [AttendanceRepo] METHOD 1: MULTIPART ===');
    final m1 = await _postMethod1(model);
    if (m1) return true;

    // Method 2: JSON + base64 backup
    debugPrint('\n=== [AttendanceRepo] METHOD 2: JSON BACKUP ===');
    final m2 = await _postMethod2(model);
    if (m2) return true;

    debugPrint('❌ [AttendanceRepo] All methods failed for: ${model.attendance_in_id}');
    return false;
  }

  // ─────────────────────────────────────────────
  // SYNC – push all unposted records to API
  // ─────────────────────────────────────────────
  Future<void> syncUnposted() async {
    await syncUnpostedWithBytes({});
  }

  // [bytesCache] maps attendanceId → original full-res Uint8List.
  // When present, the API receives the original photo even though SQLite
  // only stores a compressed thumbnail.
  Future<void> syncUnpostedWithBytes(Map<String, Uint8List> bytesCache) async {
    final unposted = await getUnposted();

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [AttendanceRepo] No unposted records to sync.');
      return;
    }

    debugPrint('🔄 [AttendanceRepo] Syncing ${unposted.length} unposted record(s)...');

    for (final model in unposted) {
      // Override thumbnail with full-res bytes if available (fresh clock-in)
      final String id = model.attendance_in_id?.toString() ?? '';
      if (bytesCache.containsKey(id)) {
        model.profile = base64Encode(bytesCache[id]!);
        debugPrint('📸 [AttendanceRepo] Using full-res bytes for $id (${bytesCache[id]!.length} B)');
      }

      final success = await _postToApi(model);

      if (success) {
        await markAsPosted(model.attendance_in_id.toString());
        debugPrint('✅ [AttendanceRepo] Marked as posted: ${model.attendance_in_id}');
      } else {
        debugPrint('⚠️ [AttendanceRepo] Skipped (will retry later): ${model.attendance_in_id}');
      }
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS – Date / Time formatting
  // ─────────────────────────────────────────────
  String _getDateString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }
    return value.toString().split('T')[0].split(' ')[0];
  }

  String _getTimeString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }

  // ─────────────────────────────────────────────
  // HELPER – profile can be Uint8List OR base64 String
  // handles both old (String) and new (Uint8List) model
  // ─────────────────────────────────────────────
  Uint8List? _getProfileBytes(dynamic profile) {
    if (profile == null) return null;
    if (profile is Uint8List) return profile;
    if (profile is List<int>) return Uint8List.fromList(profile);
    if (profile is String && profile.isNotEmpty) {
      try {
        return base64Decode(profile); // base64 String → bytes
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}