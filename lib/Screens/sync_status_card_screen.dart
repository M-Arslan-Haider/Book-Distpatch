// // import 'dart:async';
// // import 'package:connectivity_plus/connectivity_plus.dart';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:intl/intl.dart';
// //
// // // ⚠️  Adjust this import path to match your project structure
// // import '../Database/db_helper.dart';
// //
// //
// // // ═══════════════════════════════════════════════════════════════════════════════
// // // sync_status_card.dart  —  SyncController + SyncStatusCard (ek hi file)
// // //
// // // SETUP — timer_card.dart mein sirf 4 lines add karo:
// // //
// // //   1) Import (top par):
// // //        import 'sync_status_card.dart';
// // //
// // //   2) initState() mein _startAutoSyncMonitoring() se PEHLE:
// // //        SyncController.init();
// // //
// // //   3) _startAutoSyncMonitoring() mein _isOnline = ... ke BAAD:
// // //        SyncController.maybeSetOnline(_isOnline);
// // //
// // //   4) _triggerAutoSync() ke finally block mein _isSyncing = false ke BAAD:
// // //        SyncController.maybeComplete();
// // //
// // // USAGE — home_screen.dart build() mein:
// // //        SyncStatusCard(onSyncNow: _doSync),
// // // ═══════════════════════════════════════════════════════════════════════════════
// //
// //
// // // ───────────────────────────────────────────────────────────────────────────────
// // // PART 1 — SyncController (GetX)
// // // ───────────────────────────────────────────────────────────────────────────────
// // class SyncController extends GetxController {
// //
// //   // ── Singleton helpers (safe — no crash if not yet registered) ──────────────
// //   static void init() {
// //     if (!Get.isRegistered<SyncController>()) {
// //       Get.put(SyncController(), permanent: true);
// //     }
// //   }
// //
// //   static void maybeSetOnline(bool value) {
// //     if (Get.isRegistered<SyncController>()) {
// //       SyncController.to.setOnline(value);
// //     }
// //   }
// //
// //   static void maybeComplete() {
// //     if (Get.isRegistered<SyncController>()) {
// //       SyncController.to.onSyncComplete();
// //     }
// //   }
// //
// //   static void maybeStart() {
// //     if (Get.isRegistered<SyncController>()) {
// //       SyncController.to.onSyncStart();
// //     }
// //   }
// //
// //   static SyncController get to => Get.find<SyncController>();
// //
// //   // ── Observable state ────────────────────────────────────────────────────────
// //   final RxBool   isOnline     = false.obs;
// //   final RxString lastSyncAt   = ''.obs;    // '' = "Just now"
// //   final RxInt    pendingCount = 0.obs;
// //   final RxBool   isSyncing    = false.obs;
// //
// //   /// Per-table breakdown: label → unsynced count (only non-zero entries).
// //   /// Populated from real SQLite DB on every _refreshPending() call.
// //   final Rx<Map<String, int>> pendingBreakdown = Rx<Map<String, int>>({});
// //
// //   // ── Internal ─────────────────────────────────────────────────────────────────
// //   final Connectivity _connectivity = Connectivity();
// //   StreamSubscription<List<ConnectivityResult>>? _connSub;
// //   Timer? _pendingTimer;
// //
// //   @override
// //   void onInit() {
// //     super.onInit();
// //     _listenConnectivity();
// //     _checkConnectivityNow();
// //     _startPendingCheck();
// //   }
// //
// //   @override
// //   void onClose() {
// //     _connSub?.cancel();
// //     _pendingTimer?.cancel();
// //     super.onClose();
// //   }
// //
// //   // ── Real-time connectivity stream ────────────────────────────────────────────
// //   void _listenConnectivity() {
// //     _connSub = _connectivity.onConnectivityChanged.listen((results) {
// //       isOnline.value = _hasConnection(results);
// //     });
// //   }
// //
// //   void _checkConnectivityNow() async {
// //     try {
// //       final r = await _connectivity.checkConnectivity();
// //       isOnline.value = _hasConnection(r);
// //     } catch (_) {}
// //   }
// //
// //   bool _hasConnection(List<ConnectivityResult> r) =>
// //       r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);
// //
// //   // ── Called by timer_card ─────────────────────────────────────────────────────
// //   void setOnline(bool value) => isOnline.value = value;
// //
// //   void onSyncStart() => isSyncing.value = true;
// //
// //   void onSyncComplete() {
// //     isSyncing.value  = false;
// //     lastSyncAt.value = DateFormat('hh:mm a').format(DateTime.now());
// //     _refreshPending();
// //   }
// //
// //   // ── Pending items: read from real SQLite DB every 30s ────────────────────────
// //   void _startPendingCheck() {
// //     _refreshPending();
// //     _pendingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPending());
// //   }
// //
// //   Future<void> _refreshPending() async {
// //     try {
// //       final counts = await DBHelper().getUnpostedCountsFromDB();
// //       pendingBreakdown.value = counts;
// //       pendingCount.value     = counts.values.fold(0, (sum, v) => sum + v);
// //     } catch (_) {}
// //   }
// //
// //   /// Call this after any data save so count updates immediately.
// //   void refreshPending() => _refreshPending();
// // }
// //
// //
// // // ───────────────────────────────────────────────────────────────────────────────
// // // PART 2 — SyncStatusCard Widget
// // // ───────────────────────────────────────────────────────────────────────────────
// // class SyncStatusCard extends StatefulWidget {
// //   /// Existing _doSync() from home_screen.dart
// //   final VoidCallback? onSyncNow;
// //   /// Optional: open pending items sheet
// //   final VoidCallback? onViewPending;
// //
// //   const SyncStatusCard({
// //     super.key,
// //     this.onSyncNow,
// //     this.onViewPending,
// //   });
// //
// //   @override
// //   State<SyncStatusCard> createState() => _SyncStatusCardState();
// // }
// //
// // class _SyncStatusCardState extends State<SyncStatusCard>
// //     with TickerProviderStateMixin {
// //
// //   // Offline card glow pulse  (2.6 s — matches HTML syncOfflinePulse)
// //   late final AnimationController _pulseCtrl;
// //   late final Animation<double>   _pulseAnim;
// //
// //   // Dot blink  (1.4 s — matches HTML pulseDot)
// //   late final AnimationController _dotCtrl;
// //   late final Animation<double>   _dotAnim;
// //
// //   // ── Color palette (exact HTML CSS vars) ──────────────────────────────────────
// //   static const _cardBg      = Color(0xFFFFFFFF); // --surface
// //   static const _border      = Color(0xFFE7E5D9); // --border
// //   static const _textPri     = Color(0xFF1F2937); // --text
// //   static const _textSec     = Color(0xFF475569); // --text-2
// //   static const _primary     = Color(0xFF0F766E); // --primary
// //   static const _warning     = Color(0xFFF59E0B); // --warning
// //   static const _softSuccess = Color(0xFFDCFCE7); // --soft-success
// //   static const _softWarn    = Color(0xFFFEF3C7); // --soft-warning
// //   static const _onlineTxt   = Color(0xFF15803D);
// //   static const _offlineTxt  = Color(0xFFB45309);
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Make sure controller is up
// //     SyncController.init();
// //
// //     _pulseCtrl = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 2600),
// //     )..repeat(reverse: true);
// //     _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
// //
// //     _dotCtrl = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 1400),
// //     )..repeat(reverse: true);
// //     _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);
// //   }
// //
// //   @override
// //   void dispose() {
// //     _pulseCtrl.dispose();
// //     _dotCtrl.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Obx(() {
// //       final ctrl      = SyncController.to;
// //       final offline   = !ctrl.isOnline.value;
// //       final syncing   = ctrl.isSyncing.value;
// //       final pending   = ctrl.pendingCount.value;
// //       final breakdown = ctrl.pendingBreakdown.value;
// //       final lastSync  = ctrl.lastSyncAt.value.isEmpty ? 'Just now' : ctrl.lastSyncAt.value;
// //       final connLabel = offline ? 'Disconnected' : 'Connected';
// //
// //       return AnimatedBuilder(
// //         animation: _pulseAnim,
// //         builder: (_, child) {
// //           final glowAlpha  = offline ? (1 - _pulseAnim.value) * 0.35 : 0.0;
// //           final glowSpread = offline ? _pulseAnim.value * 6.0 : 0.0;
// //
// //           return Container(
// //             margin: const EdgeInsets.only(bottom: 14),
// //             decoration: BoxDecoration(
// //               color: _cardBg,
// //               borderRadius: BorderRadius.circular(16),
// //               border: Border.all(
// //                 color: offline ? _warning.withOpacity(0.5) : _border,
// //               ),
// //               boxShadow: [
// //                 BoxShadow(
// //                   color: const Color(0xFF0F766E).withOpacity(0.07),
// //                   blurRadius: 14,
// //                   offset: const Offset(0, 4),
// //                 ),
// //                 if (offline)
// //                   BoxShadow(
// //                     color: _warning.withOpacity(glowAlpha),
// //                     blurRadius: glowSpread + 4,
// //                     spreadRadius: glowSpread / 2,
// //                   ),
// //               ],
// //             ),
// //             child: child,
// //           );
// //         },
// //         child: Padding(
// //           padding: const EdgeInsets.all(14),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               _topRow(offline: offline, syncing: syncing),
// //               const SizedBox(height: 2),
// //               _row('Last Sync',          lastSync),
// //               _row('Pending Sync Items', '$pending'),
// //               // ── Real DB breakdown chips (only shown when there's something pending)
// //               if (pending > 0) _pendingBreakdown(breakdown),
// //               _row('Server Connection',  connLabel, isLast: true),
// //               const SizedBox(height: 12),
// //               _bottomRow(pending: pending, syncing: syncing),
// //               if (pending > 0 && widget.onViewPending != null) ...[
// //                 const SizedBox(height: 8),
// //                 Center(
// //                   child: GestureDetector(
// //                     onTap: widget.onViewPending,
// //                     child: Text(
// //                       'View More ($pending)',
// //                       style: const TextStyle(
// //                         fontSize: 11,
// //                         fontWeight: FontWeight.w600,
// //                         color: _primary,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ],
// //           ),
// //         ),
// //       );
// //     });
// //   }
// //
// //   // ── Top row ──────────────────────────────────────────────────────────────────
// //   Widget _topRow({required bool offline, required bool syncing}) {
// //     return Row(
// //       children: [
// //         // Cloud icon / spinner
// //         AnimatedSwitcher(
// //           duration: const Duration(milliseconds: 300),
// //           child: syncing
// //               ? const SizedBox(
// //             key: ValueKey('spin'),
// //             width: 14, height: 14,
// //             child: CircularProgressIndicator(strokeWidth: 1.8, color: _primary),
// //           )
// //               : const Icon(key: ValueKey('cloud'),
// //               Icons.cloud_upload_rounded, size: 14, color: _textPri),
// //         ),
// //         const SizedBox(width: 6),
// //         const Text(
// //           'Sync Status',
// //           style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPri),
// //         ),
// //         const Spacer(),
// //         _pill(offline: offline),
// //       ],
// //     );
// //   }
// //
// //   // ── Online / Offline pill ────────────────────────────────────────────────────
// //   Widget _pill({required bool offline}) {
// //     return AnimatedBuilder(
// //       animation: _dotAnim,
// //       builder: (_, __) {
// //         return AnimatedContainer(
// //           duration: const Duration(milliseconds: 400),
// //           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
// //           decoration: BoxDecoration(
// //             color: offline ? _softWarn : _softSuccess,
// //             borderRadius: BorderRadius.circular(11),
// //           ),
// //           child: Row(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               Transform.scale(
// //                 scale: 0.75 + _dotAnim.value * 0.25,
// //                 child: Container(
// //                   width: 7, height: 7,
// //                   decoration: BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     color: offline ? _offlineTxt : _onlineTxt,
// //                   ),
// //                 ),
// //               ),
// //               const SizedBox(width: 5),
// //               AnimatedDefaultTextStyle(
// //                 duration: const Duration(milliseconds: 300),
// //                 style: TextStyle(
// //                   fontSize: 10,
// //                   fontWeight: FontWeight.w700,
// //                   color: offline ? _offlineTxt : _onlineTxt,
// //                 ),
// //                 child: Text(offline ? 'Offline' : 'Online'),
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }
// //
// //   // ── Info row ─────────────────────────────────────────────────────────────────
// //   Widget _row(String label, String value, {bool isLast = false}) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(vertical: 6),
// //       decoration: const BoxDecoration(
// //         border: Border(top: BorderSide(color: _border)),
// //       ),
// //       child: Row(
// //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //         children: [
// //           Text(label,
// //               style: const TextStyle(fontSize: 11, color: _textSec)),
// //           Text(value,
// //               style: const TextStyle(
// //                 fontSize: 11, fontWeight: FontWeight.w700,
// //                 color: _textPri, fontFamily: 'monospace',
// //               )),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Per-table breakdown chips (shown when pending > 0) ────────────────────────
// //   Widget _pendingBreakdown(Map<String, int> items) {
// //     if (items.isEmpty) return const SizedBox.shrink();
// //     return Container(
// //       padding: const EdgeInsets.only(top: 5, bottom: 7),
// //       decoration: const BoxDecoration(
// //         border: Border(top: BorderSide(color: _border)),
// //       ),
// //       child: Wrap(
// //         spacing: 5,
// //         runSpacing: 5,
// //         children: items.entries.map((e) {
// //           return Container(
// //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
// //             decoration: BoxDecoration(
// //               color: _softWarn,
// //               borderRadius: BorderRadius.circular(6),
// //               border: Border.all(color: _warning.withOpacity(0.35)),
// //             ),
// //             child: Text(
// //               '${e.key}  ${e.value}',
// //               style: const TextStyle(
// //                 fontSize: 10,
// //                 fontWeight: FontWeight.w700,
// //                 color: _offlineTxt,
// //               ),
// //             ),
// //           );
// //         }).toList(),
// //       ),
// //     );
// //   }
// //
// //   // ── Offline tap feedback (no sync, no success message) ──────────────────────
// //   void _showOfflineMessage() {
// //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         behavior: SnackBarBehavior.floating,
// //         elevation: 0,
// //         backgroundColor: Colors.transparent,
// //         duration: const Duration(seconds: 3),
// //         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //         padding: EdgeInsets.zero,
// //         content: Container(
// //           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
// //           decoration: BoxDecoration(
// //             color: const Color(0xFFFFFBEB),
// //             borderRadius: BorderRadius.circular(12),
// //             border: Border.all(color: _warning.withOpacity(0.4)),
// //             boxShadow: [
// //               BoxShadow(
// //                 color: Colors.black.withOpacity(0.08),
// //                 blurRadius: 12,
// //                 offset: const Offset(0, 4),
// //               ),
// //             ],
// //           ),
// //           child: Row(
// //             children: [
// //               Container(
// //                 padding: const EdgeInsets.all(6),
// //                 decoration: BoxDecoration(
// //                   color: _softWarn,
// //                   shape: BoxShape.circle,
// //                 ),
// //                 child: const Icon(Icons.wifi_off_rounded,
// //                     size: 14, color: _offlineTxt),
// //               ),
// //               const SizedBox(width: 10),
// //               const Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   mainAxisSize: MainAxisSize.min,
// //                   children: [
// //                     Text(
// //                       'No Internet Connection',
// //                       style: TextStyle(
// //                         fontSize: 12.5,
// //                         fontWeight: FontWeight.w700,
// //                         color: _offlineTxt,
// //                       ),
// //                     ),
// //                     SizedBox(height: 2),
// //                     Text(
// //                       'Please reconnect and try syncing again.',
// //                       style: TextStyle(
// //                         fontSize: 11,
// //                         fontWeight: FontWeight.w500,
// //                         color: _textSec,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── Sync Now button ──────────────────────────────────────────────────────────
// //   Widget _bottomRow({required int pending, required bool syncing}) {
// //     if (pending == 0 && !syncing) return const SizedBox.shrink();
// //
// //     return Align(
// //       alignment: Alignment.centerRight,
// //       child: GestureDetector(
// //         onTap: syncing
// //             ? null
// //             : () {
// //           if (!SyncController.to.isOnline.value) {
// //             _showOfflineMessage();
// //             return;
// //           }
// //           SyncController.maybeStart();
// //           widget.onSyncNow?.call();
// //         },
// //         child: AnimatedContainer(
// //           duration: const Duration(milliseconds: 300),
// //           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
// //           decoration: BoxDecoration(
// //             gradient: syncing
// //                 ? null
// //                 : const LinearGradient(
// //               colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
// //             ),
// //             color: syncing ? _border : null,
// //             borderRadius: BorderRadius.circular(10),
// //             boxShadow: syncing
// //                 ? []
// //                 : [
// //               BoxShadow(
// //                 color: _primary.withOpacity(0.25),
// //                 blurRadius: 8,
// //                 offset: const Offset(0, 3),
// //               )
// //             ],
// //           ),
// //           child: Row(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               if (syncing)
// //                 const SizedBox(
// //                   width: 11, height: 11,
// //                   child: CircularProgressIndicator(
// //                       strokeWidth: 1.6, color: _textSec),
// //                 )
// //               else
// //                 const Icon(Icons.sync_rounded, color: Colors.white, size: 13),
// //               const SizedBox(width: 5),
// //               Text(
// //                 syncing ? 'Syncing…' : 'Sync Now',
// //                 style: TextStyle(
// //                   color: syncing ? _textSec : Colors.white,
// //                   fontSize: 11,
// //                   fontWeight: FontWeight.w700,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
//
// import 'dart:async';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
//
// // ⚠️  Adjust this import path to match your project structure
// import '../Database/db_helper.dart';
//
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // sync_status_card.dart  —  SyncController + SyncStatusCard (ek hi file)
// //
// // SETUP — timer_card.dart mein sirf 4 lines add karo:
// //
// //   1) Import (top par):
// //        import 'sync_status_card.dart';
// //
// //   2) initState() mein _startAutoSyncMonitoring() se PEHLE:
// //        SyncController.init();
// //
// //   3) _startAutoSyncMonitoring() mein _isOnline = ... ke BAAD:
// //        SyncController.maybeSetOnline(_isOnline);
// //
// //   4) _triggerAutoSync() ke finally block mein _isSyncing = false ke BAAD:
// //        SyncController.maybeComplete();
// //
// // USAGE — home_screen.dart build() mein:
// //        SyncStatusCard(onSyncNow: _doSync),
// // ═══════════════════════════════════════════════════════════════════════════════
//
//
// // ───────────────────────────────────────────────────────────────────────────────
// // PART 1 — SyncController (GetX)
// // ───────────────────────────────────────────────────────────────────────────────
// class SyncController extends GetxController {
//
//   // ── Singleton helpers (safe — no crash if not yet registered) ──────────────
//   static void init() {
//     if (!Get.isRegistered<SyncController>()) {
//       Get.put(SyncController(), permanent: true);
//     }
//   }
//
//   static void maybeSetOnline(bool value) {
//     if (Get.isRegistered<SyncController>()) {
//       SyncController.to.setOnline(value);
//     }
//   }
//
//   static void maybeComplete() {
//     if (Get.isRegistered<SyncController>()) {
//       SyncController.to.onSyncComplete();
//     }
//   }
//
//   static void maybeStart() {
//     if (Get.isRegistered<SyncController>()) {
//       SyncController.to.onSyncStart();
//     }
//   }
//
//   static SyncController get to => Get.find<SyncController>();
//
//   // ── Observable state ────────────────────────────────────────────────────────
//   final RxBool   isOnline     = false.obs;
//   final RxString lastSyncAt   = ''.obs;    // '' = "Just now"
//   final RxInt    pendingCount = 0.obs;
//   final RxBool   isSyncing    = false.obs;
//
//   /// Per-table breakdown: label → unsynced count (only non-zero entries).
//   /// Populated from real SQLite DB on every _refreshPending() call.
//   final Rx<Map<String, int>> pendingBreakdown = Rx<Map<String, int>>({});
//
//   // ── Internal ─────────────────────────────────────────────────────────────────
//   final Connectivity _connectivity = Connectivity();
//   StreamSubscription<List<ConnectivityResult>>? _connSub;
//   Timer? _pendingTimer;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _listenConnectivity();
//     _checkConnectivityNow();
//     _startPendingCheck();
//   }
//
//   @override
//   void onClose() {
//     _connSub?.cancel();
//     _pendingTimer?.cancel();
//     super.onClose();
//   }
//
//   // ── Real-time connectivity stream ────────────────────────────────────────────
//   // Note: CustomerViewModel aur VisitViewModel apni khud ki connectivity
//   // listener rakhte hain (dekhein customer_view_model.dart / visit_view_model.dart
//   // ke onInit()), jo internet wapis aane par khud retryUnsyncedCustomers() /
//   // retryUnsyncedVisits() call kar deti hain. Is liye yahan CRM ViewModels ko
//   // dobara reference karne ki zaroorat nahi — isse circular import bhi bachta hai.
//   void _listenConnectivity() {
//     _connSub = _connectivity.onConnectivityChanged.listen((results) {
//       isOnline.value = _hasConnection(results);
//     });
//   }
//
//   void _checkConnectivityNow() async {
//     try {
//       final r = await _connectivity.checkConnectivity();
//       isOnline.value = _hasConnection(r);
//     } catch (_) {}
//   }
//
//   bool _hasConnection(List<ConnectivityResult> r) =>
//       r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);
//
//   // ── Called by timer_card ─────────────────────────────────────────────────────
//   void setOnline(bool value) => isOnline.value = value;
//
//   void onSyncStart() => isSyncing.value = true;
//
//   void onSyncComplete() {
//     isSyncing.value  = false;
//     lastSyncAt.value = DateFormat('hh:mm a').format(DateTime.now());
//     _refreshPending();
//   }
//
//   // ── Pending items: read from real SQLite DB every 30s ────────────────────────
//   void _startPendingCheck() {
//     _refreshPending();
//     _pendingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPending());
//   }
//
//   Future<void> _refreshPending() async {
//     try {
//       final counts = await DBHelper().getUnpostedCountsFromDB();
//       pendingBreakdown.value = counts;
//       pendingCount.value     = counts.values.fold(0, (sum, v) => sum + v);
//     } catch (_) {}
//   }
//
//   /// Call this after any data save so count updates immediately.
//   void refreshPending() => _refreshPending();
// }
//
//
// // ───────────────────────────────────────────────────────────────────────────────
// // PART 2 — SyncStatusCard Widget
// // ───────────────────────────────────────────────────────────────────────────────
// class SyncStatusCard extends StatefulWidget {
//   /// Existing _doSync() from home_screen.dart
//   final VoidCallback? onSyncNow;
//   /// Optional: open pending items sheet
//   final VoidCallback? onViewPending;
//
//   const SyncStatusCard({
//     super.key,
//     this.onSyncNow,
//     this.onViewPending,
//   });
//
//   @override
//   State<SyncStatusCard> createState() => _SyncStatusCardState();
// }
//
// class _SyncStatusCardState extends State<SyncStatusCard>
//     with TickerProviderStateMixin {
//
//   // Offline card glow pulse  (2.6 s — matches HTML syncOfflinePulse)
//   late final AnimationController _pulseCtrl;
//   late final Animation<double>   _pulseAnim;
//
//   // Dot blink  (1.4 s — matches HTML pulseDot)
//   late final AnimationController _dotCtrl;
//   late final Animation<double>   _dotAnim;
//
//   // ── Color palette (exact HTML CSS vars) ──────────────────────────────────────
//   static const _cardBg      = Color(0xFFFFFFFF); // --surface
//   static const _border      = Color(0xFFE7E5D9); // --border
//   static const _textPri     = Color(0xFF1F2937); // --text
//   static const _textSec     = Color(0xFF475569); // --text-2
//   static const _primary     = Color(0xFF0F766E); // --primary
//   static const _warning     = Color(0xFFF59E0B); // --warning
//   static const _softSuccess = Color(0xFFDCFCE7); // --soft-success
//   static const _softWarn    = Color(0xFFFEF3C7); // --soft-warning
//   static const _onlineTxt   = Color(0xFF15803D);
//   static const _offlineTxt  = Color(0xFFB45309);
//
//   @override
//   void initState() {
//     super.initState();
//     // Make sure controller is up
//     SyncController.init();
//
//     _pulseCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2600),
//     )..repeat(reverse: true);
//     _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
//
//     _dotCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat(reverse: true);
//     _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);
//   }
//
//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _dotCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(() {
//       final ctrl      = SyncController.to;
//       final offline   = !ctrl.isOnline.value;
//       final syncing   = ctrl.isSyncing.value;
//       final pending   = ctrl.pendingCount.value;
//       final breakdown = ctrl.pendingBreakdown.value;
//       final lastSync  = ctrl.lastSyncAt.value.isEmpty ? 'Just now' : ctrl.lastSyncAt.value;
//       final connLabel = offline ? 'Disconnected' : 'Connected';
//
//       return AnimatedBuilder(
//         animation: _pulseAnim,
//         builder: (_, child) {
//           final glowAlpha  = offline ? (1 - _pulseAnim.value) * 0.35 : 0.0;
//           final glowSpread = offline ? _pulseAnim.value * 6.0 : 0.0;
//
//           return Container(
//             margin: const EdgeInsets.only(bottom: 14),
//             decoration: BoxDecoration(
//               color: _cardBg,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(
//                 color: offline ? _warning.withOpacity(0.5) : _border,
//               ),
//               boxShadow: [
//                 BoxShadow(
//                   color: const Color(0xFF0F766E).withOpacity(0.07),
//                   blurRadius: 14,
//                   offset: const Offset(0, 4),
//                 ),
//                 if (offline)
//                   BoxShadow(
//                     color: _warning.withOpacity(glowAlpha),
//                     blurRadius: glowSpread + 4,
//                     spreadRadius: glowSpread / 2,
//                   ),
//               ],
//             ),
//             child: child,
//           );
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(14),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _topRow(offline: offline, syncing: syncing),
//               const SizedBox(height: 2),
//               _row('Last Sync',          lastSync),
//               _row('Pending Sync Items', '$pending'),
//               // ── Real DB breakdown chips (only shown when there's something pending)
//               if (pending > 0) _pendingBreakdown(breakdown),
//               _row('Server Connection',  connLabel, isLast: true),
//               const SizedBox(height: 12),
//               _bottomRow(pending: pending, syncing: syncing),
//               if (pending > 0 && widget.onViewPending != null) ...[
//                 const SizedBox(height: 8),
//                 Center(
//                   child: GestureDetector(
//                     onTap: widget.onViewPending,
//                     child: Text(
//                       'View More ($pending)',
//                       style: const TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w600,
//                         color: _primary,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       );
//     });
//   }
//
//   // ── Top row ──────────────────────────────────────────────────────────────────
//   Widget _topRow({required bool offline, required bool syncing}) {
//     return Row(
//       children: [
//         // Cloud icon / spinner
//         AnimatedSwitcher(
//           duration: const Duration(milliseconds: 300),
//           child: syncing
//               ? const SizedBox(
//             key: ValueKey('spin'),
//             width: 14, height: 14,
//             child: CircularProgressIndicator(strokeWidth: 1.8, color: _primary),
//           )
//               : const Icon(key: ValueKey('cloud'),
//               Icons.cloud_upload_rounded, size: 14, color: _textPri),
//         ),
//         const SizedBox(width: 6),
//         const Text(
//           'Sync Status',
//           style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPri),
//         ),
//         const Spacer(),
//         _pill(offline: offline),
//       ],
//     );
//   }
//
//   // ── Online / Offline pill ────────────────────────────────────────────────────
//   Widget _pill({required bool offline}) {
//     return AnimatedBuilder(
//       animation: _dotAnim,
//       builder: (_, __) {
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 400),
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//           decoration: BoxDecoration(
//             color: offline ? _softWarn : _softSuccess,
//             borderRadius: BorderRadius.circular(11),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Transform.scale(
//                 scale: 0.75 + _dotAnim.value * 0.25,
//                 child: Container(
//                   width: 7, height: 7,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: offline ? _offlineTxt : _onlineTxt,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 5),
//               AnimatedDefaultTextStyle(
//                 duration: const Duration(milliseconds: 300),
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w700,
//                   color: offline ? _offlineTxt : _onlineTxt,
//                 ),
//                 child: Text(offline ? 'Offline' : 'Online'),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   // ── Info row ─────────────────────────────────────────────────────────────────
//   Widget _row(String label, String value, {bool isLast = false}) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       decoration: const BoxDecoration(
//         border: Border(top: BorderSide(color: _border)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label,
//               style: const TextStyle(fontSize: 11, color: _textSec)),
//           Text(value,
//               style: const TextStyle(
//                 fontSize: 11, fontWeight: FontWeight.w700,
//                 color: _textPri, fontFamily: 'monospace',
//               )),
//         ],
//       ),
//     );
//   }
//
//   // ── Per-table breakdown chips (shown when pending > 0) ────────────────────────
//   Widget _pendingBreakdown(Map<String, int> items) {
//     if (items.isEmpty) return const SizedBox.shrink();
//     return Container(
//       padding: const EdgeInsets.only(top: 5, bottom: 7),
//       decoration: const BoxDecoration(
//         border: Border(top: BorderSide(color: _border)),
//       ),
//       child: Wrap(
//         spacing: 5,
//         runSpacing: 5,
//         children: items.entries.map((e) {
//           return Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//             decoration: BoxDecoration(
//               color: _softWarn,
//               borderRadius: BorderRadius.circular(6),
//               border: Border.all(color: _warning.withOpacity(0.35)),
//             ),
//             child: Text(
//               '${e.key}  ${e.value}',
//               style: const TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w700,
//                 color: _offlineTxt,
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
//
//   // ── Offline tap feedback (no sync, no success message) ──────────────────────
//   void _showOfflineMessage() {
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         behavior: SnackBarBehavior.floating,
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         duration: const Duration(seconds: 3),
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         padding: EdgeInsets.zero,
//         content: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//           decoration: BoxDecoration(
//             color: const Color(0xFFFFFBEB),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: _warning.withOpacity(0.4)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.08),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(6),
//                 decoration: BoxDecoration(
//                   color: _softWarn,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.wifi_off_rounded,
//                     size: 14, color: _offlineTxt),
//               ),
//               const SizedBox(width: 10),
//               const Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       'No Internet Connection',
//                       style: TextStyle(
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w700,
//                         color: _offlineTxt,
//                       ),
//                     ),
//                     SizedBox(height: 2),
//                     Text(
//                       'Please reconnect and try syncing again.',
//                       style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w500,
//                         color: _textSec,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Sync Now button ──────────────────────────────────────────────────────────
//   Widget _bottomRow({required int pending, required bool syncing}) {
//     if (pending == 0 && !syncing) return const SizedBox.shrink();
//
//     return Align(
//       alignment: Alignment.centerRight,
//       child: GestureDetector(
//         onTap: syncing
//             ? null
//             : () {
//           if (!SyncController.to.isOnline.value) {
//             _showOfflineMessage();
//             return;
//           }
//           SyncController.maybeStart();
//           widget.onSyncNow?.call();
//         },
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//           decoration: BoxDecoration(
//             gradient: syncing
//                 ? null
//                 : const LinearGradient(
//               colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
//             ),
//             color: syncing ? _border : null,
//             borderRadius: BorderRadius.circular(10),
//             boxShadow: syncing
//                 ? []
//                 : [
//               BoxShadow(
//                 color: _primary.withOpacity(0.25),
//                 blurRadius: 8,
//                 offset: const Offset(0, 3),
//               )
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (syncing)
//                 const SizedBox(
//                   width: 11, height: 11,
//                   child: CircularProgressIndicator(
//                       strokeWidth: 1.6, color: _textSec),
//                 )
//               else
//                 const Icon(Icons.sync_rounded, color: Colors.white, size: 13),
//               const SizedBox(width: 5),
//               Text(
//                 syncing ? 'Syncing…' : 'Sync Now',
//                 style: TextStyle(
//                   color: syncing ? _textSec : Colors.white,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


