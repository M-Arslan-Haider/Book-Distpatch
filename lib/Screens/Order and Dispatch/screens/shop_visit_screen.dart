import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../view_models/shop_visit_viewmodel.dart';
import '../models/visit_model.dart';
import 'dart:developer' as developer;

class ShopVisitScreen extends StatelessWidget {
  const ShopVisitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShopVisitViewModel()..init(),
      child: const _ShopVisitContent(),
    );
  }
}

class _ShopVisitContent extends StatefulWidget {
  const _ShopVisitContent();

  @override
  State<_ShopVisitContent> createState() => _ShopVisitContentState();
}

class _ShopVisitContentState extends State<_ShopVisitContent> {
  static const _primary = Color(0xFF0C6B64);
  static const _bg = Color(0xFFE8F5F3);

  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShopVisitViewModel>();
    final model = viewModel.model;

    // Debug log
    developer.log('🔄 Building ShopVisitScreen', name: 'ShopVisitScreen');
    developer.log('📊 Form state - Brand: ${model.hasSelectedBrand}, Shop: ${model.hasSelectedShop}, Products: ${model.hasSelectedProducts}, GPS: ${model.gpsEnabled}', name: 'ShopVisitScreen');

    if (_notesController.text != (model.notes ?? '')) {
      _notesController.text = model.notes ?? '';
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                _buildShopInfo(viewModel, model),
                const SizedBox(height: 20),
                _buildStockSection(viewModel, model),
                const SizedBox(height: 20),
                _buildChecklist(viewModel, model),
                const SizedBox(height: 20),
                _buildPhotos(viewModel),
                const SizedBox(height: 20),
                _buildLocation(viewModel, model),
                const SizedBox(height: 20),
                _buildNotes(viewModel, model),
                if (model.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
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
                            child: Text(
                              model.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: viewModel.clearError,
                            child: Icon(Icons.close, color: Colors.red.shade400, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomSheet(viewModel),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shop Visit',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                    SizedBox(height: 2),
                    Text('Log a shop visit',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopInfo(ShopVisitViewModel vm, VisitModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.info_outline_rounded, label: 'Shop Information'),
        const SizedBox(height: 12),
        _BrandDropdown(
          brands: model.brands,
          selectedBrand: model.selectedBrand,
          isLoading: model.isLoadingBrands,
          onChanged: vm.selectBrand,
        ),
        const SizedBox(height: 10),
        _ShopDropdown(
          shops: model.shops,
          selectedShop: model.selectedShopName,
          isLoading: model.isLoadingShops,
          onChanged: vm.selectShop,
        ),
        const SizedBox(height: 10),
        _InfoField(
          label: 'Shop Address',
          value: model.shopAddress ?? 'Select a shop to see details',
          icon: Icons.location_on_rounded,
        ),
        const SizedBox(height: 10),
        _InfoField(
          label: 'Owner Name',
          value: model.ownerName ?? 'Select a shop to see details',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 10),
        _InfoField(
          label: 'Employee Name',
          value: model.employeeName.isEmpty ? 'Loading...' : model.employeeName,
          icon: Icons.badge_rounded,
        ),
      ],
    );
  }

  Widget _buildStockSection(ShopVisitViewModel vm, VisitModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.inventory_2_rounded, label: 'Stock Check'),
        const SizedBox(height: 12),
        _ProductSearchCard(
          products: model.products,
          isLoading: model.isLoadingProducts,
          selectedBrand: model.selectedBrand,
          onProductSelected: (product) {
            _showQuantityPicker(context, product, vm);
          },
        ),
        const SizedBox(height: 12),
        if (model.hasSelectedProducts)
          _SelectedProductsList(
            selectedProducts: model.selectedProducts,
            onAdd: (productName) {
              final product = vm.getProductByName(productName);
              if (product != null) vm.addProduct(product, 1);
            },
            onRemove: vm.removeProduct,
          ),
        const SizedBox(height: 12),
        _TotalQuantity(total: model.totalQuantity),
      ],
    );
  }

  Widget _buildChecklist(ShopVisitViewModel vm, VisitModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.checklist_rounded, label: 'Checklist'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
          ),
          child: Column(
            children: [
              _CheckItem(
                label: 'Performed Store Walk Through',
                value: model.storeWalkThrough,
                onChanged: vm.toggleStoreWalkThrough,
              ),
              const Divider(height: 1, color: Color(0xFFD4F0ED)),
              _CheckItem(
                label: 'Updated Store Planogram',
                value: model.planogramUpdated,
                onChanged: vm.togglePlanogramUpdated,
              ),
              const Divider(height: 1, color: Color(0xFFD4F0ED)),
              _CheckItem(
                label: 'Display Standards',
                value: model.displayStandards,
                onChanged: vm.toggleDisplayStandards,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotos(ShopVisitViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.photo_camera_rounded, label: 'Photos'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            developer.log('📸 Photo container tapped', name: 'ShopVisitScreen');
            final success = await vm.captureShopImage();
            if (success && mounted) {
              Get.snackbar(
                'Success',
                'Shop photo captured successfully',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFF0C6B64),
                colorText: Colors.white,
                borderRadius: 14,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              );
            } else if (!success && mounted) {
              Get.snackbar(
                'Info',
                'Photo capture cancelled or failed',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                borderRadius: 14,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: vm.model.shopImageBase64 != null ? const Color(0xFFE5F7F5) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: vm.model.shopImageBase64 != null
                    ? const Color(0xFF0C6B64)
                    : const Color(0xFFD4F0ED),
                width: vm.model.shopImageBase64 != null ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: vm.model.shopImageBase64 != null
                        ? const Color(0xFF0C6B64).withOpacity(0.1)
                        : const Color(0xFFE5F7F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: vm.model.shopImageBase64 != null
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0C6B64), size: 22)
                      : const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0C6B64), size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  vm.model.shopImageBase64 != null ? 'Photo captured ✓' : 'Take a photo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: vm.model.shopImageBase64 != null
                        ? const Color(0xFF0C6B64)
                        : const Color(0xFF1A2E2C),
                  ),
                ),
                if (vm.model.shopImageBase64 != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap to retake',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocation(ShopVisitViewModel vm, VisitModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.location_on_rounded, label: 'Location Settings'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: _primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS Enabled',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2C),
                      ),
                    ),
                    if (model.latitude != null && model.longitude != null)
                      Text(
                        '📍 ${model.latitude!.toStringAsFixed(6)}, ${model.longitude!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: model.gpsEnabled,
                onChanged: vm.toggleGPS,
                activeColor: _primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotes(ShopVisitViewModel vm, VisitModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.notes_rounded, label: 'Additional Info'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sticky_note_2_rounded, color: _primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2C),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Any extra remarks',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFB0BAC7),
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: vm.updateNotes,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(ShopVisitViewModel vm) {
    final isFormComplete = vm.isFormComplete && !vm.isSubmitting;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isFormComplete ? () async {
                  developer.log('🔘 Only Visit button pressed', name: 'ShopVisitScreen');
                  HapticFeedback.lightImpact();
                  final success = await vm.submit();
                  if (success && mounted) {
                    Get.snackbar(
                      'Success',
                      'Shop visit saved successfully',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFF0C6B64),
                      colorText: Colors.white,
                      borderRadius: 14,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    );
                  } else if (!success && mounted) {
                    Get.snackbar(
                      'Error',
                      vm.errorMessage ?? 'Failed to save visit',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: const Color(0xFFC0392B),
                      colorText: Colors.white,
                      borderRadius: 14,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 3),
                      icon: const Icon(Icons.error_rounded, color: Colors.white),
                    );
                  }
                } : null,
                icon: vm.isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: Text(
                  vm.isSubmitting ? 'Submitting...' : 'Only Visit',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFormComplete ? const Color(0xFFC0392B) : Colors.grey[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isFormComplete ? () {
                  developer.log('🔘 Order Form button pressed', name: 'ShopVisitScreen');
                  Get.snackbar(
                    'Info',
                    'Order Form feature coming soon',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.blue,
                    colorText: Colors.white,
                    borderRadius: 14,
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  );
                } : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                label: const Text(
                  'Order Form',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFormComplete ? const Color(0xFF0C6B64) : Colors.grey[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityPicker(BuildContext context, ProductItem product, ShopVisitViewModel vm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuantityPickerSheet(
        productName: product.name,
        productPrice: product.price,
        onQuantitySelected: (quantity) {
          vm.addProduct(product, quantity);
        },
      ),
    );
  }
}

// ============= UI COMPONENTS =============

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0C6B64), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C6B64),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoField({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FFFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0C6B64), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A6E59))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandDropdown extends StatelessWidget {
  final List<BrandItem> brands;
  final String? selectedBrand;
  final bool isLoading;
  final Function(String?) onChanged;

  const _BrandDropdown({required this.brands, required this.selectedBrand, required this.isLoading, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context, brands.map((b) => b.name).toList(), 'Select Brand', onChanged),
      child: _DropdownContainer(
        icon: Icons.branding_watermark_rounded,
        label: 'Brand',
        value: selectedBrand,
        hint: 'Select a Brand',
        isLoading: isLoading,
        loadingText: 'Loading brands...',
      ),
    );
  }
}

