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
import 'dispatch_screen.dart' show DispatchOrder, DispatchOrderItem;

// ─── File-level helper ──────────────────────────────────────────────────────
bool _isOrderProcessed(DispatchOrder order) {
  final s = order.dispatchStatus.toUpperCase();
  return s == 'DISPATCHED' || s == 'NOT_DISPATCHED';
}
// ────────────────────────────────────────────────────────────────────────────

class NewDispatchScreen extends StatefulWidget {
  const NewDispatchScreen({super.key});

  @override
  State<NewDispatchScreen> createState() => _NewDispatchScreenState();
}

class _NewDispatchScreenState extends State<NewDispatchScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final int currentIndex = 2;
  final int chatBadgeCount = 0;

  static const String _dispatcherEndpoint =
      'http://oracle.metaxperts.net/ords/gps_workforce/dispatcher/get';

  static const String _statusEndpoint =
      'http://oracle.metaxperts.net/ords/gps_workforce/dispatchstatus/put/status';

  late Future<List<DispatchOrder>> _futureOrders;
  late final AnimationController _shimmerController;
  String _selectedFilter = 'Pending'; // 'All' | 'Pending' | 'Dispatched'

  List<DispatchOrder> _filterOrders(List<DispatchOrder> orders) {
    if (_selectedFilter == 'Pending') {
      return orders.where((o) => !_isOrderProcessed(o)).toList();
    }
    if (_selectedFilter == 'Dispatched') {
      return orders.where(_isOrderProcessed).toList();
    }
    return orders;
  }

  @override
  void initState() {
    super.initState();
    _futureOrders = _loadOrders();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<List<DispatchOrder>> _loadOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String empId = prefs.getString('userId') ??
          prefs.getString('user_id') ??
          prefs.getString('emp_id') ??
          prefs.getString('empId') ??
          prefs.getString('employee_id') ??
          prefs.getString('employeeId') ?? '';

      final String companyCode = DBHelper.getCompanyCode() ?? '';

      debugPrint('NewDispatchScreen - emp_id: "$empId", company_code: "$companyCode"');

      if (empId.isEmpty || companyCode.isEmpty) {
        throw Exception('Employee ID or Company Code missing.');
      }

      final uri = Uri.parse('$_dispatcherEndpoint/$empId/$companyCode');
      debugPrint('Calling API: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 404) {
        throw Exception('404 Not Found - URL: $uri');
      }

      if (response.statusCode != 200) {
        throw Exception('Server error (${response.statusCode})');
      }

      final Map<String, dynamic> body = jsonDecode(response.body);

      List<dynamic> data = [];
      if (body['items'] != null && body['items'] is List) {
        data = body['items'] as List<dynamic>;
      } else if (body['data'] != null && body['data'] is List) {
        data = body['data'] as List<dynamic>;
      } else if (body['items'] != null && body['items'] is Map<String, dynamic>) {
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

      if (data.isEmpty) return [];

      return data.map((e) => DispatchOrder.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('NewDispatchScreen _loadOrders exception: $e');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    final future = _loadOrders();
    setState(() => _futureOrders = future);
    await future;
  }

  // ── Dispatch status PUT API ───────────────────────────────────────────────
  Future<void> _updateDispatchStatus(String orderId, String status) async {
    bool _success = false;
    try {
      final uri = Uri.parse('$_statusEndpoint/$orderId');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      final Map<String, dynamic> resBody = jsonDecode(response.body);
      if (resBody['success'] == true) {
        _success = true;
        Get.snackbar(
          'Success',
          'Order #$orderId marked as ${status.replaceAll('_', ' ')}',
          backgroundColor: AppColors.tealDark,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Failed',
          resBody['message']?.toString() ?? 'Could not update status',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('_updateDispatchStatus error: $e');
      Get.snackbar(
        'Error',
        'Network error — could not update status',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    // ── Refresh ONLY on success, OUTSIDE the try-catch ─────────────────────
    // This ensures refresh failures never trigger the "network error" snackbar
    if (_success) {
      try {
        await _refresh();
      } catch (_) {
        // FutureBuilder handles any refresh error via its own error state
      }
    }
  }

  // ── Card tap: show details as bottom sheet on this screen ─────────────────
  void _openDetails(DispatchOrder order) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => _DispatchDetailSheet(
        order: order,
        onStatusChange: (status) => _updateDispatchStatus(order.orderId, status),
      ),
    );
  }

  void _onNavTap(int index) {
    HapticFeedback.lightImpact();
    if (index == 2) {
      Navigator.of(context).pop();
    }
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
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
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
              return _LoadingState(shimmerController: _shimmerController);
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final orders = snapshot.data ?? [];
            final int _pendingCount   = orders.where((o) => !_isOrderProcessed(o)).length;
            final int _dispatchedCount = orders.where(_isOrderProcessed).length;
            final filteredOrders = _filterOrders(orders);

            return RefreshIndicator(
              color: AppColors.tealDark,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(bottom: 12.0),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                          const Text(
                            'New Dispatch',
                            style: TextStyle(
                              fontSize:   22,
                              fontWeight: FontWeight.w800,
                              color:      AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Create a new dispatch order from live shop data',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          _SummaryHeaderCard(orderCount: orders.length),
                          const SizedBox(height: 14),
                          // ── Filter Chips ──────────────────────────────────
                          _FilterChipBar(
                            selected: _selectedFilter,
                            onSelected: (val) =>
                                setState(() => _selectedFilter = val),
                            allCount: orders.length,
                            pendingCount: _pendingCount,
                            dispatchedCount: _dispatchedCount,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text(
                                'SELECT A SHOP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              if (filteredOrders.isNotEmpty)
                                Text(
                                  '${filteredOrders.length} ${filteredOrders.length == 1 ? "result" : "results"}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  if (filteredOrders.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(child: _EmptyState()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                            padding: EdgeInsets.only(
                              bottom: i < filteredOrders.length - 1 ? 12 : 0,
                            ),
                            child: _StaggeredEntrance(
                              index: i,
                              child: _ShopSourceCard(
                                order: filteredOrders[i],
                                onTap: () => _openDetails(filteredOrders[i]),
                                onStatusChange: (status) =>
                                    _updateDispatchStatus(filteredOrders[i].orderId, status),
                              ),
                            ),
                          ),
                          childCount: filteredOrders.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex:   currentIndex,
        chatBadgeCount: chatBadgeCount,
        onTap:          _onNavTap,
      ),
    );
  }
}

// =============================================================================
// Dispatch Detail Bottom Sheet
// =============================================================================
class _DispatchDetailSheet extends StatelessWidget {
  final DispatchOrder order;
  final Future<void> Function(String status) onStatusChange;
  const _DispatchDetailSheet({required this.order, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.statusColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE1E9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Text(
                      'Dispatch Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).maybePop();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEDEFF3)),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _DetailHeaderCard(order: order, statusColor: statusColor),
                    const SizedBox(height: 18),
                    _DetailSectionCard(
                      title: 'Shop Information',
                      icon: Icons.storefront_outlined,
                      initiallyExpanded: true,
                      rows: [
                        _DetailInfoRow(icon: Icons.storefront_outlined, label: 'Shop', value: order.shopName),
                        _DetailInfoRow(icon: Icons.location_on_outlined, label: 'Address', value: order.shopAddress),
                        _DetailInfoRow(icon: Icons.person_outline_rounded, label: 'Owner', value: order.ownerName),
                        if (order.brand.isNotEmpty)
                          _DetailInfoRow(icon: Icons.sell_outlined, label: 'Brand', value: order.brand),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DetailSectionCard(
                      title: 'Order Information',
                      icon: Icons.receipt_long_outlined,
                      rows: [
                        _DetailInfoRow(icon: Icons.receipt_long_outlined, label: 'Order ID', value: order.orderId),
                        if (order.visitId.isNotEmpty)
                          _DetailInfoRow(icon: Icons.badge_outlined, label: 'Visit ID', value: order.visitId),
                        _DetailInfoRow(icon: Icons.inventory_2_outlined, label: 'Total Items', value: '${order.items.length} items'),
                        _DetailInfoRow(
                          icon: Icons.gps_fixed_rounded,
                          label: 'GPS',
                          value: order.gpsEnabled.isNotEmpty ? order.gpsEnabled : '—',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DetailSectionCard(
                      title: 'Amount Summary',
                      icon: Icons.payments_outlined,
                      rows: [
                        _DetailInfoRow(icon: Icons.receipt_outlined, label: 'Subtotal', value: 'Rs ${order.subtotal.toStringAsFixed(0)}'),
                        _DetailInfoRow(icon: Icons.percent_rounded, label: 'GST', value: 'Rs ${order.gstAmount.toStringAsFixed(0)}'),
                        _DetailInfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Grand Total',
                          value: 'Rs ${order.grandTotal.toStringAsFixed(0)}',
                          emphasize: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DetailSectionCard(
                      title: 'Dispatcher & Timeline',
                      icon: Icons.local_shipping_outlined,
                      rows: [
                        _DetailInfoRow(icon: Icons.local_shipping_outlined, label: 'Dispatcher', value: order.dispatcherName),
                        _DetailInfoRow(icon: Icons.schedule_rounded, label: 'Created', value: order.createdDate),
                      ],
                    ),
                    if (order.notes.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _DetailSectionCard(
                        title: 'Notes',
                        icon: Icons.notes_rounded,
                        rows: [
                          _DetailInfoRow(icon: Icons.notes_rounded, label: 'Notes', value: order.notes),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Text(
                          'ITEMS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${order.items.length} ${order.items.length == 1 ? "item" : "items"}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (order.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEDEFF3)),
                        ),
                        child: const Center(
                          child: Text(
                            'No items in this order',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...List.generate(
                        order.items.length,
                            (i) => Padding(
                          padding: EdgeInsets.only(bottom: i < order.items.length - 1 ? 10 : 0),
                          child: _DetailItemCard(item: order.items[i]),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Fixed bottom action buttons ──────────────────────────────
              if (_isOrderProcessed(order))
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEDEFF3))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        order.dispatchStatus.toUpperCase() == 'DISPATCHED'
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined,
                        size: 19,
                        color: order.dispatchStatus.toUpperCase() == 'DISPATCHED'
                            ? AppColors.tealDark
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order.dispatchStatus.toUpperCase() == 'DISPATCHED'
                            ? 'This order has already been dispatched'
                            : 'This order was marked as not dispatched',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: order.dispatchStatus.toUpperCase() == 'DISPATCHED'
                              ? AppColors.tealDark
                              : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEDEFF3))),
                  ),
                  child: _DispatchActionButtons(onStatusChange: onStatusChange),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Header Card
// ─────────────────────────────────────────────────────────────────────────────
class _DetailHeaderCard extends StatelessWidget {
  final DispatchOrder order;
  final Color statusColor;
  const _DetailHeaderCard({required this.order, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealLight, AppColors.tealDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderId}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.shopName.isNotEmpty ? order.shopName : 'Unnamed shop',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      order.dispatchStatus.isNotEmpty ? order.dispatchStatus : '—',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DetailHeaderStat(label: 'ITEMS', value: '${order.items.length}'),
              ),
              Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
              Expanded(
                child: _DetailHeaderStat(
                  label: 'GRAND TOTAL',
                  value: 'Rs ${order.grandTotal.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailHeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _DetailHeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.75),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Section Card — collapsible
// ─────────────────────────────────────────────────────────────────────────────
class _DetailSectionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;
  final bool initiallyExpanded;
  const _DetailSectionCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.initiallyExpanded = false,
  });

  @override
  State<_DetailSectionCard> createState() => _DetailSectionCardState();
}

class _DetailSectionCardState extends State<_DetailSectionCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _controller;
  late final Animation<double> _expandAnim;
  late final Animation<double> _chevronAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _chevronAnim = Tween<double>(begin: 0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    _expanded ? _controller.forward() : _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.iconBgTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, size: 15, color: AppColors.tealDark),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    RotationTransition(
                      turns: _chevronAnim,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFEDEFF3)),
                ...widget.rows.asMap().entries.map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < widget.rows.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F1F4)),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value.isNotEmpty ? value : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasize ? 14.5 : 13,
                color: emphasize ? AppColors.tealDark : const Color(0xFF111827),
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
// Detail Item Card
// ─────────────────────────────────────────────────────────────────────────────
class _DetailItemCard extends StatelessWidget {
  final DispatchOrderItem item;
  const _DetailItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.iconBgTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.tealDark, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName.isNotEmpty ? item.productName : 'Product #${item.productId}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} x Rs ${item.rate.toStringAsFixed(0)}'
                      '${item.discountPercent > 0 ? "  •  ${item.discountPercent}% off" : ""}'
                      '${item.bonusPieces > 0 ? "  •  +${item.bonusPieces} bonus" : ""}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs ${item.netAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dispatch Action Buttons — stateful for loading per-button
// ─────────────────────────────────────────────────────────────────────────────
class _DispatchActionButtons extends StatefulWidget {
  final Future<void> Function(String status) onStatusChange;
  const _DispatchActionButtons({required this.onStatusChange});

  @override
  State<_DispatchActionButtons> createState() => _DispatchActionButtonsState();
}

class _DispatchActionButtonsState extends State<_DispatchActionButtons> {
  String? _loadingStatus; // which button is loading

  Future<void> _tap(String status) async {
    if (_loadingStatus != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _loadingStatus = status);
    try {
      await widget.onStatusChange(status);
    } finally {
      if (mounted) setState(() => _loadingStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: 'Dispatch',
            icon: Icons.local_shipping_rounded,
            color: AppColors.tealDark,
            outlined: false,
            loading: _loadingStatus == 'DISPATCHED',
            disabled: _loadingStatus != null,
            onTap: () => _tap('DISPATCHED'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            label: 'Not Dispatch',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFEF4444),
            outlined: true,
            loading: _loadingStatus == 'NOT_DISPATCHED',
            disabled: _loadingStatus != null,
            onTap: () => _tap('NOT_DISPATCHED'),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.outlined,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled && !loading ? color.withOpacity(0.45) : color;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : effectiveColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveColor, width: outlined ? 1.5 : 0),
        ),
        child: loading
            ? Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? color : Colors.white,
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: outlined ? effectiveColor : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: outlined ? effectiveColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered entrance animation
// ─────────────────────────────────────────────────────────────────────────────
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 45).clamp(0, 360);
    return TweenAnimationBuilder<double>(
      key: ValueKey('entrance_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary header card
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryHeaderCard extends StatelessWidget {
  final int orderCount;
  const _SummaryHeaderCard({required this.orderCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealLight, AppColors.tealDark],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDark.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$orderCount ${orderCount == 1 ? "Order" : "Orders"} Available',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Live data — synced from the dispatch server',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip bar
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChipBar extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;
  final int allCount;
  final int pendingCount;
  final int dispatchedCount;

  const _FilterChipBar({
    required this.selected,
    required this.onSelected,
    required this.allCount,
    required this.pendingCount,
    required this.dispatchedCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: allCount,
            icon: Icons.list_rounded,
            selected: selected == 'All',
            onTap: () => onSelected('All'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pending',
            count: pendingCount,
            icon: Icons.hourglass_empty_rounded,
            selected: selected == 'Pending',
            onTap: () => onSelected('Pending'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Dispatched',
            count: dispatchedCount,
            icon: Icons.check_circle_outline_rounded,
            selected: selected == 'Dispatched',
            onTap: () => onSelected('Dispatched'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg        = selected ? AppColors.tealDark : Colors.white;
    final Color textColor = selected ? Colors.white : AppColors.textSecondary;
    final Color border    = selected ? AppColors.tealDark : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 1.2),
          boxShadow: selected
              ? [
            BoxShadow(
              color: AppColors.tealDark.withOpacity(0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.22)
                    : AppColors.tealDark.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.tealDark,
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
// Shop source card
// ─────────────────────────────────────────────────────────────────────────────
class _ShopSourceCard extends StatelessWidget {
  final DispatchOrder order;
  final VoidCallback? onTap;
  final Future<void> Function(String status) onStatusChange;
  const _ShopSourceCard({
    required this.order,
    required this.onStatusChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = order.statusColor;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.tealDark.withOpacity(0.06),
        highlightColor: AppColors.tealDark.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEFF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.iconBgTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.tealDark, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.shopName.isNotEmpty ? order.shopName : 'Shop #${order.shopId}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Order #${order.orderId}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: order.dispatchStatus, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF0F1F4)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _InlineStat(
                      icon: Icons.location_on_outlined,
                      label: order.shopAddress.isNotEmpty ? order.shopAddress : '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _InlineStat(
                    icon: Icons.inventory_2_outlined,
                    label: '${order.items.length} items',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Rs ${order.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
                ],
              ),
              // ── Action buttons (hidden if already processed) ────────────
              if (!_isOrderProcessed(order)) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F1F4)),
                const SizedBox(height: 10),
                _DispatchActionButtons(onStatusChange: onStatusChange),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InlineStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.5, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label.isNotEmpty ? label : '—',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading state — shimmer skeleton
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  final AnimationController shimmerController;
  const _LoadingState({required this.shimmerController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ShimmerBox(controller: shimmerController, height: 20, width: 150, radius: 6),
        const SizedBox(height: 8),
        _ShimmerBox(controller: shimmerController, height: 13, width: 220, radius: 4),
        const SizedBox(height: 18),
        _ShimmerBox(controller: shimmerController, height: 76, width: double.infinity, radius: 18),
        const SizedBox(height: 20),
        _ShimmerBox(controller: shimmerController, height: 12, width: 110, radius: 4),
        const SizedBox(height: 12),
        for (int i = 0; i < 4; i++) ...[
          _ShimmerCard(controller: shimmerController),
          if (i < 3) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final AnimationController controller;
  const _ShimmerCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(controller: controller, height: 42, width: 42, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(controller: controller, height: 14, width: 140, radius: 4),
                    const SizedBox(height: 6),
                    _ShimmerBox(controller: controller, height: 11, width: 90, radius: 4),
                  ],
                ),
              ),
              _ShimmerBox(controller: controller, height: 22, width: 60, radius: 20),
            ],
          ),
          const SizedBox(height: 14),
          _ShimmerBox(controller: controller, height: 1, width: double.infinity, radius: 0),
          const SizedBox(height: 12),
          _ShimmerBox(controller: controller, height: 12, width: double.infinity, radius: 4),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double height;
  final double width;
  final double radius;
  const _ShimmerBox({
    required this.controller,
    required this.height,
    required this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: const [
                Color(0xFFEDEFF3),
                Color(0xFFF8F9FB),
                Color(0xFFEDEFF3),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_outlined, color: AppColors.textSecondary, size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'No dispatch data available',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'There are currently no shops or orders to display.\nPull down to refresh once records are available.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load dispatch data',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}