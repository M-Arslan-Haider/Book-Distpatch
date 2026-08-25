import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../../Database/db_helper.dart';
import '../../HomeScreenComponents/app_bottom_navbar.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import 'new_dispatch_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// dispatch_screen.dart  —  Dispatch Management Screen
// Styled to match booking_screen.dart's design language.
// Live data from:
// http://oracle.metaxperts.net/ords/gps_workforce/dispatcher/get/:emp_id/:company_code
// ═══════════════════════════════════════════════════════════════════════════

class DispatchScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const DispatchScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    this.chatBadgeCount = 0,
  });

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;

  static const String _dispatcherEndpoint =
      'http://oracle.metaxperts.net/ords/gps_workforce/dispatcher/get';

  late Future<List<DispatchOrder>> _futureOrders;

  @override
  void initState() {
    super.initState();
    _futureOrders = _loadOrders();
  }

  // ── API ──────────────────────────────────────────────────────────────────
  Future<List<DispatchOrder>> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // === FIX: Same as LeaveViewModel ===
      final String empId = prefs.getString('userId') ??
          prefs.getString('user_id') ??
          prefs.getString('emp_id') ??
          prefs.getString('empId') ??
          prefs.getString('employee_id') ??
          prefs.getString('employeeId') ?? '';

      final String companyCode = DBHelper.getCompanyCode() ?? '';

      debugPrint('📱 DispatchScreen - emp_id: "$empId", company_code: "$companyCode"');

      if (empId.isEmpty || companyCode.isEmpty) {
        throw Exception('⚠️ Employee ID or Company Code missing. emp_id: "$empId", company_code: "$companyCode"');
      }

      final uri = Uri.parse('$_dispatcherEndpoint/$empId/$companyCode');
      debugPrint('📡 Calling API: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 404) {
        throw Exception('❌ 404 Not Found - URL: $uri');
      }

      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode}) — URL: $uri');
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      debugPrint('✅ API Response keys: ${body.keys}');

      // Try 'items' first, then 'data'
      List<dynamic> data = [];
      if (body['items'] != null && body['items'] is List) {
        data = body['items'] as List<dynamic>;
      } else if (body['data'] != null && body['data'] is List) {
        data = body['data'] as List<dynamic>;
      } else if (body['items'] != null && body['items'] is Map<String, dynamic>) {
        // If items is a Map, try to extract list from it
        final itemsMap = body['items'] as Map<String, dynamic>;
        if (itemsMap['data'] != null && itemsMap['data'] is List) {
          data = itemsMap['data'] as List<dynamic>;
        } else if (itemsMap['list'] != null && itemsMap['list'] is List) {
          data = itemsMap['list'] as List<dynamic>;
        }
      } else if (body['data'] != null && body['data'] is Map<String, dynamic>) {
        final dataMap = body['data'] as Map<String, dynamic>;
        if (dataMap['items'] != null && dataMap['items'] is List) {
          data = dataMap['items'] as List<dynamic>;
        } else if (dataMap['list'] != null && dataMap['list'] is List) {
          data = dataMap['list'] as List<dynamic>;
        }
      }

      if (data.isEmpty) {
        debugPrint('⚠️ No orders found in response');
        return [];
      }

      return data.map((e) => DispatchOrder.fromJson(e as Map<String, dynamic>)).toList();

    } catch (e) {
      debugPrint('❌ _loadOrders exception: $e');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final future = _loadOrders();
    setState(() => _futureOrders = future);
    await future;
  }

  void _showOrderDetail(DispatchOrder order) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OrderDetailSheet(order: order),
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
        child: FutureBuilder<List<DispatchOrder>>(
          future: _futureOrders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.tealDark));
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final orders = snapshot.data ?? [];

            return RefreshIndicator(
              color: AppColors.tealDark,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dispatch',
                      style: TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.w800,
                        color:      _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Manage and track today\'s shipments',
                      style: TextStyle(
                        fontSize: 13,
                        color:    _textMuted,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SummaryCard(
                      total:     orders.length,
                      pending:   orders.where((o) => o.isPending).length,
                      delivered: orders.where((o) => o.isDelivered).length,
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryActionButton(
                        label: 'New Dispatch',
                        icon:  Icons.local_shipping_rounded,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Get.to(() => const NewDispatchScreen());
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'TODAY\'S DISPATCH (${orders.length} ${orders.length == 1 ? "ORDER" : "ORDERS"})',
                      style: const TextStyle(
                        fontSize:      12,
                        fontWeight:    FontWeight.w700,
                        color:         _textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (orders.isEmpty)
                      const _EmptyDispatchState()
                    else
                      ...List.generate(
                        orders.length,
                            (i) => Padding(
                          padding: EdgeInsets.only(
                            bottom: i < orders.length - 1 ? 10 : 0,
                          ),
                          child: _DispatchOrderCard(
                            order: orders[i],
                            onTap: () => _showOrderDetail(orders[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex:   widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap:          widget.onNavTap,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int pending;
  final int delivered;

  const _SummaryCard({
    required this.total,
    required this.pending,
    required this.delivered,
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
          _SummaryStat(value: '$total', label: 'TOTAL'),
          _VerticalDivider(),
          _SummaryStat(value: '$pending', label: 'PENDING'),
          _VerticalDivider(),
          _SummaryStat(value: '$delivered', label: 'DELIVERED'),
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
// Dispatch Order Card  —  booking-card style, order ID + shop + status shown
// ─────────────────────────────────────────────────────────────────────────────
class _DispatchOrderCard extends StatelessWidget {
  final DispatchOrder order;
  final VoidCallback? onTap;
  const _DispatchOrderCard({required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.statusColor;
    final statusBg    = order.statusColor.withOpacity(0.12);

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
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.tealDark, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.orderId}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.tealDark)),
                  const SizedBox(height: 2),
                  Text(order.shopName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    '${order.items.length} items  •  Rs ${order.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
              child: Text(order.dispatchStatus.isNotEmpty ? order.dispatchStatus : '—',
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

class _EmptyDispatchState extends StatelessWidget {
  const _EmptyDispatchState();

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
            child: const Icon(Icons.local_shipping_outlined, color: AppColors.textSecondary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'No dispatch orders yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'New dispatch orders will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Could not load dispatch orders',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _OrderDetailSheet extends StatelessWidget {
  final DispatchOrder order;
  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      maxChildSize: 0.94,
      minChildSize: 0.40,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.iconBgTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.tealDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderId}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (order.shopName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.shopName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: order.statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: order.statusColor.withOpacity(0.25), width: 0.8),
                    ),
                    child: Text(
                      order.dispatchStatus.isNotEmpty ? order.dispatchStatus : '—',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: order.statusColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 20),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  _detailSection('Shop Info', [
                    _detailRow(Icons.storefront_outlined, 'Shop', order.shopName),
                    _detailRow(Icons.location_on_outlined, 'Address', order.shopAddress),
                    _detailRow(Icons.person_outline_rounded, 'Owner', order.ownerName),
                    if (order.brand.isNotEmpty)
                      _detailRow(Icons.sell_outlined, 'Brand', order.brand),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('Order Info', [
                    _detailRow(Icons.receipt_long_outlined, 'Order ID', order.orderId),
                    if (order.visitId.isNotEmpty)
                      _detailRow(Icons.badge_outlined, 'Visit ID', order.visitId),
                    _detailRow(Icons.inventory_2_outlined, 'Total Items', '${order.items.length} items'),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('Amount', [
                    _detailRow(Icons.receipt_outlined, 'Subtotal', 'Rs ${order.subtotal.toStringAsFixed(0)}'),
                    _detailRow(Icons.percent_rounded, 'GST', 'Rs ${order.gstAmount.toStringAsFixed(0)}'),
                    _detailRow(Icons.payments_outlined, 'Grand Total', 'Rs ${order.grandTotal.toStringAsFixed(0)}'),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('Dispatcher & Timeline', [
                    _detailRow(Icons.local_shipping_outlined, 'Dispatcher', order.dispatcherName),
                    _detailRow(Icons.schedule_rounded, 'Created', order.createdDate),
                  ]),
                  if (order.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _detailSection('Notes', [
                      _detailRow(Icons.notes_rounded, 'Notes', order.notes),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'ITEMS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: order.items.isEmpty
                          ? [
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'No items in this order',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ]
                          : order.items.asMap().entries.map((e) {
                        final it = e.value;
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.productName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${it.quantity} x Rs ${it.rate.toStringAsFixed(0)}'
                                              '${it.discountPercent > 0 ? '  •  ${it.discountPercent}% off' : ''}'
                                              '${it.bonusPieces > 0 ? '  •  +${it.bonusPieces} bonus' : ''}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rs ${it.netAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (e.key < order.items.length - 1)
                              const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFE5E7EB)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: rows
                .asMap()
                .entries
                .map((e) => Column(
              children: [
                e.value,
                if (e.key < rows.length - 1)
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFE5E7EB)),
              ],
            ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isNotEmpty ? value : '—',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models  —  mapped from /dispatcher/get/:emp_id/:company_code
// ─────────────────────────────────────────────────────────────────────────────
class DispatchOrderItem {
  final String itemId;
  final String productId;
  final String productName;
  final String brand;
  final num    quantity;
  final num    rate;
  final num    discountPercent;
  final num    bonusPieces;
  final num    netAmount;
  final num    stock;
  final String createdDate;

  const DispatchOrderItem({
    required this.itemId,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.quantity,
    required this.rate,
    required this.discountPercent,
    required this.bonusPieces,
    required this.netAmount,
    required this.stock,
    required this.createdDate,
  });

  factory DispatchOrderItem.fromJson(Map<String, dynamic> json) {
    num _num(dynamic v) => num.tryParse(v?.toString() ?? '') ?? 0;
    String _str(dynamic v) => v?.toString() ?? '';

    return DispatchOrderItem(
      itemId:          _str(json['item_id']),
      productId:       _str(json['product_id']),
      productName:     _str(json['product_name']),
      brand:           _str(json['brand']),
      quantity:        _num(json['quantity']),
      rate:            _num(json['rate']),
      discountPercent: _num(json['discount_percent']),
      bonusPieces:     _num(json['bonus_pieces']),
      netAmount:       _num(json['net_amount']),
      stock:           _num(json['stock']),
      createdDate:     _str(json['created_date']),
    );
  }
}

class DispatchOrder {
  final String orderId;
  final String visitId;
  final String employeeId;
  final String employeeName;
  final String companyCode;
  final String shopId;
  final String shopName;
  final String shopAddress;
  final String ownerName;
  final String brand;
  final String gpsEnabled;
  final String latitude;
  final String longitude;
  final String notes;
  final num    subtotal;
  final num    gstAmount;
  final num    grandTotal;
  final String dispatcherId;
  final String dispatcherName;
  final String dispatchStatus;
  final String createdDate;
  final List<DispatchOrderItem> items;

  const DispatchOrder({
    required this.orderId,
    required this.visitId,
    required this.employeeId,
    required this.employeeName,
    required this.companyCode,
    required this.shopId,
    required this.shopName,
    required this.shopAddress,
    required this.ownerName,
    required this.brand,
    required this.gpsEnabled,
    required this.latitude,
    required this.longitude,
    required this.notes,
    required this.subtotal,
    required this.gstAmount,
    required this.grandTotal,
    required this.dispatcherId,
    required this.dispatcherName,
    required this.dispatchStatus,
    required this.createdDate,
    required this.items,
  });

  factory DispatchOrder.fromJson(Map<String, dynamic> json) {
    num _num(dynamic v) => num.tryParse(v?.toString() ?? '') ?? 0;
    String _str(dynamic v) => v?.toString() ?? '';

    final List<dynamic> rawItems = json['items'] ?? [];

    return DispatchOrder(
      orderId:        _str(json['order_id']),
      visitId:        _str(json['visit_id']),
      employeeId:     _str(json['employee_id']),
      employeeName:   _str(json['employee_name']),
      companyCode:    _str(json['company_code']),
      shopId:         _str(json['shop_id']),
      shopName:       _str(json['shop_name']),
      shopAddress:    _str(json['shop_address']),
      ownerName:      _str(json['owner_name']),
      brand:          _str(json['brand']),
      gpsEnabled:     _str(json['gps_enabled']),
      latitude:       _str(json['latitude']),
      longitude:      _str(json['longitude']),
      notes:          _str(json['notes']),
      subtotal:       _num(json['subtotal']),
      gstAmount:      _num(json['gst_amount']),
      grandTotal:     _num(json['grand_total']),
      dispatcherId:   _str(json['dispatcher_id']),
      dispatcherName: _str(json['dispatcher_name']),
      dispatchStatus: _str(json['dispatch_status']),
      createdDate:    _str(json['created_date']),
      items: rawItems
          .map((e) => DispatchOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get _statusNormalized => dispatchStatus.trim().toUpperCase();

  bool get isPending =>
      _statusNormalized == 'PENDING' || _statusNormalized == 'NEW';

  bool get isDelivered =>
      _statusNormalized == 'DELIVERED' || _statusNormalized == 'COMPLETED';

  Color get statusColor {
    switch (_statusNormalized) {
      case 'PENDING':
      case 'NEW':
        return const Color(0xFFF59E0B);
      case 'IN_TRANSIT':
      case 'DISPATCHED':
      case 'IN PROGRESS':
        return AppColors.tealDark;
      case 'DELIVERED':
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return AppColors.textSecondary;
    }
  }
}