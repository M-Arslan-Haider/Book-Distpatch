
import 'package:book_dispatch/Screens/Visit%20List/visit_constants.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../AppColors.dart';
import '../HomeScreenComponents/app_bottom_navbar.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';
import 'followup_form_screen.dart';
import 'followup_model.dart';
import 'followup_view_model.dart';

class FollowupsListScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int>? onNavTap;
  final VisitModel? presetVisit;

  const FollowupsListScreen({
    super.key,
    this.currentIndex = 8,
    this.chatBadgeCount = 0,
    this.onNavTap,
    this.presetVisit,
  });

  @override
  State<FollowupsListScreen> createState() => _FollowupsListScreenState();
}

class _FollowupsListScreenState extends State<FollowupsListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FollowupViewModel vm =
  Get.isRegistered<FollowupViewModel>() ? Get.find<FollowupViewModel>() : Get.put(FollowupViewModel());
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // ✅ Auto-refresh when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.empId.value.isNotEmpty && vm.companyCode.value.isNotEmpty) {
        vm.fetchFollowupsFromServer();
      }
    });

    if (widget.presetVisit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openForm(context, presetVisit: widget.presetVisit));
    }
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
              await vm.fetchFollowupsFromServer();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearch()),
                SliverToBoxAdapter(child: _buildSubTabs()),
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
                              (context, i) => _FollowupCard(
                            followup: rows[i],
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
                const Text('Follow-ups',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Obx(() {
                  final due = vm.dueTodayCount;
                  return Text(
                    '${vm.followups.length} scheduled${due > 0 ? ' · $due due' : ''}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  );
                }),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.iconBgTeal, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_rounded, size: 16, color: AppColors.tealDark),
                  SizedBox(width: 6),
                  Text('Visits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.tealDark)),
                ],
              ),
            ),
          ),
        ],
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
          hintText: 'Search customer, mobile or FU no…',
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

  Widget _buildSubTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 34,
        child: Obx(() {
          final activeTab = vm.subTab.value;
          // ignore: unused_local_variable
          final followupsLen = vm.followups.length;
          final counts = {
            for (final label in FollowupConstants.subTabs)
              label: vm.countByTab(label),
          };
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: FollowupConstants.subTabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final label = FollowupConstants.subTabs[i];
              final active = activeTab == label;
              final count = counts[label] ?? 0;
              return GestureDetector(
                onTap: () => vm.setSubTab(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.tealDark : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AppColors.tealDark : AppColors.divider),
                  ),
                  child: Text('$label ($count)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
                ),
              );
            },
          );
        }),
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
            'Loading follow-ups…',
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
              onTap: () => vm.fetchFollowupsFromServer(),
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
            Icon(Icons.notifications_off_rounded, size: 52, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text('No follow-ups here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Try a different tab or search, or tap + to schedule one.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {FollowupModel? editing, VisitModel? presetVisit}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FollowupFormScreen(editing: editing, presetVisit: presetVisit)),
    );
  }

  void _openDetails(BuildContext context, FollowupModel f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FollowupDetailSheet(
        followup: f,
        vm: vm,
        onRefresh: () {
          vm.fetchFollowupsFromServer();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Follow-up card
// ═══════════════════════════════════════════════════════════════════════
class _FollowupCard extends StatelessWidget {
  final FollowupModel followup;
  final VoidCallback onTap;
  const _FollowupCard({required this.followup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final overdue = followup.isOverdue;
    final displayStatus = overdue && followup.status == 'Pending' ? 'Missed' : followup.status;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(11)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(followup.customer.isEmpty ? 'Unnamed customer' : followup.customer,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${followup.fuNo} · ${_fmtDT(followup.date, followup.time)}',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withOpacity(0.85), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                _fuStatusBadge(displayStatus),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _metaItem(Icons.chat_bubble_outline_rounded, followup.method),
              _metaItem(Icons.person_rounded, followup.empName.isEmpty ? '—' : followup.empName),
              _priorityDot(followup.priority),
            ]),
            const SizedBox(height: 6),
            Text(followup.purpose, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12.5, color: AppColors.textSecondary.withOpacity(0.7)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _priorityDot(String priority) {
    final color = {'High': AppColors.error, 'Medium': AppColors.warning, 'Low': AppColors.textSecondary}[priority] ?? AppColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(priority, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    ]);
  }
}

Widget _fuStatusBadge(String status) {
  final map = {
    'Pending': [AppColors.info, AppColors.tealSurface],
    'Completed': [AppColors.greenDotDk, AppColors.greenDotLt],
    'Rescheduled': [const Color(0xFF7C3AED), const Color(0xFFF5F3FF)],
    'Missed': [AppColors.error, const Color(0xFFFDECEC)],
    'Cancelled': [AppColors.textSecondary, AppColors.surface],
  };
  final colors = map[status] ?? [AppColors.textSecondary, AppColors.surface];
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: colors[1] as Color, borderRadius: BorderRadius.circular(20)),
    child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: colors[0] as Color)),
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
// Detail sheet - Only Complete/Cancel buttons (NO EDIT)
// ═══════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════
// Detail sheet - Only Complete/Cancel buttons (NO EDIT)
// ═══════════════════════════════════════════════════════════════════════
class _FollowupDetailSheet extends StatefulWidget {
  final FollowupModel followup;
  final FollowupViewModel vm;
  final VoidCallback onRefresh;

  const _FollowupDetailSheet({
    required this.followup,
    required this.vm,
    required this.onRefresh,
  });

  @override
  State<_FollowupDetailSheet> createState() => _FollowupDetailSheetState();
}

class _FollowupDetailSheetState extends State<_FollowupDetailSheet> {
  bool _isProcessing = false;

  // ── Result options for completion ──────────────────────────────────
  final List<String> _resultOptions = [
    'Successful',
    'Customer Interested',
    'Customer Needs Time',
    'No Answer',
    'Call Back Requested',
    'Meeting Scheduled',
    'Site Visit Scheduled',
    'Not Interested',
    'Wrong Number',
  ];

  // ✅ Rating options
  final List<String> _ratingOptions = [
    'Excellent',
    'Good',
    'Average',
    'Poor',
  ];

  String? _selectedResult;
  String? _selectedRating;
  final TextEditingController _responseController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = widget.followup.isOverdue;
    final displayStatus = overdue && widget.followup.status == 'Pending' ? 'Missed' : widget.followup.status;

    // ✅ Hide buttons if already Completed or Cancelled
    final isCompleted = widget.followup.status == 'Completed';
    final isCancelled = widget.followup.status == 'Cancelled';
    final showActions = !isCompleted && !isCancelled;

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

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.followup.customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
                          Text('${widget.followup.fuNo} · ${_fmtDT(widget.followup.date, widget.followup.time)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    _fuStatusBadge(displayStatus),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Wrap(spacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                        child: Text('${widget.followup.priority} priority', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                      ),
                      if (widget.followup.method.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                          child: Text(widget.followup.method, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                        ),
                    ]),

                    if (widget.followup.visitNo != null && widget.followup.visitNo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.tealSurface, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.link_rounded, size: 16, color: AppColors.tealDark),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Linked to visit ${widget.followup.visitNo}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.tealDark))),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Details Grid ──────────────────────────────────────
                    _detailGrid([
                      ['Mobile', widget.followup.mobile],
                      ['Employee', widget.followup.empName],
                      ['Purpose', widget.followup.purpose],
                      ['Notes', widget.followup.notes],
                      if (widget.followup.status == 'Completed' && widget.followup.result != null)
                        ['Result', widget.followup.result!],
                      if (widget.followup.status == 'Completed' && widget.followup.resultResponse != null)
                        ['Response', widget.followup.resultResponse!],
                      if (widget.followup.resultRemarks != null && widget.followup.resultRemarks!.isNotEmpty)
                        ['Remarks', widget.followup.resultRemarks!],
                      if (widget.followup.rating != null && widget.followup.rating!.isNotEmpty)
                        ['Rating', widget.followup.rating!],
                    ]),

                    const SizedBox(height: 16),

                    // ── If Completed or Cancelled - Show message ──────────
                    if (isCompleted || isCancelled) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.greenDotLt : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted ? AppColors.greenDotDk : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: isCompleted ? AppColors.greenDotDk : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isCompleted
                                    ? 'This follow-up has been completed.'
                                    : 'This follow-up has been cancelled.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted ? AppColors.greenDotDk : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Action Buttons ──────────────────────────────────────────
              if (showActions) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      // ✅ Cancel Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _showCancelDialog,
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ✅ Complete Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _showCompleteDialog,
                          icon: _isProcessing
                              ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.flag_rounded, size: 18, color: Colors.white),
                          label: Text(_isProcessing ? 'Processing...' : 'Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.greenDotDk,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        final isFull = ['Purpose', 'Notes', 'Remarks'].contains(pair[0]);
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

  // ── Show Complete Dialog with Rating ──────────────────────────────────
  void _showCompleteDialog() {
    _selectedResult = null;
    _selectedRating = null;
    _responseController.clear();
    _remarksController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.flag_rounded, color: AppColors.greenDotDk),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Complete Follow-up',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 12),

              // ── Result Dropdown ─────────────────────────────────────────
              const Text('RESULT *',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedResult,
                    isExpanded: true,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Select result'),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: _resultOptions.map((r) =>
                        DropdownMenuItem(value: r, child: Text(r))
                    ).toList(),
                    onChanged: (v) => setState(() => _selectedResult = v),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Rating Dropdown (NEW) ──────────────────────────────────
              const Text('RATING',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRating,
                    isExpanded: true,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Select rating (optional)'),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: _ratingOptions.map((r) =>
                        DropdownMenuItem(value: r, child: Text(r))
                    ).toList(),
                    onChanged: (v) => setState(() => _selectedRating = v),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Customer Response ──────────────────────────────────────
              const Text('CUSTOMER RESPONSE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              TextField(
                controller: _responseController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'What did the customer say?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 12),

              // ── Remarks ─────────────────────────────────────────────────
              const Text('REMARKS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Additional notes...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 18),

              // ── Confirm Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedResult == null ? null : _confirmComplete,
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Confirm Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenDotDk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmComplete() async {
    if (_selectedResult == null) return;

    setState(() => _isProcessing = true);
    Navigator.pop(context); // Close dialog

    await widget.vm.completeFollowup(
      widget.followup.id,
      result: _selectedResult,
      response: _responseController.text.trim(),
      remarks: _remarksController.text.trim(),
      rating: _selectedRating,  // ✅ NEW - Pass rating to ViewModel
    );

    setState(() => _isProcessing = false);
    widget.onRefresh();
    Navigator.pop(context); // Close detail sheet
  }

  // ── Show Cancel Dialog ──────────────────────────────────────────────
  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.cancel_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Cancel Follow-up',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 12),

              const Text('REASON FOR CANCELLATION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Why is this follow-up being cancelled?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmCancel(reasonController.text.trim()),
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Confirm Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancel(String reason) async {
    setState(() => _isProcessing = true);
    Navigator.pop(context); // Close dialog

    await widget.vm.cancelFollowup(
      widget.followup.id,
      remarks: reason.isEmpty ? 'Cancelled by user' : reason,
    );

    setState(() => _isProcessing = false);
    widget.onRefresh();
    Navigator.pop(context); // Close detail sheet
  }
}
