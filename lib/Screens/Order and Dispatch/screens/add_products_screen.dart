


import 'package:flutter/material.dart';
import '../../../AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../models/booking_flow_model.dart';
import '../view_models/booking_flow_controller.dart';
import 'bill_summary_screen.dart';

String _stockPrefKey(String shopId, String productName) =>
    'add_products_stock_qty::$shopId::${productName.trim().toLowerCase()}';

Future<void> saveStockQtyToPrefs({
  required String shopId,
  required String productName,
  required int quantity,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_stockPrefKey(shopId, productName), quantity);
}

Future<int> loadStockQtyFromPrefs({
  required String shopId,
  required String productName,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_stockPrefKey(shopId, productName)) ?? 0;
}

/// Clears ALL saved stock quantities for a shop (all products), so the next
/// visit/order for this shop starts fresh instead of prefilling old qty.
/// Call this once a visit is submitted or an order is placed successfully.
Future<void> clearStockQtyFromPrefs({required String shopId}) async {
  final prefs = await SharedPreferences.getInstance();
  final prefix = 'add_products_stock_qty::$shopId::';
  final keysToRemove = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
  for (final key in keysToRemove) {
    await prefs.remove(key);
  }
  developer.log('🧹 Cleared ${keysToRemove.length} saved stock qty entries for shop=$shopId',
      name: 'StockPrefs');
}

class AddProductsScreen extends StatefulWidget {
  final String controllerTag;
  const AddProductsScreen({super.key, required this.controllerTag});

  @override
  State<AddProductsScreen> createState() => _AddProductsScreenState();
}

