// lib/Screens/Customers/customers_list_screen.dart




import 'package:book_dispatch/Screens/Visit%20List/visits_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../AppColors.dart';
import '../HomeScreenComponents/app_bottom_navbar.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';
import 'customer_form_screen.dart';
import 'customer_model.dart';
import 'customer_view_model.dart';

class CustomersListScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int>? onNavTap;

  const CustomersListScreen({
    super.key,
    this.currentIndex = 6,
    this.chatBadgeCount = 0,
    this.onNavTap,
  });

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CustomerViewModel vm =
  Get.isRegistered<CustomerViewModel>() ? Get.find<CustomerViewModel>() : Get.put(CustomerViewModel());
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-refresh when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.empId.value.isNotEmpty && vm.companyCode.value.isNotEmpty) {
        vm.fetchCustomersFromServer();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Obx(() => Navbar(
          userName: vm.empName.value.isEmpty ? 'Employee' : vm.empName.value,
          userInitials: vm.initials,
          scaffoldKey: _scaffoldKey,
        )),
      ),
      drawer: AppDrawer(),
      bottomNavigationBar: widget.onNavTap != null
          ? AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: widget.onNavTap!,
      )
          : null,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.tealLight,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Obx(() {
          final rows = vm.filtered;
          return RefreshIndicator(
            color: AppColors.tealLight,
            onRefresh: () async {
              await vm.fetchCustomersFromServer();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearch()),
                if (vm.isLoading.value && rows.isEmpty)
                  SliverFillRemaining(child: _buildLoadingState())
                else if (vm.errorMessage.value.isNotEmpty && rows.isEmpty)
                  SliverFillRemaining(child: _buildErrorState())
                else if (rows.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _emptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => _CustomerCard(
                            customer: rows[i],
                            onTap: () => _openDetails(context, rows[i]),
                          ),
                          childCount: rows.length,
                        ),
                      ),
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customers',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Obx(() {
                  final count = vm.customers.length;
                  final serverCount = vm.customers.where((c) => c.posted).length;
                  return Text(
                    '$count customers${serverCount > 0 ? ' · $serverCount synced' : ''}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  );
                }),
              ],
            ),
          ),
          _moduleSwitchButton(context),
        ],
      ),
    );
  }

  Widget _moduleSwitchButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitsListScreen(
              currentIndex: widget.currentIndex,
              chatBadgeCount: widget.chatBadgeCount,
              onNavTap: widget.onNavTap,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.iconBgTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded,
                size: 16, color: AppColors.tealDark),
            SizedBox(width: 6),
            Text(
              'Visits',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: vm.setSearch,
        decoration: InputDecoration(
          hintText: 'Search customer name, mobile or ID…',
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
          filled: true,
          fillColor: AppColors.cardBg,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.tealLight, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Loading customers…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 36, color: AppColors.warning),
            ),
            const SizedBox(height: 18),
            Text(
              vm.errorMessage.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => vm.fetchCustomersFromServer(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 52, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text('No customers yet',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Tap + to add your first customer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );
  }

  void _openDetails(BuildContext context, CustomerModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDetailSheet(customer: c),
    );
  }
}

// ── Customer Card ──────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;
  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.iconBgTeal,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                customer.initials,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.tealDark, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name.isEmpty ? 'Unnamed' : customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!customer.posted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Offline',
                              style: TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.w700)),
                        ),
                      if (customer.posted && customer.customerNo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.greenDotLt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(customer.customerNo!,
                              style: TextStyle(fontSize: 8, color: AppColors.greenDotDk, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(customer.mobile,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.85))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer Detail Sheet ─────────────────────────────────────────────
// lib/Screens/Customers/customers_list_screen.dart

// ... (everything same until _CustomerDetailSheet) ...

// ── Customer Detail Sheet ─────────────────────────────────────────────
class _CustomerDetailSheet extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: AppColors.iconBgTeal, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(
                        customer.initials,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.tealDark, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                          Text(customer.mobile, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          if (customer.customerNo != null && customer.customerNo!.isNotEmpty)
                            Text(customer.customerNo!,
                                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withOpacity(0.7), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    _detailGrid([
                      ['Customer No', customer.customerNo ?? '—'],
                      ['Mobile', customer.mobile],
                      ['Alternate Mobile', customer.altMobile.isEmpty ? '—' : customer.altMobile],
                      ['Email', customer.email.isEmpty ? '—' : customer.email],
                      ['Address', customer.address.isEmpty ? '—' : customer.address],
                      ['City', customer.city.isEmpty ? '—' : customer.city],
                      ['Remarks', customer.remarks.isEmpty ? '—' : customer.remarks],
                      ['Employee', customer.empName.isEmpty ? '—' : customer.empName],
                      ['Status', customer.posted ? 'Synced ✅' : 'Local Only ⏳'],
                    ]),
                    const SizedBox(height: 16),
                    if (!customer.posted)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final vm = Get.find<CustomerViewModel>();
                            vm.retryUnsyncedCustomers().then((_) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                Get.snackbar('Syncing', 'Customer will be synced to server.',
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: AppColors.tealDark,
                                    colorText: Colors.white);
                              }
                            });
                          },
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('Sync to Server'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.tealDark,
                            side: const BorderSide(color: AppColors.tealLight),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailGrid(List<List<String>> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((pair) {
        final isFull = ['Address', 'Remarks'].contains(pair[0]);
        return SizedBox(
          width: isFull ? double.infinity : 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pair[0].toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
              const SizedBox(height: 3),
              Text(pair[1].isEmpty ? '—' : pair[1],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }
}