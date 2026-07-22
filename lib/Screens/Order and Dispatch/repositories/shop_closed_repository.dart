// ═══════════════════════════════════════════════════════════════════════════
// shop_closed_repository.dart
//
// Standalone repository for the "Shop Closed" flow.
//
// API endpoints (same Oracle ORDS as booking / no-sale flows):
//   GET  /addshopget/get/:emp_id -> shops for this employee
//   POST /shopvisit/post/        -> submit (visit_type='Shop Closed')
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/shop_closed_model.dart';

class ShopClosedRepository {
  static const String baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce';

  // ── Helper: Get employee info from SharedPreferences ────────────────
  Future<Map<String, String>> getEmployeeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';

    final empName = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('empName') ??
        prefs.getString('employee_name') ??
        prefs.getString('employeeName') ??
        '';

    final companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';

    return {'empId': empId, 'empName': empName, 'companyCode': companyCode};
  }

  // ============= GET SHOPS (for shop-select step) =============
  Future<List<ShopClosedShopOption>> getShops() async {
    final info = await getEmployeeInfo();
    final empId = info['empId'] ?? '';
    final companyCode = info['companyCode'] ?? '';

    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    print('📤 [ShopClosedRepository] GET $baseUrl$endpoint');
    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      print('📥 [ShopClosedRepository] getShops status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items
            .map((e) => ShopClosedShopOption.fromJson(e as Map<String, dynamic>))
            .toList();
        print('✅ [ShopClosedRepository] parsed ${result.length} shops');
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [ShopClosedRepository] Error fetching shops: $e');
      return [];
    }
  }

  // ============= SUBMIT SHOP CLOSED VISIT =============
  Future<ShopClosedSubmitResult> submitVisit(ShopClosedVisitModel model) async {
    final endpoint = '$baseUrl/shopvisit/post/';

    try {
      final empInfo = await getEmployeeInfo();
      print('👤 [ShopClosedRepository] employee info: $empInfo');

      final payload = model.toSubmitJson(
        employeeId: empInfo['empId'] ?? '',
        employeeName: empInfo['empName'] ?? '',
        companyCode: empInfo['companyCode'] ?? '',
      );

      // Don't dump full base64 image into the console.
      final logSafePayload = Map<String, dynamic>.from(payload);
      if (logSafePayload['shop_image'] != null) {
        logSafePayload['shop_image'] =
        '<base64 ${(logSafePayload['shop_image'] as String).length} chars>';
      }

      print('📤 [ShopClosedRepository] POST $endpoint');
      print('📤 [ShopClosedRepository] payload: ${jsonEncode(logSafePayload)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📥 [ShopClosedRepository] status: ${response.statusCode}');
      print('📥 [ShopClosedRepository] body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ok = data['status']?.toString() == 'success';
        if (ok) {
          print('✅ [ShopClosedRepository] visit saved: '
              'id=${data['id']} visit_id=${data['visit_id']}');
          return ShopClosedSubmitResult(
            success: true,
            id: data['id']?.toString(),
            visitId: data['visit_id']?.toString(),
          );
        } else {
          print('❌ [ShopClosedRepository] server returned error: ${data['message']}');
          return ShopClosedSubmitResult(
            success: false,
            message: data['message']?.toString() ?? 'Unknown server error',
          );
        }
      }

      print('❌ [ShopClosedRepository] non-2xx response: ${response.statusCode}');
      return ShopClosedSubmitResult(
        success: false,
        message: 'Server returned ${response.statusCode}',
      );
    } catch (e, st) {
      print('💥 [ShopClosedRepository] submitVisit exception: $e');
      print(st);
      return ShopClosedSubmitResult(success: false, message: e.toString());
    }
  }
}

/// Result of a submitVisit() call.
class ShopClosedSubmitResult {
  final bool success;
  final String? id;
  final String? visitId;
  final String? message;

  ShopClosedSubmitResult({
    required this.success,
    this.id,
    this.visitId,
    this.message,
  });
}

/// Shop option shown in ShopClosedShopSelectScreen.
class ShopClosedShopOption {
  final String shopId;
  final String shopName;
  final String ownerName;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;

  ShopClosedShopOption({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory ShopClosedShopOption.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ShopClosedShopOption(
      shopId: json['shop_id']?.toString() ?? json['id']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
    );
  }
}