
import 'dart:developer' as developer;

/// One product row the user adds — just a quantity, no discount/bonus.
class StockLineItem {
  final String id; // product id
  final String productName;
  final String brand;
  final double price;

  int quantity;

  StockLineItem({
    required this.id,
    required this.productName,
    required this.brand,
    required this.price,
    this.quantity = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': productName,
    'brand': brand,
    'price': price, // backend JSON_TABLE reads '$.price'
    'quantity': quantity,
  };

  @override
  String toString() =>
      'StockLineItem(name: $productName, qty: $quantity, price: $price)';
}

/// The full in-progress "No Sale of Stock" visit.
class NoSaleVisitModel {
  // ── Shop (selected via NoSaleShopSelectScreen) ────────────────────────
  String shopId;
  String shopName;
  String shopAddress;
  String ownerName;
  String? shopSubtitle; // display-only, e.g. "Owner - City"

  // ── Brand / product browsing ──────────────────────────────────────────
  String? selectedBrand;
  List<String> brands = [];
  List<StockCatalogProduct> catalogProducts = []; // for selected brand
  final List<StockLineItem> lineItems = [];

  bool isLoadingBrands = false;
  bool isLoadingProducts = false;
  String? errorMessage;

  // ── Photo + location ───────────────────────────────────────────────────
  String? shopPhotoBase64;
  bool gpsEnabled = false;
  double? latitude;
  double? longitude;
  bool isCapturingLocation = false;

  String? notes;
  String? visitId; // SV-... generated right before submit
  String? orderId; // OD-... generated right before submit (NEW)

  NoSaleVisitModel({
    required this.shopId,
    required this.shopName,
    this.shopAddress = '',
    this.ownerName = '',
    this.shopSubtitle,
  });

  int get totalItemCount => lineItems.length;

  bool get hasPhoto => shopPhotoBase64 != null && shopPhotoBase64!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get hasProducts => lineItems.isNotEmpty;

  /// Builds the JSON payload for POST /shop_visit/post/
  Map<String, dynamic> toSubmitJson({
    required String employeeId,
    required String employeeName,
    required String companyCode,
  }) {
    return {
      'visit_id': visitId,
      'order_id': orderId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'company_code': companyCode,
      'brand': selectedBrand ?? '',
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_address': shopAddress,
      'owner_name': ownerName,
      'gps_enabled': gpsEnabled ? 'true' : 'false',
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'shop_image': shopPhotoBase64,
      'visit_type': 'Shop Visit',
      'products': lineItems.map((i) => i.toJson()).toList(),
    };
  }

  void logState(String tag) {
    developer.log(
      '📦 [$tag] shop=$shopName items=${lineItems.length} hasPhoto=$hasPhoto hasLocation=$hasLocation',
      name: 'NoSaleVisitModel',
    );
  }
}

/// Light catalog row used while browsing products for this flow.
class StockCatalogProduct {
  final String id;
  final String name;
  final String brand;
  final double price;

  StockCatalogProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
  });
}