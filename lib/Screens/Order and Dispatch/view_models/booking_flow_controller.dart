//
// import 'dart:developer' as developer;
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
// import '../models/booking_flow_model.dart';
// import '../repositories/booking_repository.dart';
// import '../screens/add_products_screen.dart';
//
// class BookingFlowController extends GetxController {
//   BookingFlowController({
//     required String shopId,
//     required String shopName,
//     required String shopSubtitle,
//     String? visitId,
//     BookingRepository? repository,
//   })  : model = BookingFlowModel(shopId: shopId, shopName: shopName, shopSubtitle: shopSubtitle),
//         _repository = repository ?? BookingRepository() {
//     if (visitId != null && visitId.isNotEmpty) {
//       model.visitId = visitId;
//     }
//   }
//
//   final BookingFlowModel model;
//   final BookingRepository _repository;
//
//   set visitId(String? value) {
//     if (value != null && value.isNotEmpty) {
//       model.visitId = value;
//     }
//   }
//
//   final RxInt _tick = 0.obs;
//   void _refresh() {
//     _tick.value++;
//     model.logState('refresh');
//   }
//
//   RxInt get tick => _tick;
//
//   @override
//   void onInit() {
//     super.onInit();
//     developer.log('🚀 BookingFlowController init for shop=${model.shopName} (${model.shopId})',
//         name: 'BookingFlowController');
//     loadCustomerAccount();
//     loadBrands();
//   }
//
//   // ============= CUSTOMER ACCOUNT =============
//   Future<void> loadCustomerAccount() async {
//     print('🔄 [BookingFlowController] Loading customer account for shop ${model.shopId}...');
//     developer.log('🔄 Loading customer account for shop ${model.shopId}...',
//         name: 'BookingFlowController');
//     model.isLoadingAccount = true;
//     _refresh();
//
//     try {
//       model.account = await _repository.getCustomerAccount(
//         model.shopId,
//         shopName: model.shopName,
//         shopSubtitle: model.shopSubtitle,
//       );
//       print('✅ [BookingFlowController] Customer account loaded: due=${model.account?.paymentDue}');
//       developer.log('✅ Customer account loaded: due=${model.account?.paymentDue}',
//           name: 'BookingFlowController');
//     } catch (e) {
//       print('💥 [BookingFlowController] Error loading customer account: $e');
//       developer.log('❌ Error loading customer account: $e', name: 'BookingFlowController');
//       model.errorMessage = 'Failed to load customer account';
//     } finally {
//       model.isLoadingAccount = false;
//       _refresh();
//     }
//   }
//
//   Future<void> receivePayment() async {
//     developer.log('💰 Receive Payment tapped for shop ${model.shopId}', name: 'BookingFlowController');
//   }
//
//   // ============= BRANDS =============
//   Future<void> loadBrands() async {
//     print('🔄 [BookingFlowController] Loading brands...');
//     developer.log('🔄 Loading brands...', name: 'BookingFlowController');
//     model.isLoadingBrands = true;
//     _refresh();
//
//     try {
//       final brandItems = await _repository.getBrands();
//       model.brands = brandItems
//           .map((b) => b.name)
//           .where((n) => n.trim().isNotEmpty)
//           .toList();
//       print('✅ [BookingFlowController] Loaded ${model.brands.length} brands');
//       developer.log('✅ Loaded ${model.brands.length} brands', name: 'BookingFlowController');
//       if (model.brands.isEmpty) {
//         model.errorMessage = 'No brands returned from server';
//       }
//     } catch (e) {
//       print('💥 [BookingFlowController] Error loading brands: $e');
//       developer.log('❌ Error loading brands: $e', name: 'BookingFlowController');
//       model.errorMessage = 'Failed to load brands';
//     } finally {
//       model.isLoadingBrands = false;
//       _refresh();
//     }
//   }
//
//   Future<void> selectBrand(String brand) async {
//     developer.log('🏷️ Brand selected: $brand', name: 'BookingFlowController');
//     model.selectedBrand = brand;
//     model.catalogProducts = [];
//     _refresh();
//     await loadProductsForBrand(brand);
//   }
//
//   // ============= PRODUCTS (per brand) =============
//   Future<void> loadProductsForBrand(String brand) async {
//     print('🔄 [BookingFlowController] Loading products for brand: $brand');
//     developer.log('🔄 Loading products for brand: $brand', name: 'BookingFlowController');
//     model.isLoadingProducts = true;
//     _refresh();
//
//     try {
//       final items = await _repository.getProductsByBrand(brand);
//       model.catalogProducts = items
//           .map((p) => CatalogProduct(
//         id: p.id,
//         name: p.name,
//         brand: p.brand,
//         category: '',
//         rate: double.tryParse(p.price.replaceAll(',', '')) ?? 0,
//         packInfo: '',
//       ))
//           .where((p) => p.name.trim().isNotEmpty)
//           .toList();
//
//       print('✅ [BookingFlowController] Loaded ${model.catalogProducts.length} products for $brand');
//       developer.log('✅ Loaded ${model.catalogProducts.length} products for $brand',
//           name: 'BookingFlowController');
//       if (model.catalogProducts.isEmpty) {
//         model.errorMessage = 'No products found for $brand';
//       }
//     } catch (e) {
//       print('💥 [BookingFlowController] Error loading products for $brand: $e');
//       developer.log('❌ Error loading products for $brand: $e', name: 'BookingFlowController');
//       model.errorMessage = 'Failed to load products';
//     } finally {
//       model.isLoadingProducts = false;
//       _refresh();
//     }
//   }
//
//   List<CatalogProduct> searchCatalog(String query) {
//     final source = model.catalogProducts;
//     if (query.trim().isEmpty) return source;
//     final q = query.trim().toLowerCase();
//     return source.where((p) => p.name.toLowerCase().contains(q)).toList();
//   }
//
//   // ============= LINE ITEMS (add / edit / remove) =============
//   void addOrUpdateLineItem({
//     required CatalogProduct product,
//     required int quantity,
//     required String unit,
//     required double discountPercent,
//     required int bonusPieces,
//   }) {
//     developer.log(
//       '➕ Adding line item: ${product.name} qty=$quantity unit=$unit disc=$discountPercent% bonus=$bonusPieces',
//       name: 'BookingFlowController',
//     );
//
//     if (quantity <= 0) {
//       developer.log('⚠️ Ignored — quantity must be > 0', name: 'BookingFlowController');
//       return;
//     }
//
//     final existingIndex = model.lineItems.indexWhere(
//           (i) => i.productName.trim().toLowerCase() == product.name.trim().toLowerCase(),
//     );
//     if (existingIndex != -1) {
//       model.lineItems[existingIndex]
//         ..quantity = quantity
//         ..discountPercent = discountPercent
//         ..bonusPieces = bonusPieces;
//       developer.log('🔁 Updated existing line item at index $existingIndex', name: 'BookingFlowController');
//     } else {
//       model.lineItems.add(BookingLineItem(
//         id: product.id,
//         productName: product.name,
//         brand: product.brand,
//         rate: product.rate,
//         unit: unit,
//         packInfo: product.packInfo,
//         quantity: quantity,
//         discountPercent: discountPercent,
//         bonusPieces: bonusPieces,
//       ));
//       developer.log('✅ Added new line item. Total items now: ${model.lineItems.length}',
//           name: 'BookingFlowController');
//     }
//     _refresh();
//   }
//
//   void removeLineItem(String productName) {
//     developer.log('🗑️ Removing line item: $productName', name: 'BookingFlowController');
//     model.lineItems.removeWhere(
//           (i) => i.productName.trim().toLowerCase() == productName.trim().toLowerCase(),
//     );
//     _refresh();
//   }
//
//   // ============= SHARE / PDF (Bill Summary screen) =============
//   Future<void> exportPdf() async {
//     developer.log('📄 Export PDF tapped — ${model.lineItems.length} items, grandTotal=${model.grandTotal}',
//         name: 'BookingFlowController');
//   }
//
//   Future<void> shareOnWhatsApp() async {
//     final text = _buildShareText();
//     developer.log('📲 Share on WhatsApp tapped:\n$text', name: 'BookingFlowController');
//   }
//
//   String _buildShareText() {
//     final buffer = StringBuffer();
//     buffer.writeln('Bill Summary - ${model.shopName}');
//     buffer.writeln(model.shopSubtitle);
//     buffer.writeln('---');
//     for (final item in model.lineItems) {
//       buffer.writeln('${item.productName} x${item.quantity} = Rs ${item.netAmount.toStringAsFixed(0)}');
//     }
//     buffer.writeln('---');
//     buffer.writeln('Subtotal: Rs ${model.subtotal.toStringAsFixed(0)}');
//     buffer.writeln('GST (18%): Rs ${model.gstAmount.toStringAsFixed(0)}');
//     buffer.writeln('Grand Total: Rs ${model.grandTotal.toStringAsFixed(0)}');
//     return buffer.toString();
//   }
//
//   // ============= CONFIRM BOOKING =============
//   final RxBool isSubmitting = false.obs;
//
//   Future<bool> confirmBooking() async {
//     print('🚀 [BookingFlowController] Confirming booking...');
//
//     if (model.lineItems.isEmpty) {
//       model.errorMessage = 'Please add at least one product';
//       _refresh();
//       return false;
//     }
//
//     isSubmitting.value = true;
//     _refresh();
//
//     try {
//       // Generate IDs
//       final empInfo = await _repository.getEmployeeInfo();
//       final now = DateTime.now();
//       final day = DateFormat('dd').format(now);
//       final month = DateFormat('MMM').format(now).toUpperCase();
//       final timePart = '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';
//       final empId = (empInfo['empId'] ?? '').padLeft(2, '0');
//       final companyCode = empInfo['companyCode'] ?? '';
//
//       model.visitId ??= '${companyCode.isNotEmpty ? "$companyCode-" : ""}SV-EMP-$empId-$day-$month-$timePart';
//       model.orderId ??= '${companyCode.isNotEmpty ? "$companyCode-" : ""}OD-EMP-$empId-$day-$month-$timePart';
//
//       print('🆔 [BookingFlowController] visit_id=${model.visitId} order_id=${model.orderId}');
//
//       // ✅ Repository hamesha success return karega (offline queue)
//       final result = await _repository.submitBooking(
//         model,
//         visitType: 'Booking',
//         status: 'CONFIRMED',
//       );
//
//       if (result.success) {
//         model.bookingId = result.visitId ?? model.visitId;
//         await clearStockQtyFromPrefs(shopId: model.shopId);
//         print('✅ [BookingFlowController] Booking confirmed: ${model.bookingId}');
//         return true;
//       } else {
//         // Yeh kabhi nahi hona chahiye (repository hamesha success return karega)
//         model.errorMessage = result.message ?? 'Failed to confirm booking';
//         return false;
//       }
//     } catch (e, st) {
//       print('💥 [BookingFlowController] Error: $e');
//       print(st);
//       model.errorMessage = 'Failed to confirm booking';
//       return false;
//     } finally {
//       isSubmitting.value = false;
//       _refresh();
//     }
//   }
//
//   // ============= POST-CONFIRM (merchandising proof) =============
//   Future<void> captureShopPhoto() async {
//     developer.log('📸 Capture shop photo tapped', name: 'BookingFlowController');
//   }
//
//   Future<void> captureShelfPhoto() async {
//     developer.log('📸 Capture shelf photo tapped', name: 'BookingFlowController');
//   }
//
//   void clearError() {
//     model.errorMessage = null;
//     _refresh();
//   }
//   // Add this method to BookingFlowController class:
//
//   /// Public method to refresh UI (used by CustomerAccountScreen)
//   void refreshUI() {
//     _refresh();
//   }
// }

