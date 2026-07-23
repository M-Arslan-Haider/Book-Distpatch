
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../view_models/shop_closed_viewmodel.dart';

class ShopClosedScreen extends StatefulWidget {
  final String controllerTag;
  const ShopClosedScreen({super.key, required this.controllerTag});

  @override
  State<ShopClosedScreen> createState() => _ShopClosedScreenState();
}

class _ShopClosedScreenState extends State<ShopClosedScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ShopClosedController _controller;

  static const _bg = AppColors.surface;
  static const _textMuted = AppColors.textSecondary;
  static const _textDark = AppColors.textPrimary;
  static const _tealDark = AppColors.tealDark;
  static const _tealLight = AppColors.tealLight;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ShopClosedController>(tag: widget.controllerTag);
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PhotoSourceSheet(),
    );
    if (choice == null) return;
    await _controller.captureShopPhoto(fromCamera: choice);
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    final ok = await _controller.submitVisit();
    if (!mounted) return;

    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Visit Recorded', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(
            'Shop Closed visit for ${_controller.model.shopName} was saved successfully.',
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Get.back();
                Get.back();
              },
              child: const Text('Done', style: TextStyle(color: _tealDark, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else if (_controller.model.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.model.errorMessage!)),
      );
      _controller.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name = loginVM.currentUser.value?.emp_name ?? 'User';
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(
        userName: name,
        userInitials: initials,
        scaffoldKey: _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: Obx(() {
          _controller.tick.value;
          final model = _controller.model;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

                      const Text('Shop Closed',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
                      const SizedBox(height: 2),
                      Text(model.shopName,
                          style: const TextStyle(fontSize: 13, color: _tealDark, fontWeight: FontWeight.w600)),
                      if ((model.shopSubtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(model.shopSubtitle!,
                            style: const TextStyle(fontSize: 12, color: _textMuted)),
                      ],

                      const SizedBox(height: 20),

                      Text('SHOP PHOTO', style: _labelStyle),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: model.hasPhoto
                              ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                base64Decode(model.shopPhotoBase64!),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Retake',
                                          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                              : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_rounded, color: _tealDark.withOpacity(0.5), size: 34),
                                const SizedBox(height: 8),
                                const Text('Tap to capture shop photo',
                                    style: TextStyle(fontSize: 13, color: _textMuted, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text('LOCATION', style: _labelStyle),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              model.hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                              color: model.hasLocation ? _tealDark : Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                model.isCapturingLocation
                                    ? 'Getting current location...'
                                    : model.hasLocation
                                    ? '${model.latitude!.toStringAsFixed(6)}, ${model.longitude!.toStringAsFixed(6)}'
                                    : 'Location not captured',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: model.hasLocation ? _textDark : _textMuted,
                                ),
                              ),
                            ),
                            if (model.isCapturingLocation)
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _tealDark),
                              )
                            else
                              GestureDetector(
                                onTap: () => _controller.captureLocation(),
                                child: const Icon(Icons.refresh_rounded, color: _tealDark, size: 20),
                              ),
                          ],
                        ),
                      ),

                      if (model.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
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
                                child: Text(model.errorMessage!,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                              ),
                              GestureDetector(
                                onTap: _controller.clearError,
                                child: Icon(Icons.close, color: Colors.red.shade400, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: _bg,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _controller.isSubmitting.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealDark,
                      disabledBackgroundColor: const Color(0xFFBFD9D5),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _controller.isSubmitting.value
                            ? null
                            : const LinearGradient(colors: [_tealLight, _tealDark]),
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
                            SizedBox(width: 6),
                            Text('Submit Visit',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: _textMuted,
    letterSpacing: 0.6,
  );
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.tealDark),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.tealDark),
            title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}