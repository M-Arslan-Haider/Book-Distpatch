import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit_model.dart';
import '../repositories/visit_repository.dart';

class ShopVisitViewModel extends ChangeNotifier {
  final VisitRepository _repository;
  VisitModel _model = VisitModel();

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
    await _loadEmployeeInfo();
    await Future.wait([
      loadBrands(),
      loadShops(),
    ]);
  }

  Future<void> _loadEmployeeInfo() async {
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

    notifyListeners();
  }

  // ============= LOAD BRANDS =============
  Future<void> loadBrands() async {
    _model.isLoadingBrands = true;
    _model.errorMessage = null;
    notifyListeners();

    _model.brands = await _repository.getBrands();

    _model.isLoadingBrands = false;
    notifyListeners();
  }

  // ============= LOAD SHOPS =============
  Future<void> loadShops() async {
    if (_model.employeeId.isEmpty) {
      _model.isLoadingShops = false;
      _model.errorMessage = 'Employee ID not found';
      notifyListeners();
      return;
    }

    _model.isLoadingShops = true;
    _model.errorMessage = null;
    notifyListeners();

    _model.shops = await _repository.getShops(
      _model.employeeId,
      companyCode: _model.companyCode.isNotEmpty ? _model.companyCode : null,
    );

    _model.isLoadingShops = false;
    notifyListeners();
  }

  // ============= LOAD PRODUCTS =============
  Future<void> loadProducts() async {
    if (_model.selectedBrand == null || _model.selectedBrand!.isEmpty) return;

    _model.isLoadingProducts = true;
    _model.products = [];
    _model.selectedProducts = [];
    _model.errorMessage = null;
    notifyListeners();

    _model.products = await _repository.getProductsByBrand(_model.selectedBrand!);

    _model.isLoadingProducts = false;
    notifyListeners();
  }

  // ============= SELECTIONS =============
  void selectBrand(String? brand) {
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
      _model.selectedShopId = null;
      _model.selectedShopName = null;
      _model.shopAddress = null;
      _model.ownerName = null;
    } else {
      _model.selectedShopId = shop.id;
      _model.selectedShopName = shop.name;
      _model.shopAddress = shop.address;
      _model.ownerName = shop.ownerName;
    }
    notifyListeners();
  }

  // ============= PRODUCT ACTIONS =============
  void addProduct(ProductItem product, int quantity) {
    if (quantity <= 0) return;

    final existing = _model.selectedProducts.firstWhere(
          (p) => p.name == product.name,
      orElse: () => product.copy()..quantity = 0,
    );

    if (existing.quantity > 0) {
      existing.quantity += quantity;
    } else {
      final newProduct = product.copy()..quantity = quantity;
      _model.selectedProducts.add(newProduct);
    }

    notifyListeners();
  }

  void removeProduct(String productName) {
    final index = _model.selectedProducts.indexWhere((p) => p.name == productName);
    if (index == -1) return;

    final product = _model.selectedProducts[index];
    if (product.quantity > 1) {
      product.quantity--;
    } else {
      _model.selectedProducts.removeAt(index);
    }
    notifyListeners();
  }

  ProductItem? getProductByName(String name) {
    try {
      return _model.products.firstWhere((p) => p.name == name);
    } catch (_) {
      return null;
    }
  }

  // ============= CHECKLIST =============
  void toggleGPS(bool value) {
    _model.gpsEnabled = value;
    notifyListeners();
  }

  void toggleStoreWalkThrough(bool value) {
    _model.storeWalkThrough = value;
    notifyListeners();
  }

  void togglePlanogramUpdated(bool value) {
    _model.planogramUpdated = value;
    notifyListeners();
  }

  void toggleDisplayStandards(bool value) {
    _model.displayStandards = value;
    notifyListeners();
  }

  void updateNotes(String value) {
    _model.notes = value;
    notifyListeners();
  }

  // ============= SUBMIT =============
  Future<bool> submit() async {
    if (!_model.hasSelectedBrand) {
      _model.errorMessage = 'Please select a brand';
      notifyListeners();
      return false;
    }

    if (!_model.hasSelectedShop) {
      _model.errorMessage = 'Please select a shop';
      notifyListeners();
      return false;
    }

    if (!_model.hasSelectedProducts) {
      _model.errorMessage = 'Please add at least one product';
      notifyListeners();
      return false;
    }

    final success = await _repository.submitVisit(_model.toJson());

    if (success) {
      _model.errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _model.errorMessage = 'Failed to submit visit';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _model.errorMessage = null;
    notifyListeners();
  }
}