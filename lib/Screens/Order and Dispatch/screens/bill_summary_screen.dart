// ═══════════════════════════════════════════════════════════════════════════
// bill_summary_screen.dart
//
// Opens after "Review Bill" on AddProductsScreen. Shows the itemized bill
// (item / pcs / rate / amount), subtotal, GST, grand total, an over-limit
// warning banner (matches screenshot), PDF + Share(WhatsApp) actions, and
// "Confirm Booking" which moves to BookingConfirmedScreen.
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
import 'booking_confirmed_screen.dart';

class BillSummaryScreen extends StatefulWidget {
  final String controllerTag;
  const BillSummaryScreen({super.key, required this.controllerTag});

  @override
  State<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends State<BillSummaryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final BookingFlowController _controller;

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;
  static const _tealDark  = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

  @override
  void initState() {
    super.initState();
    developer.log('🚀 Opening BillSummaryScreen (tag=${widget.controllerTag})', name: 'BillSummaryScreen');
    _controller = Get.find<BookingFlowController>(tag: widget.controllerTag);
  }

  String _fmtMoney(num v) => 'Rs ${NumberFormat('#,##0').format(v)}';

  Future<void> _handleConfirm() async {
    HapticFeedback.mediumImpact();
    developer.log('✅ Confirm Booking tapped', name: 'BillSummaryScreen');
    final success = await _controller.confirmBooking();
    if (success && mounted) {
      Get.off(() => BookingConfirmedScreen(controllerTag: widget.controllerTag));
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.model.errorMessage ?? 'Failed to confirm booking')),
      );
    }
  }

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
          _controller.tick.value;
          final model = _controller.model;
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).maybePop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
                  ),
                ),
                const SizedBox(height: 4),

                const Text('Bill Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 2),
                Text('${model.shopName} · $today',
                    style: const TextStyle(fontSize: 13, color: _textMuted)),

                const SizedBox(height: 16),

                // ── Item table ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Expanded(flex: 4, child: Text('ITEM', style: _headStyle)),
                          Expanded(flex: 2, child: Text('PCS', style: _headStyle, textAlign: TextAlign.right)),
                          Expanded(flex: 3, child: Text('RATE', style: _headStyle, textAlign: TextAlign.right)),
                          Expanded(flex: 3, child: Text('AMOUNT', style: _headStyle, textAlign: TextAlign.right)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.tealSurface),
                      const SizedBox(height: 6),
                      ...model.lineItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _textDark)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} pcs'
                                        '${item.bonusPieces > 0 ? ' +${item.bonusPieces} free' : ''}'
                                        '${item.discountPercent > 0 ? ' · ${item.discountPercent.toStringAsFixed(0)}% off' : ''}',
                                    style: const TextStyle(fontSize: 11, color: _textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                                flex: 2,
                                child: Text('${item.quantity}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, color: _textDark))),
                            Expanded(
                                flex: 3,
                                child: Text(NumberFormat('#,##0').format(item.rate),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, color: _textDark))),
                            Expanded(
                                flex: 3,
                                child: Text(NumberFormat('#,##0').format(item.netAmount),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _tealDark))),
                          ],
                        ),
                      )),
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: AppColors.tealSurface),
                      const SizedBox(height: 10),

                      _TotalsRow(label: 'Subtotal', value: _fmtMoney(model.subtotal)),
                      _TotalsRow(
                          label: 'GST (${(BookingFlowControllerGstDisplay.rate * 100).toStringAsFixed(0)}%)',
                          value: _fmtMoney(model.gstAmount)),
                      const SizedBox(height: 4),
                      _TotalsRow(
                        label: 'Grand Total',
                        value: _fmtMoney(model.grandTotal),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),

                if (model.exceedsBillLimit) ...[
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
                                const TextSpan(text: 'Order '),
                                TextSpan(
                                  text: _fmtMoney(model.grandTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(text: ' exceeds remaining limit '),
                                TextSpan(
                                  text: _fmtMoney(model.account?.remainingBillLimit ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(text: '. Supervisor override required.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── PDF + Share buttons ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _controller.exportPdf();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('PDF generated (TODO: wire real export)')));
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: _textDark),
                        label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _controller.shareOnWhatsApp();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Sharing to WhatsApp (TODO: wire share_plus)')));
                        },
                        icon: const Icon(Icons.share_outlined, size: 18, color: _textDark),
                        label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700, color: _textDark)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Confirm Booking ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _controller.isSubmitting.value ? null : _handleConfirm,
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
                        child: _controller.isSubmitting.value
                            ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Confirm Booking',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
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

  static const _headStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: _textMuted,
    letterSpacing: 0.4,
  );
}

class _TotalsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _TotalsRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 17 : 14,
              fontWeight: FontWeight.w800,
              color: emphasize ? AppColors.tealDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper to surface BookingFlowModel.gstRate for display without
/// importing the model class name directly here (keeps this file focused).
class BookingFlowControllerGstDisplay {
  static const double rate = 0.18;
}