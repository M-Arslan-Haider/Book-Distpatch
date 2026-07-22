// ═══════════════════════════════════════════════════════════════════════════
// customer_account_screen.dart
//
// Opens after "Start Booking" is tapped on ShopVisitOutcomeScreen. Shows the
// shop's ledger balance, remaining bill limit, last payment date and any
// payment due, with an overdue warning banner + "Receive Payment" action.
// Matches the "Customer Account" screenshot.
//
// NOTE: This is UI-only for now — the account numbers come from
// BookingFlowController.loadCustomerAccount() which is currently mocked.
// Wire the real Oracle ORDS endpoint there later (see TODO(api) markers).
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../view_models/booking_flow_controller.dart';
import 'add_products_screen.dart';


class CustomerAccountScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String shopSubtitle;

  const CustomerAccountScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.shopSubtitle,
  });

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final BookingFlowController _controller;
  late final String _tag; // unique GetX tag so multiple bookings don't clash

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;
  static const _tealDark  = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

  @override
  void initState() {
    super.initState();
    _tag = '${widget.shopId}_${DateTime.now().millisecondsSinceEpoch}';
    developer.log('🚀 Opening CustomerAccountScreen for shop=${widget.shopName} (${widget.shopId}), tag=$_tag',
        name: 'CustomerAccountScreen');
    _controller = Get.put(
      BookingFlowController(
        shopId: widget.shopId,
        shopName: widget.shopName,
        shopSubtitle: widget.shopSubtitle,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    // Keep the controller alive across the flow (Add Products / Bill Summary
    // / Booking Confirmed all reuse it via the same tag) — only delete it
    // once the whole flow is popped back to Booking home. See
    // AddProductsScreen / BillSummaryScreen for the matching Get.delete call
    // on final completion or cancel.
    super.dispose();
  }

  String _fmtMoney(num v) => 'Rs ${NumberFormat('#,##0').format(v)}';

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name    = loginVM.currentUser.value?.emp_name ?? 'User';

    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(
        userName:     name,
        userInitials: initials,
        scaffoldKey:  _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: Obx(() {
          _controller.tick.value; // rebuild trigger
          final model = _controller.model;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back button ─────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    developer.log('⬅️ Back from CustomerAccountScreen — disposing controller tag=$_tag',
                        name: 'CustomerAccountScreen');
                    Get.delete<BookingFlowController>(tag: _tag);
                    Navigator.of(context).maybePop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Customer Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.shopSubtitle,
                  style: const TextStyle(fontSize: 13, color: _textMuted),
                ),

                const SizedBox(height: 16),

                if (model.isLoadingAccount)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: _tealDark)),
                  )
                else ...[
                  // ── Account details card ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _AccountRow(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: _tealDark,
                          label: 'Ledger Balance',
                          value: _fmtMoney(model.account?.ledgerBalance ?? 0),
                        ),
                        const Divider(height: 1, color: AppColors.tealSurface),
                        _AccountRow(
                          icon: Icons.speed_outlined,
                          iconColor: _tealDark,
                          label: 'Remaining Bill Limit',
                          value: _fmtMoney(model.account?.remainingBillLimit ?? 0),
                        ),
                        const Divider(height: 1, color: AppColors.tealSurface),
                        _AccountRow(
                          icon: Icons.event_available_outlined,
                          iconColor: _tealDark,
                          label: 'Last Payment Date',
                          value: model.account?.lastPaymentDate != null
                              ? DateFormat('yyyy-MM-dd').format(model.account!.lastPaymentDate!)
                              : '-',
                        ),
                        const Divider(height: 1, color: AppColors.tealSurface),
                        _AccountRow(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFFDC2626),
                          label: 'Payment Due',
                          value: _fmtMoney(model.account?.paymentDue ?? 0),
                          valueColor: const Color(0xFFDC2626),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  if (model.account?.isOverdue ?? false) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6DD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF5E1A4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFB45309), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C4A03), height: 1.35),
                                children: [
                                  const TextSpan(text: 'This shop has '),
                                  TextSpan(
                                    text: _fmtMoney(model.account?.paymentDue ?? 0),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const TextSpan(text: ' overdue. Consider recovering payment.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Receive Payment ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _controller.receivePayment();
                      },
                      icon: const Icon(Icons.payments_outlined, size: 18, color: _textDark),
                      label: const Text(
                        'Receive Payment',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _textDark),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Next -> Add Products ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        developer.log('➡️ Next tapped — going to AddProductsScreen (tag=$_tag)',
                            name: 'CustomerAccountScreen');
                        Get.to(() => AddProductsScreen(controllerTag: _tag));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tealDark,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_tealLight, _tealDark]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (model.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(message: model.errorMessage!, onDismiss: _controller.clearError),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _AccountRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(onTap: onDismiss, child: Icon(Icons.close, color: Colors.red.shade400, size: 18)),
        ],
      ),
    );
  }
}