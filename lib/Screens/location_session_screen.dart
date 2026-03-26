
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../AppColors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class LocationItem {
  final int    locationId;
  final String locationName;
  final double lat;
  final double lng;
  final double radius;
  final String locationAddress;

  const LocationItem({
    required this.locationId,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.locationAddress,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      locationId      : int.tryParse(json['location_id']?.toString() ?? '0') ?? 0,
      locationName    : (json['location_name'] ?? '').toString().trim(),
      lat             : double.parse(json['lat_in'].toString()),
      lng             : double.parse(json['lng_in'].toString()),
      radius          : double.parse(json['radius'].toString()),
      locationAddress : (json['location_address'] ?? '').toString().trim(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen>
    with SingleTickerProviderStateMixin {

  bool               _isLoading = true;
  String?            _error;
  List<LocationItem> _locations = [];

  String _empId = '';
  String _token = '';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // ── Lifecycle ───────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadPrefsAndFetch();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────
  Future<void> _loadPrefsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _empId = prefs.get('emp_id')?.toString() ?? '';
    _token = prefs.getString('auth_token') ?? '';
    debugPrint('🔑 [LOCATION SELECT] emp_id=$_empId');
    await _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      debugPrint('🌐 [LOCATION SELECT] Fetching for emp_id=$_empId');

      final response = await http.get(
        Uri.parse(
          'http://oracle.metaxperts.net/ords/production/geofenceinfo/get?emp_id=$_empId',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 [LOCATION SELECT] Status: ${response.statusCode}');
      debugPrint('📡 [LOCATION SELECT] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;

        if (items.isEmpty) {
          setState(() {
            _isLoading = false;
            _error = 'No locations assigned to your account.\nPlease contact admin.';
          });
          return;
        }

        final parsed = <LocationItem>[];
        for (final item in items) {
          try {
            parsed.add(LocationItem.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('⚠️ [LOCATION SELECT] Skipped malformed item: $e');
          }
        }

        setState(() { _locations = parsed; _isLoading = false; });
        debugPrint('✅ [LOCATION SELECT] Loaded ${parsed.length} location(s)');
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Server error (${response.statusCode}).\nPlease try again.';
        });
      }
    } catch (e) {
      debugPrint('❌ [LOCATION SELECT] Error: $e');
      setState(() {
        _isLoading = false;
        _error = 'Connection failed.\nCheck your internet and retry.';
      });
    }
  }

  Future<void> _saveAndGoBack(LocationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_location_id', item.locationId);
    await prefs.setString('selected_location_name', item.locationName);
    await prefs.setDouble('selected_lat', item.lat);
    await prefs.setDouble('selected_lng', item.lng);
    await prefs.setDouble('selected_radius', item.radius);
    await prefs.setString('selected_location_address', item.locationAddress);

    debugPrint('💾 [LOCATION SELECT] Saved: "${item.locationName}" (id=${item.locationId})');

    Get.back(result: {
      'location_id'  : item.locationId,
      'location_name': item.locationName,
      'lat'          : item.lat,
      'lng'          : item.lng,
      'radius'       : item.radius,
      'address'      : item.locationAddress,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── Gradient header (mirrors TaskScreen exactly) ────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30,
              child: _decorCircle(180, AppColors.greenTeal, 0.12)),
          Positioned(bottom: -40, left: -20,
              child: _decorCircle(130, Colors.white, 0.10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(
                            color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Location',
                          style: TextStyle(
                            color:         Colors.white,
                            fontSize:      18,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'GPS Workforce Monitor System',
                          style: TextStyle(
                            color:      Colors.white.withOpacity(0.65),
                            fontSize:   11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Location icon badge
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(
                          color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body router ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    return _buildLocationList();
  }

  // ── Loading ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.cyan),
          const SizedBox(height: 16),
          Text(
            'Fetching locations…',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color:        AppColors.cyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border:       Border.all(
                    color: AppColors.cyan.withOpacity(0.18)),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 38, color: AppColors.cyan),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:  AppColors.textSecondary,
                  fontSize: 14,
                  height:   1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _fetchLocations,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.cyan.withOpacity(0.30),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                          color:      Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location list ───────────────────────────────────────────────────────────
  Widget _buildLocationList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header  (same helper as TaskScreen)
          _sectionHeader(
            '${_locations.length} location(s) available',
            Icons.place_rounded,
            AppColors.cyan,
          ),
          const SizedBox(height: 6),

          // Sub-hint
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 20),
            child: Text(
              'Tap a location below to clock in',
              style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ),

          // Cards
          ...List.generate(_locations.length, (i) {
            final item = _locations[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildLocationCard(item),
            );
          }),

        ],
      ),
    );
  }

  // ── Location card (mirrors _buildOptionCard style) ──────────────────────────
  Widget _buildLocationCard(LocationItem item) {
    return GestureDetector(
      onTap: () => _saveAndGoBack(item),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container with gradient tint
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.skyBlueDk.withOpacity(0.15),
                    AppColors.cyan.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.skyBlueDk.withOpacity(0.20)),
              ),
              child: const Icon(Icons.location_on_rounded,
                  size: 26, color: AppColors.skyBlueDk),
            ),
            const SizedBox(width: 14),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.locationName,
                    style: const TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      15,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  // Address
                  if (item.locationAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.locationAddress,
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis,
                      style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12,
                          height:   1.4),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Coordinate & radius pills
                  Wrap(
                    spacing:    6,
                    runSpacing: 4,
                    children: [
                      _InfoPill(
                        icon:  Icons.my_location_rounded,
                        label: '${item.lat.toStringAsFixed(4)}, '
                            '${item.lng.toStringAsFixed(4)}',
                        color: AppColors.cyan,
                      ),
                      _InfoPill(
                        icon:  Icons.radar_rounded,
                        label: '${item.radius.toStringAsFixed(0)} m radius',
                        color: AppColors.greenTeal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Arrow badge
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color:        AppColors.skyBlueDk.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppColors.skyBlueDk, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info s

  // ── Helpers (same as TaskScreen) ────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient:     AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color:         AppColors.primary,
              fontSize:      13,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// INFO PILL WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize:   11,
                color:      color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}