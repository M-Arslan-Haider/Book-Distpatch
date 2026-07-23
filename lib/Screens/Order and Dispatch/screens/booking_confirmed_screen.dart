

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


class BookingConfirmedScreen extends StatefulWidget {
  final String controllerTag;
  const BookingConfirmedScreen({super.key, required this.controllerTag});

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _ExpiryRecord {
  final String productName;
  final DateTime expiryDate;
  _ExpiryRecord({required this.productName, required this.expiryDate});
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final BookingFlowController _controller;

  final List<_ExpiryRecord> _expiryRecords = [];

  static const _bg        = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark  = AppColors.textPrimary;
  static const _tealDark  = AppColors.tealDark;

  @override
  void initState() {
    super.initState();
    developer.log('🚀 Opening BookingConfirmedScreen (tag=${widget.controllerTag})',
        name: 'BookingConfirmedScreen');
    _controller = Get.find<BookingFlowController>(tag: widget.controllerTag);
  }

  Future<void> _addExpiryRecord() async {
    final result = await showModalBottomSheet<_ExpiryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddExpirySheet(),
    );
    if (result != null) {
      developer.log('🗓️ Expiry record added: ${result.productName} -> ${result.expiryDate}',
          name: 'BookingConfirmedScreen');
      setState(() => _expiryRecords.add(result));
    }
  }

  void _finish() {
    developer.log('🏁 Booking flow finished (Done) — disposing controller tag=${widget.controllerTag}',
        name: 'BookingConfirmedScreen');
    Get.delete<BookingFlowController>(tag: widget.controllerTag);
    // Pop everything on this flow back to the Booking home screen.
    Get.until((route) => route.settings.name == null || Get.currentRoute == '/');
    Get.back(); // fallback single pop; adjust to Get.offAllNamed('/booking') if you have named routes
  }

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name    = loginVM.currentUser.value?.emp_name ?? 'User';
    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final model = _controller.model;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Booking Confirmed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
              const SizedBox(height: 4),
              Text(
                '#${model.bookingId ?? '—'} · Rs ${NumberFormat('#,##0').format(model.grandTotal)}',
                style: const TextStyle(fontSize: 13.5, color: _textMuted, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.tealSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFE6DE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _tealDark, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Optional field tasks — capture merchandising proof & expiry.',
                        style: TextStyle(fontSize: 12.5, color: _tealDark, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('PHOTOS', style: _label),
              ),
              const SizedBox(height: 10),

              _OptionRow(
                icon: Icons.storefront_outlined,
                label: 'Shop Photo',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.captureShopPhoto();
                },
              ),
              const SizedBox(height: 10),
              _OptionRow(
                icon: Icons.grid_view_rounded,
                label: 'Shelf Photo',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller.captureShelfPhoto();
                },
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Text('EXPIRY OF EXISTING PRODUCTS', style: _label)),
                  GestureDetector(
                    onTap: _addExpiryRecord,
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: _tealDark),
                        SizedBox(width: 2),
                        Text('Add', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _tealDark)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_expiryRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Center(
                    child: Text('No expiry records.', style: TextStyle(fontSize: 13, color: _textMuted)),
                  ),
                )
              else
                ..._expiryRecords.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: _tealDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.productName,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _textDark)),
                      ),
                      Text(DateFormat('yyyy-MM-dd').format(r.expiryDate),
                          style: const TextStyle(fontSize: 12.5, color: _textMuted)),
                    ],
                  ),
                )),

              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        developer.log('⏭️ Skip tapped on BookingConfirmedScreen', name: 'BookingConfirmedScreen');
                        _finish();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Skip', style: TextStyle(color: _textDark, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _finish();
                      },
                      icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tealDark,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
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

  static const _label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: _textMuted,
    letterSpacing: 0.6,
  );
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.tealDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C4C4)),
          ],
        ),
      ),
    );
  }
}

class _AddExpirySheet extends StatefulWidget {
  const _AddExpirySheet();

  @override
  State<_AddExpirySheet> createState() => _AddExpirySheetState();
}

class _AddExpirySheetState extends State<_AddExpirySheet> {
  final _nameController = TextEditingController();
  DateTime? _pickedDate;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date != null) setState(() => _pickedDate = date);
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty || _pickedDate == null) return;
    Navigator.pop(
      context,
      _ExpiryRecord(productName: _nameController.text.trim(), expiryDate: _pickedDate!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Add Expiry Record',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Product name',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.tealDark),
                    const SizedBox(width: 10),
                    Text(
                      _pickedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_pickedDate!)
                          : 'Select expiry date',
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}