class _AddProductsScreenState extends State<AddProductsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final BookingFlowController _controller;

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;
  static const _tealDark  = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

  @override
  void initState() {
    super.initState();
    developer.log('🚀 Opening AddProductsScreen (tag=${widget.controllerTag})', name: 'AddProductsScreen');
    _controller = Get.find<BookingFlowController>(tag: widget.controllerTag);
  }

  String _fmtMoney(num v) => 'Rs ${NumberFormat('#,##0').format(v)}';

  Future<void> _openBrandPicker() async {
    final model = _controller.model;
    developer.log('🏷️ Opening brand picker, ${model.brands.length} brands available',
        name: 'AddProductsScreen');

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
      developer.log('⚠️ Search tapped without a brand selected — prompting user',
          name: 'AddProductsScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a brand first')),
      );
      return;
    }

    developer.log('🔍 Opening product search sheet for brand=${model.selectedBrand}',
        name: 'AddProductsScreen');

    final CatalogProduct? picked = await showModalBottomSheet<CatalogProduct>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProductSearchSheet(controller: _controller),
    );

    if (picked != null) {
      developer.log('✅ Product picked from search: ${picked.name}', name: 'AddProductsScreen');
      await _openQuantitySheet(picked);
    }
  }

  Future<void> _openQuantitySheet(CatalogProduct product) async {
    developer.log('🧮 Opening quantity/discount/bonus sheet for ${product.name}',
        name: 'AddProductsScreen');

    final shopId = _controller.model.shopId;

    final existing = _controller.model.lineItems.where(
          (i) => i.productName.trim().toLowerCase() == product.name.trim().toLowerCase(),
    ).toList();
    final prefill = existing.isNotEmpty ? existing.first : null;

    // Always resolves to a non-null int; defaults to 0 when no stock is
    // saved for this shop/product combination.
    int savedStock = 0;
    try {
      // 🔍 DEBUG: Key print karo
      final key = 'add_products_stock_qty::${shopId}::${product.name.trim().toLowerCase()}';
      print('🔍 LOADING: key="$key"');

      savedStock = await loadStockQtyFromPrefs(
        shopId: shopId,
        productName: product.name.trim(),
      );
      print('📦 LOADED: savedStock=$savedStock');
    } catch (e) {
      developer.log('⚠️ Failed to load saved stock, defaulting to 0: $e', name: 'AddProductsScreen');
      savedStock = 0;
    }

    developer.log(
      '📦 Loaded saved stock: $savedStock for ${product.name}',
      name: 'AddProductsScreen',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductQuantitySheet(
        product: product,
        stock: savedStock,
        initialQuantity: prefill?.quantity ?? 0,
        initialDiscount: prefill?.discountPercent ?? 0,
        initialBonus: prefill?.bonusPieces ?? 0,
        onAdd: (qty, unit, discount, bonus) {
          _controller.addOrUpdateLineItem(
            product: product,
            quantity: qty,
            unit: unit,
            discountPercent: discount,
            bonusPieces: bonus,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name    = loginVM.currentUser.value?.emp_name ?? 'User';
    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(
        userName:     name,
        userInitials: initials,
        scaffoldKey:  _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: Obx(() {
          _controller.tick.value;
          final model = _controller.model;

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

                      const Text('Add Products',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                      const SizedBox(height: 2),
                      Text(model.shopName,
                          style: const TextStyle(fontSize: 13, color: _tealDark, fontWeight: FontWeight.w600)),

                      const SizedBox(height: 14),

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
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer_outlined, size: 18, color: _tealDark),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  model.selectedBrand ?? 'Select Brand',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: model.selectedBrand != null ? _textDark : _textMuted,
                                  ),
                                ),
                              ),
                              if (model.isLoadingBrands)
                                const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _tealDark),
                                )
                              else
                                const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _openProductSearch,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search_rounded, color: _tealDark, size: 20),
                              SizedBox(width: 10),
                              Text('Search & Add Product',
                                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _tealDark)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text('ORDER ITEMS (${model.lineItems.length})', style: _labelStyle),
                      const SizedBox(height: 10),

                      if (model.lineItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Center(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(fontSize: 13.5, color: _textMuted),
                                children: [
                                  TextSpan(text: 'No products '),
                                  TextSpan(
                                    text: 'added',
                                    style: TextStyle(color: _tealDark, fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: ' yet.'),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...model.lineItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrderItemCard(
                            item: item,
                            onEdit: () {
                              final product = CatalogProduct(
                                id: item.id,
                                name: item.productName,
                                brand: item.brand,
                                category: '',
                                rate: item.rate,
                                packInfo: item.packInfo,
                              );
                              _openQuantitySheet(product);
                            },
                            onDelete: () {
                              HapticFeedback.lightImpact();
                              _controller.removeLineItem(item.productName);
                            },
                          ),
                        )),

                      if (model.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(model.errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                              ),
                              GestureDetector(
                                onTap: _controller.clearError,
                                child: Icon(Icons.close, color: Colors.red.shade400, size: 18),
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
                  color: _bg,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 14, color: _textMuted, fontWeight: FontWeight.w600)),
                        Text(_fmtMoney(model.subtotal),
                            style: const TextStyle(fontSize: 17, color: _tealDark, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: model.lineItems.isEmpty
                            ? null
                            : () {
                          HapticFeedback.lightImpact();
                          developer.log('➡️ Review Bill tapped — going to BillSummaryScreen',
                              name: 'AddProductsScreen');
                          Get.to(() => BillSummaryScreen(controllerTag: widget.controllerTag));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tealDark,
                          disabledBackgroundColor: const Color(0xFFBFD9D5),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: model.lineItems.isEmpty
                                ? null
                                : const LinearGradient(colors: [_tealLight, _tealDark]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Review Bill',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
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

  static const _labelStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: _textMuted,
    letterSpacing: 0.6,
  );
}

class _OrderItemCard extends StatelessWidget {
  final BookingLineItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OrderItemCard({required this.item, required this.onEdit, required this.onDelete});

  String _fmtMoney(num v) => 'Rs ${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    final bonusText = item.bonusPieces > 0 ? ' +${item.bonusPieces} free' : '';
    final discountText = item.discountPercent > 0 ? ' · ${item.discountPercent.toStringAsFixed(0)}% off' : '';

    return GestureDetector(
      onTap: onEdit,
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
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(
                    '${item.quantity} pcs x Rs ${NumberFormat('#,##0').format(item.rate)}$discountText$bonusText',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmtMoney(item.netAmount),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.tealDark)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
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
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Brand',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: brands.length,
                itemBuilder: (ctx, i) {
                  final brand = brands[i];
                  final selected = brand == current;
                  return ListTile(
                    onTap: () => Navigator.pop(ctx, brand),
                    leading: const Icon(Icons.local_offer_outlined, color: AppColors.tealDark),
                    title: Text(brand, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: selected ? const Icon(Icons.check_circle, color: AppColors.tealDark) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final BookingFlowController controller;
  const _ProductSearchSheet({required this.controller});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _searchController = TextEditingController();
  List<CatalogProduct> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.controller.searchCatalog('');
  }

  void _onQueryChanged(String query) {
    developer.log('🔍 Searching products: "$query"', name: '_ProductSearchSheet');
    setState(() => _results = widget.controller.searchCatalog(query));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.controller.model.isLoadingProducts;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Select Product',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search product...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.tealDark))
                  : _results.isEmpty
                  ? const Center(
                child: Text('No products found', style: TextStyle(color: AppColors.textSecondary)),
              )
                  : ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final product = _results[i];
                  return _ProductSearchTile(
                    product: product,
                    onTap: () => Navigator.pop(ctx, product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSearchTile extends StatelessWidget {
  final CatalogProduct product;
  final VoidCallback onTap;
  const _ProductSearchTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1E3),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFFF97316), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${product.category.isNotEmpty ? product.category : product.brand} · ${product.packInfo}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs ${NumberFormat('#,##0').format(product.rate)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.tealDark)),
                const Text('/pc', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductQuantitySheet extends StatefulWidget {
  final CatalogProduct product;
  final int stock;
  final int initialQuantity;
  final double initialDiscount;
  final int initialBonus;
  final void Function(int quantity, String unit, double discountPercent, int bonusPieces) onAdd;

  const _ProductQuantitySheet({
    required this.product,
    required this.onAdd,
    this.stock = 0,
    this.initialQuantity = 0,
    this.initialDiscount = 0,
    this.initialBonus = 0,
  });

  @override
  State<_ProductQuantitySheet> createState() => _ProductQuantitySheetState();
}

class _ProductQuantitySheetState extends State<_ProductQuantitySheet> {
  late final TextEditingController _qtyController;
  late final TextEditingController _discountController;
  late final TextEditingController _bonusController;

  String _selectedUnit = 'Pieces';
  final List<String> _units = ['Pieces'];

  String? _errorText;

  // Stock is purely informational — it always defaults to 0 when no value
  // is saved for this shop/product, and it NEVER blocks the Add button.
  int get _displayStock => widget.stock < 0 ? 0 : widget.stock;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
        text: widget.initialQuantity > 0 ? widget.initialQuantity.toString() : '');
    _discountController = TextEditingController(
        text: widget.initialDiscount > 0 ? widget.initialDiscount.toStringAsFixed(0) : '');
    _bonusController = TextEditingController(
        text: widget.initialBonus > 0 ? widget.initialBonus.toString() : '');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _discountController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_qtyController.text.trim()) ?? 0;
  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  int get _bonus => int.tryParse(_bonusController.text.trim()) ?? 0;

  double get _grossTotal => _quantity * widget.product.rate;
  double get _netTotal => _grossTotal - (_grossTotal * (_discount / 100));

  // void _submit() {
  //   // ONLY quantity is validated/required here. Stock (whether 0 or any
  //   // other value) never prevents Add from working.
  //   final qty = int.tryParse(_qtyController.text.trim());
  //   if (qty == null || qty <= 0) {
  //     setState(() => _errorText = 'Enter a valid quantity');
  //     return;
  //   }
  //   final discount = _discount.clamp(0, 100).toDouble();
  //   final bonus = _bonus < 0 ? 0 : _bonus;
  //
  //   developer.log(
  //     '➕ Add tapped: ${widget.product.name} qty=$qty unit=$_selectedUnit discount=$discount bonus=$bonus stock=$_displayStock',
  //     name: '_ProductQuantitySheet',
  //   );
  //
  //   Navigator.pop(context);
  //   widget.onAdd(qty, _selectedUnit, discount, bonus);
  // }

  void _submit() {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty < 0) {
      setState(() => _errorText = 'Quantity cannot be negative');
      return;
    }
    final discount = _discount.clamp(0, 100).toDouble();
    final bonus = _bonus < 0 ? 0 : _bonus;

    Navigator.pop(context);
    widget.onAdd(qty, _selectedUnit, discount, bonus);
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(widget.product.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Rate: Rs ${NumberFormat('#,##0').format(widget.product.rate)} / piece'
                        '${widget.product.packInfo.isNotEmpty ? ' · ${widget.product.packInfo}' : ''}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),

                const SizedBox(height: 18),
                const Text('Unit', style: _fieldLabel),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUnit,
                      isExpanded: true,
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox.shrink(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: null,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Stock', style: _fieldLabel),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  // Always prints "0" when no stock is saved for this
                  // shop/product — this is purely informational and never
                  // blocks the Add button below.
                  child: Text(
                    _displayStock.toString(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Quantity', style: _fieldLabel),
                    const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                _InputBox(
                  controller: _qtyController,
                  hint: 'e.g. 24',
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                    setState(() {});
                  },
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(_errorText!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],

                if (_quantity > 0) ...[
                  const SizedBox(height: 8),
                  if (_discount > 0) ...[
                    Text(
                      'Gross: Rs ${NumberFormat('#,##0').format(_grossTotal)}  ·  '
                          'Discount: -Rs ${NumberFormat('#,##0').format(_grossTotal - _netTotal)} ($_discount%)',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '= ${_quantity.toStringAsFixed(0)} pcs · Total Rs ${NumberFormat('#,##0').format(_netTotal)}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.tealDark, fontWeight: FontWeight.w700),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discount %', style: _fieldLabel),
                          const SizedBox(height: 6),
                          _InputBox(
                            controller: _discountController,
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bonus (free pcs)', style: _fieldLabel),
                          const SizedBox(height: 6),
                          _InputBox(
                            controller: _bonusController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

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
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
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
                        child: const Text('Add',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _fieldLabel = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _InputBox({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}