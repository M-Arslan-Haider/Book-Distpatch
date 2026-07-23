

import 'dart:developer' as developer;

/// One line item added to the current booking order.
class BookingLineItem {
  final String id; // product id (from ProductItem)
  final String productName;
  final String brand;
  final double rate; // price per piece
  final String unit; // e.g. "Pieces"
  final String packInfo; // e.g. "Pack of 12" (display only)

  int quantity; // in the chosen unit
  double discountPercent; // e.g. 12 => 12%
  int bonusPieces; // free pieces

  BookingLineItem({
    required this.id,
    required this.productName,
    required this.brand,
    required this.rate,
    required this.unit,
    this.packInfo = '',
    this.quantity = 0,
    this.discountPercent = 0,
    this.bonusPieces = 0,
  });

  /// Gross amount before discount: quantity * rate
  double get grossAmount => quantity * rate;

  /// Discount amount in currency
  double get discountAmount => grossAmount * (discountPercent / 100);

  /// Net amount after discount (this is what shows in "Add Products" list
  /// and in the Bill Summary "AMOUNT" column)
  double get netAmount => grossAmount - discountAmount;

  BookingLineItem copy() => BookingLineItem(
    id: id,
    productName: productName,
    brand: brand,
    rate: rate,
    unit: unit,
    packInfo: packInfo,
    quantity: quantity,
    discountPercent: discountPercent,
    bonusPieces: bonusPieces,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': productName,
    'brand': brand,
    'price': rate, // backend JSON_TABLE reads '$.price' — must NOT be 'rate'
    'unit': unit,
    'quantity': quantity,
    'discount_percent': discountPercent,
    'bonus_pieces': bonusPieces,
    'net_amount': netAmount,
    'pack_info': packInfo,
  };

  @override
  String toString() =>
      'BookingLineItem(name: $productName, qty: $quantity, disc: $discountPercent%, bonus: $bonusPieces, net: $netAmount)';
}

/// Very light product-catalog row used while browsing "Select Product".
/// (Kept separate from ProductItem in no_sale_visit_model.dart so this flow doesn't
/// depend on the shop-visit module — merge later if you want single source.)
class CatalogProduct {
  final String id;
  final String name;
  final String brand;
  final String category; // e.g. "Edible Oil"
  final double rate;
  final String packInfo; // e.g. "Pack of 12"

  CatalogProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.rate,
    required this.packInfo,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['product']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      rate: double.tryParse(json['rate']?.toString() ?? json['price']?.toString() ?? '0') ?? 0,
      packInfo: json['pack_info']?.toString() ?? '',
    );
  }
}

/// Customer / shop account snapshot shown on the "Customer Account" screen.
class CustomerAccount {
  final String shopName;
  final String subtitle; // e.g. "Al Madina Karyana Store - Rana Tariq"
  final double ledgerBalance;
  final double remainingBillLimit;
  final DateTime? lastPaymentDate;
  final double paymentDue;

  const CustomerAccount({
    required this.shopName,
    required this.subtitle,
    required this.ledgerBalance,
    required this.remainingBillLimit,
    required this.lastPaymentDate,
    required this.paymentDue,
  });

  bool get isOverdue => paymentDue > 0;

  factory CustomerAccount.empty(String shopName, String subtitle) => CustomerAccount(
    shopName: shopName,
    subtitle: subtitle,
    ledgerBalance: 0,
    remainingBillLimit: 0,
    lastPaymentDate: null,
    paymentDue: 0,
  );
}

/// The full in-progress booking, carried across all four screens.
class BookingFlowModel {
  final String shopId;
  final String shopName;
  final String shopSubtitle;

  CustomerAccount? account;

  String? selectedBrand;
  List<String> brands = [];
  List<CatalogProduct> catalogProducts = []; // for selected brand
  final List<BookingLineItem> lineItems = [];

  bool isLoadingAccount = false;
  bool isLoadingBrands = false;
  bool isLoadingProducts = false;
  String? errorMessage;

  // ── IDs for the booking ───────────────────────────────────────────────
  String? bookingId; // set after confirm, e.g. BK-902633
  String? visitId; // sent to backend as $.visit_id — generated before submit
  String? orderId; // OD-... — order/booking ke liye alag (NEW - FIXED)

  String? shopPhotoBase64;
  String? shelfPhotoBase64;

  // ── Extra shop/visit metadata for the submit payload ─────────────────
  String shopAddress;
  String ownerName;
  bool gpsEnabled;
  double? latitude;
  double? longitude;
  String? notes;

  BookingFlowModel({
    required this.shopId,
    required this.shopName,
    required this.shopSubtitle,
    // ✅ NEW PARAMETERS WITH DEFAULTS
    this.shopAddress = '',
    this.ownerName = '',
    this.gpsEnabled = false,
    this.latitude,
    this.longitude,
  });

  double get subtotal => lineItems.fold(0.0, (sum, item) => sum + item.netAmount);

  static const double gstRate = 0.18; // 18% GST — TODO: confirm/replace with API-driven rate

  double get gstAmount => subtotal * gstRate;

  double get grandTotal => subtotal + gstAmount;

  bool get exceedsBillLimit =>
      account != null && grandTotal > account!.remainingBillLimit && account!.remainingBillLimit > 0;

  int get totalItemCount => lineItems.length;

  /// Builds the exact JSON payload expected by
  /// POST /shop_visit/post/ (see the ORDS PL/SQL handler).
  Map<String, dynamic> toSubmitJson({
    required String employeeId,
    required String employeeName,
    required String companyCode,
    required String visitType, // e.g. "Booking"
    String status = 'CONFIRMED',
  }) {
    return {
      'visit_id': visitId,
      'order_id': orderId,   // FIXED: Now using orderId, NOT visitId
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
      'shelf_image': shelfPhotoBase64,
      'visit_type': visitType,
      'subtotal': subtotal,
      'gst_amount': gstAmount,
      'grand_total': grandTotal,
      'status': status,
      'products': lineItems.map((i) => i.toJson()).toList(),
    };
  }

  void logState(String tag) {
    developer.log(
      '📦 [$tag] items=${lineItems.length} subtotal=$subtotal gst=$gstAmount grandTotal=$grandTotal',
      name: 'BookingFlowModel',
    );
  }
}