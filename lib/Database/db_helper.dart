//
// import 'package:flutter/foundation.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
//
// class DBHelper {
//
//   static Database? _database;
//
//   static const String dbName             = "employee_portal.db";
//
//   static const String attendanceTable    = "attendance_in";
//   static const String attendanceOutTable = "attendance_out";
//   static const String locationTable      = "location";
//   static const String leaveTable         = "leave_application";
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB();
//     return _database!;
//   }
//
//   Future<Database> _initDB() async {
//     final path = join(await getDatabasesPath(), dbName);
//     return await openDatabase(
//       path,
//       version: 3,           // ← bumped from 2 → 3 for location schema change
//       onCreate : _createDB,
//       onUpgrade: _onUpgrade,
//     );
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // MIGRATIONS
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     if (oldVersion < 2) {
//       await db.execute(
//           'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB');
//       debugPrint('✅ [DB] v2 — profile column added to attendance_in');
//     }
//
//     if (oldVersion < 3) {
//       // Drop & recreate location table to match Oracle schema.
//       // (Old columns: location_id, location_date, location_time, file_name,
//       //               emp_id, emp_name, total_distance, posted, body)
//       await db.execute('DROP TABLE IF EXISTS $locationTable');
//       await db.execute(_locationTableDDL);
//       debugPrint('✅ [DB] v3 — location table recreated with new Oracle-aligned schema');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // CREATE
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _createDB(Database db, int) async {
//
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
//     /// Leave Application
//     await db.execute('''
//     CREATE TABLE IF NOT EXISTS $leaveTable(
//       id TEXT PRIMARY KEY,
//       leave_id TEXT UNIQUE,
//       emp_id TEXT,
//       emp_name TEXT,
//       job_role TEXT,
//       leave_type TEXT,
//       start_date TEXT,
//       end_date TEXT,
//       total_days INTEGER,
//       is_half_day INTEGER DEFAULT 0,
//       reason TEXT,
//       attachment_data BLOB,
//       attachment_image TEXT,
//       application_date TEXT,
//       application_time TEXT,
//       status TEXT DEFAULT 'pending',
//       posted INTEGER DEFAULT 0,
//       has_attachment INTEGER DEFAULT 0
//     )
//     ''');
//   }
//
//   /// Separate constant so _onUpgrade can reuse it without duplicating SQL.
//   ///
//   /// Column mapping (local name → Oracle column):
//   ///   location_id       → LOCATION_ID
//   ///   emp_id            → EMP_ID
//   ///   emp_name          → EMP_NAME
//   ///   file_data         → FILE_DATA  (stored as Base64 TEXT locally)
//   ///   file_name         → FILE_NAME
//   ///   current_time      → CURRENT_TIME
//   ///   total_distance    → TOTAL_DISTANCE
//   ///   location_time     → LOCATION_TIME
//   ///   location_date     → LOCATION_DATE
//   ///   attendance_out_id → ATTENDANCE_OUT_ID
//   ///   posted            → local-only flag (not sent to Oracle)
//   // db_helper.dart - Update the schema
//   static const String _locationTableDDL = '''
// CREATE TABLE IF NOT EXISTS location(
//   location_id       TEXT PRIMARY KEY,
//   emp_id            TEXT,
//   emp_name          TEXT,
//   body              BLOB,
//   file_name         TEXT,
//   current_time      TEXT,
//   total_distance    TEXT,
//   location_time     TEXT,
//   location_date     TEXT,
//   attendance_out_id TEXT,
//   posted            INTEGER DEFAULT 0
// )
// ''';
//   // ─────────────────────────────────────────────────────────────────────────
//   // CRUD HELPERS (generic – reused by all repositories)
//   // ─────────────────────────────────────────────────────────────────────────
//
//   Future<int> update(String table, Map<String, dynamic> data, String idColumn, String id) async {
//     final db = await database;
//     return await db.update(
//       table,
//       data,
//       where: '$idColumn = ?',
//       whereArgs: [id],
//     );
//   }
//
//   /// INSERT (replace on conflict)
//   Future<int> insert(String table, Map<String, dynamic> data) async {
//     final db = await database;
//     return await db.insert(table, data,
//         conflictAlgorithm: ConflictAlgorithm.replace);
//   }
//
//   /// GET ALL rows
//   Future<List<Map<String, dynamic>>> getAll(String table) async {
//     final db = await database;
//     return await db.query(table);
//   }
//
//   /// GET rows where posted = 0
//   Future<List<Map<String, dynamic>>> getUnposted(String table) async {
//     final db = await database;
//     return await db.query(table, where: 'posted = ?', whereArgs: [0]);
//   }
//
//   /// Mark a single row as posted (posted = 1)
//   Future<int> markAsPosted(
//       String table, String idColumn, String id) async {
//     final db = await database;
//     return await db.update(
//       table,
//       {'posted': 1},
//       where: '$idColumn = ?',
//       whereArgs: [id],
//     );
//   }
//
//   /// DELETE a single row
//   Future<int> delete(String table, String idColumn, String id) async {
//     final db = await database;
//     return await db.delete(
//       table,
//       where: '$idColumn = ?',
//       whereArgs: [id],
//     );
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {

  static Database? _database;

  static const String dbName = "employee_portal.db";

  static const String attendanceTable = "attendance_in";
  static const String attendanceOutTable = "attendance_out";
  static const String locationTable = "location";
  static const String leaveTable = "leave_application";

  Future<Database> get database async {

    if (_database != null) return _database!;

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {

    String path = join(await getDatabasesPath(), dbName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add profile column to existing attendance_in table
      await db.execute(
        'ALTER TABLE $attendanceTable ADD COLUMN profile BLOB',
      );
      debugPrint('✅ [DB] Migrated to v2 — profile column added');
    }
  }

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
  }

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

    return await db.query(table);
  }

  /// GET UNPOSTED DATA (Sync ke liye)
  Future<List<Map<String, dynamic>>> getUnposted(String table) async {

    final db = await database;

    return await db.query(
      table,
      where: "posted = ?",
      whereArgs: [0],
    );
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