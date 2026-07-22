// ═══════════════════════════════════════════════════════════════════════════
// shop_closed_model.dart
//
// Data model for the "Shop Closed" flow:
//   ShopVisitOutcomeScreen -> ShopClosedShopSelectScreen (pick shop)
//   -> ShopClosedScreen (capture shop photo + GPS ONLY, no products)
//   -> submit
//
// Posts to the SAME endpoint as the "No Sale of Stock" / booking flow:
//   POST http://oracle.metaxperts.net/ords/gps_workforce/shopvisit/post/
// but with visit_type = 'Shop Closed' and an empty products array.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:developer' as developer;

class ShopClosedVisitModel {
  // ── Shop (selected via ShopClosedShopSelectScreen) ────────────────────
  String shopId;
  String shopName;
  String shopAddress;
  String ownerName;
  String? shopSubtitle; // display-only, e.g. "Owner - City"

  // ── Photo + location ───────────────────────────────────────────────────
  String? shopPhotoBase64;
  bool gpsEnabled = false;
  double? latitude;
  double? longitude;
  bool isCapturingLocation = false;

  String? notes;
  String? visitId; // generated right before submit
  String? errorMessage;

  ShopClosedVisitModel({
    required this.shopId,
    required this.shopName,
    this.shopAddress = '',
    this.ownerName = '',
    this.shopSubtitle,
  });

  bool get hasPhoto => shopPhotoBase64 != null && shopPhotoBase64!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;

  /// Builds the JSON payload for POST /shopvisit/post/
  Map<String, dynamic> toSubmitJson({
    required String employeeId,
    required String employeeName,
    required String companyCode,
  }) {
    return {
      'visit_id': visitId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'company_code': companyCode,
      'brand': '',
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_address': shopAddress,
      'owner_name': ownerName,
      'gps_enabled': gpsEnabled ? 'true' : 'false',
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'shop_image': shopPhotoBase64,
      'visit_type': 'Shop Closed',
      'products': const [], // Shop Closed has no product/stock data
    };
  }

  void logState(String tag) {
    developer.log(
      '📦 [$tag] shop=$shopName hasPhoto=$hasPhoto hasLocation=$hasLocation',
      name: 'ShopClosedVisitModel',
    );
  }
}