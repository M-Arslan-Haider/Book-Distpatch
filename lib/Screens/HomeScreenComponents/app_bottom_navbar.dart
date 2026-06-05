import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../actions_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
// app_bottom_navbar.dart  —  Clean version
//
// The bottom nav bar ONLY navigates to screens.
// All card-specific logic (Loan Advance, Leaves, etc.) stays inside
// actions_screen.dart where it belongs.
// ═══════════════════════════════════════════════════════════════════════════

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.chatBadgeCount = 0,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();

  late final List<AnimationController> _pressControllers;
  late final List<Animation<double>> _pressAnimations;

  // ── Design Tokens ──────────────────────────────────────────────────────
  static const _bgColor     = Color(0xFFFFFFFF);
  static const _borderColor = Color(0xFFE5E7EB);
  static const _primary     = Color(0xFF0C6B64);
  static const _primaryLit  = Color(0xFF14B8A6);
  static const _mutedIcon   = Color(0xFFA0A8B0);
  static const _mutedLabel  = Color(0xFFB0B8C0);

  static const _pillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0F5F3), Color(0xFFCCEEEB)],
  );

  static const _iconGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C6B64), Color(0xFF14B8A6)],
  );

  static const _tabs = [
    _NavTab(icon: Icons.home_rounded,           activeIcon: Icons.home,                label: 'Home'),
    _NavTab(icon: Icons.bolt_outlined,           activeIcon: Icons.bolt_rounded,        label: 'Actions'),
    _NavTab(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,      label: 'Schedule'),
    _NavTab(icon: Icons.checklist_outlined,      activeIcon: Icons.checklist_rounded,   label: 'Tasks'),
    _NavTab(icon: Icons.chat_bubble_outline,     activeIcon: Icons.chat_bubble_rounded, label: 'Chat', hasChat: true),
    _NavTab(icon: Icons.coffee_outlined,         activeIcon: Icons.coffee_rounded,      label: 'Breaks'),
    _NavTab(icon: Icons.business_outlined,       activeIcon: Icons.business_rounded,    label: 'Company'),
  ];

  @override
  void initState() {
    super.initState();
    _pressControllers = List.generate(
      _tabs.length,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 200),
      ),
    );
    _pressAnimations = _pressControllers
        .map((c) => Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final c in _pressControllers) c.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.lightImpact();
    _pressControllers[index].forward().then((_) {
      _pressControllers[index].reverse();
    });

    // ── Actions tab (index 1) → open ActionsScreen ─────────────────────
    if (index == 1) {
      if (widget.currentIndex == 1) return; // Already on Actions screen
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ActionsScreen(
                currentIndex: 1,
                chatBadgeCount: widget.chatBadgeCount,
                onNavTap: (i) {
                  Navigator.pop(context);
                  widget.onTap(i);
                },
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Professional: gentle fade + subtle upward micro-slide (like iOS tab switch)
            final fadeTween = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );
            final slideTween = Tween<Offset>(
              begin: const Offset(0.0, 0.018), // only 1.8% upward — barely perceptible
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            ));
            final scaleTween = Tween<double>(begin: 0.97, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
            );
            return FadeTransition(
              opacity: fadeTween,
              child: ScaleTransition(
                scale: scaleTween,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: slideTween,
                  child: child,
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        border: const Border(
          top: BorderSide(color: _borderColor, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C6B64).withOpacity(0.06),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Top accent line ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x3314B8A6),
                    Color(0x660C6B64),
                    Color(0x3314B8A6),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // ── Scrollable tab row ─────────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              left: 40,
              right: 40,
              bottom: bottomPadding > 0 ? bottomPadding : 8,
            ),
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_tabs.length, _buildTab),
            ),
          ),

          // ── Left fade ──────────────────────────────────────────────────
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [_bgColor, _bgColor.withOpacity(0)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Right fade ─────────────────────────────────────────────────
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [_bgColor, _bgColor.withOpacity(0)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab      = _tabs[index];
    final isActive = widget.currentIndex == index;

    return AnimatedBuilder(
      animation: _pressAnimations[index],
      builder: (context, child) => Transform.scale(
        scale: _pressAnimations[index].value,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _handleTap(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 68,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconPill(
                  tab: tab,
                  isActive: isActive,
                  chatBadgeCount: widget.chatBadgeCount,
                  pillGradient: _pillGradient,
                  iconGradient: _iconGradient,
                  primary: _primary,
                  mutedIcon: _mutedIcon,
                ),

                const SizedBox(height: 5),

                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: isActive ? 0.2 : 0.1,
                    color: isActive ? _primary : _mutedLabel,
                    height: 1.0,
                  ),
                  child: Text(tab.label, textAlign: TextAlign.center),
                ),

                const SizedBox(height: 6),

                _DotIndicator(isActive: isActive, primary: _primary, accent: _primaryLit),

                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon Pill
// ─────────────────────────────────────────────────────────────────────────────
class _IconPill extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final int chatBadgeCount;
  final LinearGradient pillGradient;
  final LinearGradient iconGradient;
  final Color primary;
  final Color mutedIcon;

  const _IconPill({
    required this.tab,
    required this.isActive,
    required this.chatBadgeCount,
    required this.pillGradient,
    required this.iconGradient,
    required this.primary,
    required this.mutedIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      width: isActive ? 46 : 38,
      height: isActive ? 38 : 34,
      transform: isActive
          ? (Matrix4.identity()..translate(0.0, -4.0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        gradient: isActive ? pillGradient : null,
        borderRadius: BorderRadius.circular(isActive ? 14 : 11),
        border: isActive
            ? Border.all(
            color: const Color(0xFF0C6B64).withOpacity(0.12), width: 1)
            : null,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: const Color(0xFF0C6B64).withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: isActive ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: isActive
                ? ShaderMask(
              shaderCallback: (bounds) =>
                  iconGradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Icon(tab.activeIcon, size: 20, color: Colors.white),
            )
                : Icon(tab.icon, size: 18, color: mutedIcon),
          ),
          if (tab.hasChat && chatBadgeCount > 0)
            Positioned(
              top: 4,
              right: 4,
              child: _ChatBadge(count: chatBadgeCount),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Badge
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBadge extends StatefulWidget {
  final int count;
  const _ChatBadge({required this.count});

  @override
  State<_ChatBadge> createState() => _ChatBadgeState();
}

class _ChatBadgeState extends State<_ChatBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.count > 9 ? '9+' : '${widget.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot Indicator
// ─────────────────────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final bool isActive;
  final Color primary;
  final Color accent;

  const _DotIndicator({
    required this.isActive,
    required this.primary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 380),
      curve: isActive ? Curves.elasticOut : Curves.easeIn,
      builder: (_, v, __) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: v.clamp(0.0, 1.0),
          child: Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, accent]),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final bool     hasChat;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.hasChat = false,
  });
}


