class VisitModel {
  // Shop Information
  String? selectedBrand;
  String? selectedShopId;
  String? selectedShopName;
  String? shopAddress;
  String? ownerName;
  String employeeId = '';
  String employeeName = '';
  String companyCode = '';

  // Lists
  List<BrandItem> brands = [];
  List<ShopItem> shops = [];
  List<ProductItem> products = [];
  List<ProductItem> selectedProducts = [];

  // UI State
  bool isLoadingBrands = false;
  bool isLoadingShops = false;
  bool isLoadingProducts = false;
  String? errorMessage;

  // Checklist
  bool gpsEnabled = false;
  bool storeWalkThrough = false;
  bool planogramUpdated = false;
  bool displayStandards = false;

  // Location
  double? latitude;
  double? longitude;

  // Additional
  String? notes;
  String? shopImageBase64; // For base64 encoded image

  // Computed
  int get totalQuantity => selectedProducts.fold(0, (sum, p) => sum + p.quantity);
  bool get hasSelectedBrand => selectedBrand != null && selectedBrand!.isNotEmpty;
  bool get hasSelectedShop => selectedShopId != null && selectedShopId!.isNotEmpty;
  bool get hasSelectedProducts => selectedProducts.isNotEmpty;

  VisitModel copy() {
    final copy = VisitModel();
    copy.selectedBrand = selectedBrand;
    copy.selectedShopId = selectedShopId;
    copy.selectedShopName = selectedShopName;
    copy.shopAddress = shopAddress;
    copy.ownerName = ownerName;
    copy.employeeId = employeeId;
    copy.employeeName = employeeName;
    copy.companyCode = companyCode;
    copy.brands = List.from(brands);
    copy.shops = List.from(shops);
    copy.products = List.from(products);
    copy.selectedProducts = List.from(selectedProducts);
    copy.isLoadingBrands = isLoadingBrands;
    copy.isLoadingShops = isLoadingShops;
    copy.isLoadingProducts = isLoadingProducts;
    copy.errorMessage = errorMessage;
    copy.gpsEnabled = gpsEnabled;
    copy.storeWalkThrough = storeWalkThrough;
    copy.planogramUpdated = planogramUpdated;
    copy.displayStandards = displayStandards;
    copy.notes = notes;
    copy.latitude = latitude;
    copy.longitude = longitude;
    copy.shopImageBase64 = shopImageBase64;
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'employee_name': employeeName,
    'company_code': companyCode,
    'brand': selectedBrand,
    'shop_id': selectedShopId,
    'shop_name': selectedShopName,
    'shop_address': shopAddress,
    'owner_name': ownerName,
    'gps_enabled': gpsEnabled,
    'latitude': latitude ?? 0.0,
    'longitude': longitude ?? 0.0,
    'notes': notes,
    'shop_image': shopImageBase64,
    'products': selectedProducts.map((p) => p.toJson()).toList(),
  };
}

class BrandItem {
  final String name;
  BrandItem({required this.name});
  factory BrandItem.fromJson(Map<String, dynamic> json) => BrandItem(
    name: _pick(json, ['brand', 'BRAND']),
  );
  static String _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return '';
  }
  Map<String, dynamic> toJson() => {'name': name};
}

class ShopItem {
  final String id;
  final String name;
  final String address;
  final String ownerName;
  ShopItem({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerName,
  });
  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: _pick(json, ['id', 'ID', 'shop_id', 'SHOP_ID']),
    name: _pick(json, ['shop_name', 'SHOP_NAME', 'shopName', 'name', 'NAME']),
    address: _pick(json, ['address', 'ADDRESS', 'shop_address', 'SHOP_ADDRESS']),
    ownerName: _pick(json, ['owner_name', 'OWNER_NAME', 'ownerName', 'OWNERNAME']),
  );
  static String _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return '';
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'ownerName': ownerName,
  };
}

class ProductItem {
  final String id;
  final String name;
  final String brand;
  final String price;
  int quantity;
  ProductItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    this.quantity = 0,
  });
  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
    id: _pick(json, ['id', 'ID', 'product_id', 'PRODUCT_ID']),
    name: _pick(json, ['product', 'PRODUCT', 'name', 'NAME', 'product_name', 'PRODUCT_NAME']),
    brand: _pick(json, ['brand', 'BRAND']),
    price: _pick(json, ['price', 'PRICE', 'product_price', 'PRODUCT_PRICE']),
    quantity: 0,
  );
  static String _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return '';
  }
  ProductItem copy() => ProductItem(
    id: id,
    name: name,
    brand: brand,
    price: price,
    quantity: quantity,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'price': price,
    'quantity': quantity,
  };
}