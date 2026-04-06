
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../Models/location_model.dart';

/// Repository: all DB + API I/O for location tracking records.
class LocationRepository {
  static const String _apiUrl =
      // 'http://oracle.metaxperts.net/ords/production/location/post/';
  'http://oracle.metaxperts.net/ords/gps_workforce/location/post/';

  // ─────────────────────────────────────────────────────────────────────────
  // DB ACCESS
  // Opens the same SQLite file your existing repositories use.
  // ⚠️  Change 'attendance_app.db' to your actual database filename.
  // ─────────────────────────────────────────────────────────────────────────

  static Database? _database;

  Future<Database> get _db async {
    _database ??= await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'attendance_app.db'); // ← your DB filename

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute(_kCreateTable),
      onOpen:   (db)    => db.execute(_kCreateTable), // safe: IF NOT EXISTS
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCHEMA  (matches your CREATE TABLE exactly)
  // ─────────────────────────────────────────────────────────────────────────

  // In location_repository.dart, update the table creation to handle larger BLOBs

  static const String _kCreateTable = '''
    CREATE TABLE IF NOT EXISTS ${LocationModel.tableName}(
      ${LocationModel.colId}          TEXT PRIMARY KEY,
      ${LocationModel.colDate}        TEXT,
      ${LocationModel.colTime}        TEXT,
      ${LocationModel.colFileName}    TEXT,
      ${LocationModel.colEmpId}       TEXT,
      ${LocationModel.colDistance}    TEXT,
      ${LocationModel.colEmpName}     TEXT,
      ${LocationModel.colPosted}      INTEGER DEFAULT 0,
      ${LocationModel.colBody}        BLOB,
      ${LocationModel.colCompanyCode} TEXT
    )
  ''';

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> insert(LocationModel model) async {
    final db = await _db;
    await db.insert(
      LocationModel.tableName,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('💾 [LocRepo] Inserted ${model.locationId}');
  }

  /// Alias so old code calling _repo.add() still compiles.
  Future<void> add(LocationModel model) => insert(model);

  Future<List<LocationModel>> getAll() async {
    final db   = await _db;
    final rows = await db.query(LocationModel.tableName);
    return rows.map(LocationModel.fromMap).toList();
  }

  Future<List<LocationModel>> getUnposted() async {
    final db   = await _db;
    final rows = await db.query(
      LocationModel.tableName,
      where    : '${LocationModel.colPosted} = ?',
      whereArgs: [0],
    );
    return rows.map(LocationModel.fromMap).toList();
  }

  /// Returns all records (posted or not) for a given date string (yyyy-MM-dd).
  Future<List<LocationModel>> getByDate(String dateStr) async {
    final db   = await _db;
    final rows = await db.query(
      LocationModel.tableName,
      where    : '${LocationModel.colDate} = ?',
      whereArgs: [dateStr],
    );
    return rows.map(LocationModel.fromMap).toList();
  }

  /// Marks every record on [dateStr] as posted=1 EXCEPT the one with [keepId].
  /// This ensures only the latest cumulative record is synced to the server.
  Future<void> markOlderRecordsPosted({
    required String dateStr,
    required String keepId,
  }) async {
    final db = await _db;
    await db.update(
      LocationModel.tableName,
      {LocationModel.colPosted: 1},
      where    : '${LocationModel.colDate} = ? AND ${LocationModel.colId} != ?',
      whereArgs: [dateStr, keepId],
    );
    debugPrint(
        '✅ [LocRepo] Suppressed older records for $dateStr (keeping $keepId)');
  }

  Future<void> markPosted(String locationId) async {
    final db = await _db;
    await db.update(
      LocationModel.tableName,
      {LocationModel.colPosted: 1},
      where    : '${LocationModel.colId} = ?',
      whereArgs: [locationId],
    );
    debugPrint('✅ [LocRepo] Marked posted: $locationId');
  }

  Future<void> delete(String locationId) async {
    final db = await _db;
    await db.delete(
      LocationModel.tableName,
      where    : '${LocationModel.colId} = ?',
      whereArgs: [locationId],
    );
    debugPrint('🗑 [LocRepo] Deleted $locationId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SYNC
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> syncUnposted() async {
    final pending = await getUnposted();
    if (pending.isEmpty) {
      debugPrint('📡 [LocRepo] Nothing to sync');
      return;
    }
    debugPrint('📡 [LocRepo] Syncing ${pending.length} record(s)…');
    for (final record in pending) {
      await _uploadRecord(record);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HTTP  –  multipart upload
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _uploadRecord(LocationModel record) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      request.fields.addAll({
        'location_id'   : record.locationId,
        'location_date' : record.locationDate,
        'location_time' : record.locationTime,
        'file_name'     : record.fileName,
        'emp_id'        : record.empId,
        'total_distance': record.totalDistance,
        'emp_name'      : record.empName,
      });

      if (record.company_code != null && record.company_code!.isNotEmpty) {
        request.fields['company_code'] = record.company_code!;
        request.fields['COMPANY_CODE'] = record.company_code!; // ← ADDED (both cases)
      }

      if (record.body != null && record.body!.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'body',
            record.body!,
            filename   : record.fileName,
            contentType: MediaType('application', 'gpx+xml'),
          ),
        );
      }

      final streamed = await request.send()
          .timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await markPosted(record.locationId);
        debugPrint('✅ [LocRepo] Uploaded ${record.locationId}');
        return true;
      }
      debugPrint('⚠️ [LocRepo] Server ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ [LocRepo] Upload failed for ${record.locationId}: $e');
      return false;
    }
  }

  /// JSON + base64 alternative — use if the server prefers JSON.
  Future<bool> uploadRecordJson(LocationModel record) async {
    try {
      final payload = record.toApiJson();
      if (record.body != null && record.body!.isNotEmpty) {
        payload['body'] = base64Encode(record.body!);
      }
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body   : jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await markPosted(record.locationId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [LocRepo] JSON upload failed: $e');
      return false;
    }
  }
}