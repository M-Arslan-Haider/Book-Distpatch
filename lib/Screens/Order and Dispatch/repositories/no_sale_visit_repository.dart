

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/no_sale_visit_model.dart';

class NoSaleVisitRepository {
  static const String baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce';

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

  // ============= GET SHOPS =============
  Future<List<NoSaleShopOption>> getShops() async {
    final info = await getEmployeeInfo();
    final empId = info['empId'] ?? '';
    final companyCode = info['companyCode'] ?? '';

    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_shops_$empId';  // ✅ Matches login preload
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedShops = cachedItems
            .map((e) => NoSaleShopOption.fromJson(e as Map<String, dynamic>))
            .toList();
        if (cachedShops.isNotEmpty) {
          print('📦 [NoSaleVisitRepository] Loaded ${cachedShops.length} shops from cache');
          _refreshShopsInBackground(empId, companyCode);
          return cachedShops;
        }
      } catch (e) {
        print('⚠️ [NoSaleVisitRepository] Error parsing cached shops: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items
            .map((e) => NoSaleShopOption.fromJson(e as Map<String, dynamic>))
            .toList();
        await prefs.setString(cachedKey, jsonEncode(items));
        return result;
      }
      return [];
    } catch (e) {
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems
              .map((e) => NoSaleShopOption.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshShopsInBackground(String empId, String companyCode) async {
    try {
      var endpoint = '/addshopget/get/$empId';
      if (companyCode.isNotEmpty) {
        endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
      }
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_shops_$empId', jsonEncode(items));
      }
    } catch (e) {
      print('⚠️ [NoSaleVisitRepository] Background shop refresh failed: $e');
    }
  }

  // ============= GET BRANDS =============
  Future<List<String>> getBrands() async {
    final endpoint = '$baseUrl/brand/get/';
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_brands';  // ✅ FIXED - matches login preload
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedBrands = cachedItems
            .map((e) => (e['brand'] ?? e['BRAND'])?.toString() ?? '')
            .where((n) => n.trim().isNotEmpty)
            .toList();
        if (cachedBrands.isNotEmpty) {
          print('📦 [NoSaleVisitRepository] Loaded ${cachedBrands.length} brands from cache');
          _refreshBrandsInBackground();
          return cachedBrands;
        }
      } catch (e) {
        print('⚠️ [NoSaleVisitRepository] Error parsing cached brands: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items
            .map((e) => (e['brand'] ?? e['BRAND'])?.toString() ?? '')
            .where((n) => n.trim().isNotEmpty)
            .toList();
        await prefs.setString(cachedKey, jsonEncode(items));
        return result;
      }
      return [];
    } catch (e) {
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems
              .map((e) => (e['brand'] ?? e['BRAND'])?.toString() ?? '')
              .where((n) => n.trim().isNotEmpty)
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshBrandsInBackground() async {
    try {
      final endpoint = '$baseUrl/brand/get/';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_brands', jsonEncode(items));
      }
    } catch (e) {
      print('⚠️ [NoSaleVisitRepository] Background brand refresh failed: $e');
    }
  }

  // ============= GET PRODUCTS BY BRAND =============
  Future<List<StockCatalogProduct>> getProductsByBrand(String brand) async {
    final endpoint =
        '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_products_$brand';  // ✅ Matches login preload
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedProducts = cachedItems.map((json) {
          final m = json as Map<String, dynamic>;
          return StockCatalogProduct(
            id: m['id']?.toString() ?? m['ID']?.toString() ?? '',
            name: m['product_name']?.toString() ??
                m['PRODUCT_NAME']?.toString() ??
                m['product']?.toString() ??
                m['PRODUCT']?.toString() ??
                m['name']?.toString() ??
                m['NAME']?.toString() ??
                '',
            brand: m['brand']?.toString() ?? m['BRAND']?.toString() ?? '',
            price: double.tryParse(
                (m['price']?.toString() ?? m['PRICE']?.toString() ?? '0')
                    .replaceAll(',', '')
            ) ?? 0,
          );
        }).where((p) => p.name.trim().isNotEmpty).toList();

        if (cachedProducts.isNotEmpty) {
          print('📦 [NoSaleVisitRepository] Loaded ${cachedProducts.length} products for "$brand" from cache');
          _refreshProductsInBackground(brand);
          return cachedProducts;
        }
      } catch (e) {
        print('⚠️ [NoSaleVisitRepository] Error parsing cached products: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final result = items.map((json) {
          final m = json as Map<String, dynamic>;
          return StockCatalogProduct(
            id: m['id']?.toString() ?? m['ID']?.toString() ?? '',
            name: m['product_name']?.toString() ??
                m['PRODUCT_NAME']?.toString() ??
                m['product']?.toString() ??
                m['PRODUCT']?.toString() ??
                m['name']?.toString() ??
                m['NAME']?.toString() ??
                '',
            brand: m['brand']?.toString() ?? m['BRAND']?.toString() ?? '',
            price: double.tryParse(
                (m['price']?.toString() ?? m['PRICE']?.toString() ?? '0')
                    .replaceAll(',', '')
            ) ?? 0,
          );
        }).where((p) => p.name.trim().isNotEmpty).toList();

        await prefs.setString(cachedKey, jsonEncode(items));
        return result;
      }
      return [];
    } catch (e) {
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems.map((json) {
            final m = json as Map<String, dynamic>;
            return StockCatalogProduct(
              id: m['id']?.toString() ?? m['ID']?.toString() ?? '',
              name: m['product_name']?.toString() ??
                  m['PRODUCT_NAME']?.toString() ??
                  m['product']?.toString() ??
                  m['PRODUCT']?.toString() ??
                  m['name']?.toString() ??
                  m['NAME']?.toString() ??
                  '',
              brand: m['brand']?.toString() ?? m['BRAND']?.toString() ?? '',
              price: double.tryParse(
                  (m['price']?.toString() ?? m['PRICE']?.toString() ?? '0')
                      .replaceAll(',', '')
              ) ?? 0,
            );
          }).where((p) => p.name.trim().isNotEmpty).toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshProductsInBackground(String brand) async {
    try {
      final endpoint = '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_products_$brand', jsonEncode(items));
      }
    } catch (e) {
      print('⚠️ [NoSaleVisitRepository] Background product refresh failed for "$brand": $e');
    }
  }

  // ============= SUBMIT NO-SALE VISIT - OFFLINE FIRST =============
  Future<NoSaleSubmitResult> submitVisit(NoSaleVisitModel model) async {
    final endpoint = '$baseUrl/shopvisit/post/';

    try {
      final empInfo = await getEmployeeInfo();

      final payload = model.toSubmitJson(
        employeeId: empInfo['empId'] ?? '',
        employeeName: empInfo['empName'] ?? '',
        companyCode: empInfo['companyCode'] ?? '',
      );

      // Log safe payload without base64
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
          print('✅ [NoSaleVisitRepository] visit saved online: ${data['visit_id']}');
          return NoSaleSubmitResult(
            success: true,
            id: data['id']?.toString(),
            visitId: data['visit_id']?.toString(),
          );
        }
      }

      // If server fails OR offline, queue it
      print('📦 [NoSaleVisitRepository] Queuing visit for offline sync...');
      await _queuePendingVisit(model, payload);

      // ✅ ALWAYS RETURN SUCCESS - User ko smoothly navigate karna hai
      return NoSaleSubmitResult(
        success: true,
        visitId: model.visitId,
        message: 'Visit saved locally (will sync when online)',
      );

    } catch (e, st) {
      print('💥 [NoSaleVisitRepository] submitVisit exception: $e');
      print(st);

      // Queue the visit
      try {
        final empInfo = await getEmployeeInfo();
        final payload = model.toSubmitJson(
          employeeId: empInfo['empId'] ?? '',
          employeeName: empInfo['empName'] ?? '',
          companyCode: empInfo['companyCode'] ?? '',
        );
        await _queuePendingVisit(model, payload);
        print('📦 [NoSaleVisitRepository] Visit queued for offline sync');
      } catch (queueError) {
        print('💥 [NoSaleVisitRepository] Error queueing visit: $queueError');
      }

      // ✅ ALWAYS RETURN SUCCESS - User ko error nahi dikhana
      return NoSaleSubmitResult(
        success: true,
        visitId: model.visitId,
        message: 'Visit saved locally (will sync when online)',
      );
    }
  }

  // ── Offline queue ──────────────────────────────────────────────────────
  Future<void> _queuePendingVisit(NoSaleVisitModel model, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'pending_visits_${model.shopId}';
      final existingQueue = prefs.getStringList(queueKey) ?? [];

      // Remove any existing entry for this visit_id
      existingQueue.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['visit_id'] == model.visitId;
        } catch (_) {
          return false;
        }
      });

      existingQueue.add(jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'payload': payload,
        'shop_id': model.shopId,
        'visit_id': model.visitId,
        'retry_count': 0,
      }));

      await prefs.setStringList(queueKey, existingQueue);
      print('📦 [NoSaleVisitRepository] Visit queued: ${model.visitId}');
      print('📦 [NoSaleVisitRepository] Total pending visits in queue: ${existingQueue.length}');
    } catch (e) {
      print('💥 [NoSaleVisitRepository] Error queueing visit: $e');
    }
  }

  // ============= SYNC PENDING VISITS =============
  Future<List<String>> syncPendingVisits() async {
    final syncedVisitIds = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final pendingKeys = allKeys.where((key) => key.startsWith('pending_visits_')).toList();

      print('📤 [NoSaleVisitRepository] Syncing ${pendingKeys.length} pending visit queues...');

      for (final key in pendingKeys) {
        final queue = prefs.getStringList(key) ?? [];
        if (queue.isEmpty) {
          await prefs.remove(key);
          continue;
        }

        print('📤 [NoSaleVisitRepository] Queue "$key" has ${queue.length} pending visits');
        final List<String> remainingQueue = [];

        for (final visitJson in queue) {
          try {
            final visitData = jsonDecode(visitJson) as Map<String, dynamic>;
            final payload = visitData['payload'] as Map<String, dynamic>;
            final endpoint = '$baseUrl/shopvisit/post/';

            print('📤 [NoSaleVisitRepository] POST $endpoint');
            print('📤 [NoSaleVisitRepository] payload: ${jsonEncode(payload)}');

            final response = await http.post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 30));

            print('📥 [NoSaleVisitRepository] status: ${response.statusCode}');
            print('📥 [NoSaleVisitRepository] body: ${response.body}');

            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              if (data['status']?.toString() == 'success') {
                syncedVisitIds.add(visitData['visit_id']?.toString() ?? '');
                print('✅ [NoSaleVisitRepository] Synced visit: ${visitData['visit_id']}');
                continue;
              }
            }
            // If failed, keep in queue
            print('⚠️ [NoSaleVisitRepository] Failed to sync visit: ${visitData['visit_id']}');
            remainingQueue.add(visitJson);
          } catch (e) {
            print('💥 [NoSaleVisitRepository] Error syncing visit: $e');
            remainingQueue.add(visitJson);
          }
        }

        if (remainingQueue.isEmpty) {
          await prefs.remove(key);
          print('🧹 [NoSaleVisitRepository] Cleared queue "$key"');
        } else {
          await prefs.setStringList(key, remainingQueue);
          print('📦 [NoSaleVisitRepository] ${remainingQueue.length} visits remaining in queue "$key"');
        }
      }
      print('✅ [NoSaleVisitRepository] Sync complete: ${syncedVisitIds.length} visits synced');
    } catch (e) {
      print('💥 [NoSaleVisitRepository] Error syncing pending visits: $e');
    }
    return syncedVisitIds;
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

/// Shop option shown in NoSaleShopSelectScreen
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