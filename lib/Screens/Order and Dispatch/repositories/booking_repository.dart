// // // ═══════════════════════════════════════════════════════════════════════════
// // // booking_repository.dart
// // //
// // // Standalone repository for the booking flow — no dependency on
// // // booking_repository.dart or no_sale_visit_model.dart.
// // //
// // // API endpoints (same Oracle ORDS as before):
// // //   GET /brand/get/
// // //   GET /products/get/?brand=...
// // //   GET /customer-account/get/:shopId   (TODO: confirm exact endpoint)
// // //   POST /booking/submit                (TODO: confirm exact endpoint)
// // // ═══════════════════════════════════════════════════════════════════════════
// //
// // import 'dart:convert';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../models/booking_flow_model.dart';
// //
// //
// // class BookingRepository {
// //   static const String baseUrl =
// //       'http://oracle.metaxperts.net/ords/gps_workforce';
// //
// //   // ── Helper: Get employee info from SharedPreferences ────────────────
// //   Future<Map<String, String>> _getEmployeeInfo() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.reload();
// //
// //     final empId = prefs.getString('userId') ??
// //         prefs.getString('user_id') ??
// //         prefs.getString('emp_id') ??
// //         prefs.getString('empId') ??
// //         prefs.getString('employee_id') ??
// //         prefs.getString('employeeId') ??
// //         '';
// //
// //     final empName = prefs.getString('userName') ??
// //         prefs.getString('user_name') ??
// //         prefs.getString('emp_name') ??
// //         prefs.getString('empName') ??
// //         prefs.getString('employee_name') ??
// //         prefs.getString('employeeName') ??
// //         '';
// //
// //     final companyCode = prefs.getString('company_code') ??
// //         prefs.getString('companyCode') ??
// //         '';
// //
// //     return {'empId': empId, 'empName': empName, 'companyCode': companyCode};
// //   }
// //
// //   // ============= GET BRANDS =============
// //   Future<List<BrandItem>> getBrands() async {
// //     final endpoint = '$baseUrl/brand/get/';
// //     print('📤 [BookingRepository] GET $endpoint');
// //     try {
// //       final response = await http.get(Uri.parse(endpoint));
// //       print('📥 [BookingRepository] getBrands status: ${response.statusCode}');
// //       print('📥 [BookingRepository] getBrands body: ${response.body}');
// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         final items = data['items'] as List? ?? [];
// //         final result = items
// //             .map((item) => BrandItem.fromJson(item as Map<String, dynamic>))
// //             .toList();
// //         print('✅ [BookingRepository] parsed ${result.length} brands');
// //         return result;
// //       }
// //       return [];
// //     } catch (e) {
// //       print('💥 [BookingRepository] Error fetching brands: $e');
// //       return [];
// //     }
// //   }
// //
// //   // ============= GET PRODUCTS BY BRAND =============
// //   Future<List<ProductItem>> getProductsByBrand(String brand) async {
// //     final endpoint =
// //         '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
// //     print('📤 [BookingRepository] GET $endpoint');
// //     try {
// //       final response = await http.get(Uri.parse(endpoint));
// //       print('📥 [BookingRepository] getProductsByBrand status: ${response.statusCode}');
// //       print('📥 [BookingRepository] getProductsByBrand body: ${response.body}');
// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         final items = data['items'] as List? ?? [];
// //         final result = items
// //             .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
// //             .toList();
// //         print('✅ [BookingRepository] parsed ${result.length} products for "$brand"');
// //         return result;
// //       }
// //       return [];
// //     } catch (e) {
// //       print('💥 [BookingRepository] Error fetching products: $e');
// //       return [];
// //     }
// //   }
// //
// //   // ============= GET CUSTOMER ACCOUNT =============
// //   // TODO(api): confirm exact endpoint — currently mocked.
// //   Future<CustomerAccount> getCustomerAccount(
// //       String shopId, {
// //         required String shopName,
// //         required String shopSubtitle,
// //       }) async {
// //     try {
// //       // TODO(api): replace with real endpoint
// //       // final response = await http.get(
// //       //   Uri.parse('$baseUrl/customer-account/get/$shopId'),
// //       // );
// //       // if (response.statusCode == 200) { ... }
// //
// //       // Mock data for now
// //       await Future.delayed(const Duration(milliseconds: 400));
// //       return CustomerAccount(
// //         shopName: shopName,
// //         subtitle: shopSubtitle,
// //         ledgerBalance: 40854,
// //         remainingBillLimit: 109146,
// //         lastPaymentDate: DateTime(2026, 6, 10),
// //         paymentDue: 12000,
// //       );
// //     } catch (e) {
// //       print('Error fetching customer account: $e');
// //       rethrow;
// //     }
// //   }
// //
// //   // ============= SUBMIT BOOKING =============
// //   Future<BookingSubmitResult> submitBooking(
// //       BookingFlowModel model, {
// //         required String visitType, // e.g. "Booking"
// //         String status = 'CONFIRMED',
// //       }) async {
// //     final endpoint = '$baseUrl/shop_visit/post/';
// //
// //     try {
// //       final empInfo = await _getEmployeeInfo();
// //       print('👤 [BookingRepository] employee info: $empInfo');
// //
// //       final payload = model.toSubmitJson(
// //         employeeId: empInfo['empId'] ?? '',
// //         employeeName: empInfo['empName'] ?? '',
// //         companyCode: empInfo['companyCode'] ?? '',
// //         visitType: visitType,
// //         status: status,
// //       );
// //
// //       // Don't dump full base64 images into the console — way too noisy.
// //       final logSafePayload = Map<String, dynamic>.from(payload);
// //       if (logSafePayload['shop_image'] != null) {
// //         logSafePayload['shop_image'] =
// //         '<base64 ${(logSafePayload['shop_image'] as String).length} chars>';
// //       }
// //       if (logSafePayload['shelf_image'] != null) {
// //         logSafePayload['shelf_image'] =
// //         '<base64 ${(logSafePayload['shelf_image'] as String).length} chars>';
// //       }
// //
// //       print('📤 [BookingRepository] POST $endpoint');
// //       print('📤 [BookingRepository] payload: ${jsonEncode(logSafePayload)}');
// //
// //       final response = await http.post(
// //         Uri.parse(endpoint),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode(payload),
// //       );
// //
// //       print('📥 [BookingRepository] status: ${response.statusCode}');
// //       print('📥 [BookingRepository] body: ${response.body}');
// //
// //       if (response.statusCode == 200 || response.statusCode == 201) {
// //         final data = jsonDecode(response.body) as Map<String, dynamic>;
// //         final ok = data['status']?.toString() == 'success';
// //         if (ok) {
// //           print('✅ [BookingRepository] booking saved: '
// //               'id=${data['id']} visit_id=${data['visit_id']}');
// //           return BookingSubmitResult(
// //             success: true,
// //             id: data['id']?.toString(),
// //             visitId: data['visit_id']?.toString(),
// //           );
// //         } else {
// //           print('❌ [BookingRepository] server returned error: ${data['message']}');
// //           return BookingSubmitResult(
// //             success: false,
// //             message: data['message']?.toString() ?? 'Unknown server error',
// //           );
// //         }
// //       }
// //
// //       print('❌ [BookingRepository] non-2xx response: ${response.statusCode}');
// //       return BookingSubmitResult(
// //         success: false,
// //         message: 'Server returned ${response.statusCode}',
// //       );
// //     } catch (e, st) {
// //       print('💥 [BookingRepository] submitBooking exception: $e');
// //       print(st);
// //       return BookingSubmitResult(success: false, message: e.toString());
// //     }
// //   }
// // }
// //
// // /// Result of a submitBooking() call.
// // class BookingSubmitResult {
// //   final bool success;
// //   final String? id; // numeric SHOP_VISIT.ID returned by the server
// //   final String? visitId; // the visit_id we sent (echoed back on success)
// //   final String? message; // error message on failure
// //
// //   BookingSubmitResult({
// //     required this.success,
// //     this.id,
// //     this.visitId,
// //     this.message,
// //   });
// // }
// //
// // // ── Lightweight data classes (mirroring visit_model but standalone) ────
// //
// // class BrandItem {
// //   final String name;
// //   BrandItem({required this.name});
// //
// //   factory BrandItem.fromJson(Map<String, dynamic> json) => BrandItem(
// //     name: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
// //   );
// // }
// //
// // class ProductItem {
// //   final String id;
// //   final String name;
// //   final String brand;
// //   final String price;
// //
// //   ProductItem({
// //     required this.id,
// //     required this.name,
// //     required this.brand,
// //     required this.price,
// //   });
// //
// //   factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
// //     id: json['id']?.toString() ??
// //         json['ID']?.toString() ??
// //         json['product_id']?.toString() ??
// //         '',
// //     name: json['product_name']?.toString() ??
// //         json['PRODUCT_NAME']?.toString() ??
// //         json['product']?.toString() ??
// //         json['PRODUCT']?.toString() ??
// //         json['name']?.toString() ??
// //         json['NAME']?.toString() ??
// //         '',
// //     brand: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
// //     price: json['price']?.toString() ??
// //         json['PRICE']?.toString() ??
// //         json['product_price']?.toString() ??
// //         '0',
// //   );
// // }
//
// // ═══════════════════════════════════════════════════════════════════════════
// // booking_repository.dart - Use SHOP_VISIT endpoint temporarily
// // ═══════════════════════════════════════════════════════════════════════════
//
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../models/booking_flow_model.dart';
//
// class BookingRepository {
//   static const String baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce';
//
//   // ── Helper: Get employee info from SharedPreferences ────────────────
//   Future<Map<String, String>> getEmployeeInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//
//     final empId = prefs.getString('userId') ??
//         prefs.getString('user_id') ??
//         prefs.getString('emp_id') ??
//         prefs.getString('empId') ??
//         prefs.getString('employee_id') ??
//         prefs.getString('employeeId') ??
//         '';
//
//     final empName = prefs.getString('userName') ??
//         prefs.getString('user_name') ??
//         prefs.getString('emp_name') ??
//         prefs.getString('empName') ??
//         prefs.getString('employee_name') ??
//         prefs.getString('employeeName') ??
//         '';
//
//     final companyCode = prefs.getString('company_code') ??
//         prefs.getString('companyCode') ??
//         '';
//
//     return {'empId': empId, 'empName': empName, 'companyCode': companyCode};
//   }
//
//   // ============= GET BRANDS =============
//   Future<List<BrandItem>> getBrands() async {
//     final endpoint = '$baseUrl/brand/get/';
//     print('📤 [BookingRepository] GET $endpoint');
//     try {
//       final response = await http.get(Uri.parse(endpoint));
//       print('📥 [BookingRepository] getBrands status: ${response.statusCode}');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final items = data['items'] as List? ?? [];
//         final result = items
//             .map((item) => BrandItem.fromJson(item as Map<String, dynamic>))
//             .toList();
//         print('✅ [BookingRepository] parsed ${result.length} brands');
//         return result;
//       }
//       return [];
//     } catch (e) {
//       print('💥 [BookingRepository] Error fetching brands: $e');
//       return [];
//     }
//   }
//
//   // ============= GET PRODUCTS BY BRAND =============
//   Future<List<ProductItem>> getProductsByBrand(String brand) async {
//     final endpoint =
//         '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
//     print('📤 [BookingRepository] GET $endpoint');
//     try {
//       final response = await http.get(Uri.parse(endpoint));
//       print('📥 [BookingRepository] getProductsByBrand status: ${response.statusCode}');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final items = data['items'] as List? ?? [];
//         final result = items
//             .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
//             .toList();
//         print('✅ [BookingRepository] parsed ${result.length} products for "$brand"');
//         return result;
//       }
//       return [];
//     } catch (e) {
//       print('💥 [BookingRepository] Error fetching products: $e');
//       return [];
//     }
//   }
//
//   // ============= GET CUSTOMER ACCOUNT =============
//   Future<CustomerAccount> getCustomerAccount(
//       String shopId, {
//         required String shopName,
//         required String shopSubtitle,
//       }) async {
//     try {
//       // Mock data for now
//       await Future.delayed(const Duration(milliseconds: 400));
//       return CustomerAccount(
//         shopName: shopName,
//         subtitle: shopSubtitle,
//         ledgerBalance: 40854,
//         remainingBillLimit: 109146,
//         lastPaymentDate: DateTime(2026, 6, 10),
//         paymentDue: 12000,
//       );
//     } catch (e) {
//       print('Error fetching customer account: $e');
//       rethrow;
//     }
//   }
//
//   // ============= SUBMIT ORDER: single call to /order_items/post/ =============
//   // Mirrors the SHOP_VISIT pattern: one POST, master row + nested products
//   // array parsed server-side via JSON_TABLE, single transaction/commit.
//   Future<BookingSubmitResult> submitOrder(
//       BookingFlowModel model, {
//         required String visitType,
//         String status = 'CONFIRMED',
//       }) async {
//     final endpoint = '$baseUrl/order_items/post/';
//     print('📤 [BookingRepository] POST $endpoint');
//
//     try {
//       final empInfo = await getEmployeeInfo();
//       print('👤 [BookingRepository] employee info: $empInfo');
//
//       final orderId = model.visitId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';
//
//       final payload = {
//         'order_id': orderId,
//         'visit_id': model.visitId,
//         'employee_id': empInfo['empId'] ?? '',
//         'employee_name': empInfo['empName'] ?? '',
//         'company_code': empInfo['companyCode'] ?? '',
//         'shop_id': model.shopId,
//         'shop_name': model.shopName,
//         'shop_address': model.shopAddress,
//         'owner_name': model.ownerName,
//         'brand': model.selectedBrand ?? '',
//         'gps_enabled': model.gpsEnabled ? 'true' : 'false',
//         'latitude': model.latitude,
//         'longitude': model.longitude,
//         'notes': model.notes,
//         'subtotal': model.subtotal,
//         'gst_amount': model.gstAmount,
//         'grand_total': model.grandTotal,
//         'shop_image': model.shopPhotoBase64,
//         'shelf_image': model.shelfPhotoBase64,
//         'products': model.lineItems.map((i) => i.toJson()).toList(),
//       };
//
//       // Log safe payload without images
//       final logSafePayload = Map<String, dynamic>.from(payload);
//       if (logSafePayload['shop_image'] != null) {
//         logSafePayload['shop_image'] =
//         '<base64 ${(logSafePayload['shop_image'] as String).length} chars>';
//       }
//       if (logSafePayload['shelf_image'] != null) {
//         logSafePayload['shelf_image'] =
//         '<base64 ${(logSafePayload['shelf_image'] as String).length} chars>';
//       }
//       print('📤 [BookingRepository] payload: ${jsonEncode(logSafePayload)}');
//
//       final response = await http.post(
//         Uri.parse(endpoint),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(payload),
//       ).timeout(const Duration(seconds: 30));
//
//       print('📥 [BookingRepository] status: ${response.statusCode}');
//       print('📥 [BookingRepository] body: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         final ok = data['status']?.toString() == 'success';
//         if (ok) {
//           final returnedOrderId = data['order_id']?.toString() ?? orderId;
//           print('✅ [BookingRepository] order saved: order_id=$returnedOrderId');
//           return BookingSubmitResult(
//             success: true,
//             id: returnedOrderId,
//             visitId: model.visitId ?? returnedOrderId,
//           );
//         } else {
//           print('❌ [BookingRepository] server returned error: ${data['message']}');
//           return BookingSubmitResult(
//             success: false,
//             message: data['message']?.toString() ?? 'Unknown server error',
//           );
//         }
//       }
//
//       print('❌ [BookingRepository] non-2xx response: ${response.statusCode}');
//       return BookingSubmitResult(
//         success: false,
//         message: 'Server returned ${response.statusCode}',
//       );
//     } catch (e, st) {
//       print('💥 [BookingRepository] submitOrder exception: $e');
//       print(st);
//       String errorMsg = e.toString();
//       if (e.toString().contains('timeout')) {
//         errorMsg = 'Request timed out. Server is taking too long to respond.';
//       } else if (e.toString().contains('SocketException')) {
//         errorMsg = 'No internet connection. Please check your network.';
//       }
//       return BookingSubmitResult(success: false, message: errorMsg);
//     }
//   }
//
//
//   // ============= SUBMIT BOOKING (Backward compatible) =============
//   Future<BookingSubmitResult> submitBooking(
//       BookingFlowModel model, {
//         required String visitType,
//         String status = 'CONFIRMED',
//       }) async {
//     return submitOrder(model, visitType: visitType, status: status);
//   }
// }
//
// /// Result of a submitBooking() call.
// class BookingSubmitResult {
//   final bool success;
//   final String? id;
//   final String? visitId;
//   final String? message;
//
//   BookingSubmitResult({
//     required this.success,
//     this.id,
//     this.visitId,
//     this.message,
//   });
// }
//
// // ── Lightweight data classes ─────────────────────────────────────────────
// class BrandItem {
//   final String name;
//   BrandItem({required this.name});
//
//   factory BrandItem.fromJson(Map<String, dynamic> json) => BrandItem(
//     name: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
//   );
// }
//
// class ProductItem {
//   final String id;
//   final String name;
//   final String brand;
//   final String price;
//
//   ProductItem({
//     required this.id,
//     required this.name,
//     required this.brand,
//     required this.price,
//   });
//
//   factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
//     id: json['id']?.toString() ??
//         json['ID']?.toString() ??
//         json['product_id']?.toString() ??
//         '',
//     name: json['product_name']?.toString() ??
//         json['PRODUCT_NAME']?.toString() ??
//         json['product']?.toString() ??
//         json['PRODUCT']?.toString() ??
//         json['name']?.toString() ??
//         json['NAME']?.toString() ??
//         '',
//     brand: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
//     price: json['price']?.toString() ??
//         json['PRICE']?.toString() ??
//         json['product_price']?.toString() ??
//         '0',
//   );
// }