///offfline
import 'dart:developer' as developer;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/booking_flow_model.dart';
import '../repositories/booking_repository.dart';
import '../screens/add_products_screen.dart';

class BookingFlowController extends GetxController {
  BookingFlowController({
    required String shopId,
    required String shopName,
    required String shopSubtitle,
    String? visitId,
    // ✅ NEW PARAMETERS
    String shopAddress = '',
    String ownerName = '',
    double? latitude,
    double? longitude,
    bool gpsEnabled = false,
    BookingRepository? repository,
  })  : model = BookingFlowModel(
    shopId: shopId,
    shopName: shopName,
    shopSubtitle: shopSubtitle,
    // ✅ INITIALIZE WITH VALUES
    shopAddress: shopAddress,
    ownerName: ownerName,
    latitude: latitude,
    longitude: longitude,
    gpsEnabled: gpsEnabled,
  ),
        _repository = repository ?? BookingRepository() {
    if (visitId != null && visitId.isNotEmpty) {
      model.visitId = visitId;
    }
  }

  final BookingFlowModel model;
  final BookingRepository _repository;

  set visitId(String? value) {
    if (value != null && value.isNotEmpty) {
      model.visitId = value;
    }
  }

  final RxInt _tick = 0.obs;
  void _refresh() {
    _tick.value++;
    model.logState('refresh');
  }

