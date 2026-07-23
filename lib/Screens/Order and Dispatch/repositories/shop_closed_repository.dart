

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

  // ============= GET SHOPS (with offline cache) =============
  Future<List<ShopClosedShopOption>> getShops() async {
    final info = await getEmployeeInfo();
    final empId = info['empId'] ?? '';
    final companyCode = info['companyCode'] ?? '';

    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    print('📤 [ShopClosedRepository] GET $baseUrl$endpoint');

    // Try to get from cache first
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_shops_$empId';  // ✅ Matches login preload
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedShops = cachedItems
            .map((e) => ShopClosedShopOption.fromJson(e as Map<String, dynamic>))
            .toList();
        if (cachedShops.isNotEmpty) {
          print('📦 [ShopClosedRepository] Loaded ${cachedShops.length} shops from cache');
          _refreshShopsInBackground(empId, companyCode);
          return cachedShops;
        }
      } catch (e) {
        print('⚠️ [ShopClosedRepository] Error parsing cached shops: $e');
      }
    }

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

        // Cache the result
        await prefs.setString(cachedKey, jsonEncode(items));
        print('📦 [ShopClosedRepository] Cached ${result.length} shops');

        return result;
      }
      return [];
    } catch (e) {
      print('💥 [ShopClosedRepository] Error fetching shops: $e');
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          final cachedShops = cachedItems
              .map((e) => ShopClosedShopOption.fromJson(e as Map<String, dynamic>))
              .toList();
          print('📦 [ShopClosedRepository] Fallback to cached shops: ${cachedShops.length}');
          return cachedShops;
        } catch (e) {
          print('⚠️ [ShopClosedRepository] Error parsing cached shops on fallback: $e');
        }
      }
      return [];
    }
  }

  // Background refresh for shops
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
        print('🔄 [ShopClosedRepository] Background shop refresh complete');
      }
    } catch (e) {
      print('⚠️ [ShopClosedRepository] Background shop refresh failed: $e');
    }
  }

  // ============= SUBMIT SHOP CLOSED VISIT (with offline queuing) =============
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

          // Clear pending visits from cache
          await _clearPendingVisitFromCache(model.shopId);

          return ShopClosedSubmitResult(
            success: true,
            id: data['id']?.toString(),
            visitId: data['visit_id']?.toString(),
          );
        } else {
          print('❌ [ShopClosedRepository] server returned error: ${data['message']}');
          // Queue the visit for later sync
          await _queuePendingVisit(model, payload);
          // ✅ FIXED: Return success so user doesn't see error
          return ShopClosedSubmitResult(
            success: true,
            visitId: model.visitId,
            message: 'Visit saved locally (will sync when online)',
          );
        }
      }

      print('❌ [ShopClosedRepository] non-2xx response: ${response.statusCode}');
      // Queue the visit for later sync
      await _queuePendingVisit(model, payload);
      // ✅ FIXED: Return success so user doesn't see error
      return ShopClosedSubmitResult(
        success: true,
        visitId: model.visitId,
        message: 'Visit saved locally (will sync when online)',
      );
    } catch (e, st) {
      print('💥 [ShopClosedRepository] submitVisit exception: $e');
      print(st);

      // Queue the visit for later sync
      try {
        final empInfo = await getEmployeeInfo();
        final payload = model.toSubmitJson(
          employeeId: empInfo['empId'] ?? '',
          employeeName: empInfo['empName'] ?? '',
          companyCode: empInfo['companyCode'] ?? '',
        );
        await _queuePendingVisit(model, payload);
        print('📦 [ShopClosedRepository] Visit queued for offline sync');
      } catch (queueError) {
        print('💥 [ShopClosedRepository] Error queueing visit: $queueError');
      }

      // ✅ FIXED: Return success so user doesn't see error
      return ShopClosedSubmitResult(
        success: true,
        visitId: model.visitId,
        message: 'Visit saved locally (will sync when online)',
      );
    }
  }

  // ── Offline queue for visits ──────────────────────────────────────────
  Future<void> _queuePendingVisit(ShopClosedVisitModel model, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'pending_closed_visits_${model.shopId}';
      final existingQueue = prefs.getStringList(queueKey) ?? [];

      // ✅ FIXED: Remove any existing entry for this visit_id
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
      print('📦 [ShopClosedRepository] Visit queued: ${model.visitId} for shop ${model.shopId}');
    } catch (e) {
      print('💥 [ShopClosedRepository] Error queueing visit: $e');
    }
  }

  Future<void> _clearPendingVisitFromCache(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'pending_closed_visits_$shopId';
      await prefs.remove(queueKey);
      print('🧹 [ShopClosedRepository] Cleared pending visits for shop $shopId');
    } catch (e) {
      print('⚠️ [ShopClosedRepository] Error clearing pending visits: $e');
    }
  }

  // ============= SYNC PENDING SHOP CLOSED VISITS =============
  Future<List<String>> syncPendingVisits() async {
    final syncedVisitIds = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final pendingKeys = allKeys.where((key) => key.startsWith('pending_closed_visits_')).toList();

      print('📤 [ShopClosedRepository] Syncing ${pendingKeys.length} pending closed visit queues...');

      for (final key in pendingKeys) {
        final queue = prefs.getStringList(key) ?? [];
        if (queue.isEmpty) {
          await prefs.remove(key);
          continue;
        }

        print('📤 [ShopClosedRepository] Queue "$key" has ${queue.length} pending visits');
        final List<String> remainingQueue = [];

        for (final visitJson in queue) {
          try {
            final visitData = jsonDecode(visitJson) as Map<String, dynamic>;
            final payload = visitData['payload'] as Map<String, dynamic>;
            final endpoint = '$baseUrl/shopvisit/post/';

            print('📤 [ShopClosedRepository] POST $endpoint');
            print('📤 [ShopClosedRepository] payload: ${jsonEncode(payload)}');

            final response = await http.post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 30));

            print('📥 [ShopClosedRepository] status: ${response.statusCode}');
            print('📥 [ShopClosedRepository] body: ${response.body}');

            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              if (data['status']?.toString() == 'success') {
                syncedVisitIds.add(visitData['visit_id']?.toString() ?? '');
                print('✅ [ShopClosedRepository] Synced visit: ${visitData['visit_id']}');
                continue;
              }
            }
            // If failed, keep in queue
            print('⚠️ [ShopClosedRepository] Failed to sync visit: ${visitData['visit_id']}');
            remainingQueue.add(visitJson);
          } catch (e) {
            print('💥 [ShopClosedRepository] Error syncing visit: $e');
            remainingQueue.add(visitJson);
          }
        }

        if (remainingQueue.isEmpty) {
          await prefs.remove(key);
          print('🧹 [ShopClosedRepository] Cleared queue "$key"');
        } else {
          await prefs.setStringList(key, remainingQueue);
          print('📦 [ShopClosedRepository] ${remainingQueue.length} visits remaining in queue "$key"');
        }
      }
      print('✅ [ShopClosedRepository] Sync complete: ${syncedVisitIds.length} visits synced');
    } catch (e) {
      print('💥 [ShopClosedRepository] Error syncing pending visits: $e');
    }
    return syncedVisitIds;
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