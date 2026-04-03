import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../Database/db_helper.dart';
import '../Models/attendanceOut_model.dart';

class AttendanceOutRepository {
  final DBHelper _dbHelper = DBHelper();

  static const String _postApiUrl =
      'http://oracle.metaxperts.net/ords/production/attendanceout/post/';

  Future<List<AttendanceOutModel>> getAll() async {
    final rows = await _dbHelper.getAll(DBHelper.attendanceOutTable);
    final models = rows.map((row) => AttendanceOutModel.fromMap(row)).toList();
    debugPrint('📊 [OutRepo] getAll: found ${models.length} records');
    return models;
  }

  Future<List<AttendanceOutModel>> getUnposted() async {
    final rows = await _dbHelper.getUnposted(DBHelper.attendanceOutTable);
    final models = rows.map((row) => AttendanceOutModel.fromMap(row)).toList();
    debugPrint('📊 [OutRepo] getUnposted: found ${models.length} unposted records');
    return models;
  }

  Future<AttendanceOutModel?> getById(String id) async {
    debugPrint('🔍 [OutRepo] getById: looking for $id');
    final all = await getAll();
    try {
      final found = all.firstWhere((r) => r.attendance_out_id?.toString() == id);
      debugPrint('✅ [OutRepo] getById: found record');
      return found;
    } catch (_) {
      debugPrint('❌ [OutRepo] getById: record not found');
      return null;
    }
  }

  Future<int> add(AttendanceOutModel model) async {
    debugPrint('📝 [OutRepo] Adding record: ${model.attendance_out_id}');
    debugPrint('📝 [OutRepo] Model data: ${model.toMap()}');

    model.attendance_out_id ??= const Uuid().v4();
    model.reason ??= 'manual';

    try {
      final result = await _dbHelper.insert(
        DBHelper.attendanceOutTable,
        model.toMap(),
      );
      debugPrint('✅ [OutRepo] Insert successful, result: $result');
      return result;
    } catch (e) {
      debugPrint('❌ [OutRepo] Insert failed: $e');
      rethrow;
    }
  }

  Future<bool> idExists(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.attendanceOutTable} '
            'WHERE attendance_out_id = ?',
        [id],
      );
      final count = result.first['cnt'] as int? ?? 0;
      return count > 0;
    } catch (e) {
      debugPrint('❌ [OutRepo] idExists error: $e');
      return false;
    }
  }

  Future<int> markAsPosted(String id) async {
    debugPrint('📝 [OutRepo] Marking as posted: $id');
    final result = await _dbHelper.markAsPosted(
      DBHelper.attendanceOutTable,
      'attendance_out_id',
      id,
    );
    debugPrint('✅ [OutRepo] Mark as posted result: $result');
    return result;
  }

  Future<int> delete(String id) async {
    debugPrint('🗑️ [OutRepo] Deleting: $id');
    final result = await _dbHelper.delete(
      DBHelper.attendanceOutTable,
      'attendance_out_id',
      id,
    );
    debugPrint('✅ [OutRepo] Delete result: $result');
    return result;
  }

  Future<bool> _postToApi(AttendanceOutModel model) async {
    const int maxRetries = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final payload = model.toMap();
        payload['reason'] = model.reason ?? 'manual';
        payload['COMPANY_CODE'] = model.company_code ?? '';
        payload['company_code'] = model.company_code ?? '';

        debugPrint('📡 [OutRepo] Attempt $attempt – POST ${model.attendance_out_id}');
        debugPrint('📡 [OutRepo] Payload: $payload');

        final response = await http
            .post(
          Uri.parse(_postApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        )
            .timeout(const Duration(seconds: 15));

        debugPrint('📡 [OutRepo] Response ${response.statusCode} for ${model.attendance_out_id}');
        debugPrint('📡 [OutRepo] Response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ [OutRepo] Posted: ${model.attendance_out_id}');
          return true;
        }

        if (response.statusCode == 409) {
          debugPrint('⚠️ [OutRepo] Already on server (409): ${model.attendance_out_id}');
          return true;
        }

        debugPrint('❌ [OutRepo] Server error ${response.statusCode}: ${response.body}');

        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        debugPrint('❌ [OutRepo] Attempt $attempt error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    return false;
  }

  Future<void> syncUnposted() async {
    final unposted = await getUnposted();

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [OutRepo] No unposted records to sync.');
      return;
    }

    debugPrint('🔄 [OutRepo] Syncing ${unposted.length} unposted record(s)...');

    final Map<String, AttendanceOutModel> unique = {};
    for (final r in unposted) {
      final id = r.attendance_out_id?.toString() ?? '';
      if (id.isNotEmpty) unique[id] = r;
    }

    debugPrint('🔄 [OutRepo] After deduplication: ${unique.length} unique records');

    int success = 0, failed = 0;

    for (final model in unique.values) {
      final posted = await _postToApi(model);

      if (posted) {
        await markAsPosted(model.attendance_out_id.toString());
        success++;
        debugPrint('✅ [OutRepo] Marked as posted: ${model.attendance_out_id}');
      } else {
        failed++;
        debugPrint('⚠️ [OutRepo] Will retry later: ${model.attendance_out_id}');
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('📊 [OutRepo] Sync done – ✅ $success posted, ❌ $failed failed');
  }
}