  RxInt get tick => _tick;

  @override
  void onInit() {
    super.onInit();
    developer.log('🚀 BookingFlowController init for shop=${model.shopName} (${model.shopId})',
        name: 'BookingFlowController');
    loadCustomerAccount();
    loadBrands();
  }

  // ============= CUSTOMER ACCOUNT =============
  Future<void> loadCustomerAccount() async {
    print('🔄 [BookingFlowController] Loading customer account for shop ${model.shopId}...');
    developer.log('🔄 Loading customer account for shop ${model.shopId}...',
        name: 'BookingFlowController');
    model.isLoadingAccount = true;
    _refresh();

    try {
      model.account = await _repository.getCustomerAccount(
        model.shopId,
        shopName: model.shopName,
        shopSubtitle: model.shopSubtitle,
      );
      print('✅ [BookingFlowController] Customer account loaded: due=${model.account?.paymentDue}');
      developer.log('✅ Customer account loaded: due=${model.account?.paymentDue}',
          name: 'BookingFlowController');
    } catch (e) {
      print('💥 [BookingFlowController] Error loading customer account: $e');
      developer.log('❌ Error loading customer account: $e', name: 'BookingFlowController');
      model.errorMessage = 'Failed to load customer account';
    } finally {
      model.isLoadingAccount = false;
      _refresh();
    }
  }

