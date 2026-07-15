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
      // Clean and prepare the data
      final cleanedData = Map<String, dynamic>.from(visitData);

      // Ensure products is properly formatted
      if (cleanedData.containsKey('products')) {
        final products = cleanedData['products'] as List;
        cleanedData['products'] = products.map((p) => {
          'id': p['id']?.toString() ?? '',
          'name': p['name']?.toString() ?? '',
          'brand': p['brand']?.toString() ?? '',
          'price': p['price']?.toString() ?? '',
          'quantity': (p['quantity'] as num?)?.toInt() ?? 0,
        }).toList();
      }

      // Remove null values (except for shop_image which can be null)
      final Map<String, dynamic> finalData = {};
      cleanedData.forEach((key, value) {
        if (value != null || key == 'shop_image') {
          finalData[key] = value;
        }
      });

      print('Submitting visit data: ${jsonEncode(finalData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/shop_visit/post/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(finalData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202;
    } catch (e) {
      print('Error submitting visit: $e');
      return false;
    }
  }
}