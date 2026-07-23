
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../models/no_sale_visit_model.dart';
import '../view_models/shop_visit_viewmodel.dart';
import '../view_models/booking_flow_controller.dart';
import 'add_products_screen.dart';

class NoSaleStockScreen extends StatefulWidget {
  final String controllerTag;
  const NoSaleStockScreen({super.key, required this.controllerTag});

  @override
  State<NoSaleStockScreen> createState() => _NoSaleStockScreenState();
}

class _NoSaleStockScreenState extends State<NoSaleStockScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final NoSaleVisitController _controller;

  static const _bg = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark = AppColors.textPrimary;
  static const _tealDark = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<NoSaleVisitController>(tag: widget.controllerTag);
  }

  String _fmtMoney(num v) => 'Rs ${NumberFormat('#,##0').format(v)}';

  bool get _canSubmit {
    final model = _controller.model;
    final hasBrand = model.selectedBrand != null && model.selectedBrand!.isNotEmpty;
    final hasPhoto = model.hasPhoto;
    final hasLocation = model.hasLocation;
    return hasBrand && hasPhoto && hasLocation;
  }

  Future<void> _openBrandPicker() async {
    final model = _controller.model;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BrandPickerSheet(brands: model.brands, current: model.selectedBrand),
    );

    if (selected != null) {
      HapticFeedback.selectionClick();
      await _controller.selectBrand(selected);
    }
  }

  Future<void> _openProductSearch() async {
    final model = _controller.model;
    if (model.selectedBrand == null || model.selectedBrand!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a brand first')),
      );
      return;
    }

    final StockCatalogProduct? picked = await showModalBottomSheet<StockCatalogProduct>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProductSearchSheet(controller: _controller),
    );

    if (picked != null) {
      await _openQuantitySheet(picked);
    }
  }

  Future<void> _openQuantitySheet(StockCatalogProduct product) async {
    developer.log(
      '🔍 Opening qty sheet for: name="${product.name}" id="${product.id}"',
      name: 'NoSaleStockScreen',
    );

    final shopId = _controller.model.shopId;

    final existing = _controller.model.lineItems.where(
          (i) => i.productName.trim().toLowerCase() == product.name.trim().toLowerCase(),
    ).toList();
    final prefill = existing.isNotEmpty ? existing.first : null;

    int initialQty = prefill?.quantity ?? 0;
    if (initialQty <= 0) {
      initialQty = await loadStockQtyFromPrefs(
        shopId: shopId,
        productName: product.name.trim(),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StockQuantitySheet(
        product: product,
        initialQuantity: initialQty,
        onAdd: (qty) {
          _controller.addOrUpdateStock(product: product, quantity: qty);
          saveStockQtyToPrefs(
            shopId: shopId,
            productName: product.name.trim(),
            quantity: qty,
          );
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoSourceSheet(),
    );
    if (choice == null) return;
    await _controller.captureShopPhoto(fromCamera: choice);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    HapticFeedback.mediumImpact();

    await _controller.submitVisit();

    if (mounted) {
      await clearStockQtyFromPrefs(shopId: _controller.model.shopId);

      Get.snackbar(
        '✅ Saved',
        'Visit saved successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _tealDark,
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context)
            ..pop()
            ..pop();
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ✅ UPDATED: _goToOrder - Pass Address, Owner, GPS to BookingFlowController
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _goToOrder() async {
    if (!_canSubmit || _controller.isSubmitting.value) return;
    HapticFeedback.selectionClick();

    final ok = await _controller.submitVisit();
    if (!mounted) return;

    if (!ok) {
      if (_controller.model.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_controller.model.errorMessage!)),
        );
        _controller.clearError();
      }
      return;
    }

    final model = _controller.model;
    final tag = widget.controllerTag;

    // ✅ PASS ALL SHOP DATA TO BOOKING CONTROLLER
    if (!Get.isRegistered<BookingFlowController>(tag: tag)) {
      Get.put(
        BookingFlowController(
          shopId: model.shopId,
          shopName: model.shopName,
          shopSubtitle: model.shopSubtitle ?? model.shopName,
          visitId: model.visitId,
          // ✅ PASS ADDRESS AND OWNER NAME
          shopAddress: model.shopAddress,
          ownerName: model.ownerName,
          // ✅ PASS GPS
          latitude: model.latitude,
          longitude: model.longitude,
          gpsEnabled: model.gpsEnabled,
        ),
        tag: tag,
      );
    } else {
      final bookingController = Get.find<BookingFlowController>(tag: tag);
      bookingController.visitId = model.visitId;
      // ✅ UPDATE ADDRESS, OWNER, GPS
      bookingController.model.shopAddress = model.shopAddress;
      bookingController.model.ownerName = model.ownerName;
      bookingController.model.latitude = model.latitude;
      bookingController.model.longitude = model.longitude;
      bookingController.model.gpsEnabled = model.gpsEnabled;
    }

    Get.to(() => AddProductsScreen(controllerTag: tag));
  }

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name = loginVM.currentUser.value?.emp_name ?? 'User';
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(userName: name, userInitials: initials, scaffoldKey: _scaffoldKey),
      drawer: AppDrawer(),
      body: SafeArea(
        child: Obx(() {
          _controller.tick.value;
          final model = _controller.model;
          final canSubmit = _canSubmit;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).maybePop();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
                        ),
                      ),
                      const SizedBox(height: 4),

                      const Text('No Sale of Stock',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                      const SizedBox(height: 2),
                      Text(model.shopName,
                          style: const TextStyle(fontSize: 13, color: _tealDark, fontWeight: FontWeight.w600)),
                      if (model.shopSubtitle != null && model.shopSubtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(model.shopSubtitle!,
                              style: const TextStyle(fontSize: 12, color: _textMuted)),
                        ),

                      const SizedBox(height: 16),

                      Text('BRAND', style: _labelStyle),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _openBrandPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: model.selectedBrand == null ? Colors.orange.withOpacity(0.6) : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  model.selectedBrand ?? (model.isLoadingBrands ? 'Loading brands...' : 'Select brand'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: model.selectedBrand == null ? _textMuted : _textDark,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      GestureDetector(
                        onTap: _openProductSearch,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _tealLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _tealDark.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline_rounded, color: _tealDark, size: 18),
                              SizedBox(width: 8),
                              Text('Search & Add Stock Item',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _tealDark)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text('STOCK ITEMS (${model.totalItemCount})', style: _labelStyle),
                      const SizedBox(height: 8),
                      if (model.lineItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Center(
                            child: Text('No stock items added yet',
                                style: TextStyle(fontSize: 13, color: _textMuted)),
                          ),
                        )
                      else
                        ...model.lineItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StockItemTile(
                            item: item,
                            onTap: () {
                              final product = StockCatalogProduct(
                                id: item.id,
                                name: item.productName,
                                brand: item.brand,
                                price: item.price,
                              );
                              _openQuantitySheet(product);
                            },
                            onRemove: () => _controller.removeStock(item.productName),
                          ),
                        )),

                      const SizedBox(height: 20),

                      Text('SHOP PHOTO', style: _labelStyle),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: double.infinity,
                          height: model.hasPhoto ? 160 : 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: model.hasPhoto ? _tealDark : Colors.orange.withOpacity(0.6),
                              width: model.hasPhoto ? 1.4 : 1,
                            ),
                          ),
                          child: model.hasPhoto
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(base64Decode(model.shopPhotoBase64!), fit: BoxFit.cover),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _controller.clearShopPhoto,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, color: _tealDark.withOpacity(0.6), size: 26),
                              const SizedBox(height: 6),
                              const Text('Tap to capture shop photo',
                                  style: TextStyle(fontSize: 12.5, color: _textMuted)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text('LOCATION', style: _labelStyle),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: model.hasLocation ? AppColors.divider : Colors.orange.withOpacity(0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              model.hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                              color: model.hasLocation ? _tealDark : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                model.isCapturingLocation
                                    ? 'Getting current location...'
                                    : model.hasLocation
                                    ? '${model.latitude!.toStringAsFixed(6)}, ${model.longitude!.toStringAsFixed(6)}'
                                    : 'Location not captured yet',
                                style: const TextStyle(fontSize: 12.5, color: _textDark, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (!model.isCapturingLocation)
                              GestureDetector(
                                onTap: _controller.captureLocation,
                                child: const Icon(Icons.refresh_rounded, color: _tealDark, size: 20),
                              ),
                          ],
                        ),
                      ),

                      if (!canSubmit) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _missingFieldsMessage(model),
                                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_controller.isSubmitting.value || !canSubmit) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmit ? _tealDark : _tealDark.withOpacity(0.35),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _controller.isSubmitting.value
                            ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                            : const Text('Submit Visit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (_controller.isSubmitting.value || !canSubmit) ? null : _goToOrder,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: canSubmit ? _tealDark : _tealDark.withOpacity(0.35), width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _controller.isSubmitting.value
                            ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: _tealDark, strokeWidth: 2.4),
                        )
                            : Text('Order',
                            style: TextStyle(
                              color: canSubmit ? _tealDark : _tealDark.withOpacity(0.35),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _missingFieldsMessage(NoSaleVisitModel model) {
    final missing = <String>[];
    if (model.selectedBrand == null || model.selectedBrand!.isEmpty) missing.add('Brand');
    if (!model.hasPhoto) missing.add('Shop Photo');
    if (!model.hasLocation) missing.add('Location');
    return 'Please complete: ${missing.join(', ')}';
  }

  static const _labelStyle = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _textMuted, letterSpacing: 0.4);
}