// ═══════════════════════════════════════════════════════════════════════════
// booking_repository.dart - Use SHOP_VISIT endpoint temporarily
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
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

  // ============= GET BRANDS =============
  Future<List<BrandItem>> getBrands() async {
    final endpoint = '$baseUrl/brand/get/';
    print('📤 [BookingRepository] GET $endpoint');
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
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [BookingRepository] Error fetching brands: $e');
      return [];
    }
  }

  // ============= GET PRODUCTS BY BRAND =============
  Future<List<ProductItem>> getProductsByBrand(String brand) async {
    final endpoint =
        '$baseUrl/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    print('📤 [BookingRepository] GET $endpoint');
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
        return result;
      }
      return [];
    } catch (e) {
      print('💥 [BookingRepository] Error fetching products: $e');
      return [];
    }
  }

  // ============= GET CUSTOMER ACCOUNT =============
  Future<CustomerAccount> getCustomerAccount(
      String shopId, {
        required String shopName,
        required String shopSubtitle,
      }) async {
    try {
      // Mock data for now
      await Future.delayed(const Duration(milliseconds: 400));
      return CustomerAccount(
        shopName: shopName,
        subtitle: shopSubtitle,
        ledgerBalance: 40854,
        remainingBillLimit: 109146,
        lastPaymentDate: DateTime(2026, 6, 10),
        paymentDue: 12000,
      );
    } catch (e) {
      print('Error fetching customer account: $e');
      rethrow;
    }
  }

  // ============= SUBMIT ORDER: single call to /order_items/post/ =============
  // Mirrors the SHOP_VISIT pattern: one POST, master row + nested products
  // array parsed server-side via JSON_TABLE, single transaction/commit.
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

      // ✅ FIX: Use model.orderId instead of model.visitId
      final orderId = model.orderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      final payload = {
        'order_id': orderId,           // ✅ OD-... wali ID
        'visit_id': model.visitId,     // ✅ SV-... wali ID
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

      // Log safe payload without images
      final logSafePayload = Map<String, dynamic>.from(payload);
      if (logSafePayload['shop_image'] != null) {
        logSafePayload['shop_image'] =
        '<base64 ${(logSafePayload['shop_image'] as String).length} chars>';
      }
      if (logSafePayload['shelf_image'] != null) {
        logSafePayload['shelf_image'] =
        '<base64 ${(logSafePayload['shelf_image'] as String).length} chars>';
      }
      print('📤 [BookingRepository] payload: ${jsonEncode(logSafePayload)}');

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
          return BookingSubmitResult(
            success: true,
            id: returnedOrderId,
            visitId: model.visitId ?? returnedOrderId,
          );
        } else {
          print('❌ [BookingRepository] server returned error: ${data['message']}');
          return BookingSubmitResult(
            success: false,
            message: data['message']?.toString() ?? 'Unknown server error',
          );
        }
      }

      print('❌ [BookingRepository] non-2xx response: ${response.statusCode}');
      return BookingSubmitResult(
        success: false,
        message: 'Server returned ${response.statusCode}',
      );
    } catch (e, st) {
      print('💥 [BookingRepository] submitOrder exception: $e');
      print(st);
      String errorMsg = e.toString();
      if (e.toString().contains('timeout')) {
        errorMsg = 'Request timed out. Server is taking too long to respond.';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'No internet connection. Please check your network.';
      }
      return BookingSubmitResult(success: false, message: errorMsg);
    }
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