// lib/Widgets/sync_status_card_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────────────────────────────────────────────────────────────
// PART 1 — SyncController (GetX)
// ───────────────────────────────────────────────────────────────────────────────
class SyncController extends GetxController {

  // ── Singleton helpers ──────────────────────────────────────────────────────
  static void init() {
    if (!Get.isRegistered<SyncController>()) {
      Get.put(SyncController(), permanent: true);
    }
  }

  static void maybeSetOnline(bool value) {
    if (Get.isRegistered<SyncController>()) {
      SyncController.to.setOnline(value);
    }
  }

  static void maybeComplete() {
    if (Get.isRegistered<SyncController>()) {
      SyncController.to.onSyncComplete();
    }
  }

  static void maybeStart() {
    if (Get.isRegistered<SyncController>()) {
      SyncController.to.onSyncStart();
    }
  }

  static SyncController get to => Get.find<SyncController>();

  // ── Observable state ────────────────────────────────────────────────────────
  final RxBool   isOnline     = false.obs;
  final RxString lastSyncAt   = ''.obs;
  final RxInt    pendingCount = 0.obs;
  final RxBool   isSyncing    = false.obs;

  /// Per-table breakdown: label → unsynced count
  final Rx<Map<String, int>> pendingBreakdown = Rx<Map<String, int>>({});