class _StockItemTile extends StatelessWidget {
  final StockLineItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _StockItemTile({required this.item, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${item.brand.isNotEmpty ? '${item.brand} · ' : ''}Qty: ${item.quantity}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPickerSheet extends StatelessWidget {
  final List<String> brands;
  final String? current;
  const _BrandPickerSheet({required this.brands, required this.current});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Brand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: brands.isEmpty
                    ? const Center(child: Text('No brands available', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: brands.length,
                  itemBuilder: (context, i) {
                    final brand = brands[i];
                    final selected = brand == current;
                    return ListTile(
                      title: Text(brand, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.tealDark) : null,
                      onTap: () => Navigator.pop(context, brand),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final NoSaleVisitController controller;
  const _ProductSearchSheet({required this.controller});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<StockCatalogProduct> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.controller.model.catalogProducts;
    _searchCtrl.addListener(() {
      setState(() => _filtered = widget.controller.searchCatalog(_searchCtrl.text));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.model.isLoadingProducts;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search product...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.tealDark, strokeWidth: 2.4))
                    : _filtered.isEmpty
                    ? const Center(child: Text('No products found', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _filtered[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('Rs ${NumberFormat('#,##0').format(p.price)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C4C4)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StockQuantitySheet extends StatefulWidget {
  final StockCatalogProduct product;
  final int initialQuantity;
  final ValueChanged<int> onAdd;

  const _StockQuantitySheet({
    required this.product,
    required this.initialQuantity,
    required this.onAdd,
  });

  @override
  State<_StockQuantitySheet> createState() => _StockQuantitySheetState();
}

class _StockQuantitySheetState extends State<_StockQuantitySheet> {
  late final TextEditingController _qtyController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.initialQuantity > 0 ? widget.initialQuantity.toString() : '',
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty < 0) {
      setState(() => _errorText = 'Quantity cannot be negative');
      return;
    }
    widget.onAdd(qty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(widget.product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Rs ${NumberFormat('#,##0').format(widget.product.price)}${widget.product.brand.isNotEmpty ? ' · ${widget.product.brand}' : ''}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Unit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: const Text(
                'Pieces',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Stock', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: const InputDecoration(
                  hintText: 'e.g. 12',
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 6),
              Text(_errorText!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealDark,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.tealDark),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.tealDark),
            title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}