//
// import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/select_shop.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'dart:developer' as developer;
//
// import '../../../AppColors.dart';
// import '../../../ViewModels/login_view_model.dart';
// import '../../HomeScreenComponents/navbar.dart';
// import '../../HomeScreenComponents/sidebar_drawer.dart';
// import '../view_models/shop_closed_viewmodel.dart';
// import 'shop_closed_screen.dart';
//
// class ShopClosedSelectScreen extends StatefulWidget {
//   const ShopClosedSelectScreen({super.key});
//
//   @override
//   State<ShopClosedSelectScreen> createState() => _ShopClosedSelectScreenState();
// }
//
// class _ShopClosedSelectScreenState extends State<ShopClosedSelectScreen> {
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
//     developer.log('✅ ShopClosedSelectScreen initState', name: 'ShopClosedSelectScreen');
//     // Auto-open the shop picker as soon as this screen appears.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       developer.log('✅ ShopClosedSelectScreen postFrameCallback - opening shop picker', name: 'ShopClosedSelectScreen');
//       _openShopPicker();
//     });
//   }
//
//   Future<void> _openShopPicker() async {
//     if (_opening) {
//       developer.log('⚠️ _openShopPicker already running', name: 'ShopClosedSelectScreen');
//       return;
//     }
//     _opening = true;
//     developer.log('🔄 Opening shop picker...', name: 'ShopClosedSelectScreen');
//
//     final shop = await showSelectShopSheet(context);
//     _opening = false;
//
//     if (shop == null) {
//       developer.log('❌ Shop picker cancelled or no shop selected', name: 'ShopClosedSelectScreen');
//       return;
//     }
//
//     developer.log('✅ Shop selected: ${shop.shopName} (${shop.shopId})', name: 'ShopClosedSelectScreen');
//     setState(() => _selectedShop = shop);
//     HapticFeedback.selectionClick();
//     _proceedWithShop(shop);
//   }
//
//   void _proceedWithShop(ShopModel shop) {
//     final tag = shop.shopId.isNotEmpty ? shop.shopId : shop.id;
//
//     final controller = Get.put(
//       ShopClosedController(
//         shopId: tag,
//         shopName: shop.shopName,
//         shopAddress: shop.address,
//         ownerName: shop.ownerName,
//         shopSubtitle:
//         '${shop.ownerName}${shop.city.isNotEmpty ? ' - ${shop.city}' : ''}',
//       ),
//       tag: tag,
//     );
//
//     if (shop.latitude != null && shop.longitude != null) {
//       controller.model.latitude = shop.latitude;
//       controller.model.longitude = shop.longitude;
//     }
//
//     // ✅ Use Get.toNamed like No Sale of Stock
//     Get.toNamed('/ShopClosedScreen', parameters: {'tag': tag});
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
//                 'Shop Closed',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
//               ),
//               const SizedBox(height: 4),
//               const Text(
//                 'Select the closed shop to record this visit.',
//                 style: TextStyle(fontSize: 13, color: _textMuted),
//               ),
//               const SizedBox(height: 24),
//               Expanded(
//                 child: Center(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.storefront_outlined, color: _tealDark.withOpacity(0.4), size: 56),
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


///offfline
import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/select_shop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../view_models/shop_closed_viewmodel.dart';
import 'shop_closed_screen.dart';

class ShopClosedSelectScreen extends StatefulWidget {
  const ShopClosedSelectScreen({super.key});

  @override
  State<ShopClosedSelectScreen> createState() => _ShopClosedSelectScreenState();
}

class _ShopClosedSelectScreenState extends State<ShopClosedSelectScreen> {
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
    developer.log('✅ ShopClosedSelectScreen initState', name: 'ShopClosedSelectScreen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      developer.log('✅ ShopClosedSelectScreen postFrameCallback - opening shop picker', name: 'ShopClosedSelectScreen');
      _openShopPicker();
    });
  }

  Future<void> _openShopPicker() async {
    if (_opening) {
      developer.log('⚠️ _openShopPicker already running', name: 'ShopClosedSelectScreen');
      return;
    }
    _opening = true;
    developer.log('🔄 Opening shop picker...', name: 'ShopClosedSelectScreen');

    final shop = await showSelectShopSheet(context);
    _opening = false;

    if (shop == null) {
      developer.log('❌ Shop picker cancelled or no shop selected', name: 'ShopClosedSelectScreen');
      return;
    }

    developer.log('✅ Shop selected: ${shop.shopName} (${shop.shopId})', name: 'ShopClosedSelectScreen');
    setState(() => _selectedShop = shop);
    HapticFeedback.selectionClick();
    _proceedWithShop(shop);
  }

  void _proceedWithShop(ShopModel shop) {
    final tag = shop.shopId.isNotEmpty ? shop.shopId : shop.id;

    final controller = Get.put(
      ShopClosedController(
        shopId: tag,
        shopName: shop.shopName,
        shopAddress: shop.address,
        ownerName: shop.ownerName,
        shopSubtitle:
        '${shop.ownerName}${shop.city.isNotEmpty ? ' - ${shop.city}' : ''}',
      ),
      tag: tag,
    );

    if (shop.latitude != null && shop.longitude != null) {
      controller.model.latitude = shop.latitude;
      controller.model.longitude = shop.longitude;
    }

    Get.toNamed('/ShopClosedScreen', parameters: {'tag': tag});
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
                'Shop Closed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the closed shop to record this visit.',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, color: _tealDark.withOpacity(0.4), size: 56),
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