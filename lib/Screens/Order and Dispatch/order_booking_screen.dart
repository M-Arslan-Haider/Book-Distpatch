import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// order_booking_screen.dart  —  Simple UI, same design language as ShopVisitScreen
// ═══════════════════════════════════════════════════════════════════════════════

class OrderBookingScreen extends StatefulWidget {
  const OrderBookingScreen({super.key});

  @override
  State<OrderBookingScreen> createState() => _OrderBookingScreenState();
}

class _OrderBookingScreenState extends State<OrderBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _primary = Color(0xFF0C6B64);
  static const _bg      = Color(0xFFE8F5F3);

  // ── Controllers ──────────────────────────────────────────────────────────
  final _shopNameCtrl   = TextEditingController();
  final _ownerNameCtrl  = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _brandCtrl      = TextEditingController();
  final _totalCtrl      = TextEditingController(text: "0.00");

  String? _creditLimit;
  String  _deliveryDate = "";

  final List<String> _creditOptions = ["7 Days", "15 Days", "30 Days", "Cash"];

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _brandCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      HapticFeedback.lightImpact();
      Get.snackbar(
        'Success',
        'Order confirmed successfully',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [

          // ── Gradient Header ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Booking',
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 2),
                          Text('Create an order form',
                              style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                children: [

                  // ── Shop Information ─────────────────────────────────────
                  const _SectionHeader(icon: Icons.store_rounded, label: 'Shop Information'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Shop Name',
                    controller: _shopNameCtrl,
                    icon:       Icons.warehouse_rounded,
                    hint:       'Not available',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Owner Name',
                    controller: _ownerNameCtrl,
                    icon:       Icons.person_rounded,
                    hint:       'Not available',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Phone Number',
                    controller: _phoneCtrl,
                    icon:       Icons.phone_rounded,
                    hint:       'Not available',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Brand',
                    controller: _brandCtrl,
                    icon:       Icons.branding_watermark_rounded,
                    hint:       'Not available',
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),

                  const SizedBox(height: 20),

                  // ── Products ───────────────────────────────────────────────
                  const _SectionHeader(icon: Icons.inventory_2_rounded, label: 'Products'),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: _primary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Search and add products here',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Order Summary ─────────────────────────────────────────
                  const _SectionHeader(icon: Icons.summarize_rounded, label: 'Order Summary'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Total',
                    controller: _totalCtrl,
                    icon:       Icons.attach_money_rounded,
                    hint:       '0.00',
                    readOnly:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _CreditLimitCard(
                    value: _creditLimit,
                    items: _creditOptions,
                    onChanged: (v) => setState(() => _creditLimit = v),
                  ),
                  const SizedBox(height: 10),

                  _DeliveryDateCard(
                    date: _deliveryDate,
                    onTap: () async {
                      final today = DateTime.now();
                      final firstDate = DateTime(today.year, today.month, today.day);
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: firstDate,
                        firstDate: firstDate,
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        final formatted =
                            "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                        setState(() => _deliveryDate = formatted);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Confirm Button ───────────────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w700,
                color:      Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;

  static const _primary = Color(0xFF0C6B64);

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      _primary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Card
// ─────────────────────────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final String                        label;
  final TextEditingController         controller;
  final IconData                      icon;
  final String                        hint;
  final String? Function(String?)?    validator;
  final int                           maxLines;
  final bool                          readOnly;
  final bool                          showLock;
  final bool                          isOptional;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _FieldCard({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.validator,
    this.maxLines   = 1,
    this.readOnly   = false,
    this.showLock   = false,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: readOnly && showLock
            ? const Color(0xFFF5FFFE)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (isOptional) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F7F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Optional',
                          style: TextStyle(
                            fontSize: 9, color: Color(0xFF1A6E59),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                TextFormField(
                  controller:      controller,
                  validator:       validator,
                  maxLines:        maxLines,
                  readOnly:        readOnly,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: readOnly && showLock
                        ? const Color(0xFF1A6E59)
                        : _textDark,
                  ),
                  decoration: InputDecoration(
                    hintText:  hint,
                    hintStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w400,
                      color: Color(0xFFB0BAC7),
                    ),
                    isDense: true,
                    border:  InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (showLock)
            const Icon(Icons.lock_rounded,
                color: Color(0xFF1A6E59), size: 16)
          else
            const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFCDD5DC), size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Credit Limit Card (dropdown)
// ─────────────────────────────────────────────────────────────────────────────
class _CreditLimitCard extends StatelessWidget {
  final String?             value;
  final List<String>        items;
  final Function(String?)   onChanged;

  static const _primary = Color(0xFF0C6B64);

  const _CreditLimitCard({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.payment_rounded, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Credit Limit',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonFormField<String>(
                  value: value,
                  isExpanded: true,
                  items: items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: onChanged,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please select a credit limit' : null,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2E2C),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Select credit limit',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery Date Card
// ─────────────────────────────────────────────────────────────────────────────
class _DeliveryDateCard extends StatelessWidget {
  final String       date;
  final VoidCallback  onTap;

  static const _primary = Color(0xFF0C6B64);

  const _DeliveryDateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, color: _primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Required Delivery',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.isEmpty ? 'Select a date' : date,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: date.isEmpty
                          ? const Color(0xFFB0BAC7)
                          : const Color(0xFF1A2E2C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_rounded,
                color: Color(0xFFB0BAC7), size: 20),
          ],
        ),
      ),
    );
  }
}