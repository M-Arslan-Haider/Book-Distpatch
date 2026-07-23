// // ═══════════════════════════════════════════════════════════════════════════
// // no_sale_shop_select_screen.dart
// //
// // Entry screen for the "No Sale of Stock" flow. Opens when "No Sale of
// // Stock" is tapped on ShopVisitOutcomeScreen.
// //
// // Reuses the SAME shop picker sheet as the booking flow (SelectShopSheet
// // from select_shop.dart) — auto-opened on entry so the user immediately
// // picks the shop they already added, its data (address/owner/lat-lng) is
// // pulled straight from that selection, then we push into NoSaleStockScreen.
// // ═══════════════════════════════════════════════════════════════════════════
//
// import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/select_shop.dart';
// import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/shop_visit_stock.dart' hide NoSaleVisitController, NoSaleStockScreen;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
//
// import '../../../AppColors.dart';
// import '../../../ViewModels/login_view_model.dart';
// import '../../HomeScreenComponents/navbar.dart';
// import '../../HomeScreenComponents/sidebar_drawer.dart';
// import '../view_models/shop_visit_viewmodel.dart';
// import 'no_sale_stock_screen.dart';
//
//
// class NoSaleShopSelectScreen extends StatefulWidget {
//   const NoSaleShopSelectScreen({super.key});
//
//   @override
//   State<NoSaleShopSelectScreen> createState() => _NoSaleShopSelectScreenState();
// }
//
// class _NoSaleShopSelectScreenState extends State<NoSaleShopSelectScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   static const _bg = AppColors.surface;
//   static const _textDark = AppColors.textPrimary;
//   static const _textMuted = AppColors.textSecondary;
//   static const _tealDark = AppColors.tealDark;
//
//   ShopModel? _selectedShop;
//   bool _opening = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // Auto-open the shop picker as soon as this screen appears.
//     WidgetsBinding.instance.addPostFrameCallback((_) => _openShopPicker());
//   }
//
//   Future<void> _openShopPicker() async {
//     if (_opening) return;
//     _opening = true;
//
//     final shop = await showSelectShopSheet(context);
//     _opening = false;
//
//     if (shop == null) return; // user dismissed sheet without picking
//
//     setState(() => _selectedShop = shop);
//     HapticFeedback.selectionClick();
//     _proceedWithShop(shop);
//   }
//
//   void _proceedWithShop(ShopModel shop) {
//     final controller = Get.put(
//       NoSaleVisitController(
//         shopId: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
//         shopName: shop.shopName,
//         shopAddress: shop.address,
//         ownerName: shop.ownerName,
//         shopSubtitle:
//         '${shop.ownerName}${shop.city.isNotEmpty ? ' - ${shop.city}' : ''}',
//       ),
//       tag: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
//     );
//
//     // If the shop already has known lat/lng, seed it — captureLocation()
//     // (called in onInit) will still refresh with the live GPS fix.
//     if (shop.latitude != null && shop.longitude != null) {
//       controller.model.latitude = shop.latitude;
//       controller.model.longitude = shop.longitude;
//     }
//
//     Get.to(() => NoSaleStockScreen(
//       controllerTag: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
//     ));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final loginVM = Get.find<LoginViewModel>();
//     final name = loginVM.currentUser.value?.emp_name ?? 'User';
//     final parts = name.trim().split(' ');
//     final initials = parts.length >= 2
//         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
//         : name.isNotEmpty ? name[0].toUpperCase() : 'U';
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: _bg,
//       appBar: Navbar(
//         userName: name,
//         userInitials: initials,
//         scaffoldKey: _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               GestureDetector(
//                 onTap: () {
//                   HapticFeedback.lightImpact();
//                   Navigator.of(context).maybePop();
//                 },
//                 behavior: HitTestBehavior.opaque,
//                 child: const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 6),
//                   child: Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'No Sale of Stock',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'Select the shop to record stock at.',
//                 style: TextStyle(fontSize: 13, color: _textMuted),
//               ),
//               const SizedBox(height: 24),
//               Expanded(
//                 child: Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.storefront_rounded, color: _tealDark.withOpacity(0.4), size: 56),
//                       const SizedBox(height: 14),
//                       Text(
//                         _selectedShop == null
//                             ? 'Pick a shop to continue'
//                             : 'Selected: ${_selectedShop!.shopName}',
//                         style: const TextStyle(fontSize: 14, color: _textMuted),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 18),
//                       ElevatedButton.icon(
//                         onPressed: _openShopPicker,
//                         icon: const Icon(Icons.search_rounded, size: 18),
//                         label: const Text('Select Shop'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: _tealDark,
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           elevation: 0,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
//

///offfline
// ═══════════════════════════════════════════════════════════════════════════
// no_sale_shop_select_screen.dart - Updated with offline support
// ═══════════════════════════════════════════════════════════════════════════

import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/select_shop.dart';
import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/shop_visit_stock.dart' hide NoSaleVisitController, NoSaleStockScreen;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../view_models/shop_visit_viewmodel.dart';
import 'no_sale_stock_screen.dart';

class NoSaleShopSelectScreen extends StatefulWidget {
  const NoSaleShopSelectScreen({super.key});

  @override
  State<NoSaleShopSelectScreen> createState() => _NoSaleShopSelectScreenState();
}

class _NoSaleShopSelectScreenState extends State<NoSaleShopSelectScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg = AppColors.surface;
  static const _textDark = AppColors.textPrimary;
  static const _textMuted = AppColors.textSecondary;
  static const _tealDark = AppColors.tealDark;

  ShopModel? _selectedShop;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openShopPicker());
  }

  Future<void> _openShopPicker() async {
    if (_opening) return;
    _opening = true;

    final shop = await showSelectShopSheet(context);
    _opening = false;

    if (shop == null) return;

    setState(() => _selectedShop = shop);
    HapticFeedback.selectionClick();
    _proceedWithShop(shop);
  }

  void _proceedWithShop(ShopModel shop) {
    final controller = Get.put(
      NoSaleVisitController(
        shopId: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
        shopName: shop.shopName,
        shopAddress: shop.address,
        ownerName: shop.ownerName,
        shopSubtitle:
        '${shop.ownerName}${shop.city.isNotEmpty ? ' - ${shop.city}' : ''}',
      ),
      tag: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
    );

    if (shop.latitude != null && shop.longitude != null) {
      controller.model.latitude = shop.latitude;
      controller.model.longitude = shop.longitude;
    }

    Get.to(() => NoSaleStockScreen(
      controllerTag: shop.shopId.isNotEmpty ? shop.shopId : shop.id,
    ));
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
      appBar: Navbar(
        userName: name,
        userInitials: initials,
        scaffoldKey: _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: Padding(
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
              const SizedBox(height: 8),
              const Text(
                'No Sale of Stock',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the shop to record stock at.',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, color: _tealDark.withOpacity(0.4), size: 56),
                      const SizedBox(height: 14),
                      Text(
                        _selectedShop == null
                            ? 'Pick a shop to continue'
                            : 'Selected: ${_selectedShop!.shopName}',
                        style: const TextStyle(fontSize: 14, color: _textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _openShopPicker,
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Select Shop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tealDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
