import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../AppColors.dart';
import '../add_shop_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// select_shop.dart
// Bottom sheet shown when "New Booking" is tapped on the Booking screen.
// Fetches the employee's shops directly from:
//   GET http://oracle.metaxperts.net/ords/gps_workforce/addshopget/get/:emp_id
//   (optionally ?company_code=...)
// Lets the user search shops, or tap "Add New Shop" to jump to AddShopScreen.
// ═══════════════════════════════════════════════════════════════════════════════

/// Call this to open the sheet, e.g. from the "New Booking" button:
///
/// ```dart
/// final selectedShop = await showSelectShopSheet(context);
/// if (selectedShop != null) {
///   // proceed to new booking flow with selectedShop
/// }
/// ```
Future<ShopModel?> showSelectShopSheet(BuildContext context) {
  return showModalBottomSheet<ShopModel>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder:            (_) => const SelectShopSheet(),
  );
}

class SelectShopSheet extends StatefulWidget {
  const SelectShopSheet({super.key});

  @override
  State<SelectShopSheet> createState() => _SelectShopSheetState();
}

class _SelectShopSheetState extends State<SelectShopSheet> {
  static const _primary = AppColors.tealDark;
  static const _accent  = AppColors.iconBgTeal;
  static const _baseUrl = 'http://oracle.metaxperts.net/ords/gps_workforce';

  final _searchCtrl = TextEditingController();

  List<ShopModel> _shops    = [];
  List<ShopModel> _filtered = [];
  bool _loading = true;
  String? _error;

  String _empId       = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    _loadEmployeeInfoAndFetchShops();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _shops
          : _shops.where((s) =>
      s.shopName.toLowerCase().contains(q) ||
          s.ownerName.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q)).toList();
    });
  }

  // ── Load emp info (same pattern used across the app) then fetch shops ───
  Future<void> _loadEmployeeInfoAndFetchShops() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';

    _companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';

    await _fetchShops();
  }

  // ── Fetch shops directly from the API ────────────────────────────────────
  // GET /addshopget/get/:emp_id?company_code=...
  Future<void> _fetchShops() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      var endpoint = '/addshopget/get/$_empId';
      if (_companyCode.isNotEmpty) {
        endpoint += '?company_code=${Uri.encodeQueryComponent(_companyCode)}';
      }

      final response = await http.get(Uri.parse('$_baseUrl$endpoint'));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final items = (data['items'] as List?) ?? [];

        setState(() {
          _shops    = items.map((e) => ShopModel.fromJson(e as Map<String, dynamic>)).toList();
          _filtered = _shops;
          _loading  = false;
        });
      } else {
        setState(() {
          _error   = 'Could not load shops (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Could not load shops. Check your connection.';
        _loading = false;
      });
    }
  }

  void _goToAddShop() {
    Navigator.pop(context); // close sheet first
    Get.to(() => const AddShopScreen());
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:      0.45,
      maxChildSize:      0.92,
      expand:            false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
                width:  40,
                height: 4,
                decoration: BoxDecoration(
                  color:        AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Text(
                      'Select Shop',
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color:        AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:  'Search shop or owner...',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.clear_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ),
                      isDense: true,
                      border:  InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // ── Add New Shop button ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: GestureDetector(
                  onTap:    _goToAddShop,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:        _accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: _primary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Add New Shop',
                          style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // ── Shops list ─────────────────────────────────────────────
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.4),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 32),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _fetchShops,
                child: const Text('Retry', style: TextStyle(color: _primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'No shops found',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding:    const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount:  _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ShopTile(
        shop:  _filtered[i],
        onTap: () => Navigator.pop(context, _filtered[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop tile row
// ─────────────────────────────────────────────────────────────────────────────
class _ShopTile extends StatelessWidget {
  final ShopModel shop;
  final VoidCallback onTap;
  const _ShopTile({required this.shop, required this.onTap});

  static const _primary = AppColors.tealDark;
  static const _accent  = AppColors.iconBgTeal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        _accent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.storefront_rounded, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.shopName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${shop.ownerName}${shop.city.isNotEmpty ? ' · ${shop.city}' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C4C4), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop model — mapped straight from the ADD_SHOP API response
// ─────────────────────────────────────────────────────────────────────────────
class ShopModel {
  final String id;
  final String empId;
  final String empName;
  final String companyCode;
  final String shopName;
  final String shopId;
  final String shopType;
  final String ownerName;
  final String contactNumber;
  final String city;
  final String address;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String? createdDate;
  final String? createdTime;

  const ShopModel({
    required this.id,
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.shopName,
    required this.shopId,
    required this.shopType,
    required this.ownerName,
    required this.contactNumber,
    required this.city,
    required this.address,
    this.notes,
    this.latitude,
    this.longitude,
    this.createdDate,
    this.createdTime,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ShopModel(
      id:            json['id']?.toString() ?? '',
      empId:         json['emp_id']?.toString() ?? '',
      empName:       json['emp_name']?.toString() ?? '',
      companyCode:   json['company_code']?.toString() ?? '',
      shopName:      json['shop_name']?.toString() ?? '',
      shopId:        json['shop_id']?.toString() ?? '',
      shopType:      json['shop_type']?.toString() ?? '',
      ownerName:     json['owner_name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      city:          json['city']?.toString() ?? '',
      address:       json['address']?.toString() ?? '',
      notes:         json['notes']?.toString(),
      latitude:      toDouble(json['latitude']),
      longitude:     toDouble(json['longitude']),
      createdDate:   json['created_date']?.toString(),
      createdTime:   json['created_time']?.toString(),
    );
  }
}