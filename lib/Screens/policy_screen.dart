import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'news_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// policy_service.dart
//
// Fetches "Company → Policy" items from the same Oracle ORDS endpoint as
// NewsService, keeping only rows whose MSG_TYPE is 'policy' and whose
// START_DATE / END_DATE window includes today.
//
//   GET http://oracle.metaxperts.net/ords/gps_workforce/gpsnew/get/?company_code=...
//
//   select ID, TITLE, MESSAGE, TARGET_USER, DESCRIPTION, COMPANY_CODE,
//          START_DATE, END_DATE, MSG_TYPE
//   from APP_NOTIFICATIONS
//   where company_code = :company_code
// ═══════════════════════════════════════════════════════════════════════════

class PolicyService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/gpsnew/get/';

  /// Fetches every APP_NOTIFICATIONS row for [companyCode], then keeps only
  /// the ones whose MSG_TYPE = 'policy' and whose START_DATE/END_DATE window
  /// covers today.
  static Future<List<NewsItem>> fetchPolicy(String companyCode) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'company_code': companyCode,
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load policy (status ${response.statusCode})');
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
        .where((item) => item.isVisibleToday() && item.msgType == 'policy')
        .toList();
  }

  /// Reads the logged-in user's company_code from SharedPreferences.
  static Future<String?> getStoredCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        prefs.getString('COMPANY_CODE');
  }
}