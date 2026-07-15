import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit_model.dart';
import '../repositories/visit_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class ShopVisitViewModel extends ChangeNotifier {
  final VisitRepository _repository;
  VisitModel _model = VisitModel();

  // Add these for form validation
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  // Flag to track if form is complete
  bool get isFormComplete =>
      _model.hasSelectedBrand &&
          _model.hasSelectedShop &&
          _model.hasSelectedProducts &&
          _model.gpsEnabled;

  ShopVisitViewModel({VisitRepository? repository})
      : _repository = repository ?? VisitRepository();

  // Getters
  VisitModel get model => _model;
  List<BrandItem> get brands => _model.brands;
  List<ShopItem> get shops => _model.shops;
  List<ProductItem> get products => _model.products;
  List<ProductItem> get selectedProducts => _model.selectedProducts;
  int get totalQuantity => _model.totalQuantity;
  bool get isLoadingBrands => _model.isLoadingBrands;
  bool get isLoadingShops => _model.isLoadingShops;
  bool get isLoadingProducts => _model.isLoadingProducts;
  String? get errorMessage => _model.errorMessage;

  // ============= INIT =============
  Future<void> init() async {
    developer.log('🚀 Initializing ShopVisitViewModel', name: 'ShopVisitViewModel');
    await _loadEmployeeInfo();
    await Future.wait([
      loadBrands(),
      loadShops(),
    ]);
    developer.log('✅ Initialization complete', name: 'ShopVisitViewModel');
  }

  Future<void> _loadEmployeeInfo() async {
    developer.log('📋 Loading employee info from SharedPreferences', name: 'ShopVisitViewModel');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _model.employeeId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';

    _model.employeeName = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('empName') ??
        prefs.getString('name') ??
        prefs.getString('full_name') ??
        prefs.getString('fullName') ??
        '';

    _model.companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';

    developer.log('👤 Employee: ID=${_model.employeeId}, Name=${_model.employeeName}', name: 'ShopVisitViewModel');
    notifyListeners();
  }

  // ============= LOAD BRANDS =============
  Future<void> loadBrands() async {
    developer.log('🔄 Loading brands...', name: 'ShopVisitViewModel');
    _model.isLoadingBrands = true;
    _model.errorMessage = null;
    notifyListeners();

    _model.brands = await _repository.getBrands();
    developer.log('✅ Loaded ${_model.brands.length} brands', name: 'ShopVisitViewModel');

    _model.isLoadingBrands = false;
    notifyListeners();
  }

  // ============= LOAD SHOPS =============
  Future<void> loadShops() async {
    if (_model.employeeId.isEmpty) {
      developer.log('❌ Employee ID not found', name: 'ShopVisitViewModel');
      _model.isLoadingShops = false;
      _model.errorMessage = 'Employee ID not found';
      notifyListeners();
      return;
    }

    developer.log('🔄 Loading shops for employee: ${_model.employeeId}', name: 'ShopVisitViewModel');
    _model.isLoadingShops = true;
    _model.errorMessage = null;
    notifyListeners();

    _model.shops = await _repository.getShops(
      _model.employeeId,
      companyCode: _model.companyCode.isNotEmpty ? _model.companyCode : null,
    );
    developer.log('✅ Loaded ${_model.shops.length} shops', name: 'ShopVisitViewModel');

    _model.isLoadingShops = false;
    notifyListeners();
  }

  // ============= LOAD PRODUCTS =============
  Future<void> loadProducts() async {
    if (_model.selectedBrand == null || _model.selectedBrand!.isEmpty) {
      developer.log('⚠️ No brand selected, skipping product load', name: 'ShopVisitViewModel');
      return;
    }

    developer.log('🔄 Loading products for brand: ${_model.selectedBrand}', name: 'ShopVisitViewModel');
    _model.isLoadingProducts = true;
    _model.products = [];
    _model.selectedProducts = [];
    _model.errorMessage = null;
    notifyListeners();

    _model.products = await _repository.getProductsByBrand(_model.selectedBrand!);
    developer.log('✅ Loaded ${_model.products.length} products for brand: ${_model.selectedBrand}', name: 'ShopVisitViewModel');

    _model.isLoadingProducts = false;
    notifyListeners();
  }

  // ============= SELECTIONS =============
  void selectBrand(String? brand) {
    developer.log('🏷️ Brand selected: $brand', name: 'ShopVisitViewModel');
    _model.selectedBrand = brand;
    _model.products = [];
    _model.selectedProducts = [];
    notifyListeners();

    if (brand != null && brand.isNotEmpty) {
      loadProducts();
    }
  }

  void selectShop(ShopItem? shop) {
    if (shop == null) {
      developer.log('🏪 Shop deselected', name: 'ShopVisitViewModel');
      _model.selectedShopId = null;
      _model.selectedShopName = null;
      _model.shopAddress = null;
      _model.ownerName = null;
    } else {
      developer.log('🏪 Shop selected: ${shop.name} (ID: ${shop.id})', name: 'ShopVisitViewModel');
      _model.selectedShopId = shop.id;
      _model.selectedShopName = shop.name;
      _model.shopAddress = shop.address;
      _model.ownerName = shop.ownerName;
    }
    notifyListeners();
  }

  // ============= PRODUCT ACTIONS =============
  void addProduct(ProductItem product, int quantity) {
    if (quantity <= 0) {
      developer.log('⚠️ Invalid quantity: $quantity', name: 'ShopVisitViewModel');
      return;
    }

    developer.log('📦 Adding product: ${product.name}, Quantity: $quantity', name: 'ShopVisitViewModel');

    final existing = _model.selectedProducts.firstWhere(
          (p) => p.name == product.name,
      orElse: () => product.copy()..quantity = 0,
    );

    if (existing.quantity > 0) {
      existing.quantity += quantity;
      developer.log('📦 Updated existing product quantity to: ${existing.quantity}', name: 'ShopVisitViewModel');
    } else {
      final newProduct = product.copy()..quantity = quantity;
      _model.selectedProducts.add(newProduct);
      developer.log('📦 Added new product to selection', name: 'ShopVisitViewModel');
    }

    developer.log('📊 Total products selected: ${_model.selectedProducts.length}', name: 'ShopVisitViewModel');
    notifyListeners();
  }

  void removeProduct(String productName) {
    developer.log('🗑️ Removing product: $productName', name: 'ShopVisitViewModel');
    final index = _model.selectedProducts.indexWhere((p) => p.name == productName);
    if (index == -1) {
      developer.log('⚠️ Product not found: $productName', name: 'ShopVisitViewModel');
      return;
    }

    final product = _model.selectedProducts[index];
    if (product.quantity > 1) {
      product.quantity--;
      developer.log('📦 Decreased quantity to: ${product.quantity}', name: 'ShopVisitViewModel');
    } else {
      _model.selectedProducts.removeAt(index);
      developer.log('🗑️ Removed product from selection', name: 'ShopVisitViewModel');
    }
    notifyListeners();
  }

  ProductItem? getProductByName(String name) {
    try {
      return _model.products.firstWhere((p) => p.name == name);
    } catch (_) {
      developer.log('⚠️ Product not found: $name', name: 'ShopVisitViewModel');
      return null;
    }
  }

  // ============= GPS LOCATION =============
  Future<bool> getCurrentLocation() async {
    developer.log('📍 Getting current location...', name: 'ShopVisitViewModel');
    try {
      Location location = Location();

      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        developer.log('⚠️ Location service disabled, requesting...', name: 'ShopVisitViewModel');
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          developer.log('❌ Location service request denied', name: 'ShopVisitViewModel');
          _model.errorMessage = 'Location service is disabled';
          notifyListeners();
          return false;
        }
      }

      // Check location permission
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        developer.log('⚠️ Location permission denied, requesting...', name: 'ShopVisitViewModel');
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          developer.log('❌ Location permission denied', name: 'ShopVisitViewModel');
          _model.errorMessage = 'Location permission denied';
          notifyListeners();
          return false;
        }
      }

      // Get current location
      LocationData locationData = await location.getLocation();
      _model.latitude = locationData.latitude;
      _model.longitude = locationData.longitude;

      developer.log('📍 Location captured: Lat=${_model.latitude}, Long=${_model.longitude}', name: 'ShopVisitViewModel');
      notifyListeners();
      return true;
    } catch (e) {
      developer.log('❌ Error getting location: $e', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Failed to get location';
      notifyListeners();
      return false;
    }
  }

  // ============= IMAGE CAPTURE =============
  Future<bool> captureShopImage() async {
    developer.log('📸 Opening camera for shop image...', name: 'ShopVisitViewModel');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image == null) {
        developer.log('📸 Camera cancelled by user', name: 'ShopVisitViewModel');
        return false;
      }

      developer.log('📸 Image captured: ${image.name}, Size: ${await image.length()} bytes', name: 'ShopVisitViewModel');

      // Read image bytes
      final bytes = await image.readAsBytes();
      developer.log('📸 Image bytes: ${bytes.length} bytes', name: 'ShopVisitViewModel');

      // Convert to base64
      _model.shopImageBase64 = base64Encode(bytes);
      developer.log('✅ Image converted to base64, length: ${_model.shopImageBase64?.length}', name: 'ShopVisitViewModel');

      notifyListeners();
      return true;
    } catch (e) {
      developer.log('❌ Error capturing image: $e', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Failed to capture image';
      notifyListeners();
      return false;
    }
  }

  // ============= CHECKLIST =============
  void toggleGPS(bool value) {
    developer.log('📍 GPS toggled: $value', name: 'ShopVisitViewModel');
    _model.gpsEnabled = value;
    if (value) {
      getCurrentLocation();
    } else {
      _model.latitude = null;
      _model.longitude = null;
    }
    notifyListeners();
  }

  void toggleStoreWalkThrough(bool value) {
    developer.log('🔄 Store walk through toggled: $value', name: 'ShopVisitViewModel');
    _model.storeWalkThrough = value;
    notifyListeners();
  }

  void togglePlanogramUpdated(bool value) {
    developer.log('📋 Planogram updated toggled: $value', name: 'ShopVisitViewModel');
    _model.planogramUpdated = value;
    notifyListeners();
  }

  void toggleDisplayStandards(bool value) {
    developer.log('📊 Display standards toggled: $value', name: 'ShopVisitViewModel');
    _model.displayStandards = value;
    notifyListeners();
  }

  void updateNotes(String value) {
    developer.log('📝 Notes updated: ${value.length} characters', name: 'ShopVisitViewModel');
    _model.notes = value;
    notifyListeners();
  }

  // ============= RESET FORM =============
  void resetForm() {
    developer.log('🔄 Resetting form...', name: 'ShopVisitViewModel');
    _model = VisitModel();
    _isSubmitting = false;
    _model.employeeId = ''; // Will be reloaded on next init
    _model.employeeName = '';
    _model.companyCode = '';
    notifyListeners();
    developer.log('✅ Form reset complete', name: 'ShopVisitViewModel');
  }

  // ============= SUBMIT =============
  Future<bool> submit() async {
    developer.log('🚀 Starting form submission...', name: 'ShopVisitViewModel');

    // Validate form
    if (!_model.hasSelectedBrand) {
      developer.log('❌ Validation failed: No brand selected', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Please select a brand';
      notifyListeners();
      return false;
    }

    if (!_model.hasSelectedShop) {
      developer.log('❌ Validation failed: No shop selected', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Please select a shop';
      notifyListeners();
      return false;
    }

    if (!_model.hasSelectedProducts) {
      developer.log('❌ Validation failed: No products added', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Please add at least one product';
      notifyListeners();
      return false;
    }

    if (!_model.gpsEnabled) {
      developer.log('❌ Validation failed: GPS not enabled', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Please enable GPS for location tracking';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    // Get current location if GPS is enabled
    if (_model.gpsEnabled) {
      final locationSuccess = await getCurrentLocation();
      if (!locationSuccess) {
        developer.log('❌ Failed to get location', name: 'ShopVisitViewModel');
        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    }

    developer.log('📤 Submitting visit data...', name: 'ShopVisitViewModel');
    developer.log('📊 Data: ${_model.toJson()}', name: 'ShopVisitViewModel');

    final success = await _repository.submitVisit(_model.toJson());

    if (success) {
      developer.log('✅ Visit submitted successfully!', name: 'ShopVisitViewModel');
      _model.errorMessage = null;
      _isSubmitting = false;

      // Reset form after successful submission
      resetForm();

      // Reload employee info
      await _loadEmployeeInfo();
      await Future.wait([
        loadBrands(),
        loadShops(),
      ]);

      notifyListeners();
      return true;
    } else {
      developer.log('❌ Failed to submit visit', name: 'ShopVisitViewModel');
      _model.errorMessage = 'Failed to submit visit';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _model.errorMessage = null;
    notifyListeners();
  }
}