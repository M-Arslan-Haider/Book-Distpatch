import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../ViewModels/login_view_model.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// add_shop_screen.dart — "New Shop" form (Pending approval flow)
// Fields kept exactly as before: Shop Name, Owner Name, Contact, City,
// Address, Notes(optional), Shop Type(optional) — plus:
//   • WhatsApp number (new, next to Contact)
//   • CNIC number + Date of Birth (new)
//   • Area (new, free text next to CNIC/Address section)
//   • Shop Photo / Shopkeeper Photo (GPS-stamped field photos) — optional
// ═══════════════════════════════════════════════════════════════════════════════

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _primary = AppColors.tealDark;
  static const _bg      = AppColors.surface;

  // ── Controllers ──────────────────────────────────────────────────────────
  final _shopNameCtrl    = TextEditingController();
  final _ownerNameCtrl   = TextEditingController();
  final _cnicCtrl        = TextEditingController();
  final _dobCtrl         = TextEditingController();
  final _contactCtrl     = TextEditingController();
  final _whatsappCtrl    = TextEditingController();
  final _areaCtrl        = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _shopTypeCtrl    = TextEditingController();
  final _notesCtrl       = TextEditingController();

  List<String> _cities = [];
  String? _selectedCity;
  bool _loadingCities = true;

  // ── GPS state ────────────────────────────────────────────────────────────
  bool _gpsEnabled = false;
  bool _fetchingLocation = false;
  double? _latitude;
  double? _longitude;

  // ── Photos — all optional ───────────────────────────────────────────────
  File? _shopPhotoImage;
  File? _shopkeeperPhotoImage;

  bool _submitting = false;

  // ── Employee Info from SharedPreferences ─────────────────────────────────
  String _empId = '';
  String _empName = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    _loadEmployeeInfo();
    _fetchCities();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _cnicCtrl.dispose();
    _dobCtrl.dispose();
    _contactCtrl.dispose();
    _whatsappCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _shopTypeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Load employee info from SharedPreferences ───────────────────────────
  Future<void> _loadEmployeeInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    _empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';

    _empName = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('empName') ??
        prefs.getString('name') ??
        prefs.getString('full_name') ??
        prefs.getString('fullName') ??
        '';

    _companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';

    if (mounted) setState(() {});
  }

  Future<void> _fetchCities() async {
    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/city/get/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        setState(() {
          _cities        = items.map((e) => e['city'].toString()).toList();
          _loadingCities = false;
        });
      } else {
        setState(() => _loadingCities = false);
      }
    } catch (e) {
      setState(() => _loadingCities = false);
    }
  }

  // ── GPS toggle handler ──────────────────────────────────────────────────
  Future<void> _onGpsToggle(bool value) async {
    if (!value) {
      setState(() {
        _gpsEnabled = false;
        _latitude   = null;
        _longitude  = null;
      });
      return;
    }

    setState(() {
      _gpsEnabled       = true;
      _fetchingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Please enable location services (GPS) on your device');
        setState(() {
          _gpsEnabled       = false;
          _fetchingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          setState(() {
            _gpsEnabled       = false;
            _fetchingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied. Enable it from app settings.');
        setState(() {
          _gpsEnabled       = false;
          _fetchingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude          = position.latitude;
        _longitude         = position.longitude;
        _fetchingLocation  = false;
      });
    } catch (e) {
      _showError('Could not fetch location. Try again.');
      setState(() {
        _gpsEnabled       = false;
        _fetchingLocation = false;
      });
    }
  }

  void _showError(String msg) {
    Get.snackbar(
      'Notice',
      msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFC0392B),
      colorText:       Colors.white,
      borderRadius:    14,
      margin:          const EdgeInsets.all(16),
      duration:        const Duration(seconds: 3),
      icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
    );
  }

  // ── Date of Birth picker ─────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime(now.year - 25),
      firstDate:   DateTime(1930),
      lastDate:    now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
    }
  }

  // ── Image pickers (all optional) ─────────────────────────────────────────
  Future<void> _pickImage(_PhotoSlot slot, {bool fromCamera = true}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source:      fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    setState(() {
      final file = File(picked.path);
      switch (slot) {
        case _PhotoSlot.shopPhoto:
          _shopPhotoImage = file;
          break;
        case _PhotoSlot.shopkeeperPhoto:
          _shopkeeperPhotoImage = file;
          break;
      }
    });
  }

  void _removeImage(_PhotoSlot slot) {
    setState(() {
      switch (slot) {
        case _PhotoSlot.shopPhoto:
          _shopPhotoImage = null;
          break;
        case _PhotoSlot.shopkeeperPhoto:
          _shopkeeperPhotoImage = null;
          break;
      }
    });
  }

  // ── Shop ID generator (unchanged pattern from before) ────────────────────
  String _generateShopId() {
    final now  = DateTime.now();
    final day  = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now).toUpperCase();
    final empPart = _empId.isNotEmpty ? _empId : '0';
    final timePart =
        '${DateFormat('HHmmss').format(now)}${now.millisecond.toString().padLeft(3, '0')}';

    if (_companyCode.isNotEmpty) {
      return '$_companyCode-SHOP-EMP-$empPart-$day-$month-$timePart';
    }
    return 'SHOP-EMP-$empPart-$day-$month-$timePart';
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_empId.isEmpty || _empName.isEmpty) {
      await _loadEmployeeInfo();
      if (_empId.isEmpty || _empName.isEmpty) {
        _showError('Could not load your profile. Please log out and log in again.');
        return;
      }
    }

    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _showError('Please select a city');
      return;
    }

    if (_gpsEnabled && (_latitude == null || _longitude == null)) {
      _showError('Please wait for GPS location to be captured, or disable GPS');
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    HapticFeedback.lightImpact();
    setState(() => _submitting = true);

    // NOTE: photo uploads (shop photo, shopkeeper photo) are
    // optional and are attached here as local file paths for now. Wire up
    // multipart/base64 upload to the backend once the media endpoint is confirmed.
    final payload = {
      'shop_name':       _shopNameCtrl.text.trim(),
      'shop_type':       _shopTypeCtrl.text.trim(),
      'owner_name':      _ownerNameCtrl.text.trim(),
      'cnic':            _cnicCtrl.text.trim(),
      'date_of_birth':   _dobCtrl.text.trim(),
      'contact_number':  _contactCtrl.text.trim(),
      'whatsapp_number': _whatsappCtrl.text.trim(),
      'area':            _areaCtrl.text.trim(),
      'city':            _selectedCity,
      'address':         _addressCtrl.text.trim(),
      'notes':           _notesCtrl.text.trim(),
      'emp_id':          _empId,
      'emp_name':        _empName,
      'company_code':    _companyCode,
      'latitude':        _latitude,
      'longitude':       _longitude,
      'shop_id':         _generateShopId(),
      'shop_photo_path':      _shopPhotoImage?.path,
      'shopkeeper_photo_path': _shopkeeperPhotoImage?.path,
    };

    final jsonPayload = jsonEncode(payload);
    const apiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/addshop/post/';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonPayload,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          '✅ Saved',
          'Shop saved as pending approval — bookable on hold.',
          snackPosition:   SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText:       Colors.white,
          borderRadius:    14,
          margin:          const EdgeInsets.all(16),
          duration:        const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        );

        _shopNameCtrl.clear();
        _shopTypeCtrl.clear();
        _ownerNameCtrl.clear();
        _cnicCtrl.clear();
        _dobCtrl.clear();
        _contactCtrl.clear();
        _whatsappCtrl.clear();
        _areaCtrl.clear();
        _addressCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _selectedCity          = null;
          _latitude              = null;
          _longitude             = null;
          _gpsEnabled            = false;
          _shopPhotoImage        = null;
          _shopkeeperPhotoImage  = null;
        });

        Future.delayed(const Duration(seconds: 1), () => Get.back());
      } else {
        String errorMsg = 'Failed to save shop. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['message'] ?? errorData['error'] ?? errorData['exception'] ?? errorMsg;
        } catch (_) {}
        _showError(errorMsg);
      }
    } catch (e) {
      String errorMsg = 'Could not connect to server. Please check your internet connection.';
      if (e.toString().contains('timeout')) {
        errorMsg = 'Request timed out. Server is taking too long to respond.';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'No internet connection. Please check your network.';
      }
      _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
            children: [
              // ── Back button ──────────────────────────────────────────
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width:  36,
                  height: 36,
                  alignment: Alignment.topLeft,
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.black, size: 22),
                ),
              ),
              const SizedBox(height: 6),

              // ── Title + pending-approval subtitle ────────────────────
              const Text(
                'New Shop',
                style: TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.w800,
                  color:      Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Saved as ',
                    ),
                    TextSpan(
                      text: 'Pending approval',
                      style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' — bookable on '),
                    TextSpan(
                      text: 'hold',
                      style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Shop / Owner name ─────────────────────────────────────
              const _FormLabel(text: 'Customer / Shop Name', required: true),
              _SoftField(
                controller: _shopNameCtrl,
                hint:       'e.g. Madina Karyana Store',
                validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              const _FormLabel(text: 'Owner Name', required: true),
              _SoftField(
                controller: _ownerNameCtrl,
                hint:       'Owner full name',
                validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── CNIC + DOB ────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel(text: 'CNIC', required: true),
                        _SoftField(
                          controller:      _cnicCtrl,
                          hint:            '35202-123456',
                          keyboardType:    TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel(text: 'Date of Birth', required: false),
                        _SoftField(
                          controller: _dobCtrl,
                          hint:       'mm/dd/yyyy',
                          readOnly:   true,
                          onTap:      _pickDob,
                          suffixIcon: Icons.calendar_today_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Contact + WhatsApp ────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel(text: 'Contact', required: true),
                        _SoftField(
                          controller:   _contactCtrl,
                          hint:         '+923..',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FormLabel(text: 'WhatsApp', required: false),
                        _SoftField(
                          controller:   _whatsappCtrl,
                          hint:         '+923..',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Area ──────────────────────────────────────────────────
              const _FormLabel(text: 'Area', required: false),
              _SoftField(
                controller: _areaCtrl,
                hint:       'e.g. Gulberg',
              ),
              const SizedBox(height: 16),

              // ── Shop Address ──────────────────────────────────────────
              const _FormLabel(text: 'Shop Address', required: true),
              _SoftField(
                controller: _addressCtrl,
                hint:       'Full shop address',
                maxLines:   3,
                validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── City ──────────────────────────────────────────────────
              const _FormLabel(text: 'City', required: true),
              _CityField(
                value:     _selectedCity,
                items:     _cities,
                isLoading: _loadingCities,
                onChanged: (v) => setState(() => _selectedCity = v),
              ),
              const SizedBox(height: 16),

              // ── Shop Type (optional, kept from original) ─────────────
              const _FormLabel(text: 'Shop Type', required: false),
              _SoftField(
                controller: _shopTypeCtrl,
                hint:       'e.g. Retail, Wholesale',
              ),
              const SizedBox(height: 16),

              // ── GPS toggle (kept from original) ──────────────────────
              _GpsToggleRow(
                enabled:   _gpsEnabled,
                fetching:  _fetchingLocation,
                latitude:  _latitude,
                longitude: _longitude,
                onChanged: _onGpsToggle,
              ),
              const SizedBox(height: 16),

              // ── Notes (optional, kept from original) ─────────────────
              const _FormLabel(text: 'Notes', required: false),
              _SoftField(
                controller: _notesCtrl,
                hint:       'Any extra remarks',
                maxLines:   2,
              ),

              const SizedBox(height: 24),

              // ── Field Photos — optional, GPS stamped ──────────────────
              const Text(
                'FIELD PHOTOS (GPS STAMPED)',
                style: TextStyle(
                  fontSize:      12,
                  fontWeight:    FontWeight.w700,
                  color:         Colors.black87,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PhotoTile(
                      label: 'Shop Photo',
                      icon:  Icons.storefront_rounded,
                      image: _shopPhotoImage,
                      onTap: () => _pickImage(_PhotoSlot.shopPhoto),
                      onRemove: () => _removeImage(_PhotoSlot.shopPhoto),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoTile(
                      label: 'Shopkeeper Photo',
                      icon:  Icons.person_rounded,
                      image: _shopkeeperPhotoImage,
                      onTap: () => _pickImage(_PhotoSlot.shopkeeperPhoto),
                      onRemove: () => _removeImage(_PhotoSlot.shopkeeperPhoto),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // ── Save button ─────────────────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: SizedBox(
          width:  double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Save Shop & Start Booking',
                  style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoSlot { shopPhoto, shopkeeperPhoto }

// ─────────────────────────────────────────────────────────────────────────────
// Form field label with optional required-asterisk
// ─────────────────────────────────────────────────────────────────────────────
class _FormLabel extends StatelessWidget {
  final String text;
  final bool   required;
  const _FormLabel({required this.text, required this.required});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      AppColors.tealDark,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFD97706))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Soft cream input field — matches the screenshot's rounded pill inputs
// ─────────────────────────────────────────────────────────────────────────────
class _SoftField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     hint;
  final TextInputType?             keyboardType;
  final List<TextInputFormatter>?  inputFormatters;
  final String? Function(String?)? validator;
  final int                        maxLines;
  final bool                       readOnly;
  final VoidCallback?              onTap;
  final IconData?                  suffixIcon;

  const _SoftField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines   = 1,
    this.readOnly   = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      validator:       validator,
      maxLines:        maxLines,
      readOnly:        readOnly,
      onTap:           onTap,
      style: const TextStyle(
        fontSize:   14,
        fontWeight: FontWeight.w500,
        color:      Colors.black,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w400,
          color:      Colors.black45,
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, size: 18, color: Colors.black87)
            : null,
        filled:     true,
        fillColor:  Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.tealDark, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: Color(0xFFC0392B)),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// City field — tappable, opens the searchable city sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CityField extends StatelessWidget {
  final String?               value;
  final List<String>          items;
  final bool                  isLoading;
  final ValueChanged<String?> onChanged;

  const _CityField({
    required this.value,
    required this.items,
    required this.isLoading,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    if (isLoading) return;
    final result = await showModalBottomSheet<String>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CitySearchSheet(items: items, initialValue: value),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isLoading ? 'Loading cities...' : (value ?? 'Select city'),
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                  color: value == null ? Colors.black45 : Colors.black,
                ),
              ),
            ),
            isLoading
                ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tealDark),
            )
                : const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.black87, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CitySearchSheet extends StatefulWidget {
  final List<String> items;
  final String?       initialValue;
  const _CitySearchSheet({required this.items, required this.initialValue});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  static const _primary = AppColors.tealDark;
  late List<String> _filtered;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = widget.items
          .where((c) => c.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize:      0.4,
      maxChildSize:      0.9,
      expand:            false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_rounded, color: _primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Select City',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus:  true,
                    onChanged:  _filter,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                    decoration: InputDecoration(
                      hintText:  'Search city...',
                      hintStyle: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: _primary, size: 20),
                      isDense: true,
                      border:  InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                    child: Text('No cities found',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)))
                    : ListView.separated(
                  controller: scrollController,
                  padding:    const EdgeInsets.symmetric(vertical: 8),
                  itemCount:  _filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1, color: AppColors.divider, indent: 20, endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final city = _filtered[index];
                    final isSelected = city == widget.initialValue;
                    return ListTile(
                      onTap: () => Navigator.pop(context, city),
                      title: Text(
                        city,
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color:      isSelected ? _primary : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: _primary, size: 20)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS toggle row (kept from the original screen, simplified visually)
// ─────────────────────────────────────────────────────────────────────────────
class _GpsToggleRow extends StatelessWidget {
  final bool                    enabled;
  final bool                    fetching;
  final double?                 latitude;
  final double?                 longitude;
  final ValueChanged<bool>      onChanged;

  const _GpsToggleRow({
    required this.enabled,
    required this.fetching,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });

  static const _primary = AppColors.tealDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        AppColors.iconBgTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.my_location_rounded, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Capture GPS Location',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 2),
                Text(
                  fetching
                      ? 'Fetching location...'
                      : (enabled && latitude != null
                      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                      : 'Optional — tag this shop\'s location'),
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            ),
          ),
          fetching
              ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
          )
              : Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: _primary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo tile — dashed-style optional upload slot (field photos)
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoTile extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final File?        image;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoTile({
    required this.label,
    required this.icon,
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  static const _primary = AppColors.tealDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    image == null ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.divider,
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image != null
            ? Stack(
          fit: StackFit.expand,
          children: [
            Image.file(image!, fit: BoxFit.cover),
            Positioned(
              top: 6, right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}