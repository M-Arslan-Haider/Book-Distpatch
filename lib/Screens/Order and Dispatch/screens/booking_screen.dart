import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/select_shop.dart';
import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/shop_visit_outcome_screen.dart';
import 'package:book_dispatch/Screens/Order%20and%20Dispatch/screens/shop_visit_shop.dart';
import 'package:flutter/material.dart';
import '../../../AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/app_bottom_navbar.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// booking_screen.dart
// (renamed from order_screen.dart)
// ═══════════════════════════════════════════════════════════════════════════════

class BookingScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const BookingScreen({
    super.key,
    this.currentIndex = 6, // Booking tab index in _allTabs
    this.chatBadgeCount = 0,
    required this.onNavTap,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg        = AppColors.surface; // warm cream bg, matches screenshot
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;

  // ── Summary stats (today's booking summary) ────────────────────────────
  // TODO: wire these up to real data from view-model
  static const int    _routeDone   = 0;
  static const int    _routeTotal  = 0;
  static const int    _bookings    = 0;
  static const String _todaySales  = 'Rs 0';

  // TODO: wire this up to the actual route/shops list — left empty for now
  static const List<_RouteShop> _todaysRoute = [];

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
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section title ────────────────────────────────────────
              const Text(
                'Booking',
                style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                  color:      _textDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Take orders & returns on your route',
                style: TextStyle(
                  fontSize: 13,
                  color:    _textMuted,
                ),
              ),

              const SizedBox(height: 16),

              // ── Today's summary card ─────────────────────────────────
              _SummaryCard(
                routeDone:  _routeDone,
                routeTotal: _routeTotal,
                bookings:   _bookings,
                todaySales: _todaySales,
              ),

              const SizedBox(height: 16),

              // ── Two action buttons: New Booking / Sale Return ────────
              Row(
                children: [
                  Expanded(
                    child: _PrimaryActionButton(
                      label: 'New Booking',
                      icon:  Icons.shopping_cart_rounded,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final selectedShop = await showSelectShopSheet(context);
                        if (selectedShop != null) {
                          Get.to(() => ShopVisitOutcomeScreen(
                            shopId:      selectedShop.shopId, // TODO(api): confirm field name on SelectedShop
                            shopName:    selectedShop.shopName,
                            shopSubtitle: '${selectedShop.ownerName}'
                                '${selectedShop.city.isNotEmpty ? ' - ${selectedShop.city}' : ''}',
                            onShopClosed: () {
                              // TODO: open closed-shop camera capture flow
                            },
                            onNoSaleOfStock: () {
                              Get.to(() => const NoSaleShopSelectScreen());
                            },
                            // onStartBooking intentionally omitted — leaving
                            // this unset makes ShopVisitOutcomeScreen use its
                            // default navigation into CustomerAccountScreen
                            // (Customer Account -> Add Products -> Bill
                            // Summary -> Booking Confirmed).
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SecondaryActionButton(
                      label: 'Sale Return',
                      icon:  Icons.replay_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // TODO: Get.to(() => const SaleReturnScreen());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ── Today's route header ─────────────────────────────────
              Text(
                'TODAY\'S ROUTE (${_todaysRoute.length} ${_todaysRoute.length == 1 ? "SHOP" : "SHOPS"})',
                style: const TextStyle(
                  fontSize:      12,
                  fontWeight:    FontWeight.w700,
                  color:         _textMuted,
                  letterSpacing: 0.6,
                ),
              ),

              const SizedBox(height: 12),

              // ── Route list — empty for now ───────────────────────────
              if (_todaysRoute.isEmpty)
                const _EmptyRouteState()
              else
                ...List.generate(
                  _todaysRoute.length,
                      (i) => Padding(
                    padding: EdgeInsets.only(
                      bottom: i < _todaysRoute.length - 1 ? 10 : 0,
                    ),
                    child: _RouteShopCard(
                      shop: _todaysRoute[i],
                      onTap: () {
                        Get.to(() => ShopVisitOutcomeScreen(
                          // TODO(api): _RouteShop currently has no id field —
                          // add one once the route endpoint returns shop_id.
                          shopName:     _todaysRoute[i].name,
                          shopSubtitle: _todaysRoute[i].subtitle,
                          onShopClosed:    () {},
                          onNoSaleOfStock: () {},
                          // onStartBooking omitted on purpose — see note above.
                        ));
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      // ── Bottom navigation bar ────────────────────────────────────────────
      bottomNavigationBar: AppBottomNavBar(
        currentIndex:   widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap:          widget.onNavTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's summary card (route done / bookings / today's sales)
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int    routeDone;
  final int    routeTotal;
  final int    bookings;
  final String todaySales;

  const _SummaryCard({
    required this.routeDone,
    required this.routeTotal,
    required this.bookings,
    required this.todaySales,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryStat(value: '$routeDone/$routeTotal', label: 'ROUTE DONE'),
          _VerticalDivider(),
          _SummaryStat(value: '$bookings', label: 'BOOKINGS'),
          _VerticalDivider(),
          _SummaryStat(value: todaySales, label: 'TODAY'),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width:  1,
      height: 34,
      color:  AppColors.divider,
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize:   17,
            fontWeight: FontWeight.w800,
            color:      AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize:      10,
            fontWeight:    FontWeight.w600,
            color:         AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary action button — "New Booking" (filled, teal gradient)
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [AppColors.tealLight, AppColors.tealDark],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      AppColors.tealDark.withOpacity(0.28),
              blurRadius: 14,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary action button — "Sale Return" (outlined / white)
// ─────────────────────────────────────────────────────────────────────────────
class _SecondaryActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.tealDark, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route shop card (used once route data is wired up)
// ─────────────────────────────────────────────────────────────────────────────
class _RouteShopCard extends StatelessWidget {
  final _RouteShop shop;
  final VoidCallback? onTap;
  const _RouteShopCard({required this.shop, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (shop.status) {
      'Booked'  => const Color(0xFF16A34A),
      'Pending' => const Color(0xFFD97706),
      _         => AppColors.textSecondary,
    };
    final statusBg = switch (shop.status) {
      'Booked'  => const Color(0xFFE9F9EF),
      'Pending' => const Color(0xFFFFF7E6),
      _         => const Color(0xFFF3F4F6),
    };

    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color:        AppColors.iconBgTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: AppColors.tealDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(shop.subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
              child: Text(shop.status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C4C4), size: 20),
          ],
        ),
      ),
    );
  }
}

class _RouteShop {
  final String name;
  final String subtitle;
  final String status;
  const _RouteShop({required this.name, required this.subtitle, required this.status});
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — shown when today's route has no shops yet
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:    double.infinity,
      padding:  const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.map_outlined, color: AppColors.textSecondary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'No shops on your route yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a shop or start a booking to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}