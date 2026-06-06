import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../AppColors.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'leave_screen.dart';
import 'loan_advance_screen.dart';        // ← New Loan / Advance screen
import 'loan_history_screen.dart';       // ← Loan / Advance History screen
import 'leave_report_get_screen.dart';   // ← Leave History screen



// ═══════════════════════════════════════════════════════════════════════════
// actions_screen.dart
//
// Actions Screen — Request / Expense / Others tabs
// Matches the UI from screenshots exactly.
//
// USAGE (in your main navigator / bottom nav onTap):
//   if (index == 1) {  // Actions tab index
//     Navigator.push(context, MaterialPageRoute(builder: (_) => const ActionsScreen()));
//   }
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
  // 0 = Request, 1 = Expense, 2 = Others
  int _selectedTab = 0;

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
    // _ActionCard(
    //   iconBg: Color(0xFF5C6BC0),
    //   icon: Icons.swap_horiz_rounded,
    //   title: 'Shift Swap',
    //   subtitle: 'Request a shift change with a colleague.',
    //   pendingCount: 0,
    // ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      bottomNavigationBar: widget.onNavTap != null
          ? AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: widget.onNavTap!,
      )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
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

            // ── Subtitle ─────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Manage your workplace actions such as leave requests,\nexpense claims, complaints, and suggestions.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _textGray,
                  height: 1.5,
                ),
              ),
            ),

            // ── Tab selector ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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

            // ── Cards list ─────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: ListView.separated(
                  key: ValueKey(_selectedTab),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _currentCards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) =>
                      _ActionCardWidget(card: _currentCards[index]),
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
// Tab Button
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
// Action Card Data Model
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
// Action Card Widget
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

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top colored accent strip ─────────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: card.iconBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon + Title row ────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: card.iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(card.icon, color: AppColors.textOnDark, size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                card.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const Spacer(),
                              // Pending badge
                              if (card.pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            card.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Buttons row ─────────────────────────────────
                Row(
                  children: [
                    // New Request button
                    Expanded(
                      flex: 5,
                      child: GestureDetector(
                        onTapDown: (_) {
                          HapticFeedback.lightImpact();
                          setState(() => _newPressed = true);
                        },
                        onTapUp: (_) => setState(() => _newPressed = false),
                        onTapCancel: () => setState(() => _newPressed = false),
                        onTap: () {
                          // ── Leaves → navigate to Leaves screen ──────
                          if (card.title == 'Leaves') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                    LeaveScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end   = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                            return;
                          }
                          // ── Half Day → navigate to Leaves screen ─────
                          if (card.title == 'Half Day') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                    LeaveScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end   = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                            return;
                          }
                          // ── Loan / Advance → open bottom sheet ──────
                          if (card.title == 'Loan / Advance') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              useSafeArea: true,
                              builder: (_) => const LoanAdvanceScreen(),
                            );
                            return;
                          }
                          // TODO: Navigate to other request forms
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          height: 44,
                          decoration: BoxDecoration(
                            color: _newPressed ? _primaryDark : _primary,
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
                        onTap: () {
                          // ── Leaves → open leave history screen ──────
                          if (card.title == 'Leaves') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                const LeaveHistoryScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end   = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                            return;
                          }
                          // ── Half Day → open leave history screen ─────
                          if (card.title == 'Half Day') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                const LeaveHistoryScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end   = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                            return;
                          }
                          // ── Loan / Advance → open history screen ────
                          if (card.title == 'Loan / Advance') {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation,
                                    secondaryAnimation) =>
                                const LoanHistoryScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end   = Offset.zero;
                                  const curve = Curves.easeOutCubic;
                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                const Duration(milliseconds: 300),
                              ),
                            );
                            return;
                          }
                          // TODO: Navigate to other history screens
                        },
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
          ),
        ],
      ),
    );
  }
}