class _ShopDropdown extends StatelessWidget {
  final List<ShopItem> shops;
  final String? selectedShop;
  final bool isLoading;
  final Function(ShopItem?) onChanged;

  const _ShopDropdown({required this.shops, required this.selectedShop, required this.isLoading, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showShopPicker(context, shops, onChanged),
      child: _DropdownContainer(
        icon: Icons.store_rounded,
        label: 'Shop',
        value: selectedShop,
        hint: 'Select a Shop',
        isLoading: isLoading,
        loadingText: 'Loading shops...',
      ),
    );
  }

  void _showShopPicker(BuildContext context, List<ShopItem> shops, Function(ShopItem?) onChanged) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShopPickerSheet(shops: shops, selectedShop: selectedShop, onChanged: onChanged),
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String hint;
  final bool isLoading;
  final String loadingText;

  const _DropdownContainer({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.isLoading,
    required this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0C6B64), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                if (isLoading)
                  const Row(
                    children: [
                      SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C6B64))),
                      SizedBox(width: 8),
                      Text('Loading...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0BAC7))),
                    ],
                  )
                else
                  Text(
                    value?.isEmpty ?? true ? hint : value!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value?.isEmpty ?? true ? const Color(0xFFB0BAC7) : const Color(0xFF1A2E2C),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB0BAC7), size: 22),
        ],
      ),
    );
  }
}

