// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../AppColors.dart';
// // import 'HomeScreenComponents/app_bottom_navbar.dart';
// // import 'WidgetDesignes/request_summary_widget.dart';
// // import 'expense_claim_screen.dart';
// // import 'expense_history_screen.dart';
// // import 'leave_screen.dart';
// // import 'loan_advance_screen.dart';
// // import 'loan_history_screen.dart';
// // import 'leave_report_get_screen.dart';
// // import 'complaint_screen.dart';
// // import 'suggestion_screen.dart';
// //
// //
// // // ═══════════════════════════════════════════════════════════════════════════
// // // actions_screen.dart
// // //
// // // Actions Screen — Request / Expense / Others tabs
// // // + RequestSummaryWidget: Leave aur Loan ke combined counts
// // // ═══════════════════════════════════════════════════════════════════════════
// //
// // class ActionsScreen extends StatefulWidget {
// //   final int currentIndex;
// //   final int chatBadgeCount;
// //   final ValueChanged<int>? onNavTap;
// //
// //   const ActionsScreen({
// //     super.key,
// //     this.currentIndex = 1,
// //     this.chatBadgeCount = 0,
// //     this.onNavTap,
// //   });
// //
// //   @override
// //   State<ActionsScreen> createState() => _ActionsScreenState();
// // }
// //
// // class _ActionsScreenState extends State<ActionsScreen> {
// //   // 0 = Request, 1 = Expense, 2 = Others
// //   int _selectedTab = 0;
// //
// //   // ── NEW: Summary widget state ──────────────────────────────────────────
// //   final LeaveHistoryViewModel _leaveVm = Get.put(LeaveHistoryViewModel());
// //   List<LoanRecord> _loanRecords = [];
// //   bool _loanLoading = false;
// //   String _empId       = '';
// //   String _empName     = 'Employee';
// //   String _companyCode = '';
// //
// //   // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
// //   static const _bgColor      = AppColors.surface;
// //   static const _primary      = AppColors.cyan;
// //   static const _cardBg       = AppColors.cardBg;
// //   static const _borderColor  = AppColors.divider;
// //   static const _textDark     = AppColors.textPrimary;
// //   static const _textGray     = AppColors.textSecondary;
// //   static const _pillBg       = AppColors.cyanLight;
// //   static const _pendingBg    = Color(0xFFFFF3E0);
// //   static const _pendingText  = AppColors.warning;
// //   static const _historyBg    = AppColors.surface;
// //
// //   // ── Request tab cards ──────────────────────────────────────────────────
// //   static const _requestCards = [
// //     _ActionCard(
// //       iconBg: AppColors.cyan,
// //       icon: Icons.beach_access_rounded,
// //       title: 'Leaves',
// //       subtitle: 'Apply for full-day leave.',
// //       pendingCount: 1,
// //     ),
// //     _ActionCard(
// //       iconBg: AppColors.greenTeal,
// //       icon: Icons.access_time_rounded,
// //       title: 'Half Day',
// //       subtitle: 'Apply for leave for part of the day.',
// //       pendingCount: 0,
// //     ),
// //     _ActionCard(
// //       iconBg: AppColors.warning,
// //       icon: Icons.attach_money_rounded,
// //       title: 'Loan / Advance',
// //       subtitle: 'Request salary advance or employee loan.',
// //       pendingCount: 1,
// //     ),
// //   ];
// //
// //   // ── Expense tab cards ──────────────────────────────────────────────────
// //   static const _expenseCards = [
// //     _ActionCard(
// //       iconBg: AppColors.greenTealDk,
// //       icon: Icons.receipt_long_rounded,
// //       title: 'Expense Claim',
// //       subtitle: 'Submit your work-related expenses.',
// //       pendingCount: 0,
// //     ),
// //   ];
// //
// //   // ── Others tab cards ───────────────────────────────────────────────────
// //   static const _othersCards = [
// //     _ActionCard(
// //       iconBg: AppColors.primary,
// //       icon: Icons.feedback_rounded,
// //       title: 'Suggestion',
// //       subtitle: 'Share your ideas or workplace suggestions.',
// //       pendingCount: 0,
// //     ),
// //     _ActionCard(
// //       iconBg: AppColors.primaryDark,
// //       icon: Icons.report_problem_rounded,
// //       title: 'Complaint',
// //       subtitle: 'Report a workplace issue or concern.',
// //       pendingCount: 0,
// //     ),
// //   ];
// //
// //   List<_ActionCard> get _currentCards {
// //     switch (_selectedTab) {
// //       case 0:  return _requestCards;
// //       case 1:  return _expenseCards;
// //       default: return _othersCards;
// //     }
// //   }
// //
// //   // ── NEW: Load user info + fetch both Leave & Loan data ─────────────────
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadAndFetch();
// //   }
// //
// //   Future<void> _loadAndFetch() async {
// //     final prefs  = await SharedPreferences.getInstance();
// //     _empId       = prefs.getString('userId') ?? '';
// //     _empName     = prefs.getString('userName') ?? 'Employee';
// //     _companyCode = prefs.getString('companyCode') ?? '';
// //     setState(() {});
// //
// //     if (_empId.isEmpty) return;
// //
// //     // Leave data fetch (via GetX ViewModel)
// //     _leaveVm.fetchLeaves(_empId, _companyCode);
// //
// //     // Loan data fetch (plain Future)
// //     setState(() => _loanLoading = true);
// //     try {
// //       final list = await LoanHistoryService.fetchHistory(
// //         empId: _empId,
// //         companyCode: _companyCode,
// //       );
// //       if (mounted) setState(() { _loanRecords = list; _loanLoading = false; });
// //     } catch (_) {
// //       if (mounted) setState(() => _loanLoading = false);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: _bgColor,
// //       bottomNavigationBar: widget.onNavTap != null
// //           ? AppBottomNavBar(
// //         currentIndex: widget.currentIndex,
// //         chatBadgeCount: widget.chatBadgeCount,
// //         onTap: widget.onNavTap!,
// //       )
// //           : null,
// //       body: SafeArea(
// //         child: CustomScrollView(
// //           physics: const BouncingScrollPhysics(),
// //           slivers: [
// //             // ── Header ────────────────────────────────────────────────────
// //             SliverToBoxAdapter(
// //               child: Padding(
// //                 padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
// //                 child: Row(
// //                   children: [
// //                     const Text(
// //                       'Actions',
// //                       style: TextStyle(
// //                         fontSize: 26,
// //                         fontWeight: FontWeight.w800,
// //                         color: _textDark,
// //                         letterSpacing: -0.5,
// //                       ),
// //                     ),
// //                     const SizedBox(width: 8),
// //                     Container(
// //                       padding: const EdgeInsets.all(3),
// //                       decoration: BoxDecoration(
// //                         color: _pillBg,
// //                         borderRadius: BorderRadius.circular(20),
// //                         border: Border.all(color: _primary.withOpacity(0.15)),
// //                       ),
// //                       child: const Icon(
// //                         Icons.info_outline_rounded,
// //                         size: 16,
// //                         color: _primary,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //
// //             // ── Subtitle ──────────────────────────────────────────────────
// //             const SliverToBoxAdapter(
// //               child: Padding(
// //                 padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
// //                 child: Text(
// //                   'Manage your workplace actions such as leave requests,\nexpense claims, complaints, and suggestions.',
// //                   style: TextStyle(
// //                     fontSize: 13.5,
// //                     color: _textGray,
// //                     height: 1.5,
// //                   ),
// //                 ),
// //               ),
// //             ),
// //
// //             // ── Summary Card ──────────────────────────────────────────────
// //             SliverToBoxAdapter(
// //               child: RequestSummaryWidget(
// //                 empName:     _empName,
// //                 leaveVm:     _leaveVm,
// //                 loanRecords: _loanRecords,
// //                 loanLoading: _loanLoading,
// //               ),
// //             ),
// //
// //             // ── Tab selector (sticky) ─────────────────────────────────────
// //             SliverPersistentHeader(
// //               pinned: true,
// //               delegate: _StickyTabDelegate(
// //                 child: Container(
// //                   color: _bgColor,
// //                   padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
// //                   child: Container(
// //                     decoration: BoxDecoration(
// //                       color: _cardBg,
// //                       borderRadius: BorderRadius.circular(16),
// //                       border: Border.all(color: _borderColor),
// //                     ),
// //                     padding: const EdgeInsets.all(5),
// //                     child: Row(
// //                       children: [
// //                         _TabButton(
// //                           icon: Icons.description_rounded,
// //                           label: 'Request',
// //                           isActive: _selectedTab == 0,
// //                           onTap: () {
// //                             HapticFeedback.lightImpact();
// //                             setState(() => _selectedTab = 0);
// //                           },
// //                         ),
// //                         _TabButton(
// //                           icon: Icons.receipt_outlined,
// //                           label: 'Expense',
// //                           isActive: _selectedTab == 1,
// //                           onTap: () {
// //                             HapticFeedback.lightImpact();
// //                             setState(() => _selectedTab = 1);
// //                           },
// //                         ),
// //                         _TabButton(
// //                           icon: Icons.more_horiz_rounded,
// //                           label: 'Others',
// //                           isActive: _selectedTab == 2,
// //                           onTap: () {
// //                             HapticFeedback.lightImpact();
// //                             setState(() => _selectedTab = 2);
// //                           },
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ),
// //
// //             // ── Action Cards ──────────────────────────────────────────────
// //             SliverPadding(
// //               padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
// //               sliver: SliverList(
// //                 delegate: SliverChildBuilderDelegate(
// //                       (context, index) {
// //                     final cards = _currentCards;
// //                     if (index >= cards.length) return null;
// //                     return Padding(
// //                       padding: EdgeInsets.only(
// //                         bottom: index < cards.length - 1 ? 14 : 0,
// //                       ),
// //                       child: _ActionCardWidget(card: cards[index]),
// //                     );
// //                   },
// //                   childCount: _currentCards.length,
// //                   // key forces rebuild on tab switch for animation
// //                   findChildIndexCallback: (_) => null,
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Sticky Tab Delegate — tab bar top pe stick karta hai scroll karte waqt
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
// //   final Widget child;
// //   // tab bar height (5 padding + ~48 tab + 12 bottom padding)
// //   static const double _h = 73;
// //
// //   const _StickyTabDelegate({required this.child});
// //
// //   @override double get minExtent => _h;
// //   @override double get maxExtent => _h;
// //
// //   @override
// //   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
// //     return SizedBox.expand(child: child);
// //   }
// //
// //   @override
// //   bool shouldRebuild(_StickyTabDelegate old) => old.child != child;
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Tab Button  (unchanged)
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _TabButton extends StatelessWidget {
// //   final IconData icon;
// //   final String label;
// //   final bool isActive;
// //   final VoidCallback onTap;
// //
// //   static const _primary    = AppColors.cyan;
// //   static const _bgActive   = AppColors.cyan;
// //   static const _textActive = AppColors.textOnDark;
// //   static const _textMuted  = AppColors.textSecondary;
// //
// //   const _TabButton({
// //     required this.icon,
// //     required this.label,
// //     required this.isActive,
// //     required this.onTap,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Expanded(
// //       child: GestureDetector(
// //         onTap: onTap,
// //         child: AnimatedContainer(
// //           duration: const Duration(milliseconds: 220),
// //           curve: Curves.easeInOut,
// //           padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
// //           decoration: BoxDecoration(
// //             color: isActive ? _bgActive : Colors.transparent,
// //             borderRadius: BorderRadius.circular(11),
// //             boxShadow: isActive
// //                 ? [
// //               BoxShadow(
// //                 color: _primary.withOpacity(0.25),
// //                 blurRadius: 12,
// //                 offset: const Offset(0, 4),
// //               )
// //             ]
// //                 : [],
// //           ),
// //           child: Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               Icon(
// //                 icon,
// //                 size: 16,
// //                 color: isActive ? _textActive : _textMuted,
// //               ),
// //               const SizedBox(width: 5),
// //               Text(
// //                 label,
// //                 style: TextStyle(
// //                   fontSize: 13,
// //                   fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
// //                   color: isActive ? _textActive : _textMuted,
// //                   letterSpacing: 0.1,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Action Card Data Model  (unchanged)
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _ActionCard {
// //   final Color iconBg;
// //   final IconData icon;
// //   final String title;
// //   final String subtitle;
// //   final int pendingCount;
// //
// //   const _ActionCard({
// //     required this.iconBg,
// //     required this.icon,
// //     required this.title,
// //     required this.subtitle,
// //     required this.pendingCount,
// //   });
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Action Card Widget  (unchanged from original — same navigation logic)
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _ActionCardWidget extends StatefulWidget {
// //   final _ActionCard card;
// //
// //   const _ActionCardWidget({required this.card});
// //
// //   @override
// //   State<_ActionCardWidget> createState() => _ActionCardWidgetState();
// // }
// //
// // class _ActionCardWidgetState extends State<_ActionCardWidget> {
// //   bool _newPressed     = false;
// //   bool _historyPressed = false;
// //
// //   static const _primary     = AppColors.cyan;
// //   static const _primaryDark = AppColors.primaryDark;
// //   static const _cardBg      = AppColors.cardBg;
// //   static const _borderColor = AppColors.divider;
// //   static const _historyBg   = AppColors.surface;
// //   static const _historyPres = AppColors.cyanMid;
// //   static const _pendingBg   = Color(0xFFFFF3E0);
// //   static const _pendingText = AppColors.warning;
// //
// //   void _openHistory(BuildContext context) {
// //     final card = widget.card;
// //     Widget screen;
// //     if (card.title == 'Leaves' || card.title == 'Half Day') {
// //       screen = const LeaveHistoryScreen();
// //     } else if (card.title == 'Loan / Advance') {
// //       screen = const LoanHistoryScreen();
// //     } else if (card.title == 'Expense Claim') {
// //       screen = const ExpenseHistoryScreen();
// //     } else {
// //       return;
// //     }
// //     Navigator.push(
// //       context,
// //       PageRouteBuilder(
// //         pageBuilder: (_, __, ___) => screen,
// //         transitionsBuilder: (_, animation, __, child) {
// //           return SlideTransition(
// //             position: Tween<Offset>(
// //               begin: const Offset(1.0, 0.0),
// //               end: Offset.zero,
// //             ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
// //             child: child,
// //           );
// //         },
// //         transitionDuration: const Duration(milliseconds: 300),
// //       ),
// //     );
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final card = widget.card;
// //
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: _cardBg,
// //         borderRadius: BorderRadius.circular(18),
// //         border: Border.all(color: _borderColor),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.04),
// //             blurRadius: 10,
// //             offset: const Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       padding: const EdgeInsets.all(16),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             children: [
// //               Container(
// //                 width: 44,
// //                 height: 44,
// //                 decoration: BoxDecoration(
// //                   color: card.iconBg.withOpacity(0.15),
// //                   borderRadius: BorderRadius.circular(13),
// //                   border: Border.all(color: card.iconBg.withOpacity(0.25)),
// //                 ),
// //                 child: Icon(card.icon, size: 22, color: card.iconBg),
// //               ),
// //               const SizedBox(width: 12),
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(
// //                       card.title,
// //                       style: const TextStyle(
// //                         fontSize: 15,
// //                         fontWeight: FontWeight.w700,
// //                         color: AppColors.textPrimary,
// //                       ),
// //                     ),
// //                     const SizedBox(height: 3),
// //                     Text(
// //                       card.subtitle,
// //                       style: const TextStyle(
// //                         fontSize: 12.5,
// //                         color: AppColors.textSecondary,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               if (card.pendingCount > 0) ...[
// //                 Container(
// //                   padding:
// //                   const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
// //                   decoration: BoxDecoration(
// //                     color: _pendingBg,
// //                     borderRadius: BorderRadius.circular(20),
// //                   ),
// //                   child: Text(
// //                     '${card.pendingCount} Pending',
// //                     style: const TextStyle(
// //                       fontSize: 11.5,
// //                       fontWeight: FontWeight.w700,
// //                       color: _pendingText,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ],
// //           ),
// //           const SizedBox(height: 14),
// //           Row(
// //             children: [
// //               // New Request button
// //               Expanded(
// //                 flex: 6,
// //                 child: GestureDetector(
// //                   onTapDown: (_) {
// //                     HapticFeedback.lightImpact();
// //                     setState(() => _newPressed = true);
// //                   },
// //                   onTapUp: (_) => setState(() => _newPressed = false),
// //                   onTapCancel: () => setState(() => _newPressed = false),
// //                   onTap: () {
// //                     if (card.title == 'Leaves' || card.title == 'Half Day') {
// //                       Navigator.push(
// //                         context,
// //                         MaterialPageRoute(
// //                             builder: (_) =>  LeaveScreen()),
// //                       );
// //                     } else if (card.title == 'Loan / Advance') {
// //                       Navigator.push(
// //                         context,
// //                         MaterialPageRoute(
// //                             builder: (_) => const LoanAdvanceScreen()),
// //                       );
// //                     }
// //                     else if (card.title == 'Expense Claim') {        // ← ADD THIS
// //                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseClaimScreen()));
// //                     } else if (card.title == 'Suggestion') {
// //                       Navigator.of(context).push(
// //                         PageRouteBuilder(
// //                           opaque: false,
// //                           barrierDismissible: true,
// //                           barrierColor: Colors.black54,
// //                           pageBuilder: (_, __, ___) => const SuggestionScreen(),
// //                           transitionsBuilder: (_, animation, __, child) {
// //                             return SlideTransition(
// //                               position: Tween<Offset>(
// //                                 begin: const Offset(0.0, 1.0),
// //                                 end: Offset.zero,
// //                               ).chain(CurveTween(curve: Curves.easeOutCubic))
// //                                   .animate(animation),
// //                               child: child,
// //                             );
// //                           },
// //                           transitionDuration: const Duration(milliseconds: 300),
// //                         ),
// //                       );
// //                     } else if (card.title == 'Complaint') {
// //                       Navigator.of(context).push(
// //                         PageRouteBuilder(
// //                           opaque: false,
// //                           barrierDismissible: true,
// //                           barrierColor: Colors.black54,
// //                           pageBuilder: (_, __, ___) => const ComplaintScreen(),
// //                           transitionsBuilder: (_, animation, __, child) {
// //                             return SlideTransition(
// //                               position: Tween<Offset>(
// //                                 begin: const Offset(0.0, 1.0),
// //                                 end: Offset.zero,
// //                               ).chain(CurveTween(curve: Curves.easeOutCubic))
// //                                   .animate(animation),
// //                               child: child,
// //                             );
// //                           },
// //                           transitionDuration: const Duration(milliseconds: 300),
// //                         ),
// //                       );
// //                     }
// //                   },
// //                   child: AnimatedContainer(
// //                     duration: const Duration(milliseconds: 100),
// //                     height: 44,
// //                     decoration: BoxDecoration(
// //                       gradient: _newPressed
// //                           ? null
// //                           : LinearGradient(
// //                         colors: [_primaryDark, _primary],
// //                         begin: Alignment.topLeft,
// //                         end: Alignment.bottomRight,
// //                       ),
// //                       color: _newPressed ? _primary.withOpacity(0.80) : null,
// //                       borderRadius: BorderRadius.circular(12),
// //                       boxShadow: _newPressed
// //                           ? []
// //                           : [
// //                         BoxShadow(
// //                           color: _primary.withOpacity(0.3),
// //                           blurRadius: 12,
// //                           offset: const Offset(0, 4),
// //                         )
// //                       ],
// //                     ),
// //                     child: const Row(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: [
// //                         Icon(Icons.add_rounded,
// //                             color: AppColors.textOnDark, size: 18),
// //                         SizedBox(width: 6),
// //                         Text(
// //                           'New Request',
// //                           style: TextStyle(
// //                             color: AppColors.textOnDark,
// //                             fontSize: 14,
// //                             fontWeight: FontWeight.w700,
// //                             letterSpacing: 0.1,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //               const SizedBox(width: 10),
// //               // History button
// //               Expanded(
// //                 flex: 4,
// //                 child: GestureDetector(
// //                   onTapDown: (_) {
// //                     HapticFeedback.lightImpact();
// //                     setState(() => _historyPressed = true);
// //                   },
// //                   onTapUp: (_) => setState(() => _historyPressed = false),
// //                   onTapCancel: () =>
// //                       setState(() => _historyPressed = false),
// //                   onTap: () => _openHistory(context),
// //                   child: AnimatedContainer(
// //                     duration: const Duration(milliseconds: 100),
// //                     height: 44,
// //                     decoration: BoxDecoration(
// //                       color: _historyPressed ? _historyPres : _historyBg,
// //                       borderRadius: BorderRadius.circular(12),
// //                       border: Border.all(color: _borderColor),
// //                     ),
// //                     child: const Row(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: [
// //                         Icon(Icons.history_rounded,
// //                             color: AppColors.textPrimary, size: 18),
// //                         SizedBox(width: 6),
// //                         Text(
// //                           'History',
// //                           style: TextStyle(
// //                             color: AppColors.textPrimary,
// //                             fontSize: 14,
// //                             fontWeight: FontWeight.w600,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../AppColors.dart';
// import 'HomeScreenComponents/app_bottom_navbar.dart';
// import 'HomeScreenComponents/navbar.dart';
// import 'HomeScreenComponents/sidebar_drawer.dart';
// import 'WidgetDesignes/request_summary_widget.dart';
// import 'expense_claim_screen.dart';
// import 'expense_history_screen.dart';
// import 'leave_screen.dart';
// import 'loan_advance_screen.dart';
// import 'loan_history_screen.dart';
// import 'leave_report_get_screen.dart';
// import 'complaint_screen.dart';
// import 'suggestion_screen.dart';
//
//
// // ═══════════════════════════════════════════════════════════════════════════
// // actions_screen.dart
// //
// // Actions Screen — Request / Expense / Others tabs
// // + RequestSummaryWidget: Leave aur Loan ke combined counts
// // ═══════════════════════════════════════════════════════════════════════════
//
// class ActionsScreen extends StatefulWidget {
//   final int currentIndex;
//   final int chatBadgeCount;
//   final ValueChanged<int>? onNavTap;
//
//   const ActionsScreen({
//     super.key,
//     this.currentIndex = 1,
//     this.chatBadgeCount = 0,
//     this.onNavTap,
//   });
//
//   @override
//   State<ActionsScreen> createState() => _ActionsScreenState();
// }
//
// class _ActionsScreenState extends State<ActionsScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   // 0 = Request, 1 = Expense, 2 = Others
//   int _selectedTab = 0;
//
//   // ── NEW: Summary widget state ──────────────────────────────────────────
//   final LeaveHistoryViewModel _leaveVm = Get.put(LeaveHistoryViewModel());
//   List<LoanRecord> _loanRecords = [];
//   bool _loanLoading = false;
//   String _empId       = '';
//   String _empName     = 'Employee';
//   String _companyCode = '';
//
//   // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
//   static const _bgColor      = AppColors.surface;
//   static const _primary      = AppColors.cyan;
//   static const _cardBg       = AppColors.cardBg;
//   static const _borderColor  = AppColors.divider;
//   static const _textDark     = AppColors.textPrimary;
//   static const _textGray     = AppColors.textSecondary;
//   static const _pillBg       = AppColors.cyanLight;
//   static const _pendingBg    = Color(0xFFFFF3E0);
//   static const _pendingText  = AppColors.warning;
//   static const _historyBg    = AppColors.surface;
//
//   // ── Request tab cards ──────────────────────────────────────────────────
//   static const _requestCards = [
//     _ActionCard(
//       iconBg: AppColors.cyan,
//       icon: Icons.beach_access_rounded,
//       title: 'Leaves',
//       subtitle: 'Apply for full-day leave.',
//       pendingCount: 1,
//     ),
//     _ActionCard(
//       iconBg: AppColors.greenTeal,
//       icon: Icons.access_time_rounded,
//       title: 'Half Day',
//       subtitle: 'Apply for leave for part of the day.',
//       pendingCount: 0,
//     ),
//     _ActionCard(
//       iconBg: AppColors.warning,
//       icon: Icons.attach_money_rounded,
//       title: 'Loan / Advance',
//       subtitle: 'Request salary advance or employee loan.',
//       pendingCount: 1,
//     ),
//   ];
//
//   // ── Expense tab cards ──────────────────────────────────────────────────
//   static const _expenseCards = [
//     _ActionCard(
//       iconBg: AppColors.greenTealDk,
//       icon: Icons.receipt_long_rounded,
//       title: 'Expense Claim',
//       subtitle: 'Submit your work-related expenses.',
//       pendingCount: 0,
//     ),
//   ];
//
//   // ── Others tab cards ───────────────────────────────────────────────────
//   static const _othersCards = [
//     _ActionCard(
//       iconBg: AppColors.primary,
//       icon: Icons.feedback_rounded,
//       title: 'Suggestion',
//       subtitle: 'Share your ideas or workplace suggestions.',
//       pendingCount: 0,
//     ),
//     _ActionCard(
//       iconBg: AppColors.primaryDark,
//       icon: Icons.report_problem_rounded,
//       title: 'Complaint',
//       subtitle: 'Report a workplace issue or concern.',
//       pendingCount: 0,
//     ),
//   ];
//
//   List<_ActionCard> get _currentCards {
//     switch (_selectedTab) {
//       case 0:  return _requestCards;
//       case 1:  return _expenseCards;
//       default: return _othersCards;
//     }
//   }
//
//   // ── NEW: Load user info + fetch both Leave & Loan data ─────────────────
//   @override
//   void initState() {
//     super.initState();
//     _loadAndFetch();
//   }
//
//   Future<void> _loadAndFetch() async {
//     final prefs  = await SharedPreferences.getInstance();
//     _empId       = prefs.getString('userId') ?? '';
//     _empName     = prefs.getString('userName') ?? 'Employee';
//     _companyCode = prefs.getString('companyCode') ?? '';
//     setState(() {});
//
//     if (_empId.isEmpty) return;
//
//     // Leave data fetch (via GetX ViewModel)
//     _leaveVm.fetchLeaves(_empId, _companyCode);
//
//     // Loan data fetch (plain Future)
//     setState(() => _loanLoading = true);
//     try {
//       final list = await LoanHistoryService.fetchHistory(
//         empId: _empId,
//         companyCode: _companyCode,
//       );
//       if (mounted) setState(() { _loanRecords = list; _loanLoading = false; });
//     } catch (_) {
//       if (mounted) setState(() => _loanLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key:             _scaffoldKey,
//       backgroundColor: _bgColor,
//       appBar: Navbar(
//         userName:     _empName,
//         userInitials: _empName.trim().split(' ').length >= 2
//             ? '${_empName.trim().split(' ')[0][0]}${_empName.trim().split(' ')[1][0]}'.toUpperCase()
//             : _empName.isNotEmpty ? _empName[0].toUpperCase() : '?',
//         scaffoldKey:  _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       bottomNavigationBar: widget.onNavTap != null
//           ? AppBottomNavBar(
//         currentIndex: widget.currentIndex,
//         chatBadgeCount: widget.chatBadgeCount,
//         onTap: widget.onNavTap!,
//       )
//           : null,
//       body: SafeArea(
//         child: CustomScrollView(
//           physics: const BouncingScrollPhysics(),
//           slivers: [
//             // ── Header ────────────────────────────────────────────────────
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
//                 child: Row(
//                   children: [
//                     const Text(
//                       'Actions',
//                       style: TextStyle(
//                         fontSize: 26,
//                         fontWeight: FontWeight.w800,
//                         color: _textDark,
//                         letterSpacing: -0.5,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.all(3),
//                       decoration: BoxDecoration(
//                         color: _pillBg,
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(color: _primary.withOpacity(0.15)),
//                       ),
//                       child: const Icon(
//                         Icons.info_outline_rounded,
//                         size: 16,
//                         color: _primary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             // ── Subtitle ──────────────────────────────────────────────────
//             const SliverToBoxAdapter(
//               child: Padding(
//                 padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
//                 child: Text(
//                   'Manage your workplace actions such as leave requests, expense claims, complaints, and suggestions.',
//                   style: TextStyle(
//                     fontSize: 13.5,
//                     color: _textGray,
//                     height: 1.5,
//                   ),
//                 ),
//               ),
//             ),
//
//             // ── Summary Card ──────────────────────────────────────────────
//             SliverToBoxAdapter(
//               child: RequestSummaryWidget(
//                 empName:     _empName,
//                 leaveVm:     _leaveVm,
//                 loanRecords: _loanRecords,
//                 loanLoading: _loanLoading,
//               ),
//             ),
//
//             // ── Tab selector (sticky) ─────────────────────────────────────
//             SliverPersistentHeader(
//               pinned: true,
//               delegate: _StickyTabDelegate(
//                 child: Container(
//                   color: _bgColor,
//                   padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: _cardBg,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: _borderColor),
//                     ),
//                     padding: const EdgeInsets.all(5),
//                     child: Row(
//                       children: [
//                         _TabButton(
//                           icon: Icons.description_rounded,
//                           label: 'Request',
//                           isActive: _selectedTab == 0,
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             setState(() => _selectedTab = 0);
//                           },
//                         ),
//                         _TabButton(
//                           icon: Icons.receipt_outlined,
//                           label: 'Expense',
//                           isActive: _selectedTab == 1,
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             setState(() => _selectedTab = 1);
//                           },
//                         ),
//                         _TabButton(
//                           icon: Icons.more_horiz_rounded,
//                           label: 'Others',
//                           isActive: _selectedTab == 2,
//                           onTap: () {
//                             HapticFeedback.lightImpact();
//                             setState(() => _selectedTab = 2);
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//
//             // ── Action Cards ──────────────────────────────────────────────
//             SliverPadding(
//               padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
//               sliver: SliverList(
//                 delegate: SliverChildBuilderDelegate(
//                       (context, index) {
//                     final cards = _currentCards;
//                     if (index >= cards.length) return null;
//                     return Padding(
//                       padding: EdgeInsets.only(
//                         bottom: index < cards.length - 1 ? 14 : 0,
//                       ),
//                       child: _ActionCardWidget(card: cards[index]),
//                     );
//                   },
//                   childCount: _currentCards.length,
//                   // key forces rebuild on tab switch for animation
//                   findChildIndexCallback: (_) => null,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Sticky Tab Delegate — tab bar top pe stick karta hai scroll karte waqt
// // ─────────────────────────────────────────────────────────────────────────────
// class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
//   final Widget child;
//   // tab bar height (5 padding + ~48 tab + 12 bottom padding)
//   static const double _h = 73;
//
//   const _StickyTabDelegate({required this.child});
//
//   @override double get minExtent => _h;
//   @override double get maxExtent => _h;
//
//   @override
//   Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return SizedBox.expand(child: child);
//   }
//
//   @override
//   bool shouldRebuild(_StickyTabDelegate old) => old.child != child;
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Tab Button  (unchanged)
// // ─────────────────────────────────────────────────────────────────────────────
// class _TabButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final bool isActive;
//   final VoidCallback onTap;
//
//   static const _primary    = AppColors.cyan;
//   static const _bgActive   = AppColors.cyan;
//   static const _textActive = AppColors.textOnDark;
//   static const _textMuted  = AppColors.textSecondary;
//
//   const _TabButton({
//     required this.icon,
//     required this.label,
//     required this.isActive,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 220),
//           curve: Curves.easeInOut,
//           padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
//           decoration: BoxDecoration(
//             color: isActive ? _bgActive : Colors.transparent,
//             borderRadius: BorderRadius.circular(11),
//             boxShadow: isActive
//                 ? [
//               BoxShadow(
//                 color: _primary.withOpacity(0.25),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               )
//             ]
//                 : [],
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 icon,
//                 size: 16,
//                 color: isActive ? _textActive : _textMuted,
//               ),
//               const SizedBox(width: 5),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
//                   color: isActive ? _textActive : _textMuted,
//                   letterSpacing: 0.1,
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
// // ─────────────────────────────────────────────────────────────────────────────
// // Action Card Data Model  (unchanged)
// // ─────────────────────────────────────────────────────────────────────────────
// class _ActionCard {
//   final Color iconBg;
//   final IconData icon;
//   final String title;
//   final String subtitle;
//   final int pendingCount;
//
//   const _ActionCard({
//     required this.iconBg,
//     required this.icon,
//     required this.title,
//     required this.subtitle,
//     required this.pendingCount,
//   });
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Action Card Widget  (unchanged from original — same navigation logic)
// // ─────────────────────────────────────────────────────────────────────────────
// class _ActionCardWidget extends StatefulWidget {
//   final _ActionCard card;
//
//   const _ActionCardWidget({required this.card});
//
//   @override
//   State<_ActionCardWidget> createState() => _ActionCardWidgetState();
// }
//
// class _ActionCardWidgetState extends State<_ActionCardWidget> {
//   bool _newPressed     = false;
//   bool _historyPressed = false;
//
//   static const _primary     = AppColors.cyan;
//   static const _primaryDark = AppColors.primaryDark;
//   static const _cardBg      = AppColors.cardBg;
//   static const _borderColor = AppColors.divider;
//   static const _historyBg   = AppColors.surface;
//   static const _historyPres = AppColors.cyanMid;
//   static const _pendingBg   = Color(0xFFFFF3E0);
//   static const _pendingText = AppColors.warning;
//
//   void _openHistory(BuildContext context) {
//     final card = widget.card;
//     Widget screen;
//     if (card.title == 'Leaves' || card.title == 'Half Day') {
//       screen = const LeaveHistoryScreen();
//     } else if (card.title == 'Loan / Advance') {
//       screen = const LoanHistoryScreen();
//     } else if (card.title == 'Expense Claim') {
//       screen = const ExpenseHistoryScreen();
//     } else {
//       return;
//     }
//     Navigator.push(
//       context,
//       PageRouteBuilder(
//         pageBuilder: (_, __, ___) => screen,
//         transitionsBuilder: (_, animation, __, child) {
//           return SlideTransition(
//             position: Tween<Offset>(
//               begin: const Offset(1.0, 0.0),
//               end: Offset.zero,
//             ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
//             child: child,
//           );
//         },
//         transitionDuration: const Duration(milliseconds: 300),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final card = widget.card;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: _cardBg,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: _borderColor),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 44,
//                 height: 44,
//                 decoration: BoxDecoration(
//                   color: card.iconBg.withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(13),
//                   border: Border.all(color: card.iconBg.withOpacity(0.25)),
//                 ),
//                 child: Icon(card.icon, size: 22, color: card.iconBg),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       card.title,
//                       style: const TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700,
//                         color: AppColors.textPrimary,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Text(
//                       card.subtitle,
//                       style: const TextStyle(
//                         fontSize: 12.5,
//                         color: AppColors.textSecondary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (card.pendingCount > 0) ...[
//                 Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: _pendingBg,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     '${card.pendingCount} Pending',
//                     style: const TextStyle(
//                       fontSize: 11.5,
//                       fontWeight: FontWeight.w700,
//                       color: _pendingText,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//           const SizedBox(height: 14),
//           Row(
//             children: [
//               // New Request button
//               Expanded(
//                 flex: 6,
//                 child: GestureDetector(
//                   onTapDown: (_) {
//                     HapticFeedback.lightImpact();
//                     setState(() => _newPressed = true);
//                   },
//                   onTapUp: (_) => setState(() => _newPressed = false),
//                   onTapCancel: () => setState(() => _newPressed = false),
//                   onTap: () {
//                     if (card.title == 'Leaves' || card.title == 'Half Day') {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (_) =>  LeaveScreen()),
//                       );
//                     } else if (card.title == 'Loan / Advance') {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (_) => const LoanAdvanceScreen()),
//                       );
//                     }
//                     else if (card.title == 'Expense Claim') {        // ← ADD THIS
//                       Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseClaimScreen()));
//                     } else if (card.title == 'Suggestion') {
//                       Navigator.of(context).push(
//                         PageRouteBuilder(
//                           opaque: false,
//                           barrierDismissible: true,
//                           barrierColor: Colors.black54,
//                           pageBuilder: (_, __, ___) => const SuggestionScreen(),
//                           transitionsBuilder: (_, animation, __, child) {
//                             return SlideTransition(
//                               position: Tween<Offset>(
//                                 begin: const Offset(0.0, 1.0),
//                                 end: Offset.zero,
//                               ).chain(CurveTween(curve: Curves.easeOutCubic))
//                                   .animate(animation),
//                               child: child,
//                             );
//                           },
//                           transitionDuration: const Duration(milliseconds: 300),
//                         ),
//                       );
//                     } else if (card.title == 'Complaint') {
//                       Navigator.of(context).push(
//                         PageRouteBuilder(
//                           opaque: false,
//                           barrierDismissible: true,
//                           barrierColor: Colors.black54,
//                           pageBuilder: (_, __, ___) => const ComplaintScreen(),
//                           transitionsBuilder: (_, animation, __, child) {
//                             return SlideTransition(
//                               position: Tween<Offset>(
//                                 begin: const Offset(0.0, 1.0),
//                                 end: Offset.zero,
//                               ).chain(CurveTween(curve: Curves.easeOutCubic))
//                                   .animate(animation),
//                               child: child,
//                             );
//                           },
//                           transitionDuration: const Duration(milliseconds: 300),
//                         ),
//                       );
//                     }
//                   },
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 100),
//                     height: 44,
//                     decoration: BoxDecoration(
//                       gradient: _newPressed
//                           ? null
//                           : LinearGradient(
//                         colors: [_primaryDark, _primary],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       color: _newPressed ? _primary.withOpacity(0.80) : null,
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: _newPressed
//                           ? []
//                           : [
//                         BoxShadow(
//                           color: _primary.withOpacity(0.3),
//                           blurRadius: 12,
//                           offset: const Offset(0, 4),
//                         )
//                       ],
//                     ),
//                     child: const Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.add_rounded,
//                             color: AppColors.textOnDark, size: 18),
//                         SizedBox(width: 6),
//                         Text(
//                           'New Request',
//                           style: TextStyle(
//                             color: AppColors.textOnDark,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.1,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               // History button
//               Expanded(
//                 flex: 4,
//                 child: GestureDetector(
//                   onTapDown: (_) {
//                     HapticFeedback.lightImpact();
//                     setState(() => _historyPressed = true);
//                   },
//                   onTapUp: (_) => setState(() => _historyPressed = false),
//                   onTapCancel: () =>
//                       setState(() => _historyPressed = false),
//                   onTap: () => _openHistory(context),
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 100),
//                     height: 44,
//                     decoration: BoxDecoration(
//                       color: _historyPressed ? _historyPres : _historyBg,
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: _borderColor),
//                     ),
//                     child: const Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.history_rounded,
//                             color: AppColors.textPrimary, size: 18),
//                         SizedBox(width: 6),
//                         Text(
//                           'History',
//                           style: TextStyle(
//                             color: AppColors.textPrimary,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import 'WidgetDesignes/request_summary_widget.dart';
import 'expense_claim_screen.dart';
import 'expense_history_screen.dart';
import 'leave_screen.dart';
import 'loan_advance_screen.dart';
import 'loan_history_screen.dart';
import 'leave_report_get_screen.dart';
import 'complaint_screen.dart';
import 'suggestion_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
// actions_screen.dart
//
// Actions Screen — Request / Expense / Others tabs
// + RequestSummaryWidget: Leave aur Loan ke combined counts
// ═══════════════════════════════════════════════════════════════════════════

class ActionsScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int>? onNavTap;

  const ActionsScreen({
    super.key,
    this.currentIndex = 1,
    this.chatBadgeCount = 0,
    this.onNavTap,
  });

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 0 = Request, 1 = Expense, 2 = Others
  int _selectedTab = 0;

  // ── NEW: Summary widget state ──────────────────────────────────────────
  final LeaveHistoryViewModel _leaveVm = Get.put(LeaveHistoryViewModel());
  List<LoanRecord> _loanRecords = [];
  bool _loanLoading = false;
  String _empId       = '';
  String _empName     = 'Employee';
  String _companyCode = '';

  // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
  static const _bgColor      = AppColors.surface;
  static const _primary      = AppColors.cyan;
  static const _cardBg       = AppColors.cardBg;
  static const _borderColor  = AppColors.divider;
  static const _textDark     = AppColors.textPrimary;
  static const _textGray     = AppColors.textSecondary;
  static const _pillBg       = AppColors.cyanLight;
  static const _pendingBg    = Color(0xFFFFF3E0);
  static const _pendingText  = AppColors.warning;
  static const _historyBg    = AppColors.surface;

  // ── Request tab cards ──────────────────────────────────────────────────
  static const _requestCards = [
    _ActionCard(
      iconBg: AppColors.cyan,
      icon: Icons.beach_access_rounded,
      title: 'Leaves',
      subtitle: 'Apply for full-day leave.',
      pendingCount: 1,
    ),
    _ActionCard(
      iconBg: AppColors.greenTeal,
      icon: Icons.access_time_rounded,
      title: 'Half Day',
      subtitle: 'Apply for leave for part of the day.',
      pendingCount: 0,
    ),
    _ActionCard(
      iconBg: AppColors.warning,
      icon: Icons.attach_money_rounded,
      title: 'Loan / Advance',
      subtitle: 'Request salary advance or employee loan.',
      pendingCount: 1,
    ),
  ];

  // ── Expense tab cards ──────────────────────────────────────────────────
  static const _expenseCards = [
    _ActionCard(
      iconBg: AppColors.greenTealDk,
      icon: Icons.receipt_long_rounded,
      title: 'Expense Claim',
      subtitle: 'Submit your work-related expenses.',
      pendingCount: 0,
    ),
  ];

  // ── Others tab cards ───────────────────────────────────────────────────
  static const _othersCards = [
    _ActionCard(
      iconBg: AppColors.primary,
      icon: Icons.feedback_rounded,
      title: 'Suggestion',
      subtitle: 'Share your ideas or workplace suggestions.',
      pendingCount: 0,
    ),
    _ActionCard(
      iconBg: AppColors.primaryDark,
      icon: Icons.report_problem_rounded,
      title: 'Complaint',
      subtitle: 'Report a workplace issue or concern.',
      pendingCount: 0,
    ),
  ];

  List<_ActionCard> get _currentCards {
    switch (_selectedTab) {
      case 0:  return _requestCards;
      case 1:  return _expenseCards;
      default: return _othersCards;
    }
  }

  // ── NEW: Load user info + fetch both Leave & Loan data ─────────────────
  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs  = await SharedPreferences.getInstance();
    _empId       = prefs.getString('userId') ?? '';
    _empName     = prefs.getString('userName') ?? 'Employee';
    _companyCode = prefs.getString('companyCode') ?? '';
    setState(() {});

    if (_empId.isEmpty) return;

    // Leave data fetch (via GetX ViewModel)
    _leaveVm.fetchLeaves(_empId, _companyCode);

    // Loan data fetch (plain Future)
    setState(() => _loanLoading = true);
    try {
      final list = await LoanHistoryService.fetchHistory(
        empId: _empId,
        companyCode: _companyCode,
      );
      if (mounted) setState(() { _loanRecords = list; _loanLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _loanLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _bgColor,
      appBar: Navbar(
        userName:     _empName,
        userInitials: _empName.trim().split(' ').length >= 2
            ? '${_empName.trim().split(' ')[0][0]}${_empName.trim().split(' ')[1][0]}'.toUpperCase()
            : _empName.isNotEmpty ? _empName[0].toUpperCase() : '?',
        scaffoldKey:  _scaffoldKey,
      ),
      drawer: AppDrawer(),
      bottomNavigationBar: widget.onNavTap != null
          ? AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: widget.onNavTap!,
      )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _pillBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primary.withOpacity(0.15)),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Subtitle ──────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Manage your workplace actions such as leave requests, expense claims, complaints, and suggestions.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _textGray,
                    height: 1.5,
                  ),
                ),
              ),
            ),

            // ── Summary Card ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: RequestSummaryWidget(
                empName:     _empName,
                leaveVm:     _leaveVm,
                loanRecords: _loanRecords,
                loanLoading: _loanLoading,
              ),
            ),

            // ── Tab selector (sticky) ─────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabDelegate(
                child: Container(
                  color: _bgColor,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Row(
                      children: [
                        _TabButton(
                          icon: Icons.description_rounded,
                          label: 'Request',
                          isActive: _selectedTab == 0,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedTab = 0);
                          },
                        ),
                        _TabButton(
                          icon: Icons.receipt_outlined,
                          label: 'Expense',
                          isActive: _selectedTab == 1,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedTab = 1);
                          },
                        ),
                        _TabButton(
                          icon: Icons.more_horiz_rounded,
                          label: 'Others',
                          isActive: _selectedTab == 2,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedTab = 2);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Action Cards ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final cards = _currentCards;
                    if (index >= cards.length) return null;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < cards.length - 1 ? 14 : 0,
                      ),
                      child: _ActionCardWidget(card: cards[index]),
                    );
                  },
                  childCount: _currentCards.length,
                  // key forces rebuild on tab switch for animation
                  findChildIndexCallback: (_) => null,
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
// Sticky Tab Delegate — tab bar top pe stick karta hai scroll karte waqt
// ─────────────────────────────────────────────────────────────────────────────
class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  // tab bar height (5 padding + ~48 tab + 12 bottom padding)
  static const double _h = 73;

  const _StickyTabDelegate({required this.child});

  @override double get minExtent => _h;
  @override double get maxExtent => _h;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyTabDelegate old) => old.child != child;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Button  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  static const _primary    = AppColors.cyan;
  static const _bgActive   = AppColors.cyan;
  static const _textActive = AppColors.textOnDark;
  static const _textMuted  = AppColors.textSecondary;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? _bgActive : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: _primary.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? _textActive : _textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _textActive : _textMuted,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Card Data Model  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard {
  final Color iconBg;
  final IconData icon;
  final String title;
  final String subtitle;
  final int pendingCount;

  const _ActionCard({
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pendingCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Card Widget  (unchanged from original — same navigation logic)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCardWidget extends StatefulWidget {
  final _ActionCard card;

  const _ActionCardWidget({required this.card});

  @override
  State<_ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<_ActionCardWidget> {
  bool _newPressed     = false;
  bool _historyPressed = false;

  static const _primary     = AppColors.cyan;
  static const _primaryDark = AppColors.primaryDark;
  static const _cardBg      = AppColors.cardBg;
  static const _borderColor = AppColors.divider;
  static const _historyBg   = AppColors.surface;
  static const _historyPres = AppColors.cyanMid;
  static const _pendingBg   = Color(0xFFFFF3E0);
  static const _pendingText = AppColors.warning;

  void _openHistory(BuildContext context) {
    final card = widget.card;
    Widget screen;
    if (card.title == 'Leaves' || card.title == 'Half Day') {
      screen = const LeaveHistoryScreen();
    } else if (card.title == 'Loan / Advance') {
      screen = const LoanHistoryScreen();
    } else if (card.title == 'Expense Claim') {
      screen = const ExpenseHistoryScreen();
    } else {
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: card.iconBg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: card.iconBg.withOpacity(0.25)),
                ),
                child: Icon(card.icon, size: 22, color: card.iconBg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (card.pendingCount > 0) ...[
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pendingBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${card.pendingCount} Pending',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _pendingText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // New Request button
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.lightImpact();
                    setState(() => _newPressed = true);
                  },
                  onTapUp: (_) => setState(() => _newPressed = false),
                  onTapCancel: () => setState(() => _newPressed = false),
                  onTap: () {
                    if (card.title == 'Leaves' || card.title == 'Half Day') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LeaveScreen(
                              isHalfDayMode: card.title == 'Half Day',
                            )),
                      );
                    } else if (card.title == 'Loan / Advance') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoanAdvanceScreen()),
                      );
                    }
                    else if (card.title == 'Expense Claim') {        // ← ADD THIS
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseClaimScreen()));
                    } else if (card.title == 'Suggestion') {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierDismissible: true,
                          barrierColor: Colors.black54,
                          pageBuilder: (_, __, ___) => const SuggestionScreen(),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 1.0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeOutCubic))
                                  .animate(animation),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    } else if (card.title == 'Complaint') {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierDismissible: true,
                          barrierColor: Colors.black54,
                          pageBuilder: (_, __, ___) => const ComplaintScreen(),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 1.0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeOutCubic))
                                  .animate(animation),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: _newPressed
                          ? null
                          : LinearGradient(
                        colors: [_primaryDark, _primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      color: _newPressed ? _primary.withOpacity(0.80) : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _newPressed
                          ? []
                          : [
                        BoxShadow(
                          color: _primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: AppColors.textOnDark, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'New Request',
                          style: TextStyle(
                            color: AppColors.textOnDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // History button
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.lightImpact();
                    setState(() => _historyPressed = true);
                  },
                  onTapUp: (_) => setState(() => _historyPressed = false),
                  onTapCancel: () =>
                      setState(() => _historyPressed = false),
                  onTap: () => _openHistory(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 44,
                    decoration: BoxDecoration(
                      color: _historyPressed ? _historyPres : _historyBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            color: AppColors.textPrimary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'History',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}