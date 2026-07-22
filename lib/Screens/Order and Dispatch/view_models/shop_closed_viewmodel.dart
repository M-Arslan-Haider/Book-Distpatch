// ═══════════════════════════════════════════════════════════════════════════
// shop_closed_controller.dart
//
// GetX controller for the "Shop Closed" flow (Select Shop -> capture photo
// + GPS -> submit). No products/stock involved.
//
// Uses image_picker + flutter_image_compress + location, same pattern used
// in NoSaleVisitController.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;

import '../models/shop_closed_model.dart';
import '../repositories/shop_closed_repository.dart';

class ShopClosedController extends GetxController {
  ShopClosedController({
    required String shopId,
    required String shopName,
    String shopAddress = '',
    String ownerName = '',
    String? shopSubtitle,
    ShopClosedRepository? repository,
  })  : model = ShopClosedVisitModel(
    shopId: shopId,
    shopName: shopName,
    shopAddress: shopAddress,
    ownerName: ownerName,
    shopSubtitle: shopSubtitle,
  ),
        _repository = repository ?? ShopClosedRepository();

  final ShopClosedVisitModel model;
  final ShopClosedRepository _repository;

  static const int _targetMaxBytes = 100 * 1024; // ~100 KB cap for base64 payload

  // Reactive trigger — model is a plain mutable class, bump this to force
  // GetX widgets (Obx / GetBuilder) to rebuild.
  final RxInt _tick = 0.obs;
  void _refresh() {
    _tick.value++;
    model.logState('refresh');
  }

  RxInt get tick => _tick;

  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    developer.log(
      '🚀 ShopClosedController init for shop=${model.shopName} (${model.shopId})',
      name: 'ShopClosedController',
    );
    captureLocation(); // auto-attempt GPS on entry
  }

  // ============= SHOP PHOTO =============
  Future<bool> captureShopPhoto({required bool fromCamera}) async {
    developer.log('📸 Capturing shop photo (fromCamera=$fromCamera)', name: 'ShopClosedController');
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        developer.log('⚠️ Photo capture cancelled', name: 'ShopClosedController');
        return false;
      }

      final originalBytes = await pickedFile.readAsBytes();
      final compressedBytes = await _compressImage(originalBytes);
      developer.log(
        '🗜️ Compressed size: ${compressedBytes.length} bytes (was ${originalBytes.length})',
        name: 'ShopClosedController',
      );

      model.shopPhotoBase64 = base64Encode(compressedBytes);
      _refresh();
      return true;
    } catch (e) {
      developer.log('❌ Error capturing shop photo: $e', name: 'ShopClosedController');
      model.errorMessage = 'Failed to capture photo';
      _refresh();
      return false;
    }
  }

  Future<Uint8List> _compressImage(Uint8List inputBytes) async {
    int quality = 80;
    int minSide = 1024;
    Uint8List result = inputBytes;

    for (int attempt = 0; attempt < 10; attempt++) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          inputBytes,
          quality: quality,
          minWidth: minSide,
          minHeight: minSide,
          format: CompressFormat.jpeg,
        );

        result = compressed;
        developer.log(
          '🗜️ Attempt ${attempt + 1}: quality=$quality, size=${compressed.length} bytes',
          name: 'ShopClosedController',
        );

        if (compressed.length <= _targetMaxBytes) break;

        quality = (quality * 0.7).round();
        minSide = (minSide * 0.7).round();
        if (quality < 10) quality = 10;
        if (minSide < 300) minSide = 300;
      } catch (e) {
        developer.log('⚠️ Compression error: $e', name: 'ShopClosedController');
        break;
      }
    }

    return result;
  }

  // ============= LOCATION (GPS) =============
  Future<bool> captureLocation() async {
    developer.log('📍 Capturing current location...', name: 'ShopClosedController');
    model.isCapturingLocation = true;
    _refresh();

    try {
      final location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          developer.log('❌ Location service not enabled', name: 'ShopClosedController');
          model.gpsEnabled = false;
          model.errorMessage = 'Please enable location services';
          return false;
        }
      }

      loc.PermissionStatus permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != loc.PermissionStatus.granted) {
          developer.log('❌ Location permission denied', name: 'ShopClosedController');
          model.gpsEnabled = false;
          model.errorMessage = 'Location permission denied';
          return false;
        }
      }

      final locData = await location.getLocation();
      model.latitude = locData.latitude;
      model.longitude = locData.longitude;
      model.gpsEnabled = true;

      developer.log('✅ Location captured: ${model.latitude}, ${model.longitude}',
          name: 'ShopClosedController');
      return true;
    } catch (e) {
      developer.log('❌ Error capturing location: $e', name: 'ShopClosedController');
      model.gpsEnabled = false;
      model.errorMessage = 'Failed to get current location';
      return false;
    } finally {
      model.isCapturingLocation = false;
      _refresh();
    }
  }

  // ── Generate unique Visit ID (same style used across the app) ─────────
  // Format: {COMPANY_CODE}-SV-EMP-{empId}-{dd}-{MMM}-{HHmmss}{ms}
  Future<String> _generateVisitId() async {
    final empInfo = await _repository.getEmployeeInfo();
    final empId = (empInfo['empId'] ?? '').padLeft(2, '0');
    final companyCode = empInfo['companyCode'] ?? '';

    final now = DateTime.now();
    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now).toUpperCase();
    final timePart =
        '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';

    String visitId;
    if (companyCode.isNotEmpty) {
      visitId = '$companyCode-SV-EMP-$empId-$day-$month-$timePart';
    } else {
      visitId = 'SV-EMP-$empId-$day-$month-$timePart';
    }

    developer.log('🆔 Generated visit_id: $visitId', name: 'ShopClosedController');
    return visitId;
  }

  //============= SUBMIT =============
  Future<bool> submitVisit() async {
    developer.log('🚀 Submitting Shop Closed visit for shop ${model.shopId}...',
        name: 'ShopClosedController');

    if (!model.hasPhoto) {
      model.errorMessage = 'Please capture a shop photo';
      _refresh();
      return false;
    }

    if (!model.hasLocation) {
      developer.log('📍 No location yet — attempting capture before submit',
          name: 'ShopClosedController');
      final ok = await captureLocation();
      if (!ok || !model.hasLocation) {
        model.errorMessage = 'Please enable GPS to capture your location';
        _refresh();
        return false;
      }
    }

    isSubmitting.value = true;
    _refresh();

    try {
      model.visitId ??= await _generateVisitId();

      final result = await _repository.submitVisit(model);

      if (result.success) {
        developer.log('✅ Shop Closed visit submitted: ${result.visitId ?? model.visitId}',
            name: 'ShopClosedController');
        model.errorMessage = null;
        return true;
      } else {
        developer.log('❌ Submit failed: ${result.message}', name: 'ShopClosedController');
        model.errorMessage = result.message ?? 'Failed to submit visit';
        return false;
      }
    } catch (e, st) {
      developer.log('❌ Error submitting visit: $e', name: 'ShopClosedController');
      print(st);
      model.errorMessage = 'Failed to submit visit';
      return false;
    } finally {
      isSubmitting.value = false;
      _refresh();
    }
  }

  void clearError() {
    model.errorMessage = null;
    _refresh();
  }
}