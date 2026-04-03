import 'dart:convert';
import 'dart:typed_data';
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
      // 'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
  'http://oracle.metaxperts.net/ords/gps_workforce/attendanceinpost/post/';

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

  // ─────────────────────────────────────────────
  // POST – Single JSON method
  //
  // Oracle ORDS bind variables (from handler source):
  //   :attendance_in_id   → attendance_in_id
  //   :attendance_in_date → attendance_in_date  (TO_DATE with 'MM/DD/YYYY')
  //   :attendance_in_time → attendance_in_time
  //   :emp_id             → emp_id
  //   :emp_name           → emp_name
  //   :job                → job
  //   :lat_in             → lat_in
  //   :lng_in             → lng_in
  //   :city               → city
  //   :address            → address
  //   :body               → body  (profile image — NOT 'profile'!)
  //   :company_code       → company_code
  // ─────────────────────────────────────────────
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
      debugPrint('🆔 ID   : ${model.attendance_in_id}');
      debugPrint('📅 Date : $dateStr');
      debugPrint('🕐 Time : $timeStr');
      debugPrint('👤 Emp  : ${model.emp_id} | ${model.emp_name}');
      debugPrint('🏢 Co   : ${model.company_code}');

      final Map<String, dynamic> payload = {
        'attendance_in_id'  : model.attendance_in_id?.toString() ?? '',
        'attendance_in_date': dateStr,   // "04/03/2026" → TO_DATE('MM/DD/YYYY')
        'attendance_in_time': timeStr,
        'emp_id'            : model.emp_id?.toString() ?? '',
        'emp_name'          : model.emp_name?.toString() ?? '',
        'job'               : model.job?.toString() ?? '',
        'lat_in'            : model.lat_in?.toString() ?? '',
        'lng_in'            : model.lng_in?.toString() ?? '',
        'city'              : model.city?.toString() ?? '',
        'address'           : model.address?.toString() ?? '',
        'company_code'      : model.company_code ?? '',
      };

      // ── Profile image → Oracle bind variable is :body (NOT :profile) ──
      final Uint8List? profileBytes = _getProfileBytes(model.profile);
      if (profileBytes != null && profileBytes.isNotEmpty) {
        payload['body'] = base64Encode(profileBytes);
        debugPrint('📸 [AttendanceRepo] Profile sent as "body": ${profileBytes.length} bytes');
      } else {
        debugPrint('📸 [AttendanceRepo] No profile image');
      }

      debugPrint('📦 [AttendanceRepo] Payload keys: ${payload.keys.toList()}');

      final response = await http.post(
        Uri.parse(_postApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept'      : 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('📡 [AttendanceRepo] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [AttendanceRepo] Posted: ${model.attendance_in_id}');
        return true;
      }

      // Duplicate key → already on server, treat as success
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

      // Use full-res photo bytes if available (fresh clock-in)
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
  // HELPER – Date → "MM/dd/yyyy" zero-padded
  // Matches Oracle: TO_DATE(:attendance_in_date, 'MM/DD/YYYY')
  // Examples: "04/03/2026", "12/31/2026"
  // ─────────────────────────────────────────────
  String _getDateString(dynamic value) {
    final fmt = DateFormat('MM/dd/yyyy'); // → "04/03/2026"
    if (value == null) return '';
    if (value is DateTime) return fmt.format(value);
    if (value is String && value.isNotEmpty) {
      // Already MM/dd/yyyy?
      try {
        fmt.parse(value);
        return value;
      } catch (_) {}
      // dd-MMM-yyyy (e.g. "03-Apr-2026")
      try {
        return fmt.format(DateFormat('dd-MMM-yyyy').parse(value));
      } catch (_) {}
      // ISO (e.g. "2026-04-03")
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