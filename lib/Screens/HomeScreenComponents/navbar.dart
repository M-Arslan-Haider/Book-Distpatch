
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  /// Pass the logged-in user's name and initials from your controller/auth.
  final String userName;
  final String userInitials;

  /// Reactive last-sync label (e.g. from your HomeController).
  /// Falls back to "Just now" when null.
  final String? lastSync;

  /// Optional: Pass scaffold key to open drawer
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const Navbar({
    super.key,
    this.userName = 'Ahmed Khan',
    this.userInitials = 'AK',
    this.lastSync,
    this.scaffoldKey,
  });

  // ── Brand colours ────────────────────────────────────────────────────────
  static const Color _tealLight = Color(0xFF3DAF93);
  static const Color _tealDark  = Color(0xFF1A6E59);
  static const Color _greenDot  = Color(0xFF4ADE80);

  // ── Greeting based on time ───────────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── PreferredSizeWidget – sets AppBar height ─────────────────────────────
  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: preferredSize.height + topPad,
        padding: EdgeInsets.only(
          top: topPad + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_tealLight, _tealDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x331A6E59),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── LEFT: Avatar ───────────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.40),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                userInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── CENTER: Greeting + Name + Sync status (EXPANDED) ──────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _greenDot,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x554ADE80),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Sync: ${lastSync ?? 'Just now'}',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── RIGHT: Drawer Icon + Sync Button (BOTH on RIGHT) ──────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drawer Menu Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withOpacity(0.15),
                    highlightColor: Colors.white.withOpacity(0.08),
                    onTap: () {
                      if (scaffoldKey != null) {
                        scaffoldKey!.currentState?.openDrawer();
                      } else {
                        Scaffold.of(context).openDrawer();
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Sync Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withOpacity(0.15),
                    highlightColor: Colors.white.withOpacity(0.08),
                    onTap: () {
                      Get.showSnackbar(
                        GetSnackBar(
                          message: 'Syncing data...',
                          duration: const Duration(seconds: 2),
                          backgroundColor: _tealDark,
                          icon: const Icon(Icons.sync, color: Colors.white),
                          borderRadius: 10,
                          margin: const EdgeInsets.all(12),
                        ),
                      );

                      debugPrint('🔄 Manual sync triggered from navbar');

                      Future.delayed(const Duration(seconds: 2), () {
                        Get.showSnackbar(
                          const GetSnackBar(
                            message: 'Data synced successfully',
                            duration: Duration(seconds: 2),
                            backgroundColor: Color(0xFF10B981),
                            icon: Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                            ),
                            borderRadius: 10,
                            margin: EdgeInsets.all(12),
                          ),
                        );
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}