  Future<void> receivePayment() async {
    developer.log('💰 Receive Payment tapped for shop ${model.shopId}', name: 'BookingFlowController');
  }

  // ============= BRANDS =============
  Future<void> loadBrands() async {
    print('🔄 [BookingFlowController] Loading brands...');
    developer.log('🔄 Loading brands...', name: 'BookingFlowController');
    model.isLoadingBrands = true;
    _refresh();

    try {
      final brandItems = await _repository.getBrands();
      model.brands = brandItems
          .map((b) => b.name)
          .where((n) => n.trim().isNotEmpty)
          .toList();
      print('✅ [BookingFlowController] Loaded ${model.brands.length} brands');
      developer.log('✅ Loaded ${model.brands.length} brands', name: 'BookingFlowController');
      if (model.brands.isEmpty) {
        model.errorMessage = 'No brands returned from server';
      }
    } catch (e) {
      print('💥 [BookingFlowController] Error loading brands: $e');
      developer.log('❌ Error loading brands: $e', name: 'BookingFlowController');
      model.errorMessage = 'Failed to load brands';
    } finally {
      model.isLoadingBrands = false;
      _refresh();
    }
  }

  Future<void> selectBrand(String brand) async {
    developer.log('🏷️ Brand selected: $brand', name: 'BookingFlowController');
    model.selectedBrand = brand;
    model.catalogProducts = [];
    _refresh();
    await loadProductsForBrand(brand);
  }

  // ============= PRODUCTS (per brand) =============
  Future<void> loadProductsForBrand(String brand) async {
    print('🔄 [BookingFlowController] Loading products for brand: $brand');
    developer.log('🔄 Loading products for brand: $brand', name: 'BookingFlowController');
    model.isLoadingProducts = true;
    _refresh();

    try {
      final items = await _repository.getProductsByBrand(brand);
      model.catalogProducts = items
          .map((p) => CatalogProduct(
        id: p.id,
        name: p.name,
        brand: p.brand,
        category: '',
        rate: double.tryParse(p.price.replaceAll(',', '')) ?? 0,
        packInfo: '',
      ))
          .where((p) => p.name.trim().isNotEmpty)
          .toList();

      print('✅ [BookingFlowController] Loaded ${model.catalogProducts.length} products for $brand');
      developer.log('✅ Loaded ${model.catalogProducts.length} products for $brand',
          name: 'BookingFlowController');
      if (model.catalogProducts.isEmpty) {
        model.errorMessage = 'No products found for $brand';
      }
    } catch (e) {
      print('💥 [BookingFlowController] Error loading products for $brand: $e');
      developer.log('❌ Error loading products for $brand: $e', name: 'BookingFlowController');
      model.errorMessage = 'Failed to load products';
    } finally {
      model.isLoadingProducts = false;
      _refresh();
    }
  }

