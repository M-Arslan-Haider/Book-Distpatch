//
// import 'package:flutter/foundation.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
//
// class DBHelper {
//
//   static Database? _database;
//
//   static const String dbName = "employee_portal.db";
//
//   static const String attendanceTable = "attendance_in";
//   static const String attendanceOutTable = "attendance_out";
//   static const String locationTable = "location";
//   static const String leaveTable = "leave_application";
//
//   Future<Database> get database async {
//
//     if (_database != null) return _database!;
//
//     _database = await _initDB();
//     return _database!;
//   }
//
//   Future<Database> _initDB() async {
//
//     String path = join(await getDatabasesPath(), dbName);
//
//     return await openDatabase(
//       path,
//       version: 2,
//       onCreate: _createDB,
//       onUpgrade: _onUpgrade,
//     );
//   }
//
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     if (oldVersion < 2) {
//       // Add profile column to existing attendance_in table
//       await db.execute(
//         'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB',
//       );
//       debugPrint('✅ [DB] Migrated to v2 — profile column added');
//     }
//   }
//
//   Future<void> _createDB(Database db, int version) async {
//     ///
//     /// Attendance IN
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $attendanceTable(
//       attendance_in_id TEXT PRIMARY KEY,
//       attendance_in_date TEXT,
//       attendance_in_time TEXT,
//       emp_id TEXT,
//       emp_name TEXT,
//       job TEXT,
//       lat_in TEXT,
//       lng_in TEXT,
//       city TEXT,
//       address TEXT,
//       posted INTEGER DEFAULT 0,
//       profile BLOB
//     )
//     ''');
//
//     /// Attendance OUT
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $attendanceOutTable(
//       attendance_out_id TEXT PRIMARY KEY,
//       attendance_out_date TEXT,
//       attendance_out_time TEXT,
//       total_time TEXT,
//       emp_id TEXT,
//       lat_out TEXT,
//       lng_out TEXT,
//       total_distance TEXT,
//       address TEXT,
//       reason TEXT DEFAULT 'manual',
//       posted INTEGER DEFAULT 0
//     )
//     ''');
//
//     /// Location
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $locationTable(
//       location_id TEXT PRIMARY KEY,
//       location_date TEXT,
//       location_time TEXT,
//       file_name TEXT,
//       emp_id TEXT,
//       emp_name TEXT,
//       total_distance TEXT,
//       posted INTEGER DEFAULT 0,
//       body BLOB
//     )
//     ''');
//
//     /// Leave Application
//     await db.execute('''
// CREATE TABLE IF NOT EXISTS $leaveTable(
//   id TEXT PRIMARY KEY,
//   leave_id TEXT UNIQUE,
//   emp_id TEXT,
//   emp_name TEXT,
//   job_role TEXT,
//   leave_type TEXT,
//   start_date TEXT,
//   end_date TEXT,
//   total_days INTEGER,
//   is_half_day INTEGER DEFAULT 0,
//   reason TEXT,
//   attachment_data BLOB,
//   attachment_image TEXT,
//   application_date TEXT,
//   application_time TEXT,
//   status TEXT DEFAULT 'pending',
//   posted INTEGER DEFAULT 0,
//   has_attachment INTEGER DEFAULT 0
// )
// ''');
//   }
//
//   /// INSERT
//   Future<int> insert(String table, Map<String, dynamic> data) async {
//
//     final db = await database;
//
//     return await db.insert(
//       table,
//       data,
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
//
//   /// GET ALL
//   /// For attendance_in: excludes the profile column so large blobs never
//   /// crash SQLite's CursorWindow (2 MB row limit). Profile is only read
//   /// by the repo when explicitly needed for API upload.
//   Future<List<Map<String, dynamic>>> getAll(String table) async {
//     final db = await database;
//
//     if (table == attendanceTable) {
//       return await db.query(
//         table,
//         columns: [
//           'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//           'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//           'city', 'address', 'posted',
//         ],
//       );
//     }
//
//     return await db.query(table);
//   }
//
//   /// GET UNPOSTED DATA (Sync ke liye)
//   /// Same as getAll — excludes profile blob for attendance_in.
//   Future<List<Map<String, dynamic>>> getUnposted(String table) async {
//     final db = await database;
//
//     if (table == attendanceTable) {
//       return await db.query(
//         table,
//         columns: [
//           'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
//           'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
//           'city', 'address', 'posted',
//         ],
//         where: 'posted = ?',
//         whereArgs: [0],
//       );
//     }
//
//     return await db.query(
//       table,
//       where: 'posted = ?',
//       whereArgs: [0],
//     );
//   }
//
//   /// GET PROFILE — reads only the profile column for one attendance_in row.
//   /// Called by the repo before an API POST to get the stored thumbnail.
//   Future<String?> getProfile(String attendanceId) async {
//     final db = await database;
//     final rows = await db.query(
//       attendanceTable,
//       columns: ['profile'],
//       where: 'attendance_in_id = ?',
//       whereArgs: [attendanceId],
//       limit: 1,
//     );
//     if (rows.isEmpty) return null;
//     return rows.first['profile'] as String?;
//   }
//
//   /// CLEANUP — NULLs out oversized profile blobs written before the
//   /// compression fix.  Runs once at startup; safe to call repeatedly.
//   Future<void> cleanupLargeProfiles() async {
//     final db = await database;
//     final cleared = await db.rawUpdate(
//       "UPDATE $attendanceTable SET profile = NULL "
//           "WHERE profile IS NOT NULL AND length(profile) > 50000",
//     );
//     debugPrint('🧹 [DB] cleanupLargeProfiles: $cleared rows cleared');
//   }
//
//   /// UPDATE POSTED STATUS
//   Future<int> markAsPosted(String table, String idColumn, String id) async {
//
//     final db = await database;
//
//     return await db.update(
//       table,
//       {"posted": 1},
//       where: "$idColumn = ?",
//       whereArgs: [id],
//     );
//   }
//
//   /// DELETE
//   Future<int> delete(String table, String idColumn, String id) async {
//
//     final db = await database;
//
//     return await db.delete(
//       table,
//       where: "$idColumn = ?",
//       whereArgs: [id],
//     );
//   }
//
// }

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {

  static Database? _database;

  static const String dbName             = "employee_portal.db";

  static const String attendanceTable    = "attendance_in";
  static const String attendanceOutTable = "attendance_out";
  static const String locationTable      = "location";
  static const String leaveTable         = "leave_application";
  static const String taskTable          = "tasks";

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: 4,                // ← bumped 3 → 4
      onCreate:  _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ── MIGRATIONS ─────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB',
      );
      debugPrint('✅ [DB] v2 — profile column added to attendance_in');
    }

    if (oldVersion < 3) {
      // Existing users get the tasks table on next app launch
      await db.execute(_taskTableDDL);
      debugPrint('✅ [DB] v3 — tasks table created');
    }

    if (oldVersion < 4) {
      // ← NEW: add task_type column with default 'SELF' to existing tasks table
      await db.execute(
        "ALTER TABLE $taskTable ADD COLUMN task_type TEXT DEFAULT 'SELF'",
      );
      debugPrint('✅ [DB] v4 — task_type column added to tasks');
    }
  }

  // ── CREATE (fresh install) ─────────────────────────────────────────────────
  Future<void> _createDB(Database db, int version) async {

    /// Attendance IN
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $attendanceTable(
      attendance_in_id TEXT PRIMARY KEY,
      attendance_in_date TEXT,
      attendance_in_time TEXT,
      emp_id TEXT,
      emp_name TEXT,
      job TEXT,
      lat_in TEXT,
      lng_in TEXT,
      city TEXT,
      address TEXT,
      posted INTEGER DEFAULT 0,
      profile BLOB
    )
    ''');

    /// Attendance OUT
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $attendanceOutTable(
      attendance_out_id TEXT PRIMARY KEY,
      attendance_out_date TEXT,
      attendance_out_time TEXT,
      total_time TEXT,
      emp_id TEXT,
      lat_out TEXT,
      lng_out TEXT,
      total_distance TEXT,
      address TEXT,
      reason TEXT DEFAULT 'manual',
      posted INTEGER DEFAULT 0
    )
    ''');

    /// Location
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $locationTable(
      location_id TEXT PRIMARY KEY,
      location_date TEXT,
      location_time TEXT,
      file_name TEXT,
      emp_id TEXT,
      emp_name TEXT,
      total_distance TEXT,
      posted INTEGER DEFAULT 0,
      body BLOB
    )
    ''');

    /// Leave Application
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $leaveTable(
      id TEXT PRIMARY KEY,
      leave_id TEXT UNIQUE,
      emp_id TEXT,
      emp_name TEXT,
      job_role TEXT,
      leave_type TEXT,
      start_date TEXT,
      end_date TEXT,
      total_days INTEGER,
      is_half_day INTEGER DEFAULT 0,
      reason TEXT,
      attachment_data BLOB,
      attachment_image TEXT,
      application_date TEXT,
      application_time TEXT,
      status TEXT DEFAULT 'pending',
      posted INTEGER DEFAULT 0,
      has_attachment INTEGER DEFAULT 0
    )
    ''');

    /// Tasks — columns match TaskModel exactly
    await db.execute(_taskTableDDL);
  }

  // ── Task table DDL — mirrors Oracle schema exactly ────────────────────────
  //  Oracle  → SQLite
  //  NUMBER  → INTEGER
  //  VARCHAR2/ Varchar → TEXT
  //  DATE    → TEXT  (stored as 'YYYY-MM-DD', matches Oracle DATE format)
  //  DEFAULT SYSDATE → DEFAULT (datetime('now'))
  //  task_type → TEXT DEFAULT 'SELF'   ← NEW column
  // ──────────────────────────────────────────────────────────────────────────
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
      task_type        TEXT    DEFAULT 'SELF'
    )
  ''';

  // ── All existing methods — unchanged ───────────────────────────────────────

  /// INSERT
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// GET ALL
  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final db = await database;

    if (table == attendanceTable) {
      return await db.query(
        table,
        columns: [
          'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
          'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
          'city', 'address', 'posted',
        ],
      );
    }

    return await db.query(table);
  }

  /// GET UNPOSTED DATA (Sync ke liye)
  Future<List<Map<String, dynamic>>> getUnposted(String table) async {
    final db = await database;

    if (table == attendanceTable) {
      return await db.query(
        table,
        columns: [
          'attendance_in_id', 'attendance_in_date', 'attendance_in_time',
          'emp_id', 'emp_name', 'job', 'lat_in', 'lng_in',
          'city', 'address', 'posted',
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

  /// GET PROFILE
  Future<String?> getProfile(String attendanceId) async {
    final db = await database;
    final rows = await db.query(
      attendanceTable,
      columns: ['profile'],
      where: 'attendance_in_id = ?',
      whereArgs: [attendanceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['profile'] as String?;
  }

  /// CLEANUP large profiles
  Future<void> cleanupLargeProfiles() async {
    final db = await database;
    final cleared = await db.rawUpdate(
      "UPDATE $attendanceTable SET profile = NULL "
          "WHERE profile IS NOT NULL AND length(profile) > 50000",
    );
    debugPrint('🧹 [DB] cleanupLargeProfiles: $cleared rows cleared');
  }

  /// UPDATE POSTED STATUS
  Future<int> markAsPosted(String table, String idColumn, String id) async {
    final db = await database;
    return await db.update(
      table,
      {"posted": 1},
      where: "$idColumn = ?",
      whereArgs: [id],
    );
  }

  /// DELETE
  Future<int> delete(String table, String idColumn, String id) async {
    final db = await database;
    return await db.delete(
      table,
      where: "$idColumn = ?",
      whereArgs: [id],
    );
  }
}