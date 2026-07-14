import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/visit_model.dart';

class VisitRepository {
  static const String baseUrl = 'http://oracle.metaxperts.net/ords/gps_workforce';

  // ============= GET BRANDS =============
  Future<List<BrandItem>> getBrands() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/brand/get/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => BrandItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching brands: $e');
      return [];
    }
  }

  // ============= GET SHOPS =============
  Future<List<ShopItem>> getShops(String employeeId, {String? companyCode}) async {
    try {
      var endpoint = '/addshopget/get/$employeeId';
      if (companyCode != null && companyCode.isNotEmpty) {
        endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
      }
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => ShopItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching shops: $e');
      return [];
    }
  }

  // ============= GET PRODUCTS =============
  Future<List<ProductItem>> getProductsByBrand(String brand) async {
    try {
      final endpoint = '/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        return items.map((item) => ProductItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  // ============= SUBMIT VISIT =============
  Future<bool> submitVisit(Map<String, dynamic> visitData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/visit/submit'), // Adjust endpoint as needed
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(visitData),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting visit: $e');
      return false;
    }
  }
}