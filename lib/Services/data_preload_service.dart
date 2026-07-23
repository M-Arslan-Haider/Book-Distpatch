// lib/Services/data_preload_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DataPreloadService {
  static const String _baseUrl = 'http://oracle.metaxperts.net/ords/gps_workforce';

  // Cache Keys - ALL consistent across the app
  static const String KEY_CITIES = 'cached_cities';
  static const String KEY_BRANDS = 'cached_brands';  // ✅ Consistent
  static const String KEY_PRODUCTS_PREFIX = 'cached_products_';
  static const String KEY_SHOPS_PREFIX = 'cached_shops_';
  static const String KEY_LOCATIONS = 'cached_locations';

  /// ═══════════════════════════════════════════════════════════════
  /// MAIN METHOD - Call after successful login
  /// ═══════════════════════════════════════════════════════════════
  static Future<void> preloadAllData({
    required String empId,
    required String companyCode,
  }) async {
    debugPrint('📦 [PRELOAD] Starting...');

    try {
      // ── 1. Cities ──────────────────────────────────────────────
      await _fetchCities();

      // ── 2. Brands ──────────────────────────────────────────────
      final brands = await _fetchBrands();

      // ── 3. Products (for first 3 brands) ──────────────────────
      if (brands.isNotEmpty) {
        for (var i = 0; i < brands.length && i < 3; i++) {
          await _fetchProducts(brands[i]);
        }
      }

      // ── 4. Shops ───────────────────────────────────────────────
      await _fetchShops(empId, companyCode);

      // ── 5. Locations ────────────────────────────────────────────
      await _fetchLocations(empId, companyCode);

      debugPrint('✅ [PRELOAD] Complete!');
    } catch (e) {
      debugPrint('❌ [PRELOAD] Error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // INDIVIDUAL FETCH METHODS
  // ═══════════════════════════════════════════════════════════════

  static Future<void> _fetchCities() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/city/get/'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(KEY_CITIES, jsonEncode(items));
        debugPrint('✅ [PRELOAD] Cities: ${items.length} cached');
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Cities error: $e');
    }
  }

  static Future<List<String>> _fetchBrands() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/brand/get/'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(KEY_BRANDS, jsonEncode(items));  // ✅ Consistent

        final brands = items
            .map((e) => (e['brand'] ?? e['BRAND'])?.toString() ?? '')
            .where((b) => b.trim().isNotEmpty)
            .toList();

        debugPrint('✅ [PRELOAD] Brands: ${brands.length} cached');
        return brands;
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Brands error: $e');
      return [];
    }
  }

  static Future<void> _fetchProducts(String brand) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${KEY_PRODUCTS_PREFIX}$brand', jsonEncode(items));  // ✅ Consistent
        debugPrint('✅ [PRELOAD] Products for "$brand": ${items.length} cached');
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Products error for "$brand": $e');
    }
  }

  static Future<void> _fetchShops(String empId, String companyCode) async {
    try {
      var endpoint = '/addshopget/get/$empId';
      if (companyCode.isNotEmpty) {
        endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${KEY_SHOPS_PREFIX}$empId', jsonEncode(items));  // ✅ Consistent
        debugPrint('✅ [PRELOAD] Shops: ${items.length} cached');
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Shops error: $e');
    }
  }

  static Future<void> _fetchLocations(String empId, String companyCode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/locations/get/?emp_id=$empId&company_code=${Uri.encodeQueryComponent(companyCode)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(KEY_LOCATIONS, jsonEncode(items));
        debugPrint('✅ [PRELOAD] Locations: ${items.length} cached');
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Locations error: $e');
    }
  }
}