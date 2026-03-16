import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

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

  /// Exact field names from GEO_FENCING table:
  /// LOCATION_ID, LOCATION_NAME, LAT_IN, LNG_IN, RADIUS, LOCATION_ADDRESS
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

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  bool _isLoading = true;
  String? _error;
  List<LocationItem> _locations = [];

  // Read from SharedPreferences
  String _empId = '';
  String _token = '';

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color _primaryColor = Color(0xFF4354E8);
  static const Color _bgColor = Color(0xFFF5F6FF);

  @override
  void initState() {
    super.initState();
    _loadPrefsAndFetch();
  }

  Future<void> _loadPrefsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _empId = prefs.get('emp_id')?.toString() ?? '';
    _token = prefs.getString('auth_token') ?? '';
    debugPrint('🔑 [LOCATION SELECT] emp_id=$_empId');
    await _fetchLocations();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API CALL
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint(
          '🌐 [LOCATION SELECT] Fetching for emp_id=${_empId}');

      final response = await http.get(
        Uri.parse(
          'http://oracle.metaxperts.net/ords/production/geofenceinfo/get?emp_id=${_empId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (_token.isNotEmpty)
            'Authorization': 'Bearer ${_token}',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 [LOCATION SELECT] Status: ${response.statusCode}');
      debugPrint('📡 [LOCATION SELECT] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items = data['items'] ?? [];

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

        setState(() {
          _locations = parsed;
          _isLoading = false;
        });

        debugPrint(
            '✅ [LOCATION SELECT] Loaded ${parsed.length} location(s)');
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

  // ══════════════════════════════════════════════════════════════════════════
  // SAVE SELECTED LOCATION → SharedPreferences → Home Screen wapas
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _saveAndGoBack(LocationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt   ('selected_location_id',      item.locationId);
    await prefs.setString('selected_location_name',    item.locationName);
    await prefs.setDouble('selected_lat',              item.lat);
    await prefs.setDouble('selected_lng',              item.lng);
    await prefs.setDouble('selected_radius',           item.radius);
    await prefs.setString('selected_location_address', item.locationAddress);

    debugPrint('💾 [LOCATION SELECT] Saved: "${item.locationName}" (id=${item.locationId})');

    Get.back(); // Home Screen par wapas jao
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Location',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            SizedBox(height: 16),
            Text('Fetching locations…',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style:
                TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchLocations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── List ─────────────────────────────────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header strip
        Container(
          color: _primaryColor,
          width: double.infinity,
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            '${_locations.length} location(s) available — select one to clock in',
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _locations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _LocationCard(
                  item: _locations[index],
                  onTap: () => _saveAndGoBack(_locations[index]),
                ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOCATION CARD WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  final LocationItem item;
  final VoidCallback onTap;

  const _LocationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF4354E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Color(0xFF4354E8), size: 24),
              ),

              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Name
                    Text(
                      item.locationName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Address (if present)
                    if (item.locationAddress.isNotEmpty) ...[
                      Text(
                        item.locationAddress,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Lat / Lng / Radius pill
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _InfoPill(
                          icon: Icons.my_location_rounded,
                          label:
                          '${item.lat.toStringAsFixed(4)}, ${item.lng.toStringAsFixed(4)}',
                        ),
                        _InfoPill(
                          icon: Icons.radar_rounded,
                          label: '${item.radius.toStringAsFixed(0)} m radius',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Arrow
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF4354E8), size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small info pill ──────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4354E8).withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF4354E8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4354E8),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}