  List<CatalogProduct> searchCatalog(String query) {
    final source = model.catalogProducts;
    if (query.trim().isEmpty) return source;
    final q = query.trim().toLowerCase();
    return source.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  // ============= LINE ITEMS (add / edit / remove) =============
  void addOrUpdateLineItem({
    required CatalogProduct product,
    required int quantity,
    required String unit,
    required double discountPercent,
    required int bonusPieces,
  }) {
    developer.log(
      '➕ Adding line item: ${product.name} qty=$quantity unit=$unit disc=$discountPercent% bonus=$bonusPieces',
      name: 'BookingFlowController',
    );

    if (quantity <= 0) {
      developer.log('⚠️ Ignored — quantity must be > 0', name: 'BookingFlowController');
      return;
    }

    final existingIndex = model.lineItems.indexWhere(
          (i) => i.productName.trim().toLowerCase() == product.name.trim().toLowerCase(),
    );
    if (existingIndex != -1) {
      model.lineItems[existingIndex]
        ..quantity = quantity
        ..discountPercent = discountPercent
        ..bonusPieces = bonusPieces;
      developer.log('🔁 Updated existing line item at index $existingIndex', name: 'BookingFlowController');
    } else {
      model.lineItems.add(BookingLineItem(
        id: product.id,
        productName: product.name,
        brand: product.brand,
        rate: product.rate,
        unit: unit,
        packInfo: product.packInfo,
        quantity: quantity,
        discountPercent: discountPercent,
        bonusPieces: bonusPieces,
      ));
      developer.log('✅ Added new line item. Total items now: ${model.lineItems.length}',
          name: 'BookingFlowController');
    }
    _refresh();
  }

  void removeLineItem(String productName) {
    developer.log('🗑️ Removing line item: $productName', name: 'BookingFlowController');
    model.lineItems.removeWhere(
          (i) => i.productName.trim().toLowerCase() == productName.trim().toLowerCase(),
    );
    _refresh();
  }

  // ============= SHARE / PDF (Bill Summary screen) =============
  Future<void> exportPdf() async {
    developer.log('📄 Export PDF tapped — ${model.lineItems.length} items, grandTotal=${model.grandTotal}',
        name: 'BookingFlowController');
  }

  Future<void> shareOnWhatsApp() async {
    final text = _buildShareText();
    developer.log('📲 Share on WhatsApp tapped:\n$text', name: 'BookingFlowController');
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('Bill Summary - ${model.shopName}');
    buffer.writeln(model.shopSubtitle);
    buffer.writeln('---');
    for (final item in model.lineItems) {
      buffer.writeln('${item.productName} x${item.quantity} = Rs ${item.netAmount.toStringAsFixed(0)}');
    }
    buffer.writeln('---');
    buffer.writeln('Subtotal: Rs ${model.subtotal.toStringAsFixed(0)}');
    buffer.writeln('GST (18%): Rs ${model.gstAmount.toStringAsFixed(0)}');
    buffer.writeln('Grand Total: Rs ${model.grandTotal.toStringAsFixed(0)}');
    return buffer.toString();
  }

  // ============= CONFIRM BOOKING =============
  final RxBool isSubmitting = false.obs;

  Future<bool> confirmBooking() async {
    print('🚀 [BookingFlowController] Confirming booking...');

    if (model.lineItems.isEmpty) {
      model.errorMessage = 'Please add at least one product';
      _refresh();
      return false;
    }

    isSubmitting.value = true;
    _refresh();

    try {
      // Generate IDs
      final empInfo = await _repository.getEmployeeInfo();
      final now = DateTime.now();
      final day = DateFormat('dd').format(now);
      final month = DateFormat('MMM').format(now).toUpperCase();
      final timePart = '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';
      final empId = (empInfo['empId'] ?? '').padLeft(2, '0');
      final companyCode = empInfo['companyCode'] ?? '';

      model.visitId ??= '${companyCode.isNotEmpty ? "$companyCode-" : ""}SV-EMP-$empId-$day-$month-$timePart';
      model.orderId ??= '${companyCode.isNotEmpty ? "$companyCode-" : ""}OD-EMP-$empId-$day-$month-$timePart';

      print('🆔 [BookingFlowController] visit_id=${model.visitId} order_id=${model.orderId}');

      // ✅ Repository hamesha success return karega (offline queue)
      final result = await _repository.submitBooking(
        model,
        visitType: 'Booking',
        status: 'CONFIRMED',
      );

      if (result.success) {
        model.bookingId = result.visitId ?? model.visitId;
        await clearStockQtyFromPrefs(shopId: model.shopId);
        print('✅ [BookingFlowController] Booking confirmed: ${model.bookingId}');
        return true;
      } else {
        // Yeh kabhi nahi hona chahiye (repository hamesha success return karega)
        model.errorMessage = result.message ?? 'Failed to confirm booking';
        return false;
      }
    } catch (e, st) {
      print('💥 [BookingFlowController] Error: $e');
      print(st);
      model.errorMessage = 'Failed to confirm booking';
      return false;
    } finally {
      isSubmitting.value = false;
      _refresh();
    }
  }

  // ============= POST-CONFIRM (merchandising proof) =============
  Future<void> captureShopPhoto() async {
    developer.log('📸 Capture shop photo tapped', name: 'BookingFlowController');
  }

  Future<void> captureShelfPhoto() async {
    developer.log('📸 Capture shelf photo tapped', name: 'BookingFlowController');
  }

  void clearError() {
    model.errorMessage = null;
    _refresh();
  }

  /// Public method to refresh UI (used by CustomerAccountScreen)
  void refreshUI() {
    _refresh();
  }
}