void _showPicker(BuildContext context, List<String> items, String title, Function(String?) onChanged) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _StringPickerSheet(items: items, title: title, onChanged: onChanged),
  );
}

class _StringPickerSheet extends StatefulWidget {
  final List<String> items;
  final String title;
  final Function(String?) onChanged;

  const _StringPickerSheet({required this.items, required this.title, required this.onChanged});

  @override
  State<_StringPickerSheet> createState() => _StringPickerSheetState();
}

class _StringPickerSheetState extends State<_StringPickerSheet> {
  late List<String> _filtered;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4F0ED), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2C))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F3), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (q) => setState(() => _filtered = widget.items.where((i) => i.toLowerCase().contains(q.toLowerCase())).toList()),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0C6B64), size: 20),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFF3F2)),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final item = _filtered[index];
                    return ListTile(
                      onTap: () { Navigator.pop(context); widget.onChanged(item); },
                      title: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A2E2C))),
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

class _ShopPickerSheet extends StatefulWidget {
  final List<ShopItem> shops;
  final String? selectedShop;
  final Function(ShopItem?) onChanged;

  const _ShopPickerSheet({required this.shops, required this.selectedShop, required this.onChanged});

  @override
  State<_ShopPickerSheet> createState() => _ShopPickerSheetState();
}

class _ShopPickerSheetState extends State<_ShopPickerSheet> {
  late List<ShopItem> _filtered;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.shops;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4F0ED), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text('Select Shop', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2C))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F3), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (q) => setState(() => _filtered = widget.shops.where((s) => s.name.toLowerCase().contains(q.toLowerCase())).toList()),
                    decoration: const InputDecoration(
                      hintText: 'Search shop...',
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0C6B64), size: 20),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFF3F2)),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final shop = _filtered[index];
                    final isSelected = shop.name == widget.selectedShop;
                    return ListTile(
                      onTap: () { Navigator.pop(context); widget.onChanged(shop); },
                      title: Text(shop.name, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF0C6B64) : const Color(0xFF1A2E2C))),
                      subtitle: shop.address.isNotEmpty ? Text(shop.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))) : null,
                      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0C6B64), size: 20) : null,
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

class _ProductSearchCard extends StatelessWidget {
  final List<ProductItem> products;
  final bool isLoading;
  final String? selectedBrand;
  final Function(ProductItem) onProductSelected;

  const _ProductSearchCard({
    required this.products,
    required this.isLoading,
    required this.selectedBrand,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isLoading && products.isNotEmpty) {
          _showProductPicker(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF0C6B64), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                  const SizedBox(height: 2),
                  if (isLoading)
                    const Row(
                      children: [
                        SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C6B64))),
                        SizedBox(width: 8),
                        Text('Loading products...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0BAC7))),
                      ],
                    )
                  else if (selectedBrand == null || selectedBrand!.isEmpty)
                    const Text('Select a brand first', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0BAC7)))
                  else if (products.isEmpty)
                      const Text('No products found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0BAC7)))
                    else
                      const Text('Search product name...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0BAC7))),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB0BAC7), size: 22),
          ],
        ),
      ),
    );
  }

  void _showProductPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductPickerSheet(
        products: products,
        onSelected: onProductSelected,
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<ProductItem> products;
  final Function(ProductItem) onSelected;

  const _ProductPickerSheet({required this.products, required this.onSelected});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  late List<ProductItem> _filtered;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.products;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD4F0ED), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text('Select Product', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2C))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F3), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (q) => setState(() => _filtered = widget.products.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList()),
                    decoration: const InputDecoration(
                      hintText: 'Search product...',
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0C6B64), size: 20),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFF3F2)),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20),
                  itemBuilder: (context, index) {
                    final product = _filtered[index];
                    return ListTile(
                      onTap: () { Navigator.pop(context); widget.onSelected(product); },
                      title: Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A2E2C))),
                      subtitle: product.price.isNotEmpty ? Text('₨ ${product.price}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))) : null,
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0C6B64), size: 24),
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

class _SelectedProductsList extends StatelessWidget {
  final List<ProductItem> selectedProducts;
  final Function(String) onAdd;
  final Function(String) onRemove;

  const _SelectedProductsList({
    required this.selectedProducts,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Column(
        children: selectedProducts.map((product) {
          return _SelectedProductItem(
            name: product.name,
            quantity: product.quantity,
            price: product.price,
            onAdd: () => onAdd(product.name),
            onRemove: () => onRemove(product.name),
          );
        }).toList(),
      ),
    );
  }
}

class _SelectedProductItem extends StatelessWidget {
  final String name;
  final int quantity;
  final String price;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _SelectedProductItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F7F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_rounded, color: Color(0xFF0C6B64), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A2E2C))),
                if (price.isNotEmpty)
                  Text('₨ $price', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, color: Color(0xFF0C6B64), size: 18),
                onPressed: onRemove,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE5F7F5),
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(width: 28, child: Center(child: Text('$quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0C6B64))))),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Color(0xFF0C6B64), size: 18),
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE5F7F5),
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(28, 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalQuantity extends StatelessWidget {
  final int total;

  const _TotalQuantity({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Quantity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A2E2C))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF0C6B64), borderRadius: BorderRadius.circular(20)),
            child: Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _CheckItem({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A2E2C)))),
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0C6B64)),
        ],
      ),
    );
  }
}

class _QuantityPickerSheet extends StatelessWidget {
  final String productName;
  final String productPrice;
  final Function(int) onQuantitySelected;

  const _QuantityPickerSheet({
    required this.productName,
    required this.productPrice,
    required this.onQuantitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFD4F0ED), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A2E2C))),
                    const SizedBox(height: 4),
                    Text(productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                    if (productPrice.isNotEmpty)
                      Text('₨ $productPrice', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0C6B64))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFF3F2)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      final quantity = index + 1;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onQuantitySelected(quantity);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5FFFE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: quantity == 1 ? const Color(0xFF0C6B64) : const Color(0xFF1A2E2C),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}