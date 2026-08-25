

import 'package:book_dispatch/Screens/Visit%20List/visit_constants.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_model.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../AppColors.dart';
import '../HomeScreenComponents/app_bottom_navbar.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';
import 'followups_list_screen.dart';

class VisitsListScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int>? onNavTap;

  const VisitsListScreen({
    super.key,
    this.currentIndex = 7,
    this.chatBadgeCount = 0,
    this.onNavTap,
  });

  @override
  State<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends State<VisitsListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final VisitViewModel vm =
  Get.isRegistered<VisitViewModel>() ? Get.find<VisitViewModel>() : Get.put(VisitViewModel());
  final TextEditingController _searchCtrl = TextEditingController();

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
        onPressed: () {
          Get.snackbar(
            'Coming Soon',
            'Add new visit feature coming soon.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: AppColors.info,
            colorText: Colors.white,
          );
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Obx(() {
          final rows = vm.filtered;
          return RefreshIndicator(
            color: AppColors.tealLight,
            onRefresh: () async {
              await vm.fetchVisitsFromServer();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearchAndChips()),
                if (rows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, i) => _VisitCard(
                          visit: rows[i],
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

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Visits',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => Text(
                  '${vm.visits.length} visits · ${vm.gpsVerifiedCount} GPS verified',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                )),
              ],
            ),
          ),
          _moduleSwitchButton(context),
        ],
      ),
    );
  }

  Widget _moduleSwitchButton(BuildContext context) {
    const due = 0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FollowupsListScreen(
            currentIndex: widget.currentIndex,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: widget.onNavTap,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.iconBgTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded,
                size: 16, color: AppColors.tealDark),
            const SizedBox(width: 6),
            const Text(
              'Follow-ups',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
            if (due > 0) ...[
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 8,
                backgroundColor: AppColors.error,
                child: Text('$due',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Search + status chips ───────────────────────────────────────────
  Widget _buildSearchAndChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: vm.setSearch,
            decoration: InputDecoration(
              hintText: 'Search customer, mobile or visit no…',
              hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.tealLight, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: Obx(() {
              final activeFilter = vm.statusFilter.value;
              final visitsLen = vm.visits.length;
              final counts = {
                for (final label in VisitConstants.statusFilters)
                  label: vm.countByStatus(label),
              };
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: VisitConstants.statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = VisitConstants.statusFilters[i];
                  final active = activeFilter == label;
                  final count = counts[label] ?? 0;
                  return GestureDetector(
                    onTap: () => vm.setStatusFilter(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? AppColors.tealDark : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.tealDark : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        '$label  $count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
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
            Icon(Icons.route_rounded, size: 52, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text('No visits found',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Try a different search or filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.9)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, VisitModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VisitDetailSheet(
        visit: v,
        viewModel: vm,
        onScheduleFollowup: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowupsListScreen(
                currentIndex: widget.currentIndex,
                chatBadgeCount: widget.chatBadgeCount,
                onNavTap: widget.onNavTap,
                presetVisit: v,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Visit card
// ═══════════════════════════════════════════════════════════════════════
class _VisitCard extends StatelessWidget {
  final VisitModel visit;
  final VoidCallback onTap;
  const _VisitCard({required this.visit, required this.onTap});

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.iconBgTeal,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (visit.customer.isNotEmpty ? visit.customer[0] : '?').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealDark,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit.customer.isEmpty ? 'Unnamed customer' : visit.customer,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${visit.visitNo} · ${_fmtDT(visit.date, visit.time)}',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withOpacity(0.85), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                _statusBadge(visit.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _metaItem(Icons.business_rounded, visit.project.isEmpty ? '—' : visit.project),
                _metaItem(Icons.person_rounded, visit.empName.isEmpty ? '—' : visit.empName),
                _metaItem(Icons.phone_rounded, visit.mobile.isEmpty ? '—' : visit.mobile),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (visit.interest.isNotEmpty) _interestBadge(visit.interest),
                _gpsBadge(visit.gpsStatus),
                if (visit.converted)
                  _pill('Converted', AppColors.tealDark, AppColors.iconBgDarkTeal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: AppColors.textSecondary.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Shared badge helpers ─────────────────────────────────────────────
Widget _statusBadge(String status) {
  final map = {
    'Planned': [AppColors.info, AppColors.tealSurface],
    'Completed': [AppColors.greenDotDk, AppColors.greenDotLt],
    'Cancelled': [AppColors.error, const Color(0xFFFDECEC)],
    'Missed': [AppColors.error, const Color(0xFFFDECEC)],
    'In Progress': [AppColors.warning, const Color(0xFFFFF3E0)],
  };
  final colors = map[status] ?? [AppColors.textSecondary, AppColors.surface];
  return _pill(status, colors[0] as Color, colors[1] as Color);
}

Widget _interestBadge(String interest) {
  final map = {
    'Hot': [AppColors.error, const Color(0xFFFDECEC)],
    'Warm': [AppColors.warning, const Color(0xFFFFF3E0)],
    'Cold': [AppColors.info, AppColors.tealSurface],
  };
  final colors = map[interest] ?? [AppColors.textSecondary, AppColors.surface];
  return _pill(interest, colors[0] as Color, colors[1] as Color);
}

Widget _gpsBadge(String status) {
  if (status == 'Verified') {
    return _pill('Verified', AppColors.greenDotDk, AppColors.greenDotLt, icon: Icons.satellite_alt_rounded);
  }
  if (status == 'Outside Location') {
    return _pill('Outside Location', AppColors.warning, const Color(0xFFFFF3E0), icon: Icons.location_off_rounded);
  }
  return _pill('Not Captured', AppColors.textSecondary, AppColors.surface, icon: Icons.satellite_alt_rounded);
}

Widget _pill(String text, Color fg, Color bg, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 10.5, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      ],
    ),
  );
}

String _fmtDT(String date, String time) {
  if (date.isEmpty) return '—';
  try {
    final d = DateTime.parse(date);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final s = '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
    return time.isEmpty ? s : '$s · $time';
  } catch (_) {
    return date;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Detail bottom sheet - SIRF VERIFY GPS BUTTON
// ═══════════════════════════════════════════════════════════════════════
class _VisitDetailSheet extends StatelessWidget {
  final VisitModel visit;
  final VisitViewModel viewModel;
  final VoidCallback onScheduleFollowup;

  const _VisitDetailSheet({
    required this.visit,
    required this.viewModel,
    required this.onScheduleFollowup,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.iconBgTeal, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.route_rounded, color: AppColors.tealDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(visit.customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                          Text('${visit.visitNo} · ${_fmtDT(visit.date, visit.time)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
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
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _statusBadge(visit.status),
                      if (visit.interest.isNotEmpty) _interestBadge(visit.interest),
                      _gpsBadge(visit.gpsStatus),
                      if (visit.converted) _pill('Converted', AppColors.tealDark, AppColors.iconBgDarkTeal),
                    ]),
                    const SizedBox(height: 16),
                    _detailGrid([
                      ['Employee', visit.empName],
                      ['Visit Type', visit.visitType],
                      ['Mobile', visit.mobile],
                      ['Email', visit.email],
                      ['Address', visit.address],
                      ['Project', visit.project],
                      ['Property Type', visit.propType],
                      ['Location', visit.location],
                      ['Size', visit.propSize],
                      ['Budget', (visit.budgetFrom > 0 || visit.budgetTo > 0) ? 'Rs ${visit.budgetFrom.toStringAsFixed(0)} – Rs ${visit.budgetTo.toStringAsFixed(0)}' : '—'],
                      ['Customer Response', visit.response],
                      ['Next Action', visit.nextAction],
                      ['Outcome', visit.outcome],
                      ['Remarks', visit.remarks],
                    ]),
                    const SizedBox(height: 16),

                    // ── ✅ GPS Status Card ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: visit.gpsStatus == 'Verified'
                            ? AppColors.greenDotLt
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: visit.gpsStatus == 'Verified'
                              ? AppColors.greenDotDk
                              : AppColors.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                visit.gpsStatus == 'Verified'
                                    ? Icons.check_circle_rounded
                                    : Icons.satellite_alt_rounded,
                                color: visit.gpsStatus == 'Verified'
                                    ? AppColors.greenDotDk
                                    : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'GPS Status: ${visit.gpsStatus}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: visit.gpsStatus == 'Verified'
                                        ? AppColors.greenDotDk
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (visit.gpsStatus == 'Verified')
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.greenDotDk,
                                  size: 20,
                                ),
                            ],
                          ),
                          if (visit.gpsLat != null && visit.gpsLng != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${visit.gpsLat!.toStringAsFixed(6)}, ${visit.gpsLng!.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (visit.gpsAcc != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.track_changes_rounded,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Accuracy: ±${visit.gpsAcc!.toStringAsFixed(0)}m',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // ── ✅ VERIFY GPS BUTTON (Main Action) ──────────────────────
              // ── ✅ VERIFY GPS BUTTON (with Already Verified check) ──────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // ✅ Verify GPS Button - Disabled if already verified
                    Expanded(
                      flex: 3,
                      child: visit.gpsStatus == 'Verified'
                          ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: AppColors.greenDotLt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.greenDotDk,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.verified_rounded,
                              color: AppColors.greenDotDk,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '✅ Verified',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.greenDotDk,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ElevatedButton.icon(
                        onPressed: () async {
                          // Close the sheet first
                          Navigator.pop(context);

                          // Show loading
                          Get.snackbar(
                            'Capturing GPS',
                            'Getting your current location...',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: AppColors.tealDark,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 2),
                          );

                          // Capture GPS
                          final gps = await viewModel.captureGps();
                          if (gps != null) {
                            // ✅ Fix: Convert int to double
                            visit.gpsStatus = gps['status'];
                            visit.gpsLat = (gps['lat'] as num).toDouble();
                            visit.gpsLng = (gps['lng'] as num).toDouble();
                            visit.gpsAcc = (gps['acc'] as num).toDouble();

                            // Update status if GPS is verified
                            if (gps['status'] == 'Verified' && visit.status == 'Planned') {
                              visit.status = 'Completed';
                            }

                            // ✅ Update on server
                            final updated = await viewModel.updateVisit(visit);
                            if (updated) {
                              // Update local list
                              final idx = viewModel.visits.indexWhere((v) => v.id == visit.id);
                              if (idx != -1) {
                                viewModel.visits[idx] = visit;
                                await viewModel.persist();
                              }

                              Get.snackbar(
                                '✅ GPS Verified',
                                'Visit location verified successfully!',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: AppColors.greenDotDk,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            } else {
                              // Fallback: save locally
                              final idx = viewModel.visits.indexWhere((v) => v.id == visit.id);
                              if (idx != -1) {
                                viewModel.visits[idx] = visit;
                                await viewModel.persist();
                              }
                              Get.snackbar(
                                '⚠️ Warning',
                                'GPS captured locally but not synced to server.',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: AppColors.warning,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 3),
                              );
                            }
                          } else {
                            Get.snackbar(
                              '❌ GPS Failed',
                              'Could not capture location. Please try again.',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: AppColors.error,
                              colorText: Colors.white,
                              duration: const Duration(seconds: 3),
                            );
                          }
                        },
                        icon: const Icon(Icons.satellite_alt_rounded, size: 20, color: Colors.white),
                        label: const Text(
                          'Verify GPS',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealLight,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Schedule Follow-up Button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: onScheduleFollowup,
                        icon: const Icon(Icons.notifications_active_rounded, size: 16),
                        label: const Text('Follow-up'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.tealDark,
                          side: const BorderSide(color: AppColors.tealLight),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
        final isFull = ['Address', 'Budget', 'Outcome', 'Remarks'].contains(pair[0]);
        return SizedBox(
          width: isFull ? double.infinity : 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pair[0].toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
              const SizedBox(height: 3),
              Text(pair[1].isEmpty ? '—' : pair[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }
}