import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// add_shop_screen.dart  —  Complete integration with login & API (FULL DEBUG)
// ═══════════════════════════════════════════════════════════════════════════════

class AddShopScreen extends StatefulWidget {
  const AddShopScreen({super.key});

  @override
  State<AddShopScreen> createState() => _AddShopScreenState();
}

class _AddShopScreenState extends State<AddShopScreen> {
  final _formKey = GlobalKey<FormState>();

  static const _primary = Color(0xFF0C6B64);
  static const _bg      = Color(0xFFE8F5F3);

  // ── Controllers ──────────────────────────────────────────────────────────
  final _shopNameCtrl    = TextEditingController();
  final _ownerNameCtrl   = TextEditingController();
  final _contactCtrl     = TextEditingController();
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

  // ── Employee Info from SharedPreferences ─────────────────────────────────
  String _empId = '';
  String _empName = '';
  String _companyCode = '';

  @override
  void initState() {
    super.initState();
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🏪 [AddShop] INIT STATE - Screen Started');
    debugPrint('════════════════════════════════════════════════════════════');
    _loadEmployeeInfo();
    _fetchCities();
  }

  // ── Load employee info from SharedPreferences ───────────────────────────
  Future<void> _loadEmployeeInfo() async {
    debugPrint('👤 [AddShop] ===== LOADING EMPLOYEE INFO =====');

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Log ALL SharedPreferences keys
    debugPrint('📋 [AddShop] All SharedPreferences keys:');
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      debugPrint('   $key = ${prefs.get(key)}');
    }

    // Try multiple possible keys for employee ID
    _empId = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';
    debugPrint('🔑 [AddShop] empId loaded: "$_empId"');

    // Try multiple possible keys for employee name
    _empName = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('empName') ??
        prefs.getString('name') ??
        prefs.getString('full_name') ??
        prefs.getString('fullName') ??
        '';
    debugPrint('👤 [AddShop] empName loaded: "$_empName"');

    // Company code
    _companyCode = prefs.getString('company_code') ??
        prefs.getString('companyCode') ??
        '';
    debugPrint('🏢 [AddShop] companyCode loaded: "$_companyCode"');

    // Check if employee info is complete
    if (_empId.isEmpty || _empName.isEmpty) {
      debugPrint('⚠️ [AddShop] ⚠️ EMPLOYEE INFO INCOMPLETE!');
      debugPrint('   empId: "${_empId}" (${_empId.isEmpty ? "EMPTY ❌" : "OK ✅"})');
      debugPrint('   empName: "${_empName}" (${_empName.isEmpty ? "EMPTY ❌" : "OK ✅"})');
      debugPrint('   companyCode: "${_companyCode}" (${_companyCode.isEmpty ? "EMPTY ❌" : "OK ✅"})');
    } else {
      debugPrint('✅ [AddShop] Employee info loaded successfully!');
      debugPrint('   ✅ empId: $_empId');
      debugPrint('   ✅ empName: $_empName');
      debugPrint('   ✅ companyCode: $_companyCode');
    }

