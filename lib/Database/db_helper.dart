//
//
// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
//
// class DBHelper {
//
//   static Database? _database;
//   static String? _currentCompanyCode;
//
//   static const String dbName             = "employee_portal.db";
//
//   static const String attendanceTable    = "attendance_in";
//   static const String attendanceOutTable = "attendance_out";
//   static const String locationTable      = "location";
//   static const String leaveTable         = "leave_application";
//   static const String taskTable          = "tasks";
//   static const String fakeGpsTable       = "fake_gps_logs";
//   static const String locationTrackingTable = "location_tracking";
//
//   static const String _taskTableDDL = '''
//     CREATE TABLE IF NOT EXISTS tasks(
//       id               INTEGER,
//       emp_id           INTEGER,
//       emp_name         TEXT,
//       task_title       TEXT,
//       task_description TEXT,
//       status           TEXT,
//       priority         TEXT,
//       due_date         TEXT,
//       comments         TEXT,
//       assigned_by      TEXT,
//       created_at       TEXT    DEFAULT (datetime('now')),
//       task_type        TEXT    DEFAULT 'SELF',
//       company_code     TEXT
//     )
//   ''';
//
//   // ── Company Code Helpers ───────────────────────────────────────────────────
//
//   static void setCompanyCode(String companyCode) {
//     _currentCompanyCode = companyCode;
//     debugPrint('🏢 [DB] Company code set to: $companyCode');
//   }
//
//   static String? getCompanyCode() => _currentCompanyCode;
//
//   static void clearCompanyCode() {
//     _currentCompanyCode = null;
//     debugPrint('🏢 [DB] Company code cleared');
//   }
//
//   // ── DB init ────────────────────────────────────────────────────────────────
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB();
//     return _database!;
//   }
//
//   Future<Database> _initDB() async {
//     String path = join(await getDatabasesPath(), dbName);
//     return await openDatabase(
//       path,
//       version: 11, // Bumped to 11 for location_tracking table
//       onCreate: _createDB,
//       onUpgrade: _onUpgrade,
//     );
//   }
//
//   // ── MIGRATIONS ─────────────────────────────────────────────────────────────
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     if (oldVersion < 2) {
//       await _safeAlter(db,
//         'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB',
//         '✅ [DB] v2 — profile column added to attendance_in',
//       );
//     }
//
//     if (oldVersion < 3) {
//       try {
//         await db.execute(_taskTableDDL);
//         debugPrint('✅ [DB] v3 — tasks table created');
//       } catch (e) {
//         debugPrint('⚠️ [DB] v3 — tasks table already exists: $e');
//       }
//     }
//
//     if (oldVersion < 4) {
//       await _safeAlter(db,
//         "ALTER TABLE $taskTable ADD COLUMN task_type TEXT DEFAULT 'SELF'",
//         '✅ [DB] v4 — task_type column added to tasks',
//       );
//     }
//
//     if (oldVersion < 5) {
//       await _safeAlter(db,
//         'ALTER TABLE $attendanceTable    ADD COLUMN company_code TEXT',
//         '✅ [DB] v5 — company_code → attendance_in',
//       );
//       await _safeAlter(db,
//         'ALTER TABLE $attendanceOutTable ADD COLUMN company_code TEXT',
//         '✅ [DB] v5 — company_code → attendance_out',
//       );
//       await _safeAlter(db,
//         'ALTER TABLE $locationTable      ADD COLUMN company_code TEXT',
//         '✅ [DB] v5 — company_code → location',
//       );
//       await _safeAlter(db,
//         'ALTER TABLE $leaveTable         ADD COLUMN company_code TEXT',
//         '✅ [DB] v5 — company_code → leave_application',
//       );
//       await _safeAlter(db,
//         'ALTER TABLE $taskTable          ADD COLUMN company_code TEXT',
//         '✅ [DB] v5 — company_code → tasks',
//       );
//
//       try {
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_company     ON $attendanceTable(company_code)');
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_out_company ON $attendanceOutTable(company_code)');
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_location_company       ON $locationTable(company_code)');
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_company          ON $leaveTable(company_code)');
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_company          ON $taskTable(company_code)');
//         debugPrint('✅ [DB] v5 — indexes created');
//       } catch (e) {
//         debugPrint('⚠️ [DB] v5 — index creation error (non-fatal): $e');
//       }
//
//       debugPrint('✅ [DB] v5 migration complete');
//     }
//
//     if (oldVersion < 6) {
//       try {
//         // Check if old table exists and drop it to recreate with correct schema
//         final tables = await db.rawQuery(
//             "SELECT name FROM sqlite_master WHERE type='table' AND name='$fakeGpsTable'"
//         );
//
//         if (tables.isNotEmpty) {
//           final columns = await db.rawQuery("PRAGMA table_info($fakeGpsTable)");
//           final hasOldSchema = columns.any((col) => col['name'] == 'latitude');
//
//           if (hasOldSchema) {
//             debugPrint('⚠️ [DB] v6 — Old fake_gps_logs schema detected, dropping table');
//             await db.execute('DROP TABLE $fakeGpsTable');
//           }
//         }
//
//         await db.execute('''
//           CREATE TABLE IF NOT EXISTS $fakeGpsTable (
//             id            INTEGER PRIMARY KEY AUTOINCREMENT,
//             emp_id        TEXT    NOT NULL,
//             emp_name      TEXT,
//             company_code  TEXT,
//             real_latitude  REAL,
//             real_longitude REAL,
//             real_address   TEXT,
//             fake_latitude  REAL,
//             fake_longitude REAL,
//             fake_address   TEXT,
//             distance_km    REAL,
//             detected_at   TEXT    NOT NULL,
//             posted        INTEGER DEFAULT 0
//           )
//         ''');
//         debugPrint('✅ [DB] v6 — fake_gps_logs table created with correct schema');
//       } catch (e) {
//         debugPrint('⚠️ [DB] v6 — fake_gps_logs error: $e');
//       }
//     }
//
//     // ── v7: (reserved) ────────────────────────────────────────────────────────
//
//     // ── v8: Add location_name column to attendance_in ─────────────────────────
//     if (oldVersion < 8) {
//       await _safeAlter(db,
//         'ALTER TABLE $attendanceTable ADD COLUMN location_name TEXT',
//         '✅ [DB] v8 — location_name column added to attendance_in',
//       );
//     }
//
//     // ── v9: Add location_name column to attendance_out ─────────────────────────
//     if (oldVersion < 9) {
//       await _safeAlter(db,
//         'ALTER TABLE $attendanceOutTable ADD COLUMN location_name TEXT',
//         '✅ [DB] v9 — location_name column added to attendance_out',
//       );
//     }
//
//     // ── v10: Safety check - ensure location_name exists (in case v9 was missed) ──
//     if (oldVersion < 10) {
//       try {
//         // Try to add it again (safe if already exists)
//         await _safeAlter(db,
//           'ALTER TABLE $attendanceOutTable ADD COLUMN location_name TEXT',
//           '✅ [DB] v10 — safety check: location_name column ensured',
//         );
//       } catch (e) {
//         debugPrint('✅ [DB] v10 — location_name column already exists');
//       }
//     }
//
//     // ── v11: Add location_tracking table for offline GPS storage ──────────────
//     if (oldVersion < 11) {
//       await db.execute('''
//       CREATE TABLE IF NOT EXISTS $locationTrackingTable(
//         id                    INTEGER PRIMARY KEY AUTOINCREMENT,
//         locationtracking_id   TEXT UNIQUE,
//         locationtracking_date TEXT,
//         locationtracking_time TEXT,
//         user_id               TEXT,
//         lat_in                REAL,
//         lng_in                REAL,
//         booker_name           TEXT,
//         designation           TEXT,
//         company_code          TEXT,
//         posted                INTEGER DEFAULT 0,
//         created_at            TEXT DEFAULT (datetime('now'))
//       )
//       ''');
//
//       try {
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_posted ON $locationTrackingTable(posted)');
//         await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_company ON $locationTrackingTable(company_code)');
//         debugPrint('✅ [DB] v11 — location_tracking table and indexes created');
//       } catch (e) {
//         debugPrint('⚠️ [DB] v11 — index creation error: $e');
//       }
//
//       debugPrint('✅ [DB] v11 migration complete');
//     }
//   }
//
//   /// Runs an ALTER TABLE and swallows errors
//   Future<void> _safeAlter(Database db, String sql, String successMsg) async {
//     try {
//       await db.execute(sql);
//       debugPrint(successMsg);
//     } catch (e) {
//       debugPrint('⚠️ [DB] ALTER skipped (already applied?): $e');
//     }
//   }
//
//   // ── CREATE (fresh install) ─────────────────────────────────────────────────
//   Future<void> _createDB(Database db, int version) async {
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $attendanceTable(
//       attendance_in_id   TEXT PRIMARY KEY,
//       attendance_in_date TEXT,
//       attendance_in_time TEXT,
//       emp_id             TEXT,
//       emp_name           TEXT,
//       job                TEXT,
//       lat_in             TEXT,
//       lng_in             TEXT,
//       city               TEXT,
//       address            TEXT,
//       location_name      TEXT,
//       posted             INTEGER DEFAULT 0,
//       profile            BLOB,
//       company_code       TEXT
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $attendanceOutTable(
//       attendance_out_id   TEXT PRIMARY KEY,
//       attendance_out_date TEXT,
//       attendance_out_time TEXT,
//       total_time          TEXT,
//       emp_id              TEXT,
//       lat_out             TEXT,
//       lng_out             TEXT,
//       total_distance      TEXT,
//       address             TEXT,
//       location_name       TEXT,
//       reason              TEXT DEFAULT 'manual',
//       posted              INTEGER DEFAULT 0,
//       company_code        TEXT
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $locationTable(
//       location_id    TEXT PRIMARY KEY,
//       location_date  TEXT,
//       location_time  TEXT,
//       file_name      TEXT,
//       emp_id         TEXT,
//       emp_name       TEXT,
//       total_distance TEXT,
//       posted         INTEGER DEFAULT 0,
//       body           BLOB,
//       company_code   TEXT
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $leaveTable(
//       id               TEXT PRIMARY KEY,
//       leave_id         TEXT UNIQUE,
//       emp_id           TEXT,
//       emp_name         TEXT,
//       job_role         TEXT,
//       leave_type       TEXT,
//       start_date       TEXT,
//       end_date         TEXT,
//       total_days       INTEGER,
//       is_half_day      INTEGER DEFAULT 0,
//       reason           TEXT,
//       attachment_data  BLOB,
//       attachment_image TEXT,
//       application_date TEXT,
//       application_time TEXT,
//       status           TEXT DEFAULT 'pending',
//       posted           INTEGER DEFAULT 0,
//       has_attachment   INTEGER DEFAULT 0,
//       company_code     TEXT
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $taskTable(
//       id               INTEGER,
//       emp_id           INTEGER,
//       emp_name         TEXT,
//       task_title       TEXT,
//       task_description TEXT,
//       status           TEXT,
//       priority         TEXT,
//       due_date         TEXT,
//       comments         TEXT,
//       assigned_by      TEXT,
//       created_at       TEXT    DEFAULT (datetime('now')),
//       task_type        TEXT    DEFAULT 'SELF',
//       company_code     TEXT
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $fakeGpsTable(
//       id            INTEGER PRIMARY KEY AUTOINCREMENT,
//       emp_id        TEXT    NOT NULL,
//       emp_name      TEXT,
//       company_code  TEXT,
//       real_latitude  REAL,
//       real_longitude REAL,
//       real_address   TEXT,
//       fake_latitude  REAL,
//       fake_longitude REAL,
//       fake_address   TEXT,
//       distance_km    REAL,
//       detected_at   TEXT    NOT NULL,
//       posted        INTEGER DEFAULT 0
//     )
//     ''');
//
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $locationTrackingTable(
//       id                    INTEGER PRIMARY KEY AUTOINCREMENT,
//       locationtracking_id   TEXT UNIQUE,
//       locationtracking_date TEXT,
//       locationtracking_time TEXT,
//       user_id               TEXT,
//       lat_in                REAL,
//       lng_in                REAL,
//       booker_name           TEXT,
//       designation           TEXT,
//       company_code          TEXT,
//       posted                INTEGER DEFAULT 0,
//       created_at            TEXT DEFAULT (datetime('now'))
//     )
//     ''');
//
//     try {
//       await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_posted ON $locationTrackingTable(posted)');
//       await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_company ON $locationTrackingTable(company_code)');
//     } catch (e) {
//       debugPrint('⚠️ [DB] Index creation error: $e');
//     }
//   }
//
//   // ── INSERT ─────────────────────────────────────────────────────────────────
//   Future<int> insert(String table, Map<String, dynamic> data) async {
//     final db = await database;
//
//     if (_currentCompanyCode != null) {
//       final existing = data['company_code'];
//       if (existing == null) {
//         data['company_code'] = _currentCompanyCode;
//         debugPrint('🏢 [DB] Auto-injected company_code: $_currentCompanyCode → $table');
//       }
//     }
//
//     return await db.insert(
//       table,
//       data,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
//
//   /// Raw insert — skips company_code injection (internal use only)
//   Future<int> insertRaw(String table, Map<String, dynamic> data) async {
//     final db = await database;
//     return await db.insert(
//       table,
//       data,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
//
//   // ── GET ALL ────────────────────────────────────────────────────────────────
//   Future<List<Map<String, dynamic>>> getAll(String table) async {
//     final db = await database;
//
//     if (_currentCompanyCode != null) {
//       if (table == attendanceTable) {
//         return await db.query(
//           table,
//           columns: [
//             'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//             'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//             'city', 'address', 'location_name', 'posted', 'company_code',
//           ],
//           where: 'company_code = ?',
//           whereArgs: [_currentCompanyCode],
//         );
//       }
//       return await db.query(
//         table,
//         where: 'company_code = ?',
//         whereArgs: [_currentCompanyCode],
//       );
//     }
//
//     if (table == attendanceTable) {
//       return await db.query(
//         table,
//         columns: [
//           'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//           'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//           'city', 'address', 'location_name', 'posted', 'company_code',
//         ],
//       );
//     }
//     return await db.query(table);
//   }
//
//   // ── GET UNPOSTED ───────────────────────────────────────────────────────────
//   Future<List<Map<String, dynamic>>> getUnposted(String table) async {
//     final db = await database;
//
//     if (_currentCompanyCode != null) {
//       if (table == attendanceTable) {
//         return await db.query(
//           table,
//           columns: [
//             'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//             'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//             'city', 'address', 'location_name', 'posted', 'company_code',
//           ],
//           where: 'posted = ? AND company_code = ?',
//           whereArgs: [0, _currentCompanyCode],
//         );
//       }
//       return await db.query(
//         table,
//         where: 'posted = ? AND company_code = ?',
//         whereArgs: [0, _currentCompanyCode],
//       );
//     }
//
//     if (table == attendanceTable) {
//       return await db.query(
//         table,
//         columns: [
//           'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//           'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//           'city', 'address', 'location_name', 'posted',
//         ],
//         where: 'posted = ?',
//         whereArgs: [0],
//       );
//     }
//     return await db.query(
//       table,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//   }
//
//   // ── GET PROFILE ────────────────────────────────────────────────────────────
//   Future<String?> getProfile(String attendanceId) async {
//     final db = await database;
//     final rows = await db.query(
//       attendanceTable,
//       columns: ['profile'],
//       where: 'attendance_in_id = ?'
//           '${_currentCompanyCode != null ? " AND company_code = ?" : ""}',
//       whereArgs: _currentCompanyCode != null
//           ? [attendanceId, _currentCompanyCode]
//           : [attendanceId],
//       limit: 1,
//     );
//     if (rows.isEmpty) return null;
//     return rows.first['profile'] as String?;
//   }
//
//   // ── CLEANUP ────────────────────────────────────────────────────────────────
//   Future<void> cleanupLargeProfiles() async {
//     final db = await database;
//     final cleared = await db.rawUpdate(
//       "UPDATE $attendanceTable SET profile = NULL "
//           "WHERE profile IS NOT NULL AND length(profile) > 50000",
//     );
//     debugPrint('🧹 [AttendanceRepo] cleanupLargeProfiles: cleared $cleared rows');
//   }
//
//   // ── MARK AS POSTED ─────────────────────────────────────────────────────────
//   Future<int> markAsPosted(String table, String idColumn, String id) async {
//     final db = await database;
//     return await db.update(
//       table,
//       {"posted": 1},
//       where: "$idColumn = ?",
//       whereArgs: [id],
//     );
//   }
//
//   // ── DELETE (soft — sets posted = -1) ──────────────────────────────────────
//   Future<int> delete(String table, String idColumn, String id) async {
//     final db = await database;
//     return await db.update(
//       table,
//       {"posted": -1},
//       where: "$idColumn = ?",
//       whereArgs: [id],
//     );
//   }
//
//   // ── DELETE (hard) ──────────────────────────────────────────────────────────
//   Future<int> deleteHard(String table, String idColumn, String id) async {
//     final db = await database;
//     return await db.delete(
//       table,
//       where: "$idColumn = ?",
//       whereArgs: [id],
//     );
//   }
//
//   // ── GET ALL FOR COMPANY (admin use) ───────────────────────────────────────
//   Future<List<Map<String, dynamic>>> getAllForCompany(
//       String table, String companyCode) async {
//     final db = await database;
//     return await db.query(
//       table,
//       where: 'company_code = ?',
//       whereArgs: [companyCode],
//     );
//   }
//
//   // ── GET COMPANY CODE ASYNC ─────────────────────────────────────────────────
//   static Future<String> getCompanyCodeAsync() async {
//     if (_currentCompanyCode != null) {
//       return _currentCompanyCode!;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final companyCode = prefs.getString('companyCode') ?? '';
//     if (companyCode.isNotEmpty) {
//       _currentCompanyCode = companyCode;
//     }
//     return companyCode;
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // LOCATION TRACKING BULK OPERATIONS (v11)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   /// Insert multiple location tracking records in bulk
//   Future<int> insertLocationTrackingBulk(List<Map<String, dynamic>> records) async {
//     final db = await database;
//     int inserted = 0;
//
//     for (final record in records) {
//       try {
//         final data = Map<String, dynamic>.from(record);
//
//         // Add company_code if missing
//         if (_currentCompanyCode != null && data['company_code'] == null) {
//           data['company_code'] = _currentCompanyCode;
//         }
//
//         // Remove 'id' if present (auto-increment)
//         data.remove('id');
//
//         await db.insert(
//           locationTrackingTable,
//           data,
//           conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicates
//         );
//         inserted++;
//       } catch (e) {
//         debugPrint('⚠️ [DB] Insert location tracking error: $e');
//       }
//     }
//
//     debugPrint('💾 [DB] Inserted $inserted location tracking records');
//     return inserted;
//   }
//
//   /// Get unposted location tracking records
//   Future<List<Map<String, dynamic>>> getUnpostedLocationTracking({int limit = 500}) async {
//     final db = await database;
//
//     String whereClause = 'posted = ?';
//     List<dynamic> whereArgs = [0];
//
//     if (_currentCompanyCode != null) {
//       whereClause += ' AND company_code = ?';
//       whereArgs.add(_currentCompanyCode);
//     }
//
//     return await db.query(
//       locationTrackingTable,
//       where: whereClause,
//       whereArgs: whereArgs,
//       orderBy: 'created_at ASC',
//       limit: limit,
//     );
//   }
//
//   /// Mark location tracking records as posted
//   Future<int> markLocationTrackingAsPosted(List<int> ids) async {
//     if (ids.isEmpty) return 0;
//
//     final db = await database;
//     final placeholders = ids.map((_) => '?').join(',');
//
//     final result = await db.rawUpdate(
//       'UPDATE $locationTrackingTable SET posted = 1 WHERE id IN ($placeholders)',
//       ids,
//     );
//
//     debugPrint('✅ [DB] Marked $result location tracking records as posted');
//     return result;
//   }
//
//   /// Get count of unposted location tracking records
//   Future<int> getUnpostedLocationTrackingCount() async {
//     final db = await database;
//
//     String whereClause = 'posted = ?';
//     List<dynamic> whereArgs = [0];
//
//     if (_currentCompanyCode != null) {
//       whereClause += ' AND company_code = ?';
//       whereArgs.add(_currentCompanyCode);
//     }
//
//     final result = await db.rawQuery(
//       'SELECT COUNT(*) as count FROM $locationTrackingTable WHERE $whereClause',
//       whereArgs,
//     );
//
//     return result.first['count'] as int? ?? 0;
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {

  static Database? _database;
  static String? _currentCompanyCode;

  static const String dbName             = "employee_portal.db";

  static const String attendanceTable    = "attendance_in";
  static const String attendanceOutTable = "attendance_out";
  static const String locationTable      = "location";
  static const String leaveTable         = "leave_application";
  static const String taskTable          = "tasks";
  static const String fakeGpsTable       = "fake_gps_logs";
  static const String locationTrackingTable = "location_tracking";

  static const String _taskTableDDL = '''
    CREATE TABLE IF NOT EXISTS tasks(
      id               INTEGER,
      emp_id           INTEGER,
      emp_name         TEXT,
      task_title       TEXT,
      task_description TEXT,
      status           TEXT,
      priority         TEXT,
      due_date         TEXT,
      comments         TEXT,
      assigned_by      TEXT,
      created_at       TEXT    DEFAULT (datetime('now')),
      task_type        TEXT    DEFAULT 'SELF',
      company_code     TEXT
    )
  ''';

  // ── Company Code Helpers ───────────────────────────────────────────────────

  static void setCompanyCode(String companyCode) {
    _currentCompanyCode = companyCode;
    debugPrint('🏢 [DB] Company code set to: $companyCode');
  }

  static String? getCompanyCode() => _currentCompanyCode;

  static void clearCompanyCode() {
    _currentCompanyCode = null;
    debugPrint('🏢 [DB] Company code cleared');
  }

  // ── DB init ────────────────────────────────────────────────────────────────

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 12, // Bumped to 12 for clock_out_image column in attendance_out
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ── MIGRATIONS ─────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAlter(db,
        'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB',
        '✅ [DB] v2 — profile column added to attendance_in',
      );
    }

    if (oldVersion < 3) {
      try {
        await db.execute(_taskTableDDL);
        debugPrint('✅ [DB] v3 — tasks table created');
      } catch (e) {
        debugPrint('⚠️ [DB] v3 — tasks table already exists: $e');
      }
    }

    if (oldVersion < 4) {
      await _safeAlter(db,
        "ALTER TABLE $taskTable ADD COLUMN task_type TEXT DEFAULT 'SELF'",
        '✅ [DB] v4 — task_type column added to tasks',
      );
    }

    if (oldVersion < 5) {
      await _safeAlter(db,
        'ALTER TABLE $attendanceTable    ADD COLUMN company_code TEXT',
        '✅ [DB] v5 — company_code → attendance_in',
      );
      await _safeAlter(db,
        'ALTER TABLE $attendanceOutTable ADD COLUMN company_code TEXT',
        '✅ [DB] v5 — company_code → attendance_out',
      );
      await _safeAlter(db,
        'ALTER TABLE $locationTable      ADD COLUMN company_code TEXT',
        '✅ [DB] v5 — company_code → location',
      );
      await _safeAlter(db,
        'ALTER TABLE $leaveTable         ADD COLUMN company_code TEXT',
        '✅ [DB] v5 — company_code → leave_application',
      );
      await _safeAlter(db,
        'ALTER TABLE $taskTable          ADD COLUMN company_code TEXT',
        '✅ [DB] v5 — company_code → tasks',
      );

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_company     ON $attendanceTable(company_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_out_company ON $attendanceOutTable(company_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_location_company       ON $locationTable(company_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_company          ON $leaveTable(company_code)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_company          ON $taskTable(company_code)');
        debugPrint('✅ [DB] v5 — indexes created');
      } catch (e) {
        debugPrint('⚠️ [DB] v5 — index creation error (non-fatal): $e');
      }

      debugPrint('✅ [DB] v5 migration complete');
    }

    if (oldVersion < 6) {
      try {
        // Check if old table exists and drop it to recreate with correct schema
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$fakeGpsTable'"
        );

        if (tables.isNotEmpty) {
          final columns = await db.rawQuery("PRAGMA table_info($fakeGpsTable)");
          final hasOldSchema = columns.any((col) => col['name'] == 'latitude');

          if (hasOldSchema) {
            debugPrint('⚠️ [DB] v6 — Old fake_gps_logs schema detected, dropping table');
            await db.execute('DROP TABLE $fakeGpsTable');
          }
        }

        await db.execute('''
          CREATE TABLE IF NOT EXISTS $fakeGpsTable (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            emp_id        TEXT    NOT NULL,
            emp_name      TEXT,
            company_code  TEXT,
            real_latitude  REAL,
            real_longitude REAL,
            real_address   TEXT,
            fake_latitude  REAL,
            fake_longitude REAL,
            fake_address   TEXT,
            distance_km    REAL,
            detected_at   TEXT    NOT NULL,
            posted        INTEGER DEFAULT 0
          )
        ''');
        debugPrint('✅ [DB] v6 — fake_gps_logs table created with correct schema');
      } catch (e) {
        debugPrint('⚠️ [DB] v6 — fake_gps_logs error: $e');
      }
    }

    // ── v7: (reserved) ────────────────────────────────────────────────────────

    // ── v8: Add location_name column to attendance_in ─────────────────────────
    if (oldVersion < 8) {
      await _safeAlter(db,
        'ALTER TABLE $attendanceTable ADD COLUMN location_name TEXT',
        '✅ [DB] v8 — location_name column added to attendance_in',
      );
    }

    // ── v9: Add location_name column to attendance_out ─────────────────────────
    if (oldVersion < 9) {
      await _safeAlter(db,
        'ALTER TABLE $attendanceOutTable ADD COLUMN location_name TEXT',
        '✅ [DB] v9 — location_name column added to attendance_out',
      );
    }

    // ── v10: Safety check - ensure location_name exists (in case v9 was missed) ──
    if (oldVersion < 10) {
      try {
        // Try to add it again (safe if already exists)
        await _safeAlter(db,
          'ALTER TABLE $attendanceOutTable ADD COLUMN location_name TEXT',
          '✅ [DB] v10 — safety check: location_name column ensured',
        );
      } catch (e) {
        debugPrint('✅ [DB] v10 — location_name column already exists');
      }
    }

    // ── v11: Add location_tracking table for offline GPS storage ──────────────
    if (oldVersion < 11) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS $locationTrackingTable(
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        locationtracking_id   TEXT UNIQUE,
        locationtracking_date TEXT,
        locationtracking_time TEXT,
        user_id               TEXT,
        lat_in                REAL,
        lng_in                REAL,
        booker_name           TEXT,
        designation           TEXT,
        company_code          TEXT,
        posted                INTEGER DEFAULT 0,
        created_at            TEXT DEFAULT (datetime('now'))
      )
      ''');

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_posted ON $locationTrackingTable(posted)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_company ON $locationTrackingTable(company_code)');
        debugPrint('✅ [DB] v11 — location_tracking table and indexes created');
      } catch (e) {
        debugPrint('⚠️ [DB] v11 — index creation error: $e');
      }

      debugPrint('✅ [DB] v11 migration complete');
    }

    // ── v12: Add clock_out_image column to attendance_out ────────────────────
    if (oldVersion < 12) {
      await _safeAlter(db,
        'ALTER TABLE $attendanceOutTable ADD COLUMN clock_out_image TEXT',
        '✅ [DB] v12 — clock_out_image column added to attendance_out',
      );
      debugPrint('✅ [DB] v12 migration complete');
    }
  }

  /// Runs an ALTER TABLE and swallows errors
  Future<void> _safeAlter(Database db, String sql, String successMsg) async {
    try {
      await db.execute(sql);
      debugPrint(successMsg);
    } catch (e) {
      debugPrint('⚠️ [DB] ALTER skipped (already applied?): $e');
    }
  }

  // ── CREATE (fresh install) ─────────────────────────────────────────────────
  Future<void> _createDB(Database db, int version) async {

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $attendanceTable(
      attendance_in_id   TEXT PRIMARY KEY,
      attendance_in_date TEXT,
      attendance_in_time TEXT,
      emp_id             TEXT,
      emp_name           TEXT,
      job                TEXT,
      lat_in             TEXT,
      lng_in             TEXT,
      city               TEXT,
      address            TEXT,
      location_name      TEXT,
      posted             INTEGER DEFAULT 0,
      profile            BLOB,
      company_code       TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $attendanceOutTable(
      attendance_out_id   TEXT PRIMARY KEY,
      attendance_out_date TEXT,
      attendance_out_time TEXT,
      total_time          TEXT,
      emp_id              TEXT,
      lat_out             TEXT,
      lng_out             TEXT,
      total_distance      TEXT,
      address             TEXT,
      location_name       TEXT,
      reason              TEXT DEFAULT 'manual',
      posted              INTEGER DEFAULT 0,
      company_code        TEXT,
      clock_out_image     TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $locationTable(
      location_id    TEXT PRIMARY KEY,
      location_date  TEXT,
      location_time  TEXT,
      file_name      TEXT,
      emp_id         TEXT,
      emp_name       TEXT,
      total_distance TEXT,
      posted         INTEGER DEFAULT 0,
      body           BLOB,
      company_code   TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $leaveTable(
      id               TEXT PRIMARY KEY,
      leave_id         TEXT UNIQUE,
      emp_id           TEXT,
      emp_name         TEXT,
      job_role         TEXT,
      leave_type       TEXT,
      start_date       TEXT,
      end_date         TEXT,
      total_days       INTEGER,
      is_half_day      INTEGER DEFAULT 0,
      reason           TEXT,
      attachment_data  BLOB,
      attachment_image TEXT,
      application_date TEXT,
      application_time TEXT,
      status           TEXT DEFAULT 'pending',
      posted           INTEGER DEFAULT 0,
      has_attachment   INTEGER DEFAULT 0,
      company_code     TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $taskTable(
      id               INTEGER,
      emp_id           INTEGER,
      emp_name         TEXT,
      task_title       TEXT,
      task_description TEXT,
      status           TEXT,
      priority         TEXT,
      due_date         TEXT,
      comments         TEXT,
      assigned_by      TEXT,
      created_at       TEXT    DEFAULT (datetime('now')),
      task_type        TEXT    DEFAULT 'SELF',
      company_code     TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $fakeGpsTable(
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      emp_id        TEXT    NOT NULL,
      emp_name      TEXT,
      company_code  TEXT,
      real_latitude  REAL,
      real_longitude REAL,
      real_address   TEXT,
      fake_latitude  REAL,
      fake_longitude REAL,
      fake_address   TEXT,
      distance_km    REAL,
      detected_at   TEXT    NOT NULL,
      posted        INTEGER DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS $locationTrackingTable(
      id                    INTEGER PRIMARY KEY AUTOINCREMENT,
      locationtracking_id   TEXT UNIQUE,
      locationtracking_date TEXT,
      locationtracking_time TEXT,
      user_id               TEXT,
      lat_in                REAL,
      lng_in                REAL,
      booker_name           TEXT,
      designation           TEXT,
      company_code          TEXT,
      posted                INTEGER DEFAULT 0,
      created_at            TEXT DEFAULT (datetime('now'))
    )
    ''');

    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_posted ON $locationTrackingTable(posted)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_location_tracking_company ON $locationTrackingTable(company_code)');
    } catch (e) {
      debugPrint('⚠️ [DB] Index creation error: $e');
    }
  }

  // ── INSERT ─────────────────────────────────────────────────────────────────
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;

    if (_currentCompanyCode != null) {
      final existing = data['company_code'];
      if (existing == null) {
        data['company_code'] = _currentCompanyCode;
        debugPrint('🏢 [DB] Auto-injected company_code: $_currentCompanyCode → $table');
      }
    }

    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Raw insert — skips company_code injection (internal use only)
  Future<int> insertRaw(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── GET ALL ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;

    if (_currentCompanyCode != null) {
      if (table == attendanceTable) {
        return await db.query(
          table,
          columns: [
            'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
            'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
            'city', 'address', 'location_name', 'posted', 'company_code',
          ],
          where: 'company_code = ?',
          whereArgs: [_currentCompanyCode],
        );
      }
      return await db.query(
        table,
        where: 'company_code = ?',
        whereArgs: [_currentCompanyCode],
      );
    }

    if (table == attendanceTable) {
      return await db.query(
        table,
        columns: [
          'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
          'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
          'city', 'address', 'location_name', 'posted', 'company_code',
        ],
      );
    }
    return await db.query(table);
  }

  // ── GET UNPOSTED ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUnposted(String table) async {
    final db = await database;

    if (_currentCompanyCode != null) {
      if (table == attendanceTable) {
        return await db.query(
          table,
          columns: [
            'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
            'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
            'city', 'address', 'location_name', 'posted', 'company_code',
          ],
          where: 'posted = ? AND company_code = ?',
          whereArgs: [0, _currentCompanyCode],
        );
      }
      return await db.query(
        table,
        where: 'posted = ? AND company_code = ?',
        whereArgs: [0, _currentCompanyCode],
      );
    }

    if (table == attendanceTable) {
      return await db.query(
        table,
        columns: [
          'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
          'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
          'city', 'address', 'location_name', 'posted',
        ],
        where: 'posted = ?',
        whereArgs: [0],
      );
    }
    return await db.query(
      table,
      where: 'posted = ?',
      whereArgs: [0],
    );
  }

  // ── GET PROFILE ────────────────────────────────────────────────────────────
  Future<String?> getProfile(String attendanceId) async {
    final db = await database;
    final rows = await db.query(
      attendanceTable,
      columns: ['profile'],
      where: 'attendance_in_id = ?'
          '${_currentCompanyCode != null ? " AND company_code = ?" : ""}',
      whereArgs: _currentCompanyCode != null
          ? [attendanceId, _currentCompanyCode]
          : [attendanceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['profile'] as String?;
  }

  // ── CLEANUP ────────────────────────────────────────────────────────────────
  Future<void> cleanupLargeProfiles() async {
    final db = await database;
    final cleared = await db.rawUpdate(
      "UPDATE $attendanceTable SET profile = NULL "
          "WHERE profile IS NOT NULL AND length(profile) > 50000",
    );
    debugPrint('🧹 [AttendanceRepo] cleanupLargeProfiles: cleared $cleared rows');
  }

  // ── MARK AS POSTED ─────────────────────────────────────────────────────────
  Future<int> markAsPosted(String table, String idColumn, String id) async {
    final db = await database;
    return await db.update(
      table,
      {"posted": 1},
      where: "$idColumn = ?",
      whereArgs: [id],
    );
  }

  // ── DELETE (soft — sets posted = -1) ──────────────────────────────────────
  Future<int> delete(String table, String idColumn, String id) async {
    final db = await database;
    return await db.update(
      table,
      {"posted": -1},
      where: "$idColumn = ?",
      whereArgs: [id],
    );
  }

  // ── DELETE (hard) ──────────────────────────────────────────────────────────
  Future<int> deleteHard(String table, String idColumn, String id) async {
    final db = await database;
    return await db.delete(
      table,
      where: "$idColumn = ?",
      whereArgs: [id],
    );
  }

  // ── GET ALL FOR COMPANY (admin use) ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllForCompany(
      String table, String companyCode) async {
    final db = await database;
    return await db.query(
      table,
      where: 'company_code = ?',
      whereArgs: [companyCode],
    );
  }

  // ── GET COMPANY CODE ASYNC ─────────────────────────────────────────────────
  static Future<String> getCompanyCodeAsync() async {
    if (_currentCompanyCode != null) {
      return _currentCompanyCode!;
    }

    final prefs = await SharedPreferences.getInstance();
    final companyCode = prefs.getString('companyCode') ?? '';
    if (companyCode.isNotEmpty) {
      _currentCompanyCode = companyCode;
    }
    return companyCode;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCATION TRACKING BULK OPERATIONS (v11)
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert multiple location tracking records in bulk
  Future<int> insertLocationTrackingBulk(List<Map<String, dynamic>> records) async {
    final db = await database;
    int inserted = 0;

    for (final record in records) {
      try {
        final data = Map<String, dynamic>.from(record);

        // Add company_code if missing
        if (_currentCompanyCode != null && data['company_code'] == null) {
          data['company_code'] = _currentCompanyCode;
        }

        // Remove 'id' if present (auto-increment)
        data.remove('id');

        await db.insert(
          locationTrackingTable,
          data,
          conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicates
        );
        inserted++;
      } catch (e) {
        debugPrint('⚠️ [DB] Insert location tracking error: $e');
      }
    }

    debugPrint('💾 [DB] Inserted $inserted location tracking records');
    return inserted;
  }

  /// Get unposted location tracking records
  Future<List<Map<String, dynamic>>> getUnpostedLocationTracking({int limit = 500}) async {
    final db = await database;

    String whereClause = 'posted = ?';
    List<dynamic> whereArgs = [0];

    if (_currentCompanyCode != null) {
      whereClause += ' AND company_code = ?';
      whereArgs.add(_currentCompanyCode);
    }

    return await db.query(
      locationTrackingTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Mark location tracking records as posted
  Future<int> markLocationTrackingAsPosted(List<int> ids) async {
    if (ids.isEmpty) return 0;

    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');

    final result = await db.rawUpdate(
      'UPDATE $locationTrackingTable SET posted = 1 WHERE id IN ($placeholders)',
      ids,
    );

    debugPrint('✅ [DB] Marked $result location tracking records as posted');
    return result;
  }

  /// Get count of unposted location tracking records
  Future<int> getUnpostedLocationTrackingCount() async {
    final db = await database;

    String whereClause = 'posted = ?';
    List<dynamic> whereArgs = [0];

    if (_currentCompanyCode != null) {
      whereClause += ' AND company_code = ?';
      whereArgs.add(_currentCompanyCode);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $locationTrackingTable WHERE $whereClause',
      whereArgs,
    );

    return result.first['count'] as int? ?? 0;
  }
}