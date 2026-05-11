//
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
//
// import '../AppColors.dart';
//
// // ══════════════════════════════════════════════════════════════════════════════
// // MODEL
// // ══════════════════════════════════════════════════════════════════════════════
//
// class LocationItem {
//   final int    locationId;
//   final String locationName;
//   final double lat;
//   final double lng;
//   final double radius;
//   final String locationAddress;
//
//   const LocationItem({
//     required this.locationId,
//     required this.locationName,
//     required this.lat,
//     required this.lng,
//     required this.radius,
//     required this.locationAddress,
//   });
//
//   factory LocationItem.fromJson(Map<String, dynamic> json) {
//     return LocationItem(
//       locationId      : int.tryParse(json['location_id']?.toString() ?? '0') ?? 0,
//       locationName    : (json['location_name'] ?? '').toString().trim(),
//       lat             : double.parse(json['lat_in'].toString()),
//       lng             : double.parse(json['lng_in'].toString()),
//       radius          : double.parse(json['radius'].toString()),
//       locationAddress : (json['location_address'] ?? '').toString().trim(),
//     );
//   }
// }
//
// // ══════════════════════════════════════════════════════════════════════════════
// // SCREEN
// // ══════════════════════════════════════════════════════════════════════════════
//
// class LocationSelectionScreen extends StatefulWidget {
//   const LocationSelectionScreen({super.key});
//
//   @override
//   State<LocationSelectionScreen> createState() =>
//       _LocationSelectionScreenState();
// }
//
// class _LocationSelectionScreenState extends State<LocationSelectionScreen>
//     with SingleTickerProviderStateMixin {
//
//   bool               _isLoading  = true;
//   String?            _error;
//   List<LocationItem> _locations  = [];
//   bool               _isOffline  = false; // true when showing cached data
//
//   String _empId       = '';
//   String _companyCode = '';
//   String _token       = '';
//
//   late AnimationController _fadeCtrl;
//   late Animation<double>   _fadeAnim;
//
//   // ── Lifecycle ───────────────────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 450));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//     _loadPrefsAndFetch();
//   }
//
//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── Data ────────────────────────────────────────────────────────────────────
//   Future<void> _loadPrefsAndFetch() async {
//     final prefs = await SharedPreferences.getInstance();
//     _empId       = prefs.get('emp_id')?.toString() ?? '';
//     _companyCode = prefs.getString('companyCode') ?? '';
//     _token       = prefs.getString('auth_token') ?? '';
//     debugPrint('🔑 [LOCATION SELECT] emp_id=$_empId  company_code=$_companyCode');
//     await _fetchLocations();
//   }
//
//   Future<void> _fetchLocations() async {
//     setState(() { _isLoading = true; _error = null; _isOffline = false; });
//
//     // ── 1. Try live API ──────────────────────────────────────────────────────
//     try {
//       debugPrint('🌐 [LOCATION SELECT] Fetching live for emp_id=$_empId  company_code=$_companyCode');
//
//       final response = await http.get(
//         Uri.http(
//           'oracle.metaxperts.net',
//           '/ords/gps_workforce/geofenceinfo/get',
//           {
//             'emp_id'      : _empId,
//             'company_code': _companyCode,
//           },
//         ),
//         headers: {
//           'Content-Type': 'application/json',
//           if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
//         },
//       ).timeout(const Duration(seconds: 10));
//
//       debugPrint('📡 [LOCATION SELECT] Status: ${response.statusCode}');
//
//       if (response.statusCode == 200) {
//         final data  = jsonDecode(response.body) as Map<String, dynamic>;
//         final items = (data['items'] ?? []) as List<dynamic>;
//
//         if (items.isEmpty) {
//           // Live call succeeded but no locations – still update cache
//           _saveToCache([]);
//           setState(() {
//             _isLoading = false;
//             _error = 'No locations assigned to your account.\nPlease contact admin.';
//           });
//           return;
//         }
//
//         final parsed = _parseItems(items);
//
//         // ── Update cache with fresh data ─────────────────────────────────────
//         _saveToCache(items);
//
//         setState(() { _locations = parsed; _isLoading = false; });
//         debugPrint('✅ [LOCATION SELECT] Live: loaded ${parsed.length} location(s)');
//         return; // ← done, no need for fallback
//       }
//       // Non-200: fall through to cache
//       debugPrint('⚠️ [LOCATION SELECT] Server error ${response.statusCode} – trying cache');
//     } catch (e) {
//       // Network error (no internet, timeout, etc.) – fall through to cache
//       debugPrint('⚠️ [LOCATION SELECT] Network error: $e – trying cache');
//     }
//
//     // ── 2. Fallback: use cached locations ────────────────────────────────────
//     await _loadFromCache();
//   }
//
//   // ── Cache helpers ────────────────────────────────────────────────────────────
//   Future<void> _saveToCache(List<dynamic> rawItems) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('cached_locations', jsonEncode(rawItems));
//       await prefs.setString('cached_locations_emp_id', _empId);
//       debugPrint('💾 [LOCATION CACHE] Saved ${rawItems.length} item(s)');
//     } catch (e) {
//       debugPrint('⚠️ [LOCATION CACHE] Could not save: $e');
//     }
//   }
//
//   Future<void> _loadFromCache() async {
//     try {
//       final prefs      = await SharedPreferences.getInstance();
//       final cachedJson = prefs.getString('cached_locations');
//
//       if (cachedJson == null || cachedJson.isEmpty) {
//         setState(() {
//           _isLoading = false;
//           _error = 'No internet connection and no cached locations found.\nPlease connect and try again.';
//         });
//         return;
//       }
//
//       final items  = (jsonDecode(cachedJson) as List<dynamic>);
//       final parsed = _parseItems(items);
//
//       if (parsed.isEmpty) {
//         setState(() {
//           _isLoading = false;
//           _error = 'No locations found in cache.\nConnect to internet and retry.';
//         });
//         return;
//       }
//
//       setState(() {
//         _locations = parsed;
//         _isLoading = false;
//         _isOffline = true; // show offline banner
//       });
//       debugPrint('📦 [LOCATION CACHE] Loaded ${parsed.length} cached location(s)');
//     } catch (e) {
//       debugPrint('❌ [LOCATION CACHE] Failed to read cache: $e');
//       setState(() {
//         _isLoading = false;
//         _error = 'Connection failed and cache is unavailable.\nPlease try again.';
//       });
//     }
//   }
//
//   List<LocationItem> _parseItems(List<dynamic> items) {
//     final parsed = <LocationItem>[];
//     for (final item in items) {
//       try {
//         parsed.add(LocationItem.fromJson(item as Map<String, dynamic>));
//       } catch (e) {
//         debugPrint('⚠️ [LOCATION SELECT] Skipped malformed item: $e');
//       }
//     }
//     return parsed;
//   }
//
//   // ── Save selection & go back ─────────────────────────────────────────────────
//   Future<void> _saveAndGoBack(LocationItem item) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setInt('selected_location_id', item.locationId);
//     await prefs.setString('selected_location_name', item.locationName);
//     await prefs.setDouble('selected_lat', item.lat);
//     await prefs.setDouble('selected_lng', item.lng);
//     await prefs.setDouble('selected_radius', item.radius);
//     await prefs.setString('selected_location_address', item.locationAddress);
//
//     debugPrint('💾 [LOCATION SELECT] Saved: "${item.locationName}" (id=${item.locationId})');
//
//     Get.back(result: {
//       'location_id'  : item.locationId,
//       'location_name': item.locationName,
//       'lat'          : item.lat,
//       'lng'          : item.lng,
//       'radius'       : item.radius,
//       'address'      : item.locationAddress,
//     });
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // BUILD
//   // ══════════════════════════════════════════════════════════════════════════
//
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor:          Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: Column(
//           children: [
//             _buildHeader(),
//             // ── Offline banner (shown below header) ─────────────────────────
//             if (_isOffline) _buildOfflineBanner(),
//             Expanded(child: _buildBody()),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Offline banner ──────────────────────────────────────────────────────────
//   Widget _buildOfflineBanner() {
//     return Container(
//       width: double.infinity,
//       color: Colors.orange.shade700,
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Row(
//         children: [
//           const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
//           const SizedBox(width: 8),
//           const Expanded(
//             child: Text(
//               'Offline – showing cached locations',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           GestureDetector(
//             onTap: _fetchLocations, // retry button
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.25),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Text(
//                 'Retry',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Body switcher ────────────────────────────────────────────────────────────
//   Widget _buildBody() {
//     if (_isLoading)  return _buildLoader();
//     if (_error != null) return _buildError();
//     return _buildLocationList();
//   }
//
//   Widget _buildLoader() {
//     return const Center(
//       child: CircularProgressIndicator(color: AppColors.primary),
//     );
//   }
//
//   Widget _buildError() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.location_off_rounded,
//                 size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
//             const SizedBox(height: 16),
//             Text(
//               _error!,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color:    AppColors.textSecondary,
//                 fontSize: 14,
//                 height:   1.5,
//               ),
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton.icon(
//               onPressed: _fetchLocations,
//               icon:  const Icon(Icons.refresh_rounded),
//               label: const Text('Retry'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primary,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Gradient header ─────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             AppColors.primary,
//             AppColors.cyan,
//             AppColors.cyanBright,
//             AppColors.greenTeal,
//           ],
//           begin: Alignment.topLeft,
//           end:   Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft:  Radius.circular(36),
//           bottomRight: Radius.circular(36),
//         ),
//       ),
//       child: Stack(
//         children: [
//           Positioned(top: -50, right: -30,
//               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
//           Positioned(bottom: -40, left: -20,
//               child: _decorCircle(130, Colors.white, 0.10)),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//               child: Row(
//                 children: [
//                   // Back button
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.20),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Icon(Icons.arrow_back_ios_new_rounded,
//                           color: Colors.white, size: 18),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   // Title block
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Text('Select Location',
//                             style: TextStyle(
//                               color:      Colors.white,
//                               fontSize:   20,
//                               fontWeight: FontWeight.w700,
//                             )),
//                         SizedBox(height: 2),
//                         Text('Choose your work site',
//                             style: TextStyle(
//                               color:    Colors.white70,
//                               fontSize: 12,
//                             )),
//                       ],
//                     ),
//                   ),
//                   // Refresh icon (top-right)
//                   GestureDetector(
//                     onTap: _fetchLocations,
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.20),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Icon(Icons.refresh_rounded,
//                           color: Colors.white, size: 20),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Location list ───────────────────────────────────────────────────────────
//   Widget _buildLocationList() {
//     return SingleChildScrollView(
//       physics: const BouncingScrollPhysics(),
//       padding: const EdgeInsets.fromLTRB(18, 28, 18, 40),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _sectionHeader(
//             '${_locations.length} location(s) available',
//             Icons.place_rounded,
//             AppColors.cyan,
//           ),
//           const SizedBox(height: 6),
//           Padding(
//             padding: const EdgeInsets.only(left: 4, bottom: 20),
//             child: Text(
//               'Tap a location below to clock in',
//               style: TextStyle(
//                   color:    AppColors.textSecondary,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w400),
//             ),
//           ),
//           ...List.generate(_locations.length, (i) {
//             final item = _locations[i];
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 14),
//               child: _buildLocationCard(item),
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   // ── Location card ───────────────────────────────────────────────────────────
//   Widget _buildLocationCard(LocationItem item) {
//     return GestureDetector(
//       onTap: () => _saveAndGoBack(item),
//       child: Container(
//         width:   double.infinity,
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color:        AppColors.cardBg,
//           borderRadius: BorderRadius.circular(18),
//           border:       Border.all(color: AppColors.divider),
//           boxShadow: [
//             BoxShadow(
//               color:      Colors.black.withOpacity(0.05),
//               blurRadius: 14,
//               offset:     const Offset(0, 5),
//             ),
//           ],
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 56, height: 56,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.skyBlueDk.withOpacity(0.15),
//                     AppColors.cyan.withOpacity(0.08),
//                   ],
//                   begin: Alignment.topLeft,
//                   end:   Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(
//                     color: AppColors.skyBlueDk.withOpacity(0.20)),
//               ),
//               child: const Icon(Icons.location_on_rounded,
//                   size: 26, color: AppColors.skyBlueDk),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     item.locationName,
//                     style: const TextStyle(
//                       color:         AppColors.textPrimary,
//                       fontSize:      15,
//                       fontWeight:    FontWeight.w700,
//                       letterSpacing: 0.1,
//                     ),
//                   ),
//                   if (item.locationAddress.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       item.locationAddress,
//                       maxLines:  2,
//                       overflow:  TextOverflow.ellipsis,
//                       style: TextStyle(
//                           color:    AppColors.textSecondary,
//                           fontSize: 12,
//                           height:   1.4),
//                     ),
//                   ],
//                   const SizedBox(height: 8),
//                   Wrap(
//                     spacing:    6,
//                     runSpacing: 4,
//                     children: [
//                       _InfoPill(
//                         icon:  Icons.my_location_rounded,
//                         label: '${item.lat.toStringAsFixed(4)}, '
//                             '${item.lng.toStringAsFixed(4)}',
//                         color: AppColors.cyan,
//                       ),
//                       _InfoPill(
//                         icon:  Icons.radar_rounded,
//                         label: '${item.radius.toStringAsFixed(0)} m radius',
//                         color: AppColors.greenTeal,
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 8),
//             Container(
//               width: 34, height: 34,
//               decoration: BoxDecoration(
//                 color:        AppColors.skyBlueDk.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Icon(Icons.arrow_forward_ios_rounded,
//                   color: AppColors.skyBlueDk, size: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────────────
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               gradient:     AppColors.brandGradient,
//               borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color:        color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(
//               color:         AppColors.primary,
//               fontSize:      13,
//               fontWeight:    FontWeight.w700,
//               letterSpacing: 0.3)),
//     ]);
//   }
//
//   Widget _decorCircle(double size, Color color, double opacity) => Container(
//     width: size, height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: color.withOpacity(opacity),
//     ),
//   );
// }
//
// // ══════════════════════════════════════════════════════════════════════════════
// // INFO PILL WIDGET
// // ══════════════════════════════════════════════════════════════════════════════
//
// class _InfoPill extends StatelessWidget {
//   final IconData icon;
//   final String   label;
//   final Color    color;
//
//   const _InfoPill({
//     required this.icon,
//     required this.label,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color:        color.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(20),
//         border:       Border.all(color: color.withOpacity(0.18)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 11, color: color),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: TextStyle(
//                 fontSize:   11,
//                 color:      color,
//                 fontWeight: FontWeight.w600),
//           ),
//         ],
//       ),
//     );
//   }
// }

///firebase
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../AppColors.dart';
import '../../Services/remote_config_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class LocationItem {
  final int     locationId;
  final String  locationName;
  final double  lat;
  final double  lng;
  final double  radius;
  final String  locationAddress;
  final String? shapeCoords;   // NEW – raw JSON string from shape_coords
  final String? shapeType;     // NEW – e.g. "polygon" or null

  const LocationItem({
    required this.locationId,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.locationAddress,
    this.shapeCoords,
    this.shapeType,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      locationId      : int.tryParse(json['location_id']?.toString() ?? '0') ?? 0,
      locationName    : (json['building_office'] ?? '').toString().trim(), // MAPPED: building_office → locationName
      lat             : double.parse(json['lat_in'].toString()),
      lng             : double.parse(json['lng_in'].toString()),
      radius          : double.parse(json['radius'].toString()),
      locationAddress : (json['location_address'] ?? '').toString().trim(),
      shapeCoords     : json['shape_coords']?.toString(),
      shapeType       : json['shape_type']?.toString(),
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

  bool               _isLoading  = true;
  String?            _error;
  List<LocationItem> _locations  = [];
  bool               _isOffline  = false;

  String _empId       = '';
  String _companyCode = '';
  String _token       = '';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

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

  Future<void> _loadPrefsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _empId       = prefs.get('emp_id')?.toString() ?? '';
    _companyCode = prefs.getString('companyCode') ?? '';
    _token       = prefs.getString('auth_token') ?? '';
    debugPrint('🔑 [LOCATION SELECT] emp_id=$_empId  company_code=$_companyCode');
    await _fetchLocations();
  }

  // ✅ UPDATED: Using Remote Config for geofence URL
  Future<void> _fetchLocations() async {
    setState(() { _isLoading = true; _error = null; _isOffline = false; });

    try {
      debugPrint('🌐 [LOCATION SELECT] Fetching live for emp_id=$_empId  company_code=$_companyCode');

      final geofenceUrl = RemoteConfigService.getGeofenceUrl(_empId, _companyCode);
      debugPrint('📡 [LOCATION SELECT] URL: $geofenceUrl');

      final response = await http.get(
        Uri.parse(geofenceUrl),
        headers: {
          'Content-Type': 'application/json',
          if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
        },
      ).timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      debugPrint('📡 [LOCATION SELECT] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;

        if (items.isEmpty) {
          _saveToCache([]);
          setState(() {
            _isLoading = false;
            _error = 'No locations assigned to your account.\nPlease contact admin.';
          });
          return;
        }

        final parsed = _parseItems(items);
        _saveToCache(items);

        setState(() { _locations = parsed; _isLoading = false; });
        debugPrint('✅ [LOCATION SELECT] Live: loaded ${parsed.length} location(s)');
        return;
      }
      debugPrint('⚠️ [LOCATION SELECT] Server error ${response.statusCode} – trying cache');
    } catch (e) {
      debugPrint('⚠️ [LOCATION SELECT] Network error: $e – trying cache');
    }

    await _loadFromCache();
  }

  Future<void> _saveToCache(List<dynamic> rawItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_locations', jsonEncode(rawItems));
      await prefs.setString('cached_locations_emp_id', _empId);
      debugPrint('💾 [LOCATION CACHE] Saved ${rawItems.length} item(s)');
    } catch (e) {
      debugPrint('⚠️ [LOCATION CACHE] Could not save: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_locations');

      if (cachedJson == null || cachedJson.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No internet connection and no cached locations found.\nPlease connect and try again.';
        });
        return;
      }

      final items  = (jsonDecode(cachedJson) as List<dynamic>);
      final parsed = _parseItems(items);

      if (parsed.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No locations found in cache.\nConnect to internet and retry.';
        });
        return;
      }

      setState(() {
        _locations = parsed;
        _isLoading = false;
        _isOffline = true;
      });
      debugPrint('📦 [LOCATION CACHE] Loaded ${parsed.length} cached location(s)');
    } catch (e) {
      debugPrint('❌ [LOCATION CACHE] Failed to read cache: $e');
      setState(() {
        _isLoading = false;
        _error = 'Connection failed and cache is unavailable.\nPlease try again.';
      });
    }
  }

  List<LocationItem> _parseItems(List<dynamic> items) {
    final parsed = <LocationItem>[];
    for (final item in items) {
      try {
        parsed.add(LocationItem.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ [LOCATION SELECT] Skipped malformed item: $e');
      }
    }
    return parsed;
  }

  Future<void> _saveAndGoBack(LocationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_location_id', item.locationId);
    await prefs.setString('selected_location_name', item.locationName);
    await prefs.setDouble('selected_lat', item.lat);
    await prefs.setDouble('selected_lng', item.lng);
    await prefs.setDouble('selected_radius', item.radius);
    await prefs.setString('selected_location_address', item.locationAddress);
    // NEW – persist shape data
    if (item.shapeCoords != null) {
      await prefs.setString('selected_shape_coords', item.shapeCoords!);
    } else {
      await prefs.remove('selected_shape_coords');
    }
    if (item.shapeType != null) {
      await prefs.setString('selected_shape_type', item.shapeType!);
    } else {
      await prefs.remove('selected_shape_type');
    }

    debugPrint('💾 [LOCATION SELECT] Saved: "${item.locationName}" (id=${item.locationId})');

    Get.back(result: {
      'location_id'  : item.locationId,
      'location_name': item.locationName,
      'lat'          : item.lat,
      'lng'          : item.lng,
      'radius'       : item.radius,
      'address'      : item.locationAddress,
      'shape_coords' : item.shapeCoords,   // NEW
      'shape_type'   : item.shapeType,     // NEW
    });
  }

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
            if (_isOffline) _buildOfflineBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Offline – showing cached locations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: _fetchLocations,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading)  return _buildLoader();
    if (_error != null) return _buildError();
    return _buildLocationList();
  }

  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded,
                size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 14,
                height:   1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLocations,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Select Location',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   20,
                              fontWeight: FontWeight.w700,
                            )),
                        SizedBox(height: 2),
                        Text('Choose your work site',
                            style: TextStyle(
                              color:    Colors.white70,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _fetchLocations,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            '${_locations.length} location(s) available',
            Icons.place_rounded,
            AppColors.cyan,
          ),
          const SizedBox(height: 6),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.locationName,
                    style: const TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      15,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
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
                      // NEW – show shape type if available
                      if (item.shapeType != null && item.shapeType!.isNotEmpty)
                        _InfoPill(
                          icon:  item.shapeType == 'polygon'
                              ? Icons.hexagon_outlined
                              : Icons.radio_button_unchecked_rounded,
                          label: item.shapeType!,
                          color: AppColors.skyBlueDk,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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