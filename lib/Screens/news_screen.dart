import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
// news_service.dart
//
// Fetches "Company → News" items for the logged-in company from the Oracle
// ORDS endpoint backed by APP_NOTIFICATIONS, then keeps only the rows whose
// START_DATE / END_DATE window includes today:
//
//   GET http://oracle.metaxperts.net/ords/gps_workforce/gpsnew/get/?company_code=...
//
//   select ID, TITLE, MESSAGE, TARGET_USER, DESCRIPTION, COMPANY_CODE,
//          START_DATE, END_DATE
//   from APP_NOTIFICATIONS
//   where company_code = :company_code
//
// Visibility rule (inclusive on both ends):
//   START_DATE = 16-Jun-2026  -> item starts showing ON 16-Jun-2026.
//   END_DATE   = 20-Jun-2026  -> item still shows on 20-Jun-2026,
//                                 stops showing from 21-Jun-2026 onward.
// ═══════════════════════════════════════════════════════════════════════════

class NewsItem {
  final int id;
  final String title;
  final String message;
  final String description;
  final String targetUser;
  final String companyCode;
  final String msgType;
  final DateTime? startDate;
  final DateTime? endDate;

  const NewsItem({
    required this.id,
    required this.title,
    required this.message,
    required this.description,
    required this.targetUser,
    required this.companyCode,
    required this.msgType,
    this.startDate,
    this.endDate,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: int.tryParse('${_field(json, 'id') ?? 0}') ?? 0,
      title: (_field(json, 'title') ?? '').toString(),
      message: (_field(json, 'message') ?? '').toString(),
      description: (_field(json, 'description') ?? '').toString(),
      targetUser: (_field(json, 'target_user') ?? '').toString(),
      companyCode: (_field(json, 'company_code') ?? '').toString(),
      msgType: (_field(json, 'msg_type') ?? '').toString().toLowerCase(),
      startDate: _parseOracleDate(_field(json, 'start_date')),
      endDate: _parseOracleDate(_field(json, 'end_date')),
    );
  }

  /// True when "today" falls within [startDate, endDate], inclusive on
  /// both ends. A null startDate means "no lower bound", a null endDate
  /// means "no upper bound / never expires".
  bool isVisibleToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (startDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (today.isBefore(start)) return false;
    }
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (today.isAfter(end)) return false;
    }
    return true;
  }
}

/// Reads a JSON field by key, case-insensitively. ORDS responses for
/// SQL-based handlers commonly return the column names exactly as written
/// in the SELECT (here: ID, TITLE, MESSAGE, ... in upper case), but this
/// keeps working even if a future version returns lower/camel case.
dynamic _field(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) return json[key];
  final upper = key.toUpperCase();
  if (json.containsKey(upper)) return json[upper];
  final lower = key.toLowerCase();
  if (json.containsKey(lower)) return json[lower];
  return null;
}

/// Parses the date strings coming back for START_DATE / END_DATE. Both
/// columns are VARCHAR2 on the Oracle side (not real DATE columns), so the
/// exact text format depends on how the row was inserted. This covers the
/// common formats seen from Oracle / ORDS / APEX:
///   "16-JUN-2026", "16-Jun-26", "2026-06-16", "2026-06-16T00:00:00Z", "16/06/2026"
DateTime? _parseOracleDate(dynamic raw) {
  if (raw == null) return null;
  final value = raw.toString().trim();
  if (value.isEmpty) return null;

  // 1) ISO-ish formats — let Dart's own parser try first.
  final iso = DateTime.tryParse(value);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  // 2) "DD-MON-YYYY" / "DD-MON-YY", e.g. 16-JUN-2026 / 16-JUN-26
  const months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };
  final dashParts = value.split('-');
  if (dashParts.length == 3) {
    final day = int.tryParse(dashParts[0]);
    final month = months[dashParts[1].toUpperCase()];
    var year = int.tryParse(dashParts[2]);
    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000; // "26" -> 2026
      return DateTime(year, month, day);
    }
  }

  // 3) "DD/MM/YYYY"
  final slashParts = value.split('/');
  if (slashParts.length == 3) {
    final day = int.tryParse(slashParts[0]);
    final month = int.tryParse(slashParts[1]);
    final year = int.tryParse(slashParts[2]);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}

class NewsService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/gpsnew/get/';

  /// Fetches every APP_NOTIFICATIONS row for [companyCode], then keeps only
  /// the ones whose START_DATE/END_DATE window covers today.
  static Future<List<NewsItem>> fetchNews(String companyCode) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'company_code': companyCode,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load news (status ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> rawItems;
    if (decoded is Map && decoded['items'] is List) {
      rawItems = decoded['items'] as List;
    } else if (decoded is List) {
      rawItems = decoded;
    } else {
      rawItems = const [];
    }

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map((row) => NewsItem.fromJson(row))
        .toList();

    return items
        .where((item) => item.isVisibleToday() && item.msgType == 'news')
        .toList();
  }

  /// Reads the logged-in user's company_code from SharedPreferences.
  /// NOTE: adjust the key(s) below if your app already stores company_code
  /// under a different key elsewhere (e.g. wherever emp_id / emp_name are
  /// read from in the rest of the app).
  static Future<String?> getStoredCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        prefs.getString('COMPANY_CODE');
  }
}


