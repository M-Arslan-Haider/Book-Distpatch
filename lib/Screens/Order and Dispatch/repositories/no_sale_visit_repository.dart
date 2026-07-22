// ═══════════════════════════════════════════════════════════════════════════
// no_sale_visit_repository.dart
//
// Standalone repository for the "No Sale of Stock" flow.
//
// API endpoints (same Oracle ORDS as booking flow):
//   GET  /addshopget/get/:emp_id           -> shops for this employee
//   GET  /brand/get/                       -> brands
//   GET  /products/get/?brand=...          -> products for a brand
//   POST /shop_visit/post/                 -> submit (visit_type='Shop Visit')
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/no_sale_visit_model.dart';

class NoSaleVisitRepository {
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
  Future<List<NoSaleShopOption>> getShops() async {
    final info = await getEmployeeInfo();
    final empId = info['empId'] ?? '';
    final companyCode = info['companyCode'] ?? '';

    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    print('📤 [NoSaleVisitRepository] GET $baseUrl$endpoint');
    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      print('📥 [NoSaleVisitRepository] getShops status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items
            .map((e) => NoSaleShopOption.fromJson(e as Map<String, dynamic>))
            .toList();
        print('✅ [NoSaleVisitRepository] parsed ${result.length} shops');
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [NoSaleVisitRepository] Error fetching shops: $e');
      return [];
    }
  }

  // ============= GET BRANDS =============
  Future<List<String>> getBrands() async {
    final endpoint = '$baseUrl/brand/get/';
    print('📤 [NoSaleVisitRepository] GET $endpoint');
    try {
      final response = await http.get(Uri.parse(endpoint));
      print('📥 [NoSaleVisitRepository] getBrands status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items
            .map((e) => (e['brand'] ?? e['BRAND'])?.toString() ?? '')
            .where((n) => n.trim().isNotEmpty)
            .toList();
        print('✅ [NoSaleVisitRepository] parsed ${result.length} brands');
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [NoSaleVisitRepository] Error fetching brands: $e');
      return [];
    }
  }

  // ============= GET PRODUCTS BY BRAND =============
  Future<List<StockCatalogProduct>> getProductsByBrand(String brand) async {
    final endpoint =
        '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    print('📤 [NoSaleVisitRepository] GET $endpoint');
    try {
      final response = await http.get(Uri.parse(endpoint));
      print('📥 [NoSaleVisitRepository] getProductsByBrand status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items.map((json) {
          final m = json as Map<String, dynamic>;
          final id = m['id']?.toString() ??
              m['ID']?.toString() ??
              m['product_id']?.toString() ??
              '';
          final name = m['product_name']?.toString() ??
              m['PRODUCT_NAME']?.toString() ??
              m['product']?.toString() ??
              m['PRODUCT']?.toString() ??
              m['name']?.toString() ??
              m['NAME']?.toString() ??
              '';
          final brandName = m['brand']?.toString() ?? m['BRAND']?.toString() ?? '';
          final priceStr = m['price']?.toString() ??
              m['PRICE']?.toString() ??
              m['product_price']?.toString() ??
              '0';
          return StockCatalogProduct(
            id: id,
            name: name,
            brand: brandName,
            price: double.tryParse(priceStr.replaceAll(',', '')) ?? 0,
          );
        }).where((p) => p.name.trim().isNotEmpty).toList();

        print('✅ [NoSaleVisitRepository] parsed ${result.length} products for "$brand"');
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [NoSaleVisitRepository] Error fetching products: $e');
      return [];
    }
  }

  // ============= SUBMIT NO-SALE VISIT =============
  Future<NoSaleSubmitResult> submitVisit(NoSaleVisitModel model) async {
    final endpoint = '$baseUrl/shopvisit/post/';

    try {
      final empInfo = await getEmployeeInfo();
      print('👤 [NoSaleVisitRepository] employee info: $empInfo');

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

      print('📤 [NoSaleVisitRepository] POST $endpoint');
      print('📤 [NoSaleVisitRepository] payload: ${jsonEncode(logSafePayload)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📥 [NoSaleVisitRepository] status: ${response.statusCode}');
      print('📥 [NoSaleVisitRepository] body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ok = data['status']?.toString() == 'success';
        if (ok) {
          print('✅ [NoSaleVisitRepository] visit saved: '
              'id=${data['id']} visit_id=${data['visit_id']}');
          return NoSaleSubmitResult(
            success: true,
            id: data['id']?.toString(),
            visitId: data['visit_id']?.toString(),
          );
        } else {
          print('❌ [NoSaleVisitRepository] server returned error: ${data['message']}');
          return NoSaleSubmitResult(
            success: false,
            message: data['message']?.toString() ?? 'Unknown server error',
          );
        }
      }

      print('❌ [NoSaleVisitRepository] non-2xx response: ${response.statusCode}');
      return NoSaleSubmitResult(
        success: false,
        message: 'Server returned ${response.statusCode}',
      );
    } catch (e, st) {
      print('💥 [NoSaleVisitRepository] submitVisit exception: $e');
      print(st);
      return NoSaleSubmitResult(success: false, message: e.toString());
    }
  }
}

/// Result of a submitVisit() call.
class NoSaleSubmitResult {
  final bool success;
  final String? id;
  final String? visitId;
  final String? message;

  NoSaleSubmitResult({
    required this.success,
    this.id,
    this.visitId,
    this.message,
  });
}

/// Shop option shown in NoSaleShopSelectScreen — mirrors ShopModel from
/// select_shop.dart but kept local so this flow has no cross-file dependency.
class NoSaleShopOption {
  final String shopId;
  final String shopName;
  final String ownerName;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;

  NoSaleShopOption({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory NoSaleShopOption.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return NoSaleShopOption(
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