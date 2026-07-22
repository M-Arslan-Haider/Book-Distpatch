// ═══════════════════════════════════════════════════════════════════════════
// no_sale_visit_controller.dart
//
// GetX controller for the "No Sale of Stock" flow (Select Shop -> Add Stock
// -> capture photo + GPS -> submit).
//
// Uses image_picker + flutter_image_compress + location, same pattern used
// elsewhere in the app (see ShopVisitViewModel._compressImage).
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;

import '../models/no_sale_visit_model.dart';
import '../repositories/no_sale_visit_repository.dart';

class NoSaleVisitController extends GetxController {
  NoSaleVisitController({
    required String shopId,
    required String shopName,
    String shopAddress = '',
    String ownerName = '',
    String? shopSubtitle,
    NoSaleVisitRepository? repository,
  })  : model = NoSaleVisitModel(
    shopId: shopId,
    shopName: shopName,
    shopAddress: shopAddress,
    ownerName: ownerName,
    shopSubtitle: shopSubtitle,
  ),
        _repository = repository ?? NoSaleVisitRepository();

  final NoSaleVisitModel model;
  final NoSaleVisitRepository _repository;

  static const int _targetMaxBytes = 150 * 1024; // ~150 KB cap — keeps base64 payload small enough for ORDS

  // Reactive trigger — model is a plain mutable class, bump this to force
  // GetX widgets (Obx / GetBuilder) to rebuild.
  final RxInt _tick = 0.obs;
  void _refresh() {
    _tick.value++;
    model.logState('refresh');
  }

