// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../AppColors.dart';
//
// // ── Model ─────────────────────────────────────────────────────────────────────
// class LeaveRecord {
//   final int id;
//   final String empId;
//   final String empName;
//   final String leaveType;
//   final String startDate;
//   final String endDate;
//   final double totalDays;
//   final String isHalfDay;
//   final String reason;
//   final String applicationDate;
//   final String status;
//
//   LeaveRecord({
//     required this.id,
//     required this.empId,
//     required this.empName,
//     required this.leaveType,
//     required this.startDate,
//     required this.endDate,
//     required this.totalDays,
//     required this.isHalfDay,
//     required this.reason,
//     required this.applicationDate,
//     required this.status,
//   });
//
//   factory LeaveRecord.fromJson(Map<String, dynamic> json) {
//     // Oracle ORDS returns lowercase keys — support both cases
//     dynamic v(String key) =>
//         json[key] ?? json[key.toLowerCase()] ?? json[key.toUpperCase()];
//
//     final rawId = v('ID') ?? v('id') ?? 0;
//     final rawDays = v('TOTAL_DAYS') ?? v('total_days') ?? '0';
//     final rawStatus = v('STATUS') ?? v('status') ?? 'Pending';
//
//     return LeaveRecord(
//       id: rawId is int
//           ? rawId
//           : int.tryParse(rawId.toString()) ?? 0,
//       empId: v('EMP_ID')?.toString() ?? '',
//       empName: v('EMP_NAME')?.toString() ?? '',
//       leaveType: v('LEAVE_TYPE')?.toString() ?? '',
//       startDate: v('START_DATE')?.toString() ?? '',
//       endDate: v('END_DATE')?.toString() ?? '',
//       totalDays: double.tryParse(rawDays.toString()) ?? 0,
//       isHalfDay: v('IS_HALF_DAY')?.toString() ?? 'N',
//       reason: v('REASON')?.toString() ?? '',
//       applicationDate: v('APPLICATION_DATE')?.toString() ?? '',
//       status: rawStatus.toString(),
//     );
//   }
// }
//
// // ── ViewModel ─────────────────────────────────────────────────────────────────
// class LeaveHistoryViewModel extends GetxController {
//   final RxList<LeaveRecord> leaves = <LeaveRecord>[].obs;
//   final RxBool isLoading = false.obs;
//   final RxString errorMessage = ''.obs;
//   final RxString filterStatus = 'All'.obs;
//
//   final List<String> statusFilters = [
//     'All',
//     'Pending',
//     'Approved',
//     'Rejected',
//   ];
//
//   String _norm(String s) => s.trim().toLowerCase();
//
//   List<LeaveRecord> get filteredLeaves {
//     if (filterStatus.value == 'All') return leaves;
//     return leaves
//         .where((l) => _norm(l.status) == _norm(filterStatus.value))
//         .toList();
//   }
//
//   // Summary counts
//   int get totalLeaves => leaves.length;
//   int get pendingCount =>
//       leaves.where((l) => _norm(l.status) == 'pending').length;
//   int get approvedCount =>
//       leaves.where((l) => _norm(l.status) == 'approved').length;
//   int get rejectedCount =>
//       leaves.where((l) => _norm(l.status) == 'rejected').length;
//
//   Future<void> fetchLeaves(String empId) async {
//     isLoading.value = true;
//     errorMessage.value = '';
//     try {
//       final uri = Uri.parse(
//           'http://oracle.metaxperts.net/ords/production/leaves/get?emp_id=$empId');
//       final response = await http
//           .get(uri, headers: {'Content-Type': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final items = data['items'] as List? ?? data as List? ?? [];
//         leaves.value =
//             items.map((e) => LeaveRecord.fromJson(e)).toList();
//         // Sort by application date descending
//         leaves.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
//       } else {
//         errorMessage.value =
//         'Server error: ${response.statusCode}';
//       }
//     } catch (e) {
//       errorMessage.value = 'Failed to load leave data.\nPlease check your connection.';
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }
//
// // ── Screen ────────────────────────────────────────────────────────────────────
// class LeaveHistoryScreen extends StatefulWidget {
//   const LeaveHistoryScreen({super.key});
//
//   @override
//   State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
// }
//
// class _LeaveHistoryScreenState extends State<LeaveHistoryScreen>
//     with SingleTickerProviderStateMixin {
//   final LeaveHistoryViewModel vm = Get.put(LeaveHistoryViewModel());
//   String _empId = '';
//   String _empName = '';
//
//   late final AnimationController _fadeCtrl;
//   late final Animation<double> _fadeAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 500));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//     _loadAndFetch();
//   }
//
//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadAndFetch() async {
//     final prefs = await SharedPreferences.getInstance();
//     _empId = prefs.getString('userId') ?? '';
//     _empName = prefs.getString('userName') ?? 'Employee';
//     setState(() {});
//     if (_empId.isNotEmpty) vm.fetchLeaves(_empId);
//   }
//
//   // ── Status helpers ──────────────────────────────────────────────────────────
//   Color _statusColor(String status) {
//     switch (status.trim().toLowerCase()) {
//       case 'approved':
//         return AppColors.greenTeal;
//       case 'rejected':
//         return AppColors.warning;
//       case 'pending':
//         return const Color(0xFFE8A020);
//       default:
//         return AppColors.textSecondary;
//     }
//   }
//
//   IconData _statusIcon(String status) {
//     switch (status.trim().toLowerCase()) {
//       case 'approved':
//         return Icons.check_circle_rounded;
//       case 'rejected':
//         return Icons.cancel_rounded;
//       case 'pending':
//         return Icons.hourglass_empty_rounded;
//       default:
//         return Icons.info_rounded;
//     }
//   }
//
//   Color _leaveTypeColor(String type) {
//     switch (type.trim().toLowerCase()) {
//       case 'annual':
//       case 'annual leave':
//         return AppColors.cyan;
//       case 'sick':
//       case 'sick leave':
//         return const Color(0xFFE8A020);
//       case 'casual':
//       case 'casual leave':
//         return AppColors.skyBlueDk;
//       case 'unpaid':
//       case 'unpaid leave':
//         return AppColors.warning;
//       default:
//         return AppColors.primary;
//     }
//   }
//
//   // ── Date formatter ──────────────────────────────────────────────────────────
//   String _formatDate(String raw) {
//     if (raw.isEmpty) return '—';
//     try {
//       // Oracle often returns ISO strings
//       final dt = DateTime.parse(raw);
//       const months = [
//         'Jan','Feb','Mar','Apr','May','Jun',
//         'Jul','Aug','Sep','Oct','Nov','Dec'
//       ];
//       return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
//     } catch (_) {
//       return raw.length > 10 ? raw.substring(0, 10) : raw;
//     }
//   }
//
//   // ── Build ───────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: CustomScrollView(
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             _buildSliverHeader(),
//             SliverToBoxAdapter(child: _buildSummaryCards()),
//             SliverToBoxAdapter(child: _buildFilterBar()),
//             _buildLeaveList(),
//             const SliverToBoxAdapter(child: SizedBox(height: 40)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Sliver Header ───────────────────────────────────────────────────────────
//   Widget _buildSliverHeader() {
//     return SliverAppBar(
//       expandedHeight: 160,
//       pinned: true,
//       elevation: 0,
//       backgroundColor: AppColors.primary,
//       leading: GestureDetector(
//         onTap: () => Get.back(),
//         child: Container(
//           margin: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: const Icon(Icons.arrow_back_rounded,
//               color: Colors.white, size: 20),
//         ),
//       ),
//       actions: [
//         Obx(() => GestureDetector(
//           onTap: vm.isLoading.value
//               ? null
//               : () => vm.fetchLeaves(_empId),
//           child: Container(
//             margin: const EdgeInsets.all(10),
//             width: 38,
//             height: 38,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: vm.isLoading.value
//                 ? const Padding(
//               padding: EdgeInsets.all(10),
//               child: CircularProgressIndicator(
//                   color: Colors.white, strokeWidth: 2),
//             )
//                 : const Icon(Icons.refresh_rounded,
//                 color: Colors.white, size: 20),
//           ),
//         )),
//       ],
//       flexibleSpace: FlexibleSpaceBar(
//         background: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 AppColors.primary,
//                 AppColors.cyan,
//                 AppColors.cyanBright,
//                 AppColors.greenTeal,
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.only(
//               bottomLeft: Radius.circular(28),
//               bottomRight: Radius.circular(28),
//             ),
//           ),
//           child: Stack(
//             children: [
//               Positioned(
//                   top: -40,
//                   right: -20,
//                   child: _decorCircle(160, AppColors.greenTeal, 0.10)),
//               Positioned(
//                   bottom: -30,
//                   left: -10,
//                   child: _decorCircle(110, Colors.white, 0.08)),
//               SafeArea(
//                 child: Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 52,
//                         height: 52,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.15),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                               color: Colors.white.withOpacity(0.25)),
//                         ),
//                         child: const Icon(
//                           Icons.event_note_rounded,
//                           color: Colors.white,
//                           size: 28,
//                         ),
//                       ),
//                       const SizedBox(width: 14),
//                       Expanded(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               'Leave History',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.w800,
//                                 letterSpacing: 0.3,
//                               ),
//                             ),
//                             const SizedBox(height: 3),
//                             Text(
//                               _empName.isNotEmpty
//                                   ? _empName
//                                   : 'Loading…',
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.75),
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
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
//
//   // ── Summary Cards ───────────────────────────────────────────────────────────
//   Widget _buildSummaryCards() {
//     return Obx(() {
//       if (vm.isLoading.value && vm.leaves.isEmpty) {
//         return const SizedBox.shrink();
//       }
//       return Padding(
//         padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
//         child: Row(
//           children: [
//             _summaryCard('Total', vm.totalLeaves, Icons.event_note_rounded,
//                 AppColors.cyan),
//             const SizedBox(width: 10),
//             _summaryCard('Approved', vm.approvedCount,
//                 Icons.check_circle_rounded, AppColors.greenTeal),
//             const SizedBox(width: 10),
//             _summaryCard('Pending', vm.pendingCount,
//                 Icons.hourglass_empty_rounded, const Color(0xFFE8A020)),
//             const SizedBox(width: 10),
//             _summaryCard('Rejected', vm.rejectedCount,
//                 Icons.cancel_rounded, AppColors.warning),
//           ],
//         ),
//       );
//     });
//   }
//
//   Widget _summaryCard(
//       String label, int count, IconData icon, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//         decoration: BoxDecoration(
//           color: AppColors.cardBg,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: color.withOpacity(0.20)),
//           boxShadow: [
//             BoxShadow(
//               color: color.withOpacity(0.08),
//               blurRadius: 8,
//               offset: const Offset(0, 3),
//             )
//           ],
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 34,
//               height: 34,
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, size: 18, color: color),
//             ),
//             const SizedBox(height: 7),
//             Text(
//               '$count',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w800,
//                 color: color,
//               ),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textSecondary,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Filter Bar ──────────────────────────────────────────────────────────────
//   Widget _buildFilterBar() {
//     return Obx(() {
//       if (vm.isLoading.value && vm.leaves.isEmpty) {
//         return const SizedBox.shrink();
//       }
//       return Padding(
//         padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(children: [
//               Container(
//                   width: 4,
//                   height: 18,
//                   decoration: BoxDecoration(
//                       gradient: AppColors.brandGradient,
//                       borderRadius: BorderRadius.circular(2))),
//               const SizedBox(width: 8),
//               const Text(
//                 'Leave Records',
//                 style: TextStyle(
//                   color: AppColors.primary,
//                   fontSize: 13,
//                   fontWeight: FontWeight.w700,
//                   letterSpacing: 0.3,
//                 ),
//               ),
//               const Spacer(),
//               Obx(() => Text(
//                 '${vm.filteredLeaves.length} records',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: AppColors.textSecondary,
//                   fontWeight: FontWeight.w500,
//                 ),
//               )),
//             ]),
//             const SizedBox(height: 12),
//             SizedBox(
//               height: 34,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: vm.statusFilters.length,
//                 separatorBuilder: (_, __) => const SizedBox(width: 8),
//                 itemBuilder: (_, i) {
//                   final f = vm.statusFilters[i];
//                   final active = vm.filterStatus.value == f;
//                   return GestureDetector(
//                     onTap: () => vm.filterStatus.value = f,
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 200),
//                       padding:
//                       const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//                       decoration: BoxDecoration(
//                         gradient:
//                         active ? AppColors.brandGradient : null,
//                         color: active ? null : AppColors.cardBg,
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: active
//                               ? Colors.transparent
//                               : AppColors.divider,
//                         ),
//                         boxShadow: active
//                             ? [
//                           BoxShadow(
//                             color: AppColors.cyan.withOpacity(0.30),
//                             blurRadius: 8,
//                             offset: const Offset(0, 3),
//                           )
//                         ]
//                             : [],
//                       ),
//                       child: Text(
//                         f,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: active
//                               ? Colors.white
//                               : AppColors.textSecondary,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       );
//     });
//   }
//
//   // ── Leave List ──────────────────────────────────────────────────────────────
//   Widget _buildLeaveList() {
//     return Obx(() {
//       if (vm.isLoading.value && vm.leaves.isEmpty) {
//         return SliverFillRemaining(
//           child: _buildLoadingState(),
//         );
//       }
//
//       if (vm.errorMessage.value.isNotEmpty) {
//         return SliverFillRemaining(
//           child: _buildErrorState(),
//         );
//       }
//
//       final items = vm.filteredLeaves;
//
//       if (items.isEmpty) {
//         return SliverFillRemaining(
//           child: _buildEmptyState(),
//         );
//       }
//
//       return SliverPadding(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//         sliver: SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) => _buildLeaveCard(items[index], index),
//             childCount: items.length,
//           ),
//         ),
//       );
//     });
//   }
//
//   // ── Leave Card ──────────────────────────────────────────────────────────────
//   Widget _buildLeaveCard(LeaveRecord leave, int index) {
//     final statusColor = _statusColor(leave.status);
//     final typeColor = _leaveTypeColor(leave.leaveType);
//     final isHalf = leave.isHalfDay == 'Y' || leave.isHalfDay == '1';
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(
//           color: statusColor.withOpacity(0.20),
//           width: 1.2,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: statusColor.withOpacity(0.07),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // ── Card Header ──────────────────────────────────────────────────
//           Container(
//             padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
//             decoration: BoxDecoration(
//               color: typeColor.withOpacity(0.04),
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(18),
//                 topRight: Radius.circular(18),
//               ),
//             ),
//             child: Row(
//               children: [
//                 // Leave Type Icon Badge
//                 Container(
//                   width: 44,
//                   height: 44,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         typeColor.withOpacity(0.9),
//                         typeColor.withOpacity(0.6),
//                       ],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: [
//                       BoxShadow(
//                         color: typeColor.withOpacity(0.30),
//                         blurRadius: 8,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   child: const Icon(
//                     Icons.calendar_today_rounded,
//                     color: Colors.white,
//                     size: 20,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Flexible(
//                             child: Text(
//                               leave.leaveType,
//                               style: const TextStyle(
//                                 fontSize: 15,
//                                 fontWeight: FontWeight.w700,
//                                 color: AppColors.textPrimary,
//                               ),
//                             ),
//                           ),
//                           if (isHalf) ...[
//                             const SizedBox(width: 6),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 7, vertical: 2),
//                               decoration: BoxDecoration(
//                                 color: AppColors.cyan.withOpacity(0.12),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                               child: const Text(
//                                 'Half Day',
//                                 style: TextStyle(
//                                   fontSize: 9,
//                                   fontWeight: FontWeight.w700,
//                                   color: AppColors.cyan,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                       const SizedBox(height: 3),
//                       Text(
//                         'Applied: ${_formatDate(leave.applicationDate)}',
//                         style: TextStyle(
//                           fontSize: 11,
//                           color: AppColors.textSecondary,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Status Badge
//                 Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                   decoration: BoxDecoration(
//                     color: statusColor.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(
//                         color: statusColor.withOpacity(0.30), width: 1),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(_statusIcon(leave.status),
//                           size: 12, color: statusColor),
//                       const SizedBox(width: 4),
//                       Text(
//                         leave.status,
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w700,
//                           color: statusColor,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // ── Divider ──────────────────────────────────────────────────────
//           Divider(
//               height: 1,
//               color: AppColors.divider.withOpacity(0.6),
//               indent: 16,
//               endIndent: 16),
//
//           // ── Date Range Row ────────────────────────────────────────────────
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Row(
//               children: [
//                 _dateChip(
//                     label: 'From',
//                     value: _formatDate(leave.startDate),
//                     icon: Icons.arrow_circle_right_outlined,
//                     color: AppColors.cyan),
//                 Expanded(
//                   child: Column(
//                     children: [
//                       DashedDivider(color: AppColors.divider),
//                       const SizedBox(height: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 3),
//                         decoration: BoxDecoration(
//                           gradient: AppColors.brandGradient,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Text(
//                           '${leave.totalDays % 1 == 0 ? leave.totalDays.toInt() : leave.totalDays} day${leave.totalDays == 1 ? '' : 's'}',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 _dateChip(
//                     label: 'To',
//                     value: _formatDate(leave.endDate),
//                     icon: Icons.arrow_circle_left_outlined,
//                     color: AppColors.greenTeal,
//                     alignRight: true),
//               ],
//             ),
//           ),
//
//           // ── Reason Row ───────────────────────────────────────────────────
//           if (leave.reason.isNotEmpty)
//             Container(
//               margin:
//               const EdgeInsets.fromLTRB(16, 0, 16, 14),
//               padding:
//               const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//               decoration: BoxDecoration(
//                 color: AppColors.surface,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: AppColors.divider.withOpacity(0.7)),
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Icon(Icons.format_quote_rounded,
//                       size: 16,
//                       color: AppColors.textSecondary.withOpacity(0.5)),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       leave.reason,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: AppColors.textSecondary,
//                         fontWeight: FontWeight.w500,
//                         height: 1.4,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             const SizedBox(height: 14),
//         ],
//       ),
//     );
//   }
//
//   Widget _dateChip({
//     required String label,
//     required String value,
//     required IconData icon,
//     required Color color,
//     bool alignRight = false,
//   }) {
//     return Column(
//       crossAxisAlignment:
//       alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 10,
//             color: AppColors.textSecondary,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ── States ──────────────────────────────────────────────────────────────────
//   Widget _buildLoadingState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: 64,
//             height: 64,
//             decoration: BoxDecoration(
//               gradient: AppColors.brandGradient,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: const Padding(
//               padding: EdgeInsets.all(16),
//               child: CircularProgressIndicator(
//                   color: Colors.white, strokeWidth: 2.5),
//             ),
//           ),
//           const SizedBox(height: 18),
//           const Text(
//             'Loading leave records…',
//             style: TextStyle(
//               color: AppColors.textSecondary,
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildErrorState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               width: 72,
//               height: 72,
//               decoration: BoxDecoration(
//                 color: AppColors.warning.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Icon(Icons.wifi_off_rounded,
//                   size: 36, color: AppColors.warning),
//             ),
//             const SizedBox(height: 18),
//             Text(
//               vm.errorMessage.value,
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 color: AppColors.textSecondary,
//                 fontSize: 14,
//                 height: 1.5,
//               ),
//             ),
//             const SizedBox(height: 20),
//             GestureDetector(
//               onTap: () => vm.fetchLeaves(_empId),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 24, vertical: 12),
//                 decoration: BoxDecoration(
//                   gradient: AppColors.brandGradient,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.refresh_rounded,
//                         color: Colors.white, size: 18),
//                     SizedBox(width: 8),
//                     Text(
//                       'Try Again',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w700,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: 80,
//             height: 80,
//             decoration: BoxDecoration(
//               color: AppColors.cyan.withOpacity(0.08),
//               borderRadius: BorderRadius.circular(24),
//             ),
//             child: Icon(
//               Icons.event_busy_rounded,
//               size: 40,
//               color: AppColors.cyan.withOpacity(0.50),
//             ),
//           ),
//           const SizedBox(height: 18),
//           const Text(
//             'No Leave Records Found',
//             style: TextStyle(
//               color: AppColors.textPrimary,
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             vm.filterStatus.value == 'All'
//                 ? 'You have not applied for any leave yet.'
//                 : 'No ${vm.filterStatus.value.toLowerCase()} leave applications.',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: AppColors.textSecondary,
//               fontSize: 13,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _decorCircle(double size, Color color, double opacity) => Container(
//     width: size,
//     height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: color.withOpacity(opacity),
//     ),
//   );
// }
//
// // ── Leave Activity Strip (used on HomeScreen) ─────────────────────────────────
// class LeaveActivityStrip extends StatefulWidget {
//   const LeaveActivityStrip({super.key});
//
//   @override
//   State<LeaveActivityStrip> createState() => _LeaveActivityStripState();
// }
//
// class _LeaveActivityStripState extends State<LeaveActivityStrip> {
//   late final LeaveHistoryViewModel _vm;
//   String _empId = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _vm = Get.put(LeaveHistoryViewModel());
//     _loadAndFetch();
//   }
//
//   Future<void> _loadAndFetch() async {
//     final prefs = await SharedPreferences.getInstance();
//     _empId = prefs.getString('userId') ?? '';
//     if (_empId.isNotEmpty) _vm.fetchLeaves(_empId);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 5),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Section Header ──────────────────────────────────────────────
//           Row(children: [
//             Container(
//               width: 4,
//               height: 20,
//               decoration: BoxDecoration(
//                 gradient: AppColors.brandGradient,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               width: 28,
//               height: 28,
//               decoration: BoxDecoration(
//                 color: AppColors.cyan.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(Icons.event_note_rounded,
//                   size: 15, color: AppColors.cyan),
//             ),
//             const SizedBox(width: 8),
//             const Text(
//               'Leave Overview',
//               style: TextStyle(
//                 color: AppColors.primary,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w700,
//                 letterSpacing: 0.3,
//               ),
//             ),
//           ]),
//           const SizedBox(height: 12),
//
//           // ── Card ─────────────────────────────────────────────────────────
//           Obx(() {
//             final isLoading = _vm.isLoading.value;
//             final hasError = _vm.errorMessage.value.isNotEmpty;
//
//             return Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: AppColors.cardBg,
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: AppColors.divider),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.04),
//                     blurRadius: 10,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: isLoading && _vm.leaves.isEmpty
//                   ? const SizedBox(
//                 height: 80,
//                 child: Center(
//                   child: CircularProgressIndicator(
//                       color: AppColors.cyan, strokeWidth: 2.5),
//                 ),
//               )
//                   : hasError
//                   ? SizedBox(
//                 height: 80,
//                 child: Center(
//                   child: GestureDetector(
//                     onTap: () => _vm.fetchLeaves(_empId),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.refresh_rounded,
//                             size: 16, color: AppColors.cyan),
//                         const SizedBox(width: 6),
//                         Text(
//                           'Tap to retry',
//                           style: TextStyle(
//                             fontSize: 13,
//                             color: AppColors.cyan,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               )
//                   : _buildContent(),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildContent() {
//     final total    = _vm.totalLeaves;
//     final pending  = _vm.pendingCount;
//     final approved = _vm.approvedCount;
//     final rejected = _vm.rejectedCount;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // ── Stats Row ───────────────────────────────────────────────────
//         Row(
//           children: [
//             _statBox('Total',    total,    Icons.event_note_rounded,      AppColors.cyan),
//             const SizedBox(width: 8),
//             _statBox('Approved', approved, Icons.check_circle_rounded,    AppColors.greenTeal),
//             const SizedBox(width: 8),
//             _statBox('Pending',  pending,  Icons.hourglass_empty_rounded, const Color(0xFFE8A020)),
//             const SizedBox(width: 8),
//             _statBox('Rejected', rejected, Icons.cancel_rounded,          AppColors.warning),
//           ],
//         ),
//
//         const SizedBox(height: 14),
//
//         // ── View Details Button (full width, centered) ──────────────────
//         GestureDetector(
//           onTap: () => Get.to(
//                 () => const LeaveHistoryScreen(),
//             transition: Transition.rightToLeft,
//             duration: const Duration(milliseconds: 300),
//           ),
//           child: Container(
//             width: double.infinity,
//             padding: const EdgeInsets.symmetric(vertical: 12),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   AppColors.cyan.withOpacity(0.15),
//                   AppColors.cyan.withOpacity(0.05),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.arrow_forward_rounded,
//                     size: 18, color: AppColors.cyan),
//                 const SizedBox(width: 6),
//                 Text(
//                   'View Details',
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.cyan,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _statBox(String label, int count, IconData icon, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.05),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: color.withOpacity(0.15)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Icon(icon, size: 13, color: color),
//                 Text(
//                   '$count',
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w800,
//                     color: color,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 5),
//             // FIX: maxLines + ellipsis so label stays on one line
//             Text(
//               label,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w500,
//                 color: AppColors.textSecondary,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ── Dashed Divider helper ─────────────────────────────────────────────────────
// class DashedDivider extends StatelessWidget {
//   final Color color;
//   const DashedDivider({super.key, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(builder: (_, constraints) {
//       final width = constraints.maxWidth;
//       const dash = 4.0;
//       const space = 3.0;
//       final count = (width / (dash + space)).floor();
//       return Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: List.generate(
//           count,
//               (_) => Container(
//             width: dash,
//             height: 1,
//             margin: const EdgeInsets.only(right: space),
//             color: color,
//           ),
//         ),
//       );
//     });
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../AppColors.dart';

// ── Model ─────────────────────────────────────────────────────────────────────
class LeaveRecord {
  final int id;
  final String empId;
  final String empName;
  final String leaveType;
  final String startDate;
  final String endDate;
  final double totalDays;
  final String isHalfDay;
  final String reason;
  final String applicationDate;
  final String status;
  final String companyCode;

  LeaveRecord({
    required this.id,
    required this.empId,
    required this.empName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.isHalfDay,
    required this.reason,
    required this.applicationDate,
    required this.status,
    required this.companyCode,
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    // Oracle ORDS returns lowercase keys — support both cases
    dynamic v(String key) =>
        json[key] ?? json[key.toLowerCase()] ?? json[key.toUpperCase()];

    final rawId = v('ID') ?? v('id') ?? 0;
    final rawDays = v('TOTAL_DAYS') ?? v('total_days') ?? '0';
    final rawStatus = v('STATUS') ?? v('status') ?? 'Pending';

    return LeaveRecord(
      id: rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0,
      empId: v('EMP_ID')?.toString() ?? '',
      empName: v('EMP_NAME')?.toString() ?? '',
      leaveType: v('LEAVE_TYPE')?.toString() ?? '',
      startDate: v('START_DATE')?.toString() ?? '',
      endDate: v('END_DATE')?.toString() ?? '',
      totalDays: double.tryParse(rawDays.toString()) ?? 0,
      isHalfDay: v('IS_HALF_DAY')?.toString() ?? 'N',
      reason: v('REASON')?.toString() ?? '',
      applicationDate: v('APPLICATION_DATE')?.toString() ?? '',
      status: rawStatus.toString(),
      companyCode: v('COMPANY_CODE')?.toString() ?? '',
    );
  }
}

// ── ViewModel ─────────────────────────────────────────────────────────────────
class LeaveHistoryViewModel extends GetxController {
  final RxList<LeaveRecord> leaves = <LeaveRecord>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString filterStatus = 'All'.obs;

  final List<String> statusFilters = ['All', 'Pending', 'Approved', 'Rejected'];

  String _norm(String s) => s.trim().toLowerCase();

  List<LeaveRecord> get filteredLeaves {
    if (filterStatus.value == 'All') return leaves;
    return leaves
        .where((l) => _norm(l.status) == _norm(filterStatus.value))
        .toList();
  }

  // Summary counts
  int get totalLeaves => leaves.length;
  int get pendingCount =>
      leaves.where((l) => _norm(l.status) == 'pending').length;
  int get approvedCount =>
      leaves.where((l) => _norm(l.status) == 'approved').length;
  int get rejectedCount =>
      leaves.where((l) => _norm(l.status) == 'rejected').length;

  Future<void> fetchLeaves(String empId, String companyCode) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final uri = Uri.parse(
          'http://oracle.metaxperts.net/ords/gps_workforce/leaves/get'
              '?emp_id=$empId&company_code=$companyCode');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? data as List? ?? [];
        leaves.value = items.map((e) => LeaveRecord.fromJson(e)).toList();
        // Sort by application date descending
        leaves.sort((a, b) => b.applicationDate.compareTo(a.applicationDate));
      } else {
        errorMessage.value = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage.value =
      'Failed to load leave data.\nPlease check your connection.';
    } finally {
      isLoading.value = false;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen>
    with SingleTickerProviderStateMixin {
  final LeaveHistoryViewModel vm = Get.put(LeaveHistoryViewModel());
  String _empId = '';
  String _empName = '';
  String _companyCode = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadAndFetch();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _empId = prefs.getString('userId') ?? '';
    _empName = prefs.getString('userName') ?? 'Employee';
    _companyCode = prefs.getString('companyCode') ?? '';
    setState(() {});
    if (_empId.isNotEmpty) vm.fetchLeaves(_empId, _companyCode);
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return AppColors.greenTeal;
      case 'rejected':
        return AppColors.warning;
      case 'pending':
        return const Color(0xFFE8A020);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _leaveTypeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'annual':
      case 'annual leave':
        return AppColors.cyan;
      case 'sick':
      case 'sick leave':
        return const Color(0xFFE8A020);
      case 'casual':
      case 'casual leave':
        return AppColors.skyBlueDk;
      case 'unpaid':
      case 'unpaid leave':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  // ── Date formatter ──────────────────────────────────────────────────────────
  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.length > 10 ? raw.substring(0, 10) : raw;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(),
            SliverToBoxAdapter(child: _buildSummaryCards()),
            SliverToBoxAdapter(child: _buildFilterBar()),
            _buildLeaveList(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Sliver Header ───────────────────────────────────────────────────────────
  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      leading: GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 20),
        ),
      ),
      actions: [
        Obx(() => GestureDetector(
          onTap: vm.isLoading.value
              ? null
              : () => vm.fetchLeaves(_empId, _companyCode),
          child: Container(
            margin: const EdgeInsets.all(10),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: vm.isLoading.value
                ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 20),
          ),
        )),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.cyan,
                AppColors.cyanBright,
                AppColors.greenTeal,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                  top: -40,
                  right: -20,
                  child: _decorCircle(160, AppColors.greenTeal, 0.10)),
              Positioned(
                  bottom: -30,
                  left: -10,
                  child: _decorCircle(110, Colors.white, 0.08)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.event_note_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leave History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _empName.isNotEmpty ? _empName : 'Loading…',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

  // ── Summary Cards ───────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Obx(() {
      if (vm.isLoading.value && vm.leaves.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(
          children: [
            _summaryCard(
                'Total', vm.totalLeaves, Icons.event_note_rounded, AppColors.cyan),
            const SizedBox(width: 10),
            _summaryCard('Approved', vm.approvedCount,
                Icons.check_circle_rounded, AppColors.greenTeal),
            const SizedBox(width: 10),
            _summaryCard('Pending', vm.pendingCount,
                Icons.hourglass_empty_rounded, const Color(0xFFE8A020)),
            const SizedBox(width: 10),
            _summaryCard('Rejected', vm.rejectedCount,
                Icons.cancel_rounded, AppColors.warning),
          ],
        ),
      );
    });
  }

  Widget _summaryCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 7),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Bar ──────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Obx(() {
      if (vm.isLoading.value && vm.leaves.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text(
                'Leave Records',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Obx(() => Text(
                '${vm.filteredLeaves.length} records',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              )),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vm.statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = vm.statusFilters[i];
                  final active = vm.filterStatus.value == f;
                  return GestureDetector(
                    onTap: () => vm.filterStatus.value = f,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: active ? AppColors.brandGradient : null,
                        color: active ? null : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                          active ? Colors.transparent : AppColors.divider,
                        ),
                        boxShadow: active
                            ? [
                          BoxShadow(
                            color: AppColors.cyan.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                            : [],
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                          active ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Leave List ──────────────────────────────────────────────────────────────
  Widget _buildLeaveList() {
    return Obx(() {
      if (vm.isLoading.value && vm.leaves.isEmpty) {
        return SliverFillRemaining(child: _buildLoadingState());
      }
      if (vm.errorMessage.value.isNotEmpty) {
        return SliverFillRemaining(child: _buildErrorState());
      }
      final items = vm.filteredLeaves;
      if (items.isEmpty) {
        return SliverFillRemaining(child: _buildEmptyState());
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLeaveCard(items[index], index),
            childCount: items.length,
          ),
        ),
      );
    });
  }

  // ── Leave Card ──────────────────────────────────────────────────────────────
  Widget _buildLeaveCard(LeaveRecord leave, int index) {
    final statusColor = _statusColor(leave.status);
    final typeColor = _leaveTypeColor(leave.leaveType);
    final isHalf = leave.isHalfDay == 'Y' || leave.isHalfDay == '1';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.20), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        typeColor.withOpacity(0.9),
                        typeColor.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              leave.leaveType,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isHalf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Half Day',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cyan),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Applied: ${_formatDate(leave.applicationDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withOpacity(0.30), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(leave.status),
                          size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        leave.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: AppColors.divider.withOpacity(0.6),
              indent: 16,
              endIndent: 16),

          // ── Date Range Row ─────────────────────────────────────────────
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _dateChip(
                    label: 'From',
                    value: _formatDate(leave.startDate),
                    icon: Icons.arrow_circle_right_outlined,
                    color: AppColors.cyan),
                Expanded(
                  child: Column(
                    children: [
                      DashedDivider(color: AppColors.divider),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${leave.totalDays % 1 == 0 ? leave.totalDays.toInt() : leave.totalDays}'
                              ' day${leave.totalDays == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _dateChip(
                    label: 'To',
                    value: _formatDate(leave.endDate),
                    icon: Icons.arrow_circle_left_outlined,
                    color: AppColors.greenTeal,
                    alignRight: true),
              ],
            ),
          ),

          // ── Reason Row ─────────────────────────────────────────────────
          if (leave.reason.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: AppColors.divider.withOpacity(0.7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: 16,
                      color: AppColors.textSecondary.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      leave.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment:
      alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  // ── States ──────────────────────────────────────────────────────────────────
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
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Loading leave records…',
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
              onTap: () => vm.fetchLeaves(_empId, _companyCode),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.event_busy_rounded,
                size: 40, color: AppColors.cyan.withOpacity(0.50)),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Leave Records Found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vm.filterStatus.value == 'All'
                ? 'You have not applied for any leave yet.'
                : 'No ${vm.filterStatus.value.toLowerCase()} leave applications.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ── Leave Activity Strip (used on HomeScreen) ─────────────────────────────────
class LeaveActivityStrip extends StatefulWidget {
  const LeaveActivityStrip({super.key});

  @override
  State<LeaveActivityStrip> createState() => _LeaveActivityStripState();
}

class _LeaveActivityStripState extends State<LeaveActivityStrip> {
  late final LeaveHistoryViewModel _vm;
  String _empId = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    _vm = Get.put(LeaveHistoryViewModel());
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _empId = prefs.getString('userId') ?? '';
    _companyCode = prefs.getString('companyCode') ?? '';
    if (_empId.isNotEmpty) _vm.fetchLeaves(_empId, _companyCode);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ────────────────────────────────────────────
          Row(children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_note_rounded,
                  size: 15, color: AppColors.cyan),
            ),
            const SizedBox(width: 8),
            const Text(
              'Leave Overview',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Card ───────────────────────────────────────────────────────
          Obx(() {
            final isLoading = _vm.isLoading.value;
            final hasError = _vm.errorMessage.value.isNotEmpty;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: isLoading && _vm.leaves.isEmpty
                  ? const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.cyan, strokeWidth: 2.5),
                ),
              )
                  : hasError
                  ? SizedBox(
                height: 80,
                child: Center(
                  child: GestureDetector(
                    onTap: () =>
                        _vm.fetchLeaves(_empId, _companyCode),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 16, color: AppColors.cyan),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to retry',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  : _buildContent(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final total = _vm.totalLeaves;
    final pending = _vm.pendingCount;
    final approved = _vm.approvedCount;
    final rejected = _vm.rejectedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statBox('Total', total, Icons.event_note_rounded, AppColors.cyan),
            const SizedBox(width: 8),
            _statBox('Approved', approved, Icons.check_circle_rounded,
                AppColors.greenTeal),
            const SizedBox(width: 8),
            _statBox('Pending', pending, Icons.hourglass_empty_rounded,
                const Color(0xFFE8A020)),
            const SizedBox(width: 8),
            _statBox(
                'Rejected', rejected, Icons.cancel_rounded, AppColors.warning),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Get.to(
                () => const LeaveHistoryScreen(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 300),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.cyan.withOpacity(0.15),
                  AppColors.cyan.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppColors.cyan),
                const SizedBox(width: 6),
                Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 13, color: color),
                Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed Divider helper ─────────────────────────────────────────────────────
class DashedDivider extends StatelessWidget {
  final Color color;
  const DashedDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final width = constraints.maxWidth;
      const dash = 4.0;
      const space = 3.0;
      final count = (width / (dash + space)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
              (_) => Container(
            width: dash,
            height: 1,
            margin: const EdgeInsets.only(right: space),
            color: color,
          ),
        ),
      );
    });
  }
}