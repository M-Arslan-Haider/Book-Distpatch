
import 'dart:developer' as developer;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/booking_flow_model.dart';
import '../repositories/booking_repository.dart';
import '../screens/add_products_screen.dart';   // ✅ yeh import add karo

class BookingFlowController extends GetxController {
  BookingFlowController({
    required String shopId,
    required String shopName,
    required String shopSubtitle,
    String? visitId,
    BookingRepository? repository,
  })  : model = BookingFlowModel(shopId: shopId, shopName: shopName, shopSubtitle: shopSubtitle),
        _repository = repository ?? BookingRepository() {
    // If a visit_id was already generated elsewhere (e.g. the "No Sale of
    // Stock" flow before routing into Order), reuse it so both records
    // share the same visit_id on the backend.
    if (visitId != null && visitId.isNotEmpty) {
      model.visitId = visitId;
    }
  }

  final BookingFlowModel model;
  final BookingRepository _repository;

  /// Allows setting/overriding the visit_id after construction — used when
  /// this controller was already registered (Get.isRegistered) before the
  /// caller obtained the visit_id to reuse.
  set visitId(String? value) {
    if (value != null && value.isNotEmpty) {
      model.visitId = value;
    }
  }

  // Reactive trigger — since BookingFlowModel is a plain mutable class,
  // bump this to force GetX widgets (Obx / GetBuilder) to rebuild.
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
    // TODO(api): open a "Receive Payment" flow / hit the payment endpoint.
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

    // ⚠️ Backend sends a duplicate/non-unique `id` for different products
    // (same as the No Sale of Stock flow), so matching must be done by
    // product NAME, not id.
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
    // TODO(api/native): generate an actual PDF (e.g. via `pdf` / `printing`
    // package) from model.lineItems + model.account, then share/save it.
    developer.log('📄 Export PDF tapped — ${model.lineItems.length} items, grandTotal=${model.grandTotal}',
        name: 'BookingFlowController');
  }

  Future<void> shareOnWhatsApp() async {
    // TODO(native): build a share message/text and invoke `share_plus` with
    // WhatsApp target, or share the generated PDF file.
    final text = _buildShareText();
    developer.log('📲 Share on WhatsApp tapped:\n$text', name: 'BookingFlowController');
    // TODO: await Share.share(text); // from share_plus package
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
    print('🚀 [BookingFlowController] Confirming booking for shop ${model.shopId}...');
    developer.log('🚀 Confirming booking for shop ${model.shopId}...', name: 'BookingFlowController');

    if (model.lineItems.isEmpty) {
      print('❌ [BookingFlowController] Validation failed: no line items');
      developer.log('❌ Validation failed: no line items', name: 'BookingFlowController');
      model.errorMessage = 'Please add at least one product before confirming';
      _refresh();
      return false;
    }

    isSubmitting.value = true;
    _refresh();

    try {
      // Generate the visit_id up front — this is what ties SHOP_VISIT to
      // its SHOP_VISIT_DETAILS rows on the backend. If one was already
      // reused from another flow (e.g. No Sale of Stock), keep it as-is.
      final empInfo = await _repository.getEmployeeInfo();
      final empId = (empInfo['empId'] ?? '').padLeft(2, '0');
      final companyCode = empInfo['companyCode'] ?? '';

      final now = DateTime.now();
      final day = DateFormat('dd').format(now);
      final month = DateFormat('MMM').format(now).toUpperCase();
      final timePart =
          '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';

      if (companyCode.isNotEmpty) {
        model.orderId ??= '$companyCode-OD-EMP-$empId-$day-$month-$timePart';
      } else {
        model.orderId ??= 'OD-EMP-$empId-$day-$month-$timePart';
      }
      print('🆔 [BookingFlowController] visit_id=${model.visitId} order_id=${model.orderId}');

      final result = await _repository.submitBooking(
        model,
        visitType: 'Booking',
        status: 'CONFIRMED',
      );

      if (result.success) {
        model.bookingId = result.visitId ?? model.visitId;
        await clearStockQtyFromPrefs(shopId: model.shopId);
        print('🧹 Stock cleared for shop ${model.shopId}');

        print('✅ [BookingFlowController] Booking confirmed: ...');
            'bookingId=${model.bookingId} serverId=${result.id} total=${model.grandTotal}';
        developer.log('✅ Booking confirmed: ${model.bookingId} total=${model.grandTotal}',
            name: 'BookingFlowController');
        return true;
      } else {
        print('❌ [BookingFlowController] Booking failed: ${result.message}');
        developer.log('❌ Booking failed: ${result.message}', name: 'BookingFlowController');
        model.errorMessage = result.message ?? 'Failed to confirm booking';
        return false;
      }
    } catch (e, st) {
      print('💥 [BookingFlowController] Error confirming booking: $e');
      print(st);
      developer.log('❌ Error confirming booking: $e', name: 'BookingFlowController');
      model.errorMessage = 'Failed to confirm booking';
      return false;
    } finally {
      isSubmitting.value = false;
      _refresh();
    }
  }

  // ============= POST-CONFIRM (merchandising proof) =============
  Future<void> captureShopPhoto() async {
    // TODO(native): reuse ShopVisitViewModel._compressImage pattern with
    // image_picker + flutter_image_compress, store into model.shopPhotoBase64.
    developer.log('📸 Capture shop photo tapped', name: 'BookingFlowController');
  }

  Future<void> captureShelfPhoto() async {
    // TODO(native): same as above for model.shelfPhotoBase64.
    developer.log('📸 Capture shelf photo tapped', name: 'BookingFlowController');
  }

  void clearError() {
    model.errorMessage = null;
    _refresh();
  }
}