  RxInt get tick => _tick;

  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    developer.log(
      '🚀 NoSaleVisitController init for shop=${model.shopName} (${model.shopId})',
      name: 'NoSaleVisitController',
    );
    loadBrands();
    captureLocation(); // auto-attempt GPS on entry
  }

  // ============= BRANDS =============
  Future<void> loadBrands() async {
    developer.log('🔄 Loading brands...', name: 'NoSaleVisitController');
    model.isLoadingBrands = true;
    _refresh();

    try {
      model.brands = await _repository.getBrands();
      developer.log('✅ Loaded ${model.brands.length} brands', name: 'NoSaleVisitController');
      if (model.brands.isEmpty) {
        model.errorMessage = 'No brands returned from server';
      }
    } catch (e) {
      developer.log('❌ Error loading brands: $e', name: 'NoSaleVisitController');
      model.errorMessage = 'Failed to load brands';
    } finally {
      model.isLoadingBrands = false;
      _refresh();
    }
  }

  Future<void> selectBrand(String brand) async {
    developer.log('🏷️ Brand selected: $brand', name: 'NoSaleVisitController');
    model.selectedBrand = brand;
    model.catalogProducts = [];
    _refresh();
    await loadProductsForBrand(brand);
  }

  // ============= PRODUCTS (per brand) =============
  Future<void> loadProductsForBrand(String brand) async {
    developer.log('🔄 Loading products for brand: $brand', name: 'NoSaleVisitController');
    model.isLoadingProducts = true;
    _refresh();

    try {
      model.catalogProducts = await _repository.getProductsByBrand(brand);
      developer.log('✅ Loaded ${model.catalogProducts.length} products for $brand',
          name: 'NoSaleVisitController');
      if (model.catalogProducts.isEmpty) {
        model.errorMessage = 'No products found for $brand';
      }
    } catch (e) {
      developer.log('❌ Error loading products for $brand: $e', name: 'NoSaleVisitController');
      model.errorMessage = 'Failed to load products';
    } finally {
      model.isLoadingProducts = false;
      _refresh();
    }
  }

  List<StockCatalogProduct> searchCatalog(String query) {
    final source = model.catalogProducts;
    if (query.trim().isEmpty) return source;
    final q = query.trim().toLowerCase();
    return source.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  void addOrUpdateStock({
    required StockCatalogProduct product,
    required int quantity,
  }) {
    developer.log('➕ Adding stock: ${product.name} qty=$quantity', name: 'NoSaleVisitController');

    if (quantity <= 0) {
      developer.log('⚠️ Ignored — quantity must be > 0', name: 'NoSaleVisitController');
      return;
    }

    final existingIndex = model.lineItems.indexWhere(
          (i) => i.productName.trim().toLowerCase() == product.name.trim().toLowerCase(),
    );

    if (existingIndex != -1) {
      model.lineItems[existingIndex].quantity = quantity;
      developer.log('🔁 Updated existing stock item at index $existingIndex',
          name: 'NoSaleVisitController');
    } else {
      model.lineItems.add(StockLineItem(
        id: product.id,
        productName: product.name,
        brand: product.brand,
        price: product.price,
        quantity: quantity,
      ));
      developer.log('✅ Added new stock item. Total items now: ${model.lineItems.length}',
          name: 'NoSaleVisitController');
    }
    _refresh();
  }

  // ⚠️ Backend sends a duplicate/non-unique `id` for different products
  // (e.g. every product in a brand can come back as id="2"), so matching
  // must be done by product NAME, not id.
  void removeStock(String productName) {
    developer.log('🗑️ Removing stock item: $productName', name: 'NoSaleVisitController');
    model.lineItems.removeWhere(
          (i) => i.productName.trim().toLowerCase() == productName.trim().toLowerCase(),
    );
    _refresh();
  }

  // ============= SHOP PHOTO =============
  Future<bool> captureShopPhoto({required bool fromCamera}) async {
    developer.log('📸 Capturing shop photo (fromCamera=$fromCamera)', name: 'NoSaleVisitController');
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        developer.log('⚠️ Photo capture cancelled', name: 'NoSaleVisitController');
        return false;
      }

      final originalBytes = await pickedFile.readAsBytes();
      final compressedBytes = await _compressImage(originalBytes);
      developer.log(
        '🗜️ Compressed size: ${compressedBytes.length} bytes (was ${originalBytes.length})',
        name: 'NoSaleVisitController',
      );

      model.shopPhotoBase64 = base64Encode(compressedBytes);
      developer.log('✅ Shop photo captured, base64 length: ${model.shopPhotoBase64?.length}',
          name: 'NoSaleVisitController');
      _refresh();
      return true;
    } catch (e) {
      developer.log('❌ Error capturing shop photo: $e', name: 'NoSaleVisitController');
      model.errorMessage = 'Failed to capture photo';
      _refresh();
      return false;
    }
  }

  void clearShopPhoto() {
    model.shopPhotoBase64 = null;
    _refresh();
  }

  // no_sale_visit_controller.dart mein _compressImage ko update karo

  Future<List<int>> _compressImage(List<int> inputBytes) async {
    // Pehle se hi chhota dimension aur quality
    int quality = 50;  // 70 se kam
    int minSide = 800; // 1024 se kam
    List<int> result = inputBytes;

    // Target 100KB karte hain (150KB se kam)
    const int targetMaxBytes = 100 * 1024;

    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(inputBytes),
          quality: quality,
          minWidth: minSide,
          minHeight: minSide,
          format: CompressFormat.jpeg,
        );

        result = compressed;
        developer.log(
          '🗜️ Attempt ${attempt + 1}: quality=$quality, size=${compressed.length} bytes',
          name: 'NoSaleVisitController',
        );

        if (compressed.length <= targetMaxBytes) break;

        // Zyada aggressive reduction
        quality = (quality * 0.7).round(); // 70% of previous
        minSide = (minSide * 0.7).round();
        if (quality < 10) quality = 10;
        if (minSide < 300) minSide = 300;
      } catch (e) {
        developer.log('⚠️ Compression error: $e', name: 'NoSaleVisitController');
        break;
      }
    }

    return result;
  }

  // ============= LOCATION (GPS) =============
  Future<bool> captureLocation() async {
    developer.log('📍 Capturing current location...', name: 'NoSaleVisitController');
    model.isCapturingLocation = true;
    _refresh();

    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          developer.log('❌ Location service not enabled', name: 'NoSaleVisitController');
          model.gpsEnabled = false;
          model.errorMessage = 'Please enable location services';
          return false;
        }
      }

      loc.PermissionStatus permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) {
          developer.log('❌ Location permission denied', name: 'NoSaleVisitController');
          model.gpsEnabled = false;
          model.errorMessage = 'Location permission denied';
          return false;
        }
      }

      final locData = await location.getLocation();
      model.latitude = locData.latitude;
      model.longitude = locData.longitude;
      model.gpsEnabled = true;

      developer.log('✅ Location captured: ${model.latitude}, ${model.longitude}',
          name: 'NoSaleVisitController');
      return true;
    } catch (e) {
      developer.log('❌ Error capturing location: $e', name: 'NoSaleVisitController');
      model.gpsEnabled = false;
      model.errorMessage = 'Failed to get current location';
      return false;
    } finally {
      model.isCapturingLocation = false;
      _refresh();
    }
  }

  // ── Generate unique Visit ID (same style used across the app) ─────────
  // Format: {COMPANY_CODE}-SV-EMP-{empId}-{dd}-{MMM}-{HHmmss}{ms}
  Future<String> _generateVisitId() async {
    final empInfo = await _repository.getEmployeeInfo();
    final empId = (empInfo['empId'] ?? '').padLeft(2, '0');
    final companyCode = empInfo['companyCode'] ?? '';

    final now = DateTime.now();
    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now).toUpperCase();
    final timePart =
        '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';

    String visitId;
    if (companyCode.isNotEmpty) {
      visitId = '$companyCode-SV-EMP-$empId-$day-$month-$timePart';
    } else {
      visitId = 'SV-EMP-$empId-$day-$month-$timePart';
    }

    developer.log('🆔 Generated visit_id: $visitId', name: 'NoSaleVisitController');
    return visitId;
  }

  //============= SUBMIT =============
  Future<bool> submitVisit() async {
    developer.log('🚀 Submitting No Sale of Stock visit for shop ${model.shopId}...',
        name: 'NoSaleVisitController');

    if (!model.hasProducts) {
      model.errorMessage = 'Please add at least one stock item';
      _refresh();
      return false;
    }

    if (!model.hasPhoto) {
      model.errorMessage = 'Please capture a shop photo';
      _refresh();
      return false;
    }

    if (!model.hasLocation) {
      developer.log('📍 No location yet — attempting capture before submit',
          name: 'NoSaleVisitController');
      final ok = await captureLocation();
      if (!ok || !model.hasLocation) {
        model.errorMessage = 'Please enable GPS to capture your location';
        _refresh();
        return false;
      }
    }

    isSubmitting.value = true;
    _refresh();

    try {
      model.visitId ??= await _generateVisitId();

      final result = await _repository.submitVisit(model);

      if (result.success) {
        developer.log('✅ No Sale of Stock visit submitted: ${result.visitId ?? model.visitId}',
            name: 'NoSaleVisitController');
        model.errorMessage = null;
        return true;
      } else {
        developer.log('❌ Submit failed: ${result.message}', name: 'NoSaleVisitController');
        model.errorMessage = result.message ?? 'Failed to submit visit';
        return false;
      }
    } catch (e, st) {
      developer.log('❌ Error submitting visit: $e', name: 'NoSaleVisitController');
      print(st);
      model.errorMessage = 'Failed to submit visit';
      return false;
    } finally {
      isSubmitting.value = false;
      _refresh();
    }
  }

  // ============= SUBMIT =============
  // Future<bool> submitVisit() async {
  //   developer.log('🚀 Submitting No Sale of Stock visit for shop ${model.shopId}...',
  //       name: 'NoSaleVisitController');
  //
  //   if (!model.hasProducts) {
  //     model.errorMessage = 'Please add at least one stock item';
  //     _refresh();
  //     return false;
  //   }
  //
  //   // Photo is now optional — removed the hasPhoto check.
  //
  //   if (!model.hasLocation) {
  //     developer.log('📍 No location yet — attempting capture before submit',
  //         name: 'NoSaleVisitController');
  //     final ok = await captureLocation();
  //     if (!ok || !model.hasLocation) {
  //       model.errorMessage = 'Please enable GPS to capture your location';
  //       _refresh();
  //       return false;
  //     }
  //   }
  //
  //   isSubmitting.value = true;
  //   _refresh();
  //
  //   try {
  //     model.visitId ??= await _generateVisitId();
  //
  //     final result = await _repository.submitVisit(model);
  //
  //     if (result.success) {
  //       developer.log('✅ No Sale of Stock visit submitted: ${result.visitId ?? model.visitId}',
  //           name: 'NoSaleVisitController');
  //       model.errorMessage = null;
  //       return true;
  //     } else {
  //       developer.log('❌ Submit failed: ${result.message}', name: 'NoSaleVisitController');
  //       model.errorMessage = result.message ?? 'Failed to submit visit';
  //       return false;
  //     }
  //   } catch (e, st) {
  //     developer.log('❌ Error submitting visit: $e', name: 'NoSaleVisitController');
  //     print(st);
  //     model.errorMessage = 'Failed to submit visit';
  //     return false;
  //   } finally {
  //     isSubmitting.value = false;
  //     _refresh();
  //   }
  // }

  void clearError() {
    model.errorMessage = null;
    _refresh();
  }
}