    debugPrint('👤 [AddShop] ===== END LOADING EMPLOYEE INFO =====');
    debugPrint('');
  }

  Future<void> _fetchCities() async {
    debugPrint('🌆 [AddShop] ===== FETCHING CITIES =====');
    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/city/get/';
      debugPrint('🌆 [AddShop] API URL: $url');

      final response = await http.get(
        Uri.parse(url),
      );

      debugPrint('🌆 [AddShop] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;
        debugPrint('🌆 [AddShop] Items count: ${items.length}');
        debugPrint('🌆 [AddShop] Raw items: $items');

        setState(() {
          _cities = items.map((e) => e['city'].toString()).toList();
          _loadingCities = false;
        });
        debugPrint('🌆 [AddShop] ✅ Cities loaded: ${_cities.length} cities');
        debugPrint('🌆 [AddShop] Cities list: $_cities');
      } else {
        debugPrint('🌆 [AddShop] ❌ Non-200 response: ${response.statusCode}');
        debugPrint('🌆 [AddShop] Response body: ${response.body}');
        setState(() => _loadingCities = false);
      }
    } catch (e) {
      debugPrint('🌆 [AddShop] ❌ Error fetching cities: $e');
      debugPrint('🌆 [AddShop] Stack trace: ${StackTrace.current}');
      setState(() => _loadingCities = false);
    }
    debugPrint('🌆 [AddShop] ===== END FETCHING CITIES =====');
    debugPrint('');
  }

  // ── GPS toggle handler ──────────────────────────────────────────────────
  Future<void> _onGpsToggle(bool value) async {
    debugPrint('📍 [AddShop] ===== GPS TOGGLE =====');
    debugPrint('📍 [AddShop] New value: $value');

    if (!value) {
      debugPrint('📍 [AddShop] GPS disabled - clearing location');
      setState(() {
        _gpsEnabled = false;
        _latitude   = null;
        _longitude  = null;
      });
      debugPrint('📍 [AddShop] ===== GPS TOGGLE END =====');
      debugPrint('');
      return;
    }

    debugPrint('📍 [AddShop] GPS enabled - fetching location...');
    setState(() {
      _gpsEnabled       = true;
      _fetchingLocation = true;
    });

    try {
      // Check if location services are on
      debugPrint('📍 [AddShop] Checking location services...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('📍 [AddShop] Location services enabled: $serviceEnabled');

      if (!serviceEnabled) {
        debugPrint('📍 [AddShop] ❌ Location services disabled');
        _showError('Please enable location services (GPS) on your device');
        setState(() {
          _gpsEnabled       = false;
          _fetchingLocation = false;
        });
        return;
      }

      // Check / request permission
      debugPrint('📍 [AddShop] Checking location permission...');
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 [AddShop] Current permission: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('📍 [AddShop] Permission denied - requesting...');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 [AddShop] Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('📍 [AddShop] ❌ Permission denied by user');
          _showError('Location permission denied');
          setState(() {
            _gpsEnabled       = false;
            _fetchingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 [AddShop] ❌ Permission permanently denied');
        _showError('Location permission permanently denied. Enable it from app settings.');
        setState(() {
          _gpsEnabled       = false;
          _fetchingLocation = false;
        });
        return;
      }

      // Get current position
      debugPrint('📍 [AddShop] Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint('📍 [AddShop] ✅ Position captured!');
      debugPrint('📍 [AddShop] Latitude: ${position.latitude}');
      debugPrint('📍 [AddShop] Longitude: ${position.longitude}');
      debugPrint('📍 [AddShop] Accuracy: ${position.accuracy}');
      debugPrint('📍 [AddShop] Altitude: ${position.altitude}');

      setState(() {
        _latitude         = position.latitude;
        _longitude        = position.longitude;
        _fetchingLocation = false;
      });

      HapticFeedback.lightImpact();
      Get.snackbar(
        'Location Captured',
        'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: _primary,
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );

      debugPrint('📍 [AddShop] ===== GPS TOGGLE END (SUCCESS) =====');
      debugPrint('');
    } catch (e) {
      debugPrint('📍 [AddShop] ❌ Error getting location: $e');
      debugPrint('📍 [AddShop] Stack trace: ${StackTrace.current}');
      setState(() {
        _gpsEnabled       = false;
        _fetchingLocation = false;
      });
      _showError('Failed to get location: $e');
      debugPrint('📍 [AddShop] ===== GPS TOGGLE END (ERROR) =====');
      debugPrint('');
    }
  }

  void _showError(String msg) {
    debugPrint('❌ [AddShop] ERROR: $msg');
    Get.snackbar(
      'Error',
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

  @override
  void dispose() {
    debugPrint('🧹 [AddShop] Disposing controllers...');
    _shopNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _shopTypeCtrl.dispose();
    _notesCtrl.dispose();
    debugPrint('🧹 [AddShop] Controllers disposed');
    super.dispose();
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    debugPrint('');
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🏪 [AddShop] ===== SUBMIT STARTED =====');
    debugPrint('════════════════════════════════════════════════════════════');

    // Validate employee info first
    debugPrint('👤 [AddShop] Step 1: Validating employee info...');
    debugPrint('   empId: "$_empId"');
    debugPrint('   empName: "$_empName"');

    if (_empId.isEmpty || _empName.isEmpty) {
      debugPrint('⚠️ [AddShop] Employee info missing! Trying to reload...');
      await _loadEmployeeInfo(); // Try to reload
      if (_empId.isEmpty || _empName.isEmpty) {
        debugPrint('❌ [AddShop] Employee info still missing after reload!');
        Get.snackbar(
          '⚠️ Employee Info Missing',
          'Could not load your profile. Please log out and log in again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFC0392B),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        );
        debugPrint('🏪 [AddShop] ===== SUBMIT ENDED (FAILED - EMPLOYEE INFO) =====');
        debugPrint('');
        return;
      }
    }
    debugPrint('✅ [AddShop] Employee info valid');

    // Validate city
    debugPrint('🏙️ [AddShop] Step 2: Validating city...');
    debugPrint('   Selected city: "$_selectedCity"');
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      debugPrint('❌ [AddShop] No city selected!');
      Get.snackbar(
        'Required',
        'Please select a city',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
      debugPrint('🏪 [AddShop] ===== SUBMIT ENDED (FAILED - NO CITY) =====');
      debugPrint('');
      return;
    }
    debugPrint('✅ [AddShop] City selected: $_selectedCity');

    // Validate GPS
    debugPrint('📍 [AddShop] Step 3: Validating GPS...');
    debugPrint('   GPS Enabled: $_gpsEnabled');
    debugPrint('   Latitude: $_latitude');
    debugPrint('   Longitude: $_longitude');

    if (_gpsEnabled && (_latitude == null || _longitude == null)) {
      debugPrint('❌ [AddShop] GPS enabled but no location captured!');
      Get.snackbar(
        'Required',
        'Please wait for GPS location to be captured, or disable GPS',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 2),
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
      );
      debugPrint('🏪 [AddShop] ===== SUBMIT ENDED (FAILED - GPS NOT CAPTURED) =====');
      debugPrint('');
      return;
    }
    debugPrint('✅ [AddShop] GPS validation passed');

    // Validate form
    debugPrint('📝 [AddShop] Step 4: Validating form...');
    final formValid = _formKey.currentState?.validate() ?? false;
    debugPrint('   Form valid: $formValid');

    if (!formValid) {
      debugPrint('❌ [AddShop] Form validation failed!');
      debugPrint('🏪 [AddShop] ===== SUBMIT ENDED (FAILED - FORM INVALID) =====');
      debugPrint('');
      return;
    }
    debugPrint('✅ [AddShop] Form validation passed');

    HapticFeedback.lightImpact();

    // ── Build payload ──────────────────────────────────────────────────────
    debugPrint('📦 [AddShop] Step 5: Building payload...');

    final payload = {
      'shop_name':  _shopNameCtrl.text.trim(),
      'shop_type':  _shopTypeCtrl.text.trim(),
      'owner_name': _ownerNameCtrl.text.trim(),
      'contact_number': _contactCtrl.text.trim(),
      'city':       _selectedCity,
      'address':    _addressCtrl.text.trim(),
      'notes':      _notesCtrl.text.trim(),
      'emp_id':     _empId,
      'emp_name':   _empName,
      'company_code': _companyCode,
      'latitude':   _latitude,
      'longitude':  _longitude,
    };

    debugPrint('📦 [AddShop] Payload details:');
    debugPrint('   shop_name: "${payload['shop_name']}"');
    debugPrint('   shop_type: "${payload['shop_type']}"');
    debugPrint('   owner_name: "${payload['owner_name']}"');
    debugPrint('   contact_number: "${payload['contact_number']}"');
    debugPrint('   city: "${payload['city']}"');
    debugPrint('   address: "${payload['address']}"');
    debugPrint('   notes: "${payload['notes']}"');
    debugPrint('   emp_id: "${payload['emp_id']}"');
    debugPrint('   emp_name: "${payload['emp_name']}"');
    debugPrint('   company_code: "${payload['company_code']}"');
    debugPrint('   latitude: ${payload['latitude']}');
    debugPrint('   longitude: ${payload['longitude']}');

    final jsonPayload = jsonEncode(payload);
    debugPrint('📦 [AddShop] Full JSON payload:');
    debugPrint(jsonPayload);
    debugPrint('📦 [AddShop] Payload size: ${jsonPayload.length} bytes');

    // ── Send to API ────────────────────────────────────────────────────────
    debugPrint('');
    debugPrint('📡 [AddShop] Step 6: Sending to API...');

    final String apiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce/addshop/post/';
    debugPrint('📡 [AddShop] API URL: $apiUrl');
    debugPrint('📡 [AddShop] Method: POST');
    debugPrint('📡 [AddShop] Content-Type: application/json');

    try {
      final stopwatch = Stopwatch()..start();
      debugPrint('⏱️ [AddShop] Request started at: ${DateTime.now()}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonPayload,
      ).timeout(const Duration(seconds: 30));

      stopwatch.stop();
      debugPrint('⏱️ [AddShop] Request completed in ${stopwatch.elapsedMilliseconds}ms');

      debugPrint('📡 [AddShop] Response Status: ${response.statusCode}');
      debugPrint('📡 [AddShop] Response Headers: ${response.headers}');
      debugPrint('📡 [AddShop] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [AddShop] SUCCESS! Shop added successfully!');

        // Try to parse response
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('📦 [AddShop] Parsed response: $responseData');
        } catch (_) {}

        Get.snackbar(
          '✅ Success',
          'Shop added successfully!',
          snackPosition:   SnackPosition.BOTTOM,
          backgroundColor: _primary,
          colorText:       Colors.white,
          borderRadius:    14,
          margin:          const EdgeInsets.all(16),
          duration:        const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        );

        // Clear form after success
        debugPrint('🧹 [AddShop] Clearing form fields...');
        _shopNameCtrl.clear();
        _shopTypeCtrl.clear();
        _ownerNameCtrl.clear();
        _contactCtrl.clear();
        _addressCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _selectedCity = null;
          _latitude = null;
          _longitude = null;
          _gpsEnabled = false;
        });
        debugPrint('✅ [AddShop] Form cleared');

        // Navigate back after delay
        debugPrint('⏱️ [AddShop] Navigating back in 1 second...');
        Future.delayed(const Duration(seconds: 1), () {
          debugPrint('🏪 [AddShop] Navigating back to previous screen');
          Get.back();
        });
      } else {
        // Try to parse error message from response
        debugPrint('❌ [AddShop] API returned error status: ${response.statusCode}');
        String errorMsg = 'Failed to add shop. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          debugPrint('📦 [AddShop] Error response body: $errorData');
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          } else if (errorData['error'] != null) {
            errorMsg = errorData['error'];
          } else if (errorData['exception'] != null) {
            errorMsg = errorData['exception'];
          }
          debugPrint('📦 [AddShop] Extracted error message: "$errorMsg"');
        } catch (e) {
          debugPrint('⚠️ [AddShop] Could not parse error response: $e');
        }

        Get.snackbar(
          '❌ Error',
          errorMsg,
          snackPosition:   SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFC0392B),
          colorText:       Colors.white,
          borderRadius:    14,
          margin:          const EdgeInsets.all(16),
          duration:        const Duration(seconds: 3),
          icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        );
      }
    } catch (e) {
      debugPrint('❌ [AddShop] Network error: $e');
      debugPrint('❌ [AddShop] Stack trace: ${StackTrace.current}');

      String errorMsg = 'Could not connect to server. Please check your internet connection.';
      if (e.toString().contains('timeout')) {
        errorMsg = 'Request timed out. Server is taking too long to respond.';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'No internet connection. Please check your network.';
      }
      debugPrint('📦 [AddShop] User-friendly error: "$errorMsg"');

      Get.snackbar(
        'Network Error',
        errorMsg,
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC0392B),
        colorText:       Colors.white,
        borderRadius:    14,
        margin:          const EdgeInsets.all(16),
        duration:        const Duration(seconds: 3),
        icon: const Icon(Icons.wifi_off_rounded, color: Colors.white),
      );
    }

    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🏪 [AddShop] ===== SUBMIT ENDED =====');
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [AddShop] BUILD called');

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
                      onTap: () {
                        debugPrint('🏪 [AddShop] Back button pressed');
                        Get.back();
                      },
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
                          Text('Add Shop',
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 2),
                          Text('Register a new shop',
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
                      child: const Icon(Icons.add_business_rounded,
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

                  // ── Employee Info Badge ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F7F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.badge_rounded,
                              color: _primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _empName.isNotEmpty ? _empName : 'Loading...',
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A2E2C),
                                ),
                              ),
                              Text(
                                _empId.isNotEmpty ? 'ID: $_empId' : 'Please login first',
                                style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_companyCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F7F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _companyCode,
                              style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Shop Info ──────────────────────────────────────────
                  const _SectionHeader(icon: Icons.storefront_rounded, label: 'Shop Info'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Shop Name',
                    controller: _shopNameCtrl,
                    icon:       Icons.store_rounded,
                    hint:       'Enter shop name',
                    validator:  (v) {
                      final isValid = (v != null && v.trim().isNotEmpty);
                      debugPrint('🔍 [AddShop] Validating shop_name: "$v" -> $isValid');
                      return isValid ? null : 'Required';
                    },
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Shop Type',
                    controller: _shopTypeCtrl,
                    icon:       Icons.category_rounded,
                    hint:       'e.g. Retail, Wholesale',
                    isOptional: true,
                    validator:  null,
                  ),

                  const SizedBox(height: 20),

                  // ── Owner Info ───────────────────────────────────────────
                  const _SectionHeader(icon: Icons.person_rounded, label: 'Owner Info'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Owner Name',
                    controller: _ownerNameCtrl,
                    icon:       Icons.person_rounded,
                    hint:       "Owner's full name",
                    validator:  (v) {
                      final isValid = (v != null && v.trim().isNotEmpty);
                      debugPrint('🔍 [AddShop] Validating owner_name: "$v" -> $isValid');
                      return isValid ? null : 'Required';
                    },
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:           'Contact Number',
                    controller:      _contactCtrl,
                    icon:            Icons.phone_rounded,
                    hint:            '03XX-XXXXXXX',
                    keyboardType:    TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator:       (v) {
                      final isValid = (v != null && v.isNotEmpty);
                      debugPrint('🔍 [AddShop] Validating contact: "$v" -> $isValid');
                      return isValid ? null : 'Required';
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Location Info ────────────────────────────────────────
                  const _SectionHeader(icon: Icons.location_on_rounded, label: 'Location Info'),
                  const SizedBox(height: 12),

                  _CityDropdownCard(
                    value: _selectedCity,
                    items: _cities,
                    isLoading: _loadingCities,
                    onChanged: (v) {
                      debugPrint('🏙️ [AddShop] City selected: "$v"');
                      setState(() => _selectedCity = v);
                    },
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Address',
                    controller: _addressCtrl,
                    icon:       Icons.home_rounded,
                    hint:       'Full shop address',
                    maxLines:   2,
                    validator:  (v) {
                      final isValid = (v != null && v.trim().isNotEmpty);
                      debugPrint('🔍 [AddShop] Validating address: "$v" -> $isValid');
                      return isValid ? null : 'Required';
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── GPS Toggle Card ──────────────────────────────────────
                  _GpsToggleCard(
                    enabled:     _gpsEnabled,
                    fetching:    _fetchingLocation,
                    latitude:    _latitude,
                    longitude:   _longitude,
                    onChanged:   _onGpsToggle,
                    onRefresh:   () {
                      debugPrint('🔄 [AddShop] GPS refresh button pressed');
                      _onGpsToggle(true);
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Additional Info ──────────────────────────────────────
                  const _SectionHeader(icon: Icons.notes_rounded, label: 'Additional Info'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Notes',
                    controller: _notesCtrl,
                    icon:       Icons.sticky_note_2_rounded,
                    hint:       'Any extra remarks',
                    maxLines:   3,
                    isOptional: true,
                    validator:  null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Submit Button ───────────────────────────────────────────────────
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
              'Save Shop',
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
// GPS Toggle Card
// ─────────────────────────────────────────────────────────────────────────────
class _GpsToggleCard extends StatelessWidget {
  final bool                enabled;
  final bool                fetching;
  final double?             latitude;
  final double?             longitude;
  final ValueChanged<bool>  onChanged;
  final VoidCallback        onRefresh;

  static const _primary = Color(0xFF0C6B64);

  const _GpsToggleCard({
    required this.enabled,
    required this.fetching,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    required this.onRefresh,
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F7F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.gps_fixed_rounded,
                  color: enabled ? _primary : const Color(0xFFB0BAC7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Use Current Location (GPS)',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2E2C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fetching
                          ? 'Fetching location...'
                          : enabled
                          ? 'Location will be saved with shop'
                          : 'Enable to auto-capture lat/long',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              fetching
                  ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              )
                  : Switch(
                value: enabled,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: _primary,
                inactiveTrackColor: const Color(0xFFE5E9E8),
                inactiveThumbColor: Colors.white,
              ),
            ],
          ),

          if (enabled && latitude != null && longitude != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF0F4F3)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_rounded, color: _primary, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lat: ${latitude!.toStringAsFixed(5)}, Lng: ${longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600,
                      color: Color(0xFF1A6E59),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F7F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: _primary, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
  final TextInputType?                keyboardType;
  final List<TextInputFormatter>?     inputFormatters;
  final String? Function(String?)?    validator;
  final int                           maxLines;
  final bool                          readOnly;
  final VoidCallback?                 onTap;
  final bool                          showArrow;
  final bool                          showLock;
  final bool                          isOptional;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _FieldCard({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines   = 1,
    this.readOnly   = false,
    this.onTap,
    this.showArrow  = false,
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
                  keyboardType:    keyboardType,
                  inputFormatters: inputFormatters,
                  validator:       validator,
                  maxLines:        maxLines,
                  readOnly:        readOnly,
                  onTap:           onTap,
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
          if (showArrow)
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFB0BAC7), size: 22)
          else if (showLock)
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
// City Dropdown Card  —  tappable field that opens a searchable picker
// ─────────────────────────────────────────────────────────────────────────────
class _CityDropdownCard extends StatelessWidget {
  final String?           value;
  final List<String>      items;
  final bool               isLoading;
  final Function(String?) onChanged;

  static const _primary  = Color(0xFF0C6B64);
  static const _textDark = Color(0xFF1A2E2C);

  const _CityDropdownCard({
    required this.value,
    required this.items,
    required this.isLoading,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    if (isLoading) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySearchSheet(items: items, initialValue: value),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
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
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F7F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_city_rounded,
                  color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'City',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  isLoading
                      ? const Row(
                    children: [
                      SizedBox(
                        height: 14, width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading cities...',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: Color(0xFFB0BAC7),
                        ),
                      ),
                    ],
                  )
                      : Text(
                    (value == null || value!.isEmpty)
                        ? 'Select city'
                        : value!,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: (value == null || value!.isEmpty)
                          ? const Color(0xFFB0BAC7)
                          : _textDark,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFB0BAC7), size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// City Search Sheet — bottom sheet with search filter + list
// ─────────────────────────────────────────────────────────────────────────────
class _CitySearchSheet extends StatefulWidget {
  final List<String> items;
  final String?       initialValue;

  const _CitySearchSheet({required this.items, required this.initialValue});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  static const _primary = Color(0xFF0C6B64);

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
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
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
                  color: const Color(0xFFD4F0ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_rounded,
                        color: _primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Select City',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2E2C),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FFFE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _filter,
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2E2C),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city...',
                      hintStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400,
                        color: Color(0xFFB0BAC7),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _primary, size: 20),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _filter('');
                        },
                        child: const Icon(Icons.clear_rounded,
                            color: Color(0xFFB0BAC7), size: 18),
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEFF3F2)),

              // ── City list ────────────────────────────────────────────────
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                  child: Text(
                    'No cities found',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFFB0BAC7),
                    ),
                  ),
                )
                    : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1, color: Color(0xFFF0F4F3), indent: 20, endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final city = _filtered[index];
                    final isSelected = city == widget.initialValue;
                    return ListTile(
                      onTap: () => Navigator.pop(context, city),
                      title: Text(
                        city,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? _primary : const Color(0xFF1A2E2C),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20)
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