  // ── Internal ─────────────────────────────────────────────────────────────────
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _pendingTimer;

  // ── CRM ViewModels (lazy loaded via Get.find) ──────────────────────────────
  // CustomerViewModel, VisitViewModel, FollowupViewModel apni khud ki
  // connectivity listener rakhte hain (onInit mein), jo internet wapas
  // ane par auto-sync call kar deti hain.
  // Is liye yahan unhe reference nahi kar rahe.

  @override
  void onInit() {
    super.onInit();
    _listenConnectivity();
    _checkConnectivityNow();
    _startPendingCheck();
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _pendingTimer?.cancel();
    super.onClose();
  }

  void _listenConnectivity() {
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
    });
  }

  void _checkConnectivityNow() async {
    try {
      final r = await _connectivity.checkConnectivity();
      isOnline.value = _hasConnection(r);
    } catch (_) {}
  }

  bool _hasConnection(List<ConnectivityResult> r) =>
      r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);

  void setOnline(bool value) => isOnline.value = value;

  void onSyncStart() => isSyncing.value = true;

  void onSyncComplete() {
    isSyncing.value  = false;
    lastSyncAt.value = DateFormat('hh:mm a').format(DateTime.now());
    _refreshPending();
  }

  // ── Pending items: read from SharedPreferences cache ──────────────────────
  // SQLite ke bajaye SharedPreferences se read karte hain kyunki
  // Customer/Visit/Followup ViewModels SharedPreferences use karte hain.
  void _startPendingCheck() {
    _refreshPending();
    _pendingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPending());
  }

  Future<void> _refreshPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = <String, int>{};

      // Check Customers
      final customersRaw = prefs.getString('gps_customers_v1');
      if (customersRaw != null && customersRaw.isNotEmpty) {
        final customers = jsonDecode(customersRaw) as List;
        final unsynced = customers.where((c) => c['posted'] == false).length;
        if (unsynced > 0) counts['Customers'] = unsynced;
      }

      // Check Visits
      final visitsRaw = prefs.getString('gps_visits_v1');
      if (visitsRaw != null && visitsRaw.isNotEmpty) {
        final visits = jsonDecode(visitsRaw) as List;
        final unsynced = visits.where((v) => v['posted'] == false).length;
        if (unsynced > 0) counts['Visits'] = unsynced;
      }

      // Check Followups
      final followupsRaw = prefs.getString('gps_followups_v1');
      if (followupsRaw != null && followupsRaw.isNotEmpty) {
        final followups = jsonDecode(followupsRaw) as List;
        final unsynced = followups.where((f) => f['posted'] == false).length;
        if (unsynced > 0) counts['Follow-ups'] = unsynced;
      }

      pendingBreakdown.value = counts;
      pendingCount.value = counts.values.fold(0, (sum, v) => sum + v);
    } catch (_) {}
  }

  /// Call this after any data save so count updates immediately.
  void refreshPending() => _refreshPending();
}

