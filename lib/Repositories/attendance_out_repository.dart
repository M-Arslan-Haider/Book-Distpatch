import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../Database/db_helper.dart';
import '../Models/attendanceOut_model.dart';
import '../Services/remote_config_service.dart';

class AttendanceOutRepository {
  final DBHelper _dbHelper = DBHelper();

  static String get _postApiUrl => RemoteConfigService.getAttendanceOutUrl();

  // ══════════════════════════════════════════════════════════════════════════
  // GET ALL
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<AttendanceOutModel>> getAll() async {
    debugPrint('📊 [OutRepo] ───── getAll() called ─────');
    try {
      final rows = await _dbHelper.getAll(DBHelper.attendanceOutTable);
      debugPrint('📊 [OutRepo] Raw rows from SQLite: ${rows.length}');
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        debugPrint('📊 [OutRepo] Row[$i]: '
            'id=${r['attendance_out_id']} | '
            'emp=${r['emp_id']} | '
            'posted=${r['posted']} | '
            'reason=${r['reason']} | '
            'company=${r['company_code']} | '
            'image=${r['clock_out_image'] != null ? "✅ present (${(r['clock_out_image'] as String).length} chars)" : "❌ NULL"}');
      }
      final models = rows.map((row) => AttendanceOutModel.fromMap(row)).toList();
      debugPrint('📊 [OutRepo] getAll: returning ${models.length} models');
      return models;
    } catch (e, st) {
      debugPrint('❌ [OutRepo] getAll EXCEPTION: $e');
      debugPrint('❌ [OutRepo] getAll stacktrace: $st');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GET UNPOSTED
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<AttendanceOutModel>> getUnposted() async {
    debugPrint('📊 [OutRepo] ───── getUnposted() called ─────');
    try {
      final rows = await _dbHelper.getUnposted(DBHelper.attendanceOutTable);
      debugPrint('📊 [OutRepo] Unposted raw rows from SQLite: ${rows.length}');
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        debugPrint('📊 [OutRepo] UnpostedRow[$i]: '
            'id=${r['attendance_out_id']} | '
            'emp=${r['emp_id']} | '
            'date=${r['attendance_out_date']} | '
            'time=${r['attendance_out_time']} | '
            'posted=${r['posted']} | '
            'company=${r['company_code']} | '
            'distance=${r['total_distance']} | '
            'image=${r['clock_out_image'] != null ? "✅ (${(r['clock_out_image'] as String).length} chars)" : "❌ NULL"}');
      }
      final models = rows.map((row) => AttendanceOutModel.fromMap(row)).toList();
      debugPrint('📊 [OutRepo] getUnposted: ${models.length} unposted model(s) ready to sync');
      return models;
    } catch (e, st) {
      debugPrint('❌ [OutRepo] getUnposted EXCEPTION: $e');
      debugPrint('❌ [OutRepo] getUnposted stacktrace: $st');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GET BY ID
  // ══════════════════════════════════════════════════════════════════════════

  Future<AttendanceOutModel?> getById(String id) async {
    debugPrint('🔍 [OutRepo] getById: looking for $id');
    final all = await getAll();
    try {
      final found = all.firstWhere((r) => r.attendance_out_id?.toString() == id);
      debugPrint('✅ [OutRepo] getById: found record for $id');
      return found;
    } catch (_) {
      debugPrint('❌ [OutRepo] getById: record NOT found for $id');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADD (INSERT TO SQLITE)
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> add(AttendanceOutModel model) async {
    debugPrint('📝 [OutRepo] ───── add() called ─────');
    debugPrint('📝 [OutRepo] attendance_out_id  : ${model.attendance_out_id}');
    debugPrint('📝 [OutRepo] emp_id             : ${model.emp_id}');
    debugPrint('📝 [OutRepo] attendance_out_date: ${model.attendance_out_date}');
    debugPrint('📝 [OutRepo] attendance_out_time: ${model.attendance_out_time}');
    debugPrint('📝 [OutRepo] total_time         : ${model.total_time}');
    debugPrint('📝 [OutRepo] total_distance     : ${model.total_distance}');
    debugPrint('📝 [OutRepo] lat_out            : ${model.lat_out}');
    debugPrint('📝 [OutRepo] lng_out            : ${model.lng_out}');
    debugPrint('📝 [OutRepo] address            : ${model.address}');
    debugPrint('📝 [OutRepo] location_name      : ${model.location_name}');
    debugPrint('📝 [OutRepo] reason             : ${model.reason}');
    debugPrint('📝 [OutRepo] company_code       : ${model.company_code}');
    debugPrint('📝 [OutRepo] posted             : ${model.posted}');
    debugPrint('📝 [OutRepo] clock_out_image    : ${model.clock_out_image != null ? "✅ present — ${model.clock_out_image!.length} chars" : "❌ NULL — image will NOT be saved to SQLite"}');

    model.attendance_out_id ??= const Uuid().v4();
    model.reason ??= 'manual';

    final mapToInsert = model.toMap();
    debugPrint('📝 [OutRepo] toMap() keys: ${mapToInsert.keys.toList()}');
    debugPrint('📝 [OutRepo] toMap() clock_out_image: ${mapToInsert['clock_out_image'] != null ? "✅ present in map" : "❌ NULL in map — check toMap()"}');

    try {
      final result = await _dbHelper.insert(
        DBHelper.attendanceOutTable,
        mapToInsert,
      );
      if (result > 0) {
        debugPrint('✅ [OutRepo] SQLite INSERT success — rowId: $result');
      } else {
        debugPrint('⚠️ [OutRepo] SQLite INSERT returned $result — may have been replaced');
      }
      return result;
    } catch (e, st) {
      debugPrint('❌ [OutRepo] SQLite INSERT FAILED: $e');
      debugPrint('❌ [OutRepo] Insert stacktrace: $st');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ID EXISTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> idExists(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.attendanceOutTable} '
            'WHERE attendance_out_id = ?',
        [id],
      );
      final count = result.first['cnt'] as int? ?? 0;
      debugPrint('🔍 [OutRepo] idExists($id): count=$count');
      return count > 0;
    } catch (e) {
      debugPrint('❌ [OutRepo] idExists error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MARK AS POSTED
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> markAsPosted(String id) async {
    debugPrint('📝 [OutRepo] markAsPosted: $id');
    final result = await _dbHelper.markAsPosted(
      DBHelper.attendanceOutTable,
      'attendance_out_id',
      id,
    );
    debugPrint('✅ [OutRepo] markAsPosted result: $result (1=success, 0=not found)');
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> delete(String id) async {
    debugPrint('🗑️ [OutRepo] delete: $id');
    final result = await _dbHelper.delete(
      DBHelper.attendanceOutTable,
      'attendance_out_id',
      id,
    );
    debugPrint('✅ [OutRepo] delete result: $result');
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST TO API — FULL DEBUG
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _postToApi(AttendanceOutModel model) async {
    const int maxRetries = 2;

    final String apiUrl = _postApiUrl;
    debugPrint('📡 [OutRepo] ═══════════ _postToApi() START ═══════════');
    debugPrint('📡 [OutRepo] API URL          : $apiUrl');
    debugPrint('📡 [OutRepo] URL empty check  : ${apiUrl.isEmpty ? "❌ URL IS EMPTY!" : "✅ URL ok"}');
    debugPrint('📡 [OutRepo] Record ID        : ${model.attendance_out_id}');
    debugPrint('📡 [OutRepo] emp_id           : ${model.emp_id}');
    debugPrint('📡 [OutRepo] date             : ${model.attendance_out_date}');
    debugPrint('📡 [OutRepo] time             : ${model.attendance_out_time}');
    debugPrint('📡 [OutRepo] total_time       : ${model.total_time}');
    debugPrint('📡 [OutRepo] total_distance   : ${model.total_distance}');
    debugPrint('📡 [OutRepo] lat_out          : ${model.lat_out}');
    debugPrint('📡 [OutRepo] lng_out          : ${model.lng_out}');
    debugPrint('📡 [OutRepo] address          : ${model.address}');
    debugPrint('📡 [OutRepo] location_name    : ${model.location_name}');
    debugPrint('📡 [OutRepo] reason           : ${model.reason}');
    debugPrint('📡 [OutRepo] company_code     : ${model.company_code}');
    debugPrint('📡 [OutRepo] clock_out_image  : ${model.clock_out_image != null ? "✅ present — ${model.clock_out_image!.length} chars | preview: ${model.clock_out_image!.substring(0, model.clock_out_image!.length > 50 ? 50 : model.clock_out_image!.length)}..." : "❌ NULL — image will NOT be sent to Oracle"}');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('📡 [OutRepo] ── Attempt $attempt of $maxRetries ──');
      try {
        // Build payload from model
        final Map<String, dynamic> payload = model.toMap();

        // Override / add required fields
        payload['reason']       = model.reason ?? 'manual';
        payload['COMPANY_CODE'] = model.company_code ?? '';
        payload['company_code'] = model.company_code ?? '';

        // Remove 'posted' — Oracle does not need it
        payload.remove('posted');

        // clock_out_image — send base64 string if present, otherwise null.
        // Oracle PL/SQL cannot handle empty string '' for BLOB conversion — must be null.
        if (model.clock_out_image != null && model.clock_out_image!.isNotEmpty) {
          payload['clock_out_image'] = model.clock_out_image;
          debugPrint('📡 [OutRepo] ✅ clock_out_image added to payload (${model.clock_out_image!.length} chars)');
        } else {
          payload['clock_out_image'] = null;  // ✅ FIX: Oracle requires NULL not empty string for BLOB
          debugPrint('📡 [OutRepo] ℹ️ clock_out_image sent as null (auto/system clockout — no selfie)');
        }

        // Log full payload (image replaced with summary)
        final Map<String, dynamic> logPayload = Map.from(payload);
        if (logPayload.containsKey('clock_out_image')) {
          logPayload['clock_out_image'] = '[BASE64 — ${model.clock_out_image?.length ?? 0} chars]';
        }
        debugPrint('📡 [OutRepo] Payload keys   : ${payload.keys.toList()}');
        debugPrint('📡 [OutRepo] Payload (safe) : $logPayload');

        final String jsonBody  = jsonEncode(payload);
        final int    sizeBytes = jsonBody.length;
        debugPrint('📡 [OutRepo] Payload size   : $sizeBytes bytes (${(sizeBytes / 1024).toStringAsFixed(1)} KB)');
        debugPrint('📡 [OutRepo] Sending POST...');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept'      : 'application/json',
          },
          body: jsonBody,
        ).timeout(const Duration(seconds: 15));

        debugPrint('📡 [OutRepo] ── Response ──');
        debugPrint('📡 [OutRepo] Status code    : ${response.statusCode}');
        debugPrint('📡 [OutRepo] Response body  : ${response.body}');
        debugPrint('📡 [OutRepo] Response headers: ${response.headers}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ [OutRepo] POST SUCCESS ✅ for ${model.attendance_out_id}');
          debugPrint('📡 [OutRepo] ═══════════ _postToApi() END ═══════════');
          return true;
        }

        if (response.statusCode == 409) {
          debugPrint('⚠️ [OutRepo] 409 Conflict — record already on server: ${model.attendance_out_id}');
          debugPrint('📡 [OutRepo] ═══════════ _postToApi() END ═══════════');
          return true;
        }

        debugPrint('❌ [OutRepo] POST FAILED — HTTP ${response.statusCode}');
        debugPrint('❌ [OutRepo] Server response: ${response.body}');

        if (attempt < maxRetries) {
          debugPrint('⏳ [OutRepo] Waiting 1s before retry $attempt...');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e, st) {
        debugPrint('❌ [OutRepo] Attempt $attempt EXCEPTION: $e');
        debugPrint('❌ [OutRepo] Exception type: ${e.runtimeType}');
        debugPrint('❌ [OutRepo] Stacktrace: $st');
        if (attempt < maxRetries) {
          debugPrint('⏳ [OutRepo] Waiting 1s before retry...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    debugPrint('❌ [OutRepo] ALL $maxRetries ATTEMPTS FAILED for ${model.attendance_out_id}');
    debugPrint('📡 [OutRepo] ═══════════ _postToApi() END ═══════════');
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC UNPOSTED
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> syncUnposted() async {
    debugPrint('🔄 [OutRepo] ═══════════ syncUnposted() START ═══════════');

    final unposted = await getUnposted();

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [OutRepo] No unposted records in SQLite — nothing to sync');
      debugPrint('🔄 [OutRepo] ═══════════ syncUnposted() END ═══════════');
      return;
    }

    debugPrint('🔄 [OutRepo] Found ${unposted.length} unposted record(s)');

    // Deduplicate by ID
    final Map<String, AttendanceOutModel> unique = {};
    for (final r in unposted) {
      final id = r.attendance_out_id?.toString() ?? '';
      if (id.isNotEmpty) {
        unique[id] = r;
      } else {
        debugPrint('⚠️ [OutRepo] Skipping record with EMPTY id');
      }
    }
    debugPrint('🔄 [OutRepo] After dedup: ${unique.length} unique record(s)');

    int success = 0, failed = 0, index = 0;

    for (final model in unique.values) {
      index++;
      debugPrint('🔄 [OutRepo] ── Processing $index/${unique.length}: ${model.attendance_out_id} ──');
      debugPrint('🔄 [OutRepo] image status: ${model.clock_out_image != null ? "✅ (${model.clock_out_image!.length} chars)" : "❌ NULL"}');

      final posted = await _postToApi(model);

      if (posted) {
        await markAsPosted(model.attendance_out_id.toString());
        success++;
        debugPrint('✅ [OutRepo] Record $index → posted + marked ✅');
      } else {
        failed++;
        debugPrint('⚠️ [OutRepo] Record $index → FAILED — will retry on next sync ❌');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('📊 [OutRepo] ═══ Sync Summary ═══');
    debugPrint('📊 [OutRepo] Total   : ${unique.length}');
    debugPrint('📊 [OutRepo] Success : $success ✅');
    debugPrint('📊 [OutRepo] Failed  : $failed ❌');
    debugPrint('🔄 [OutRepo] ═══════════ syncUnposted() END ═══════════');
  }
}