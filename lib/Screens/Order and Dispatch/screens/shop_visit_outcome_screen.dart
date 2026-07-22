

import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/shop_visit_shop.dart';
import 'package:flutter/material.dart';
import '../../../AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:developer' as developer;

import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import 'customer_account_screen.dart';
import 'shop_closed_select_screen.dart';



// ═══════════════════════════════════════════════════════════════════════════════
// shop_visit_outcome_screen.dart
//
// Opens when the salesman taps a shop (from "Select Shop" sheet, or from
// "Today's Route" list). Shows the shop name at the top and lets the user
// choose what happened at the visit:
//   • Shop Closed        -> capture closed-shop photo
//   • No Sale of Stock   -> capture shop + stock photo
//   • Start Booking      -> proceed to order entry
// ═══════════════════════════════════════════════════════════════════════════════

class ShopVisitOutcomeScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String shopSubtitle;

  final VoidCallback? onShopClosed;
  final VoidCallback? onNoSaleOfStock;
  final VoidCallback? onStartBooking;

  const ShopVisitOutcomeScreen({
    super.key,
    this.shopId = '',
    required this.shopName,
    required this.shopSubtitle,
    this.onShopClosed,
    this.onNoSaleOfStock,
    this.onStartBooking,
  });

  @override
  State<ShopVisitOutcomeScreen> createState() => _ShopVisitOutcomeScreenState();
}

class _ShopVisitOutcomeScreenState extends State<ShopVisitOutcomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;

  static const _tealDark  = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button ─────────────────────────────────────────
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

              // ── Shop header card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                    colors: [_tealLight, _tealDark],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:      _tealDark.withOpacity(0.25),
                      blurRadius: 14,
                      offset:     const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width:  46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.shopName,
                            style: const TextStyle(
                              fontSize:   17,
                              fontWeight: FontWeight.w800,
                              color:      Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.shopSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color:    Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Prompt ────────────────────────────────────────────────
              const Text(
                'Choose the visit outcome for this shop.',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),

              const SizedBox(height: 14),

              // ── Shop Closed ───────────────────────────────────────────
              // ── Shop Closed ───────────────────────────────────────────
              // ── Shop Closed ───────────────────────────────────────────
              // ── Shop Closed ───────────────────────────────────────────
              _OutcomeCard(
                icon:        Icons.storefront_outlined,
                iconColor:   const Color(0xFFF97316),
                iconBg:      const Color(0xFFFFF1E3),
                title:       'Shop Closed',
                subtitle:    'Capture closed shop photo',
                onTap: () {
                  HapticFeedback.lightImpact();
                  developer.log(
                    '🔒 Shop Closed tapped for shop=${widget.shopName} (id=${widget.shopId})',
                    name: 'ShopVisitOutcomeScreen',
                  );

                  // ✅ DIRECT NAVIGATE - bilkul No Sale of Stock ki tarah
                  // Callback ko ignore karein
                  Get.to(() => const ShopClosedSelectScreen());
                },
              ),
              const SizedBox(height: 12),

              // ── No Sale of Stock ──────────────────────────────────────
              _OutcomeCard(
                icon:        Icons.block_rounded,
                iconColor:   const Color(0xFFF97316),
                iconBg:      const Color(0xFFFFF1E3),
                title:       'Shop Visit / Order Booking',
                subtitle:    'Shop Visit + Order Book',
                onTap: () {
                  HapticFeedback.lightImpact();
                  developer.log(
                    '📦 No Sale of Stock tapped for shop=${widget.shopName} (id=${widget.shopId})',
                    name: 'ShopVisitOutcomeScreen',
                  );
                  if (widget.onNoSaleOfStock != null) {
                    widget.onNoSaleOfStock!.call();
                  } else {
                    Get.to(() => const NoSaleShopSelectScreen());
                  }
                },
              ),
              const SizedBox(height: 12),

              // ── Start Booking (highlighted / primary) ─────────────────
              _OutcomeCard(
                icon:        Icons.shopping_cart_rounded,
                iconColor:   _tealDark,
                iconBg:      AppColors.iconBgTeal,
                title:       'Start Booking',
                subtitle:    'Proceed to order entry',
                highlighted: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  developer.log(
                    '🛒 Start Booking tapped for shop=${widget.shopName} (id=${widget.shopId})',
                    name: 'ShopVisitOutcomeScreen',
                  );
                  if (widget.onStartBooking != null) {
                    widget.onStartBooking!.call();
                  } else {
                    Get.to(() => CustomerAccountScreen(
                      shopId: widget.shopId,
                      shopName: widget.shopName,
                      shopSubtitle: widget.shopSubtitle,
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single outcome option card (Shop Closed / No Sale of Stock / Start Booking)
// ─────────────────────────────────────────────────────────────────────────────
class _OutcomeCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        iconBg;
  final String       title;
  final String       subtitle;
  final bool         highlighted;
  final VoidCallback onTap;

  const _OutcomeCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  static const _textDark  = AppColors.textPrimary;
  static const _textMuted = AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color:        highlighted ? AppColors.tealSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? AppColors.tealDark : AppColors.divider,
            width: highlighted ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                color:        iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}