// ───────────────────────────────────────────────────────────────────────────────
// PART 2 — SyncStatusCard Widget
// ───────────────────────────────────────────────────────────────────────────────
class SyncStatusCard extends StatefulWidget {
  final VoidCallback? onSyncNow;
  final VoidCallback? onViewPending;

  const SyncStatusCard({
    super.key,
    this.onSyncNow,
    this.onViewPending,
  });

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _dotCtrl;
  late final Animation<double>   _dotAnim;

  static const _cardBg      = Color(0xFFFFFFFF);
  static const _border      = Color(0xFFE7E5D9);
  static const _textPri     = Color(0xFF1F2937);
  static const _textSec     = Color(0xFF475569);
  static const _primary     = Color(0xFF0F766E);
  static const _warning     = Color(0xFFF59E0B);
  static const _softSuccess = Color(0xFFDCFCE7);
  static const _softWarn    = Color(0xFFFEF3C7);
  static const _onlineTxt   = Color(0xFF15803D);
  static const _offlineTxt  = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    SyncController.init();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ctrl      = SyncController.to;
      final offline   = !ctrl.isOnline.value;
      final syncing   = ctrl.isSyncing.value;
      final pending   = ctrl.pendingCount.value;
      final breakdown = ctrl.pendingBreakdown.value;
      final lastSync  = ctrl.lastSyncAt.value.isEmpty ? 'Just now' : ctrl.lastSyncAt.value;
      final connLabel = offline ? 'Disconnected' : 'Connected';

      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) {
          final glowAlpha  = offline ? (1 - _pulseAnim.value) * 0.35 : 0.0;
          final glowSpread = offline ? _pulseAnim.value * 6.0 : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: offline ? _warning.withOpacity(0.5) : _border,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                if (offline)
                  BoxShadow(
                    color: _warning.withOpacity(glowAlpha),
                    blurRadius: glowSpread + 4,
                    spreadRadius: glowSpread / 2,
                  ),
              ],
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topRow(offline: offline, syncing: syncing),
              const SizedBox(height: 2),
              _row('Last Sync',          lastSync),
              _row('Pending Sync Items', '$pending'),
              if (pending > 0) _pendingBreakdown(breakdown),
              _row('Server Connection',  connLabel, isLast: true),
              const SizedBox(height: 12),
              _bottomRow(pending: pending, syncing: syncing),
              if (pending > 0 && widget.onViewPending != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: widget.onViewPending,
                    child: Text(
                      'View More ($pending)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _topRow({required bool offline, required bool syncing}) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: syncing
              ? const SizedBox(
            key: ValueKey('spin'),
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: _primary),
          )
              : const Icon(key: ValueKey('cloud'),
              Icons.cloud_upload_rounded, size: 14, color: _textPri),
        ),
        const SizedBox(width: 6),
        const Text(
          'Sync Status',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPri),
        ),
        const Spacer(),
        _pill(offline: offline),
      ],
    );
  }

  Widget _pill({required bool offline}) {
    return AnimatedBuilder(
      animation: _dotAnim,
      builder: (_, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: offline ? _softWarn : _softSuccess,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.75 + _dotAnim.value * 0.25,
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: offline ? _offlineTxt : _onlineTxt,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: offline ? _offlineTxt : _onlineTxt,
                ),
                child: Text(offline ? 'Offline' : 'Online'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textSec)),
          Text(value, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: _textPri, fontFamily: 'monospace',
          )),
        ],
      ),
    );
  }

  Widget _pendingBreakdown(Map<String, int> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: items.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _softWarn,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _warning.withOpacity(0.35)),
            ),
            child: Text(
              '${e.key}  ${e.value}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _offlineTxt,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showOfflineMessage() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _warning.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _softWarn,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 14, color: _offlineTxt),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _offlineTxt,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Please reconnect and try syncing again.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _textSec,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomRow({required int pending, required bool syncing}) {
    if (pending == 0 && !syncing) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: syncing
            ? null
            : () {
          if (!SyncController.to.isOnline.value) {
            _showOfflineMessage();
            return;
          }
          SyncController.maybeStart();
          widget.onSyncNow?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: syncing
                ? null
                : const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
            color: syncing ? _border : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: syncing
                ? []
                : [
              BoxShadow(
                color: _primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncing)
                const SizedBox(
                  width: 11, height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: _textSec),
                )
              else
                const Icon(Icons.sync_rounded, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(
                syncing ? 'Syncing…' : 'Sync Now',
                style: TextStyle(
                  color: syncing ? _textSec : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
