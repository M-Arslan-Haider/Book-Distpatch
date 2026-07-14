import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'order_booking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// shop_visit_screen.dart  —  Brand + Shop dropdowns wired to Oracle ORDS APIs
// Same design language as AddShopScreen (FULL DEBUG)
// ═══════════════════════════════════════════════════════════════════════════════

class ShopVisitScreen extends StatefulWidget {
  const ShopVisitScreen({super.key});

  @override
  State<ShopVisitScreen> createState() => _ShopVisitScreenState();
}

class _ShopVisitScreenState extends State<ShopVisitScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _primary = Color(0xFF0C6B64);
  static const _bg      = Color(0xFFE8F5F3);

  // ── Controllers ──────────────────────────────────────────────────────────
  final _shopAddressCtrl  = TextEditingController();
  final _ownerNameCtrl    = TextEditingController();
  final _employeeNameCtrl = TextEditingController();
  final _notesCtrl        = TextEditingController();

  bool _gpsEnabled          = false;
  bool _checkAvailability   = false;
  bool _checkCleanliness    = false;
  bool _checkDisplay        = false;

  // ── Employee Info from SharedPreferences ─────────────────────────────────
  String _empId       = '';
  String _empName     = '';
  String _companyCode = '';

  // ── Brand dropdown state ─────────────────────────────────────────────────
  List<String> _brands        = [];
  String?      _selectedBrand;
  bool         _loadingBrands = true;

  // ── Shop dropdown state ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _shops         = [];
  Map<String, dynamic>?      _selectedShop;
  bool                       _loadingShops  = true;

  @override
  void initState() {
    super.initState();
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🏬 [ShopVisit] INIT STATE - Screen Started');
    debugPrint('════════════════════════════════════════════════════════════');
    _fetchBrands();
    _loadEmployeeInfoThenShops();
  }

  // ── Load employee info, then fetch shop list (needs emp_id) ─────────────
  Future<void> _loadEmployeeInfoThenShops() async {
    await _loadEmployeeInfo();
    await _fetchShops();
  }

  Future<void> _loadEmployeeInfo() async {
    debugPrint('👤 [ShopVisit] ===== LOADING EMPLOYEE INFO =====');

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    debugPrint('📋 [ShopVisit] All SharedPreferences keys:');
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      debugPrint('   $key = ${prefs.get(key)}');
    }

    _empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';
    debugPrint('🔑 [ShopVisit] empId loaded: "$_empId"');

    _empName = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('empName') ??
        prefs.getString('name') ??
        prefs.getString('full_name') ??
        prefs.getString('fullName') ??
        '';
    debugPrint('👤 [ShopVisit] empName loaded: "$_empName"');

    _companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';
    debugPrint('🏢 [ShopVisit] companyCode loaded: "$_companyCode"');

    if (_empId.isEmpty) {
      debugPrint('⚠️ [ShopVisit] ⚠️ empId is EMPTY! Shop list cannot be fetched.');
    } else {
      debugPrint('✅ [ShopVisit] Employee info loaded successfully!');
    }

    if (mounted) {
      setState(() {
        _employeeNameCtrl.text = _empName;
      });
    } else {
      _employeeNameCtrl.text = _empName;
    }

    debugPrint('👤 [ShopVisit] ===== END LOADING EMPLOYEE INFO =====');
    debugPrint('');
  }

  // ── Fetch brands: http://oracle.metaxperts.net/ords/gps_workforce/brand/get/ ─
  Future<void> _fetchBrands() async {
    debugPrint('🏷️ [ShopVisit] ===== FETCHING BRANDS =====');
    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/brand/get/';
      debugPrint('🏷️ [ShopVisit] API URL: $url');

      final response = await http.get(Uri.parse(url));
      debugPrint('🏷️ [ShopVisit] Response Status: ${response.statusCode}');
      debugPrint('🏷️ [ShopVisit] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final items = data['items'] as List;
        debugPrint('🏷️ [ShopVisit] Items count: ${items.length}');

        setState(() {
          _brands = items
              .map((e) => (e['brand'] ?? e['BRAND'] ?? '').toString())
              .where((b) => b.trim().isNotEmpty)
              .toList();
          _loadingBrands = false;
        });
        debugPrint('🏷️ [ShopVisit] ✅ Brands loaded: ${_brands.length} -> $_brands');
      } else {
        debugPrint('🏷️ [ShopVisit] ❌ Non-200 response: ${response.statusCode}');
        setState(() => _loadingBrands = false);
      }
    } catch (e) {
      debugPrint('🏷️ [ShopVisit] ❌ Error fetching brands: $e');
      debugPrint('🏷️ [ShopVisit] Stack trace: ${StackTrace.current}');
      setState(() => _loadingBrands = false);
    }
    debugPrint('🏷️ [ShopVisit] ===== END FETCHING BRANDS =====');
    debugPrint('');
  }

  // ── Helper: pull first non-empty value from a list of possible keys ─────
  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final k in keys) {
      final v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '';
  }

  // ── Fetch shops: .../addshopget/get/:emp_id  (emp_id + company_code wise) ─
  Future<void> _fetchShops() async {
    debugPrint('🏪 [ShopVisit] ===== FETCHING SHOPS =====');

    if (_empId.isEmpty) {
      debugPrint('🏪 [ShopVisit] ⚠️ No empId available - skipping shop fetch');
      setState(() => _loadingShops = false);
      debugPrint('🏪 [ShopVisit] ===== END FETCHING SHOPS (SKIPPED) =====');
      debugPrint('');
      return;
    }

    debugPrint('🏪 [ShopVisit] DEBUG _empId="$_empId" (empty=${_empId.isEmpty})');
    debugPrint('🏪 [ShopVisit] DEBUG _companyCode="$_companyCode" (empty=${_companyCode.isEmpty})');

    try {
      var url = 'http://oracle.metaxperts.net/ords/gps_workforce/addshopget/get/$_empId';
      if (_companyCode.isNotEmpty) {
        url += '?company_code=${Uri.encodeQueryComponent(_companyCode)}';
        debugPrint('🏪 [ShopVisit] DEBUG company_code appended to URL');
      } else {
        debugPrint('🏪 [ShopVisit] ⚠️ DEBUG company_code EMPTY — query param NOT appended!');
      }
      debugPrint('🏪 [ShopVisit] FINAL API URL: $url');

      final response = await http.get(Uri.parse(url));
      debugPrint('🏪 [ShopVisit] Response Status: ${response.statusCode}');
      debugPrint('🏪 [ShopVisit] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        debugPrint('🏪 [ShopVisit] Items count: ${items.length}');

        setState(() {
          _shops = items;
          _loadingShops = false;
        });
        debugPrint('🏪 [ShopVisit] ✅ Shops loaded: ${_shops.length}');
      } else {
        debugPrint('🏪 [ShopVisit] ❌ Non-200 response: ${response.statusCode}');
        setState(() => _loadingShops = false);
      }
    } catch (e) {
      debugPrint('🏪 [ShopVisit] ❌ Error fetching shops: $e');
      debugPrint('🏪 [ShopVisit] Stack trace: ${StackTrace.current}');
      setState(() => _loadingShops = false);
    }
    debugPrint('🏪 [ShopVisit] ===== END FETCHING SHOPS =====');
    debugPrint('');
  }

  String get _selectedShopName =>
      _selectedShop == null ? '' : _pick(_selectedShop!, ['shop_name', 'SHOP_NAME', 'shopName', 'name', 'NAME']);

  // ── Called when a shop is picked — auto-fills address & owner ───────────
  void _onShopSelected(Map<String, dynamic> shop) {
    final address = _pick(shop, ['address', 'ADDRESS', 'shop_address', 'SHOP_ADDRESS']);
    final owner   = _pick(shop, ['owner_name', 'OWNER_NAME', 'ownerName', 'OWNERNAME']);

    debugPrint('🏪 [ShopVisit] Shop selected: "${_pick(shop, [
      'shop_name', 'SHOP_NAME', 'shopName', 'name', 'NAME'
    ])}"');
    debugPrint('🏪 [ShopVisit]   address: "$address"');
    debugPrint('🏪 [ShopVisit]   owner:   "$owner"');

    setState(() {
      _selectedShop        = shop;
      _shopAddressCtrl.text = address;
      _ownerNameCtrl.text   = owner;
    });
  }

  @override
  void dispose() {
    _shopAddressCtrl.dispose();
    _ownerNameCtrl.dispose();
    _employeeNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    debugPrint('🏬 [ShopVisit] ===== SUBMIT =====');
    debugPrint('   Brand: "$_selectedBrand"');
    debugPrint('   Shop:  "$_selectedShopName"');

    if (_selectedBrand == null || _selectedBrand!.isEmpty) {
      Get.snackbar(
        'Required', 'Please select a brand',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
      return;
    }

    if (_selectedShop == null) {
      Get.snackbar(
        'Required', 'Please select a shop',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.lightImpact();
      Get.snackbar(
        'Success',
        'Shop visit saved successfully',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [

          // ── Gradient Header ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
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
                        width: 42, height: 42,
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
                      width: 42, height: 42,
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
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                children: [

                  // ── Shop Info ──────────────────────────────────────────
                  const _SectionHeader(icon: Icons.info_outline_rounded, label: 'Shop Information'),
                  const SizedBox(height: 12),

                  // Brand dropdown — fetched from brand/get/
                  _SearchDropdownCard(
                    icon:      Icons.branding_watermark_rounded,
                    label:     'Brand',
                    hint:      'Select a Brand',
                    value:     _selectedBrand,
                    items:     _brands,
                    isLoading: _loadingBrands,
                    loadingText: 'Loading brands...',
                    sheetTitle:  'Select Brand',
                    searchHint:  'Search brand...',
                    onChanged: (v) {
                      debugPrint('🏷️ [ShopVisit] Brand selected: "$v"');
                      setState(() => _selectedBrand = v);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Shop dropdown — fetched from addshopget/get/:emp_id
                  _ShopDropdownCard(
                    value:     _selectedShopName,
                    shops:     _shops,
                    isLoading: _loadingShops,
                    pick:      _pick,
                    onChanged: _onShopSelected,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Shop Address',
                    controller: _shopAddressCtrl,
                    icon:       Icons.location_on_rounded,
                    hint:       'Select a shop to see details',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Owner Name',
                    controller: _ownerNameCtrl,
                    icon:       Icons.person_rounded,
                    hint:       'Select a shop to see details',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Employee Name',
                    controller: _employeeNameCtrl,
                    icon:       Icons.badge_rounded,
                    hint:       'Loading...',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),

                  const SizedBox(height: 20),

                  // ── Stock Check ───────────────────────────────────────────
                  const _SectionHeader(icon: Icons.inventory_2_rounded, label: 'Stock Check'),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: _primary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Search and add products here',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Checklist ─────────────────────────────────────────────
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
                          label: 'Product Availability',
                          value: _checkAvailability,
                          onChanged: (v) => setState(() => _checkAvailability = v),
                        ),
                        const Divider(height: 1, color: Color(0xFFD4F0ED)),
                        _CheckItem(
                          label: 'Shelf Cleanliness',
                          value: _checkCleanliness,
                          onChanged: (v) => setState(() => _checkCleanliness = v),
                        ),
                        const Divider(height: 1, color: Color(0xFFD4F0ED)),
                        _CheckItem(
                          label: 'Display Standards',
                          value: _checkDisplay,
                          onChanged: (v) => setState(() => _checkDisplay = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Photos ────────────────────────────────────────────────
                  const _SectionHeader(icon: Icons.photo_camera_rounded, label: 'Photos'),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFD4F0ED), width: 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F7F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_a_photo_rounded,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Take a photo',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2E2C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Location Settings ─────────────────────────────────────
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
                        const Expanded(
                          child: Text(
                            'GPS Enabled',
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: Color(0xFF1A2E2C),
                            ),
                          ),
                        ),
                        Switch(
                          value: _gpsEnabled,
                          onChanged: (v) => setState(() => _gpsEnabled = v),
                          activeColor: _primary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Additional Info ──────────────────────────────────────
                  const _SectionHeader(icon: Icons.notes_rounded, label: 'Additional Info'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Notes',
                    controller: _notesCtrl,
                    icon:       Icons.sticky_note_2_rounded,
                    hint:       'Any extra remarks',
                    maxLines:   3,
                    isOptional: true,
                    validator:  null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Action Buttons ───────────────────────────────────────────────────
      bottomSheet: Container(
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
                  onPressed: _submit,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: const Text(
                    'Only Visit',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
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
                  onPressed: () {
                    Get.to(() => const OrderBookingScreen());
                  },
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  label: const Text(
                    'Order Form',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;

  static const _primary = Color(0xFF0C6B64);

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      _primary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Card
// ─────────────────────────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final String                        label;
  final TextEditingController         controller;
  final IconData                      icon;
  final String                        hint;
  final String? Function(String?)?    validator;
  final int                           maxLines;
  final bool                          readOnly;
  final bool                          showLock;
  final bool                          isOptional;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _FieldCard({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.validator,
    this.maxLines   = 1,
    this.readOnly   = false,
    this.showLock   = false,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: readOnly && showLock
            ? const Color(0xFFF5FFFE)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (isOptional) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F7F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Optional',
                          style: TextStyle(
                            fontSize: 9, color: Color(0xFF1A6E59),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                TextFormField(
                  controller:      controller,
                  validator:       validator,
                  maxLines:        maxLines,
                  readOnly:        readOnly,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: readOnly && showLock
                        ? const Color(0xFF1A6E59)
                        : _textDark,
                  ),
                  decoration: InputDecoration(
                    hintText:  hint,
                    hintStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w400,
                      color: Color(0xFFB0BAC7),
                    ),
                    isDense: true,
                    border:  InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (showLock)
            const Icon(Icons.lock_rounded,
                color: Color(0xFF1A6E59), size: 16)
          else
            const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFCDD5DC), size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Checklist Item
// ─────────────────────────────────────────────────────────────────────────────
class _CheckItem extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  static const _primary = Color(0xFF0C6B64);

  const _CheckItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: Color(0xFF1A2E2C),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _primary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic Search Dropdown Card — used for Brand (same pattern as City dropdown
// in AddShopScreen). Tap opens a searchable bottom sheet over a List<String>.
// ─────────────────────────────────────────────────────────────────────────────
class _SearchDropdownCard extends StatelessWidget {
  final IconData           icon;
  final String              label;
  final String              hint;
  final String?             value;
  final List<String>        items;
  final bool                 isLoading;
  final String               loadingText;
  final String               sheetTitle;
  final String               searchHint;
  final Function(String?)   onChanged;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _SearchDropdownCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.isLoading,
    required this.loadingText,
    required this.sheetTitle,
    required this.searchHint,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    if (isLoading) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StringSearchSheet(
        items: items,
        initialValue: value,
        title: sheetTitle,
        searchHint: searchHint,
        icon: icon,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  isLoading
                      ? Row(
                    children: [
                      const SizedBox(
                        height: 14, width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loadingText,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: Color(0xFFB0BAC7),
                        ),
                      ),
                    ],
                  )
                      : Text(
                    (value == null || value!.isEmpty) ? hint : value!,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: (value == null || value!.isEmpty)
                          ? const Color(0xFFB0BAC7)
                          : _textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFB0BAC7), size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic search sheet for a List<String>
// ─────────────────────────────────────────────────────────────────────────────
class _StringSearchSheet extends StatefulWidget {
  final List<String> items;
  final String?       initialValue;
  final String        title;
  final String        searchHint;
  final IconData      icon;

  const _StringSearchSheet({
    required this.items,
    required this.initialValue,
    required this.title,
    required this.searchHint,
    required this.icon,
  });

  @override
  State<_StringSearchSheet> createState() => _StringSearchSheetState();
}

class _StringSearchSheetState extends State<_StringSearchSheet> {
  static const _primary = Color(0xFF0C6B64);

  late List<String> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.items
          .where((c) => c.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F0ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(widget.icon, color: _primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2E2C),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _filter,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2E2C),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400,
                        color: Color(0xFFB0BAC7),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _primary, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _filter('');
                        },
                        child: const Icon(Icons.clear_rounded,
                            color: Color(0xFFB0BAC7), size: 18),
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEFF3F2)),

              // ── List ────────────────────────────────────────────────
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFFB0BAC7),
                    ),
                  ),
                )
                    : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final entry = _filtered[index];
                    final isSelected = entry == widget.initialValue;
                    return ListTile(
                      onTap: () => Navigator.pop(context, entry),
                      title: Text(
                        entry,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? _primary : const Color(0xFF1A2E2C),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20)
                          : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shop Dropdown Card — fetched from addshopget/get/:emp_id.
// Selecting a shop returns the full record so address & owner auto-fill.
// ─────────────────────────────────────────────────────────────────────────────
class _ShopDropdownCard extends StatelessWidget {
  final String?                          value;
  final List<Map<String, dynamic>>       shops;
  final bool                             isLoading;
  final String Function(Map<String, dynamic>, List<String>) pick;
  final Function(Map<String, dynamic>)   onChanged;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _ShopDropdownCard({
    required this.value,
    required this.shops,
    required this.isLoading,
    required this.pick,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    if (isLoading) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShopSearchSheet(
        shops: shops,
        initialValue: value,
        pick: pick,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.store_rounded, color: _primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Shop',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  isLoading
                      ? Row(
                    children: [
                      const SizedBox(
                        height: 14, width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Loading shops...',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: Color(0xFFB0BAC7),
                        ),
                      ),
                    ],
                  )
                      : Text(
                    (value == null || value!.isEmpty) ? 'Select a Shop' : value!,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: (value == null || value!.isEmpty)
                          ? const Color(0xFFB0BAC7)
                          : _textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFB0BAC7), size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop Search Sheet — list of shop records, filtered by name, shows address
// as a subtitle so it's easy to tell shops with the same name apart.
// ─────────────────────────────────────────────────────────────────────────────
class _ShopSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final String?                     initialValue;
  final String Function(Map<String, dynamic>, List<String>) pick;

  const _ShopSearchSheet({
    required this.shops,
    required this.initialValue,
    required this.pick,
  });

  @override
  State<_ShopSearchSheet> createState() => _ShopSearchSheetState();
}

class _ShopSearchSheetState extends State<_ShopSearchSheet> {
  static const _primary = Color(0xFF0C6B64);

  late List<Map<String, dynamic>> _filtered;
  final _searchCtrl = TextEditingController();

  String _nameOf(Map<String, dynamic> s) =>
      widget.pick(s, ['shop_name', 'SHOP_NAME', 'shopName', 'name', 'NAME']);

  String _addressOf(Map<String, dynamic> s) =>
      widget.pick(s, ['address', 'ADDRESS', 'shop_address', 'SHOP_ADDRESS']);

  @override
  void initState() {
    super.initState();
    _filtered = widget.shops;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.shops
          .where((s) => _nameOf(s).toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F0ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.store_rounded, color: _primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Shop',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2E2C),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _filter,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2E2C),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search shop...',
                      hintStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400,
                        color: Color(0xFFB0BAC7),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _primary, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _filter('');
                        },
                        child: const Icon(Icons.clear_rounded,
                            color: Color(0xFFB0BAC7), size: 18),
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEFF3F2)),

              // ── Shop list ────────────────────────────────────────────────
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                  child: Text(
                    'No shops found',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFFB0BAC7),
                    ),
                  ),
                )
                    : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final shop = _filtered[index];
                    final name    = _nameOf(shop);
                    final address = _addressOf(shop);
                    final isSelected = name == widget.initialValue;
                    return ListTile(
                      onTap: () => Navigator.pop(context, shop),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? _primary : const Color(0xFF1A2E2C),
                        ),
                      ),
                      subtitle: address.isEmpty
                          ? null
                          : Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20)
                          : null,
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