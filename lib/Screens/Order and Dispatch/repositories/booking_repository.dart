

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_flow_model.dart';

class BookingRepository {
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

  // ============= GET BRANDS (with offline cache) =============
  Future<List<BrandItem>> getBrands() async {
    final endpoint = '$baseUrl/brand/get/';
    print('📤 [BookingRepository] GET $endpoint');

    // Try to get from cache first (for offline use)
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_brands';
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedBrands = cachedItems
            .map((item) => BrandItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedBrands.isNotEmpty) {
          print('📦 [BookingRepository] Loaded ${cachedBrands.length} brands from cache');
          // Return cached data immediately, but still try to refresh in background
          _refreshBrandsInBackground();
          return cachedBrands;
        }
      } catch (e) {
        print('⚠️ [BookingRepository] Error parsing cached brands: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      print('📥 [BookingRepository] getBrands status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final result = items
            .map((item) => BrandItem.fromJson(item as Map<String, dynamic>))
            .toList();
        print('✅ [BookingRepository] parsed ${result.length} brands');

        // Cache the result for offline use
        await prefs.setString(cachedKey, jsonEncode(items));
        print('📦 [BookingRepository] Cached ${result.length} brands');

        return result;
      }
      return [];
    } catch (e) {
      print('💥 [BookingRepository] Error fetching brands: $e');
      // Return cached data if available (fallback)
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          final cachedBrands = cachedItems
              .map((item) => BrandItem.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 [BookingRepository] Fallback to cached brands: ${cachedBrands.length}');
          return cachedBrands;
        } catch (e) {
          print('⚠️ [BookingRepository] Error parsing cached brands on fallback: $e');
        }
      }
      return [];
    }
  }

  // Background refresh for brands
  Future<void> _refreshBrandsInBackground() async {
    try {
      final endpoint = '$baseUrl/brand/get/';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_brands', jsonEncode(items));
        print('🔄 [BookingRepository] Background brand refresh complete');
      }
    } catch (e) {
      print('⚠️ [BookingRepository] Background brand refresh failed: $e');
    }
  }

  // ============= GET PRODUCTS BY BRAND (with offline cache) =============
  Future<List<ProductItem>> getProductsByBrand(String brand) async {
    final endpoint =
        '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    print('📤 [BookingRepository] GET $endpoint');

    // Try to get from cache first
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_products_$brand';  // ✅ Matches login preload
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedProducts = cachedItems
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedProducts.isNotEmpty) {
          print('📦 [BookingRepository] Loaded ${cachedProducts.length} products for "$brand" from cache');
          // Refresh in background
          _refreshProductsInBackground(brand);
          return cachedProducts;
        }
      } catch (e) {
        print('⚠️ [BookingRepository] Error parsing cached products: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      print('📥 [BookingRepository] getProductsByBrand status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final result = items
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();
        print('✅ [BookingRepository] parsed ${result.length} products for "$brand"');

        // Cache the result
        await prefs.setString(cachedKey, jsonEncode(items));
        print('📦 [BookingRepository] Cached ${result.length} products for "$brand"');

        return result;
      }
      return [];
    } catch (e) {
      print('💥 [BookingRepository] Error fetching products: $e');
      // Return cached data if available
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          final cachedProducts = cachedItems
              .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
              .toList();
          print('📦 [BookingRepository] Fallback to cached products: ${cachedProducts.length} for "$brand"');
          return cachedProducts;
        } catch (e) {
          print('⚠️ [BookingRepository] Error parsing cached products on fallback: $e');
        }
      }
      return [];
    }
  }

  // Background refresh for products
  Future<void> _refreshProductsInBackground(String brand) async {
    try {
      final endpoint = '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_products_$brand', jsonEncode(items));
        print('🔄 [BookingRepository] Background product refresh complete for "$brand"');
      }
    } catch (e) {
      print('⚠️ [BookingRepository] Background product refresh failed for "$brand": $e');
    }
  }

  // ============= GET CUSTOMER ACCOUNT (with offline cache) =============
  Future<CustomerAccount> getCustomerAccount(
      String shopId, {
        required String shopName,
        required String shopSubtitle,
      }) async {
    try {
      // Try to get from cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedKey = 'cached_account_$shopId';
      final cachedData = prefs.getString(cachedKey);

      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final Map<String, dynamic> cachedAccount = jsonDecode(cachedData);
          final account = CustomerAccount(
            shopName: cachedAccount['shopName'] ?? shopName,
            subtitle: cachedAccount['subtitle'] ?? shopSubtitle,
            ledgerBalance: (cachedAccount['ledgerBalance'] ?? 0).toDouble(),
            remainingBillLimit: (cachedAccount['remainingBillLimit'] ?? 0).toDouble(),
            lastPaymentDate: cachedAccount['lastPaymentDate'] != null
                ? DateTime.parse(cachedAccount['lastPaymentDate'])
                : null,
            paymentDue: (cachedAccount['paymentDue'] ?? 0).toDouble(),
          );
          print('📦 [BookingRepository] Loaded customer account from cache for shop $shopId');
          // Refresh in background
          _refreshAccountInBackground(shopId, shopName, shopSubtitle);
          return account;
        } catch (e) {
          print('⚠️ [BookingRepository] Error parsing cached account: $e');
        }
      }

      // Mock data for now (will be replaced with real API)
      await Future.delayed(const Duration(milliseconds: 400));
      final account = CustomerAccount(
        shopName: shopName,
        subtitle: shopSubtitle,
        ledgerBalance: 40854,
        remainingBillLimit: 109146,
        lastPaymentDate: DateTime(2026, 6, 10),
        paymentDue: 12000,
      );

      // Cache the result
      await prefs.setString(cachedKey, jsonEncode({
        'shopName': account.shopName,
        'subtitle': account.subtitle,
        'ledgerBalance': account.ledgerBalance,
        'remainingBillLimit': account.remainingBillLimit,
        'lastPaymentDate': account.lastPaymentDate?.toIso8601String(),
        'paymentDue': account.paymentDue,
      }));
      print('📦 [BookingRepository] Cached customer account for shop $shopId');

      return account;
    } catch (e) {
      print('Error fetching customer account: $e');
      rethrow;
    }
  }

  // Background refresh for account
  Future<void> _refreshAccountInBackground(String shopId, String shopName, String shopSubtitle) async {
    try {
      // TODO: Replace with real API call
      // final response = await http.get(Uri.parse('$baseUrl/customer-account/get/$shopId'));
      // if (response.statusCode == 200) { ... }

      // For now, just use mock data
      final account = CustomerAccount(
        shopName: shopName,
        subtitle: shopSubtitle,
        ledgerBalance: 40854,
        remainingBillLimit: 109146,
        lastPaymentDate: DateTime(2026, 6, 10),
        paymentDue: 12000,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_account_$shopId', jsonEncode({
        'shopName': account.shopName,
        'subtitle': account.subtitle,
        'ledgerBalance': account.ledgerBalance,
        'remainingBillLimit': account.remainingBillLimit,
        'lastPaymentDate': account.lastPaymentDate?.toIso8601String(),
        'paymentDue': account.paymentDue,
      }));
      print('🔄 [BookingRepository] Background account refresh complete for shop $shopId');
    } catch (e) {
      print('⚠️ [BookingRepository] Background account refresh failed: $e');
    }
  }

  // ============= SUBMIT ORDER (with offline queuing) =============
  // booking_repository.dart - submitOrder method

  Future<BookingSubmitResult> submitOrder(
      BookingFlowModel model, {
        required String visitType,
        String status = 'CONFIRMED',
      }) async {
    final endpoint = '$baseUrl/order_items/post/';
    print('📤 [BookingRepository] POST $endpoint');

    try {
      final empInfo = await getEmployeeInfo();
      print('👤 [BookingRepository] employee info: $empInfo');

      final orderId = model.orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      final payload = {
        'order_id': orderId,
        'visit_id': model.visitId,
        'employee_id': empInfo['empId'] ?? '',
        'employee_name': empInfo['empName'] ?? '',
        'company_code': empInfo['companyCode'] ?? '',
        'shop_id': model.shopId,
        'shop_name': model.shopName,
        'shop_address': model.shopAddress,
        'owner_name': model.ownerName,
        'brand': model.selectedBrand ?? '',
        'gps_enabled': model.gpsEnabled ? 'true' : 'false',
        'latitude': model.latitude,
        'longitude': model.longitude,
        'notes': model.notes,
        'subtotal': model.subtotal,
        'gst_amount': model.gstAmount,
        'grand_total': model.grandTotal,
        'shop_image': model.shopPhotoBase64,
        'shelf_image': model.shelfPhotoBase64,
        'products': model.lineItems.map((i) => i.toJson()).toList(),
      };

      // Try to post online
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 [BookingRepository] status: ${response.statusCode}');
      print('📥 [BookingRepository] body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ok = data['status']?.toString() == 'success';
        if (ok) {
          final returnedOrderId = data['order_id']?.toString() ?? orderId;
          print('✅ [BookingRepository] order saved: order_id=$returnedOrderId');
          await _clearPendingOrderFromCache(model.shopId);
          return BookingSubmitResult(
            success: true,
            id: returnedOrderId,
            visitId: model.visitId ?? returnedOrderId,
          );
        }
      }

      // If server fails OR offline, queue it
      print('📦 [BookingRepository] Queuing order for offline sync...');
      await _queuePendingOrder(model, payload);

      // ✅ ALWAYS RETURN SUCCESS - User ko smooth navigate karna hai
      return BookingSubmitResult(
        success: true,
        id: orderId,
        visitId: model.visitId ?? orderId,
        message: 'Order saved locally (will sync when online)',
      );

    } catch (e, st) {
      print('💥 [BookingRepository] submitOrder exception: $e');
      print(st);

      // Queue the order
      try {
        final empInfo = await getEmployeeInfo();
        final orderId = model.orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final payload = {
          'order_id': orderId,
          'visit_id': model.visitId,
          'employee_id': empInfo['empId'] ?? '',
          'employee_name': empInfo['empName'] ?? '',
          'company_code': empInfo['companyCode'] ?? '',
          'shop_id': model.shopId,
          'shop_name': model.shopName,
          'shop_address': model.shopAddress,
          'owner_name': model.ownerName,
          'brand': model.selectedBrand ?? '',
          'gps_enabled': model.gpsEnabled ? 'true' : 'false',
          'latitude': model.latitude,
          'longitude': model.longitude,
          'notes': model.notes,
          'subtotal': model.subtotal,
          'gst_amount': model.gstAmount,
          'grand_total': model.grandTotal,
          'shop_image': model.shopPhotoBase64,
          'shelf_image': model.shelfPhotoBase64,
          'products': model.lineItems.map((i) => i.toJson()).toList(),
        };
        await _queuePendingOrder(model, payload);
        print('📦 [BookingRepository] Order queued for offline sync');
      } catch (queueError) {
        print('💥 [BookingRepository] Error queueing order: $queueError');
      }

      // ✅ ALWAYS RETURN SUCCESS
      return BookingSubmitResult(
        success: true,
        id: model.orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        visitId: model.visitId,
        message: 'Order saved locally (will sync when online)',
      );
    }
  }

  // ── Offline queue for orders ──────────────────────────────────────────
  Future<void> _queuePendingOrder(BookingFlowModel model, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'pending_orders_${model.shopId}';
      final existingQueue = prefs.getStringList(queueKey) ?? [];

      // Remove any existing entry for this order_id
      existingQueue.removeWhere((item) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          return data['order_id'] == model.orderId;
        } catch (_) {
          return false;
        }
      });

      existingQueue.add(jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'payload': payload,
        'shop_id': model.shopId,
        'visit_id': model.visitId,
        'order_id': model.orderId,
        'retry_count': 0,
      }));

      await prefs.setStringList(queueKey, existingQueue);
      print('📦 [BookingRepository] Order queued: ${model.orderId} for shop ${model.shopId}');
      print('📦 [BookingRepository] Total pending orders in queue: ${existingQueue.length}');
    } catch (e) {
      print('💥 [BookingRepository] Error queueing order: $e');
    }
  }

  Future<void> _clearPendingOrderFromCache(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueKey = 'pending_orders_$shopId';
      await prefs.remove(queueKey);
      print('🧹 [BookingRepository] Cleared pending orders for shop $shopId');
    } catch (e) {
      print('⚠️ [BookingRepository] Error clearing pending orders: $e');
    }
  }

  // ============= SYNC PENDING ORDERS (called when internet is available) =============
  // ============= SYNC PENDING ORDERS =============
  // booking_repository.dart mein:

  Future<List<String>> syncPendingOrders() async {
    final syncedOrderIds = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final pendingKeys = allKeys.where((key) => key.startsWith('pending_orders_')).toList();

      debugPrint('📤 [BookingRepository] 🔥 Syncing ${pendingKeys.length} pending order queues...');

      for (final key in pendingKeys) {
        final queue = prefs.getStringList(key) ?? [];
        if (queue.isEmpty) {
          await prefs.remove(key);
          continue;
        }

        debugPrint('📤 [BookingRepository] Queue "$key" has ${queue.length} pending orders');

        for (final orderJson in queue) {
          try {
            final orderData = jsonDecode(orderJson) as Map<String, dynamic>;
            final payload = orderData['payload'] as Map<String, dynamic>;
            final endpoint = '$baseUrl/order_items/post/';

            debugPrint('📤 [BookingRepository] POST $endpoint');
            debugPrint('📤 [BookingRepository] payload: ${jsonEncode(payload)}');

            final response = await http.post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 30));

            debugPrint('📥 [BookingRepository] status: ${response.statusCode}');
            debugPrint('📥 [BookingRepository] body: ${response.body}');

            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = jsonDecode(response.body) as Map<String, dynamic>;
              if (data['status']?.toString() == 'success') {
                syncedOrderIds.add(orderData['order_id']?.toString() ?? '');
                debugPrint('✅ [BookingRepository] Synced order: ${orderData['order_id']}');
              }
            }
          } catch (e) {
            debugPrint('💥 [BookingRepository] Error syncing order: $e');
          }
        }

        await prefs.remove(key);
      }

      debugPrint('✅ [BookingRepository] Sync complete: ${syncedOrderIds.length} orders synced');
    } catch (e) {
      debugPrint('💥 [BookingRepository] Error syncing pending orders: $e');
    }
    return syncedOrderIds;
  }

  // ============= SUBMIT BOOKING (Backward compatible) =============
  Future<BookingSubmitResult> submitBooking(
      BookingFlowModel model, {
        required String visitType,
        String status = 'CONFIRMED',
      }) async {
    return submitOrder(model, visitType: visitType, status: status);
  }
}

/// Result of a submitBooking() call.
class BookingSubmitResult {
  final bool success;
  final String? id;
  final String? visitId;
  final String? message;

  BookingSubmitResult({
    required this.success,
    this.id,
    this.visitId,
    this.message,
  });
}

// ── Lightweight data classes ─────────────────────────────────────────────
class BrandItem {
  final String name;
  BrandItem({required this.name});

  factory BrandItem.fromJson(Map<String, dynamic> json) => BrandItem(
    name: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
  );
}

class ProductItem {
  final String id;
  final String name;
  final String brand;
  final String price;

  ProductItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
    id: json['id']?.toString() ??
        json['ID']?.toString() ??
        json['product_id']?.toString() ??
        '',
    name: json['product_name']?.toString() ??
        json['PRODUCT_NAME']?.toString() ??
        json['product']?.toString() ??
        json['PRODUCT']?.toString() ??
        json['name']?.toString() ??
        json['NAME']?.toString() ??
        '',
    brand: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
    price: json['price']?.toString() ??
        json['PRICE']?.toString() ??
        json['product_price']?.toString() ??
        '0',
  );
}