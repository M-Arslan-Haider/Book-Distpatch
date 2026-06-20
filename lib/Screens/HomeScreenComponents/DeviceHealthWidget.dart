// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart' as geo;
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:android_intent_plus/android_intent.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../../AppColors.dart';
//
// // ══════════════════════════════════════════════════════════════════════════════
// // DeviceHealthWidget — App theme colors (tealLight/tealDark) matched with Navbar
// // ══════════════════════════════════════════════════════════════════════════════
//
// class DeviceHealthWidget extends StatefulWidget {
//   const DeviceHealthWidget({super.key});
//
//   @override
//   State<DeviceHealthWidget> createState() => _DeviceHealthWidgetState();
// }
//
// class _DeviceHealthWidgetState extends State<DeviceHealthWidget>
//     with WidgetsBindingObserver {
//
//   // ── State ──────────────────────────────────────────────────────────────────
//   bool _gpsEnabled        = false;
//   bool _gpsPermitted      = false;
//   bool _bgLocationAllowed = false;
//   bool _batteryOptGood    = false;
//   bool _isOnline          = false;
//   bool _loading           = true;
//
//   // ── Streams & timers ───────────────────────────────────────────────────────
//   StreamSubscription<geo.ServiceStatus>? _gpsServiceSub;
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
//   Timer? _pollTimer;
//
//   static const _channel = MethodChannel(
//       'com.metaxperts.GPS_Workforce_Monitor/location_monitor');
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initAll();
//   }
//
//   @override
//   void dispose() {
//     _gpsServiceSub?.cancel();
//     _connectivitySub?.cancel();
//     _pollTimer?.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _checkGpsPermission();
//       _checkBgLocation();
//       _checkBatteryOptimization();
//     }
//   }
//
//   // ── Init ───────────────────────────────────────────────────────────────────
//   Future<void> _initAll() async {
//     await Future.wait([
//       _checkGpsService(),
//       _checkGpsPermission(),
//       _checkBgLocation(),
//       _checkBatteryOptimization(),
//       _checkInternet(),
//     ]);
//     if (mounted) setState(() => _loading = false);
//
//     // GPS on/off → instant stream
//     _gpsServiceSub = geo.Geolocator.getServiceStatusStream().listen((status) {
//       if (mounted) setState(() => _gpsEnabled = status == geo.ServiceStatus.enabled);
//       _checkGpsPermission();
//     });
//
//     // Internet → instant stream
//     _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
//       if (mounted) setState(() {
//         _isOnline = results.any((r) => r != ConnectivityResult.none);
//       });
//     });
//
//     // Battery + BgLocation + GPS perm → har 2s poll
//     _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
//       _checkGpsPermission();
//       _checkBgLocation();
//       _checkBatteryOptimization();
//     });
//   }
//
//   Future<void> _checkGpsService() async {
//     final enabled = await geo.Geolocator.isLocationServiceEnabled();
//     if (mounted) setState(() => _gpsEnabled = enabled);
//   }
//
//   Future<void> _checkGpsPermission() async {
//     final perm = await geo.Geolocator.checkPermission();
//     final ok = perm == geo.LocationPermission.always ||
//         perm == geo.LocationPermission.whileInUse;
//     if (mounted) setState(() => _gpsPermitted = ok);
//   }
//
//   Future<void> _checkBgLocation() async {
//     final perm = await geo.Geolocator.checkPermission();
//     if (mounted) setState(() => _bgLocationAllowed = perm == geo.LocationPermission.always);
//   }
//
//   Future<void> _checkBatteryOptimization() async {
//     bool good = false;
//     try {
//       final result = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
//       good = result ?? false;
//     } catch (_) {
//       final status = await Permission.ignoreBatteryOptimizations.status;
//       good = status.isGranted;
//     }
//     if (mounted) setState(() => _batteryOptGood = good);
//   }
//
//   Future<void> _checkInternet() async {
//     final result = await Connectivity().checkConnectivity();
//     if (mounted) setState(() => _isOnline = result != ConnectivityResult.none);
//   }
//
//   // ── Computed ───────────────────────────────────────────────────────────────
//   bool get _gpsGood => _gpsEnabled && _gpsPermitted;
//
//   String get _gpsSubtitle {
//     if (!_gpsEnabled) return 'Location Off';
//     if (!_gpsPermitted) return 'Denied';
//     return 'Allowed';
//   }
//
//   String get _bgSubtitle       => _bgLocationAllowed ? 'Allowed' : 'Not Allowed';
//   String get _batterySubtitle  => _batteryOptGood ? 'Disabled' : 'Enabled';
//   String get _internetSubtitle => _isOnline ? 'Connected' : 'Disconnected';
//
//   // ── Settings openers ───────────────────────────────────────────────────────
//   Future<void> _openLocationSettings() async {
//     if (!_gpsEnabled) {
//       const AndroidIntent(action: 'android.settings.LOCATION_SOURCE_SETTINGS').launch();
//     } else {
//       await openAppSettings();
//     }
//   }
//
//   Future<void> _openBatterySettings() async {
//     try {
//       const AndroidIntent(
//         action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
//         data: 'package:com.metaxperts.GPS_Workforce_Monitor',
//       ).launch();
//     } catch (_) {
//       await openAppSettings();
//     }
//   }
//
//   // ── Battery Info Popup — app theme colors ──────────────────────────────────
//   void _showBatteryInfoDialog() {
//     showDialog(
//       context: context,
//       barrierColor: Colors.black.withOpacity(0.45),
//       builder: (ctx) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         backgroundColor: Colors.white,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // ── Icon circle — tealLight tint ────────────────────────────
//               Container(
//                 width: 60, height: 60,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: AppColors.tealSurface,
//                   border: Border.all(
//                       color: AppColors.tealLight.withOpacity(0.30), width: 1.5),
//                 ),
//                 child: const Icon(Icons.info_rounded,
//                     size: 30, color: AppColors.tealDark),
//               ),
//               const SizedBox(height: 16),
//
//               // ── Title ───────────────────────────────────────────────────
//               const Text('Info',
//                   style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       color: AppColors.textPrimary)),
//               const SizedBox(height: 12),
//
//               // ── Body ────────────────────────────────────────────────────
//               Text(
//                 'If battery optimization is enabled, your phone may stop background tracking.\nPlease disable it for better tracking.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                     fontSize: 13.5,
//                     color: AppColors.textSecondary,
//                     height: 1.55),
//               ),
//               const SizedBox(height: 24),
//
//               // ── Got it button — navbar gradient ─────────────────────────
//               SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: DecoratedBox(
//                   decoration: BoxDecoration(
//                     gradient: AppColors.brandGradient,
//                     borderRadius: BorderRadius.circular(12),
//                     boxShadow: AppColors.cyanGlow,
//                   ),
//                   child: TextButton(
//                     onPressed: () => Navigator.of(ctx).pop(),
//                     child: const Text('Got it',
//                         style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                             letterSpacing: 0.3)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // BUILD
//   // ══════════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.divider, width: 1),
//         boxShadow: AppColors.cardShadow,
//       ),
//       child: Column(
//         children: [
//           // ── Header — gradient top bar ────────────────────────────────────
//           Container(
//             padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
//             decoration: BoxDecoration(
//               gradient: AppColors.brandGradient,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
//             ),
//             child: Row(
//               children: [
//                 // Phone icon box
//                 Container(
//                   width: 34, height: 34,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.18),
//                     borderRadius: BorderRadius.circular(9),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.30), width: 1),
//                   ),
//                   child: const Icon(Icons.phone_android_rounded,
//                       size: 18, color: Colors.white),
//                 ),
//                 const SizedBox(width: 10),
//                 const Text('Device Health',
//                     style: TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white,
//                         letterSpacing: 0.2)),
//                 const SizedBox(width: 6),
//                 // Info icon in header
//                 GestureDetector(
//                   onTap: _showBatteryInfoDialog,
//                   child: Icon(Icons.info_outline_rounded,
//                       size: 16, color: Colors.white.withOpacity(0.80)),
//                 ),
//                 const Spacer(),
//                 // View Details link
//                 Flexible(
//                   child: GestureDetector(
//                     onTap: () => openAppSettings(),
//                     child: Text('View Details →',
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                             fontSize: 11.5,
//                             color: Colors.white.withOpacity(0.90),
//                             fontWeight: FontWeight.w600)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // ── Rows ────────────────────────────────────────────────────────
//           if (_loading)
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 24),
//               child: SizedBox(
//                 width: 22, height: 22,
//                 child: CircularProgressIndicator(
//                     strokeWidth: 2, color: AppColors.tealLight),
//               ),
//             )
//           else ...[
//             _healthRow(
//               icon: Icons.gps_fixed_rounded,
//               iconColor: AppColors.tealDark,
//               iconBg: AppColors.tealSurface,
//               title: 'GPS Permission',
//               subtitle: _gpsSubtitle,
//               isGood: _gpsGood,
//               onTap: _gpsGood ? null : _openLocationSettings,
//             ),
//             _divider(),
//             _healthRow(
//               icon: Icons.location_on_rounded,
//               iconColor: AppColors.tealDark,
//               iconBg: AppColors.tealSurface,
//               title: 'Background Location',
//               subtitle: _bgSubtitle,
//               isGood: _bgLocationAllowed,
//               onTap: _bgLocationAllowed ? null : () => openAppSettings(),
//             ),
//             _divider(),
//             _healthRow(
//               icon: Icons.battery_charging_full_rounded,
//               iconColor: AppColors.warning,
//               iconBg: const Color(0xFFFFF3E0),
//               title: 'Battery Optimization',
//               subtitle: _batterySubtitle,
//               isGood: _batteryOptGood,
//               showInfoIcon: true,
//               onInfoTap: _showBatteryInfoDialog,
//               onTap: _batteryOptGood ? null : _openBatterySettings,
//             ),
//             _divider(),
//             _healthRow(
//               icon: Icons.wifi_rounded,
//               iconColor: AppColors.tealDark,
//               iconBg: AppColors.tealSurface,
//               title: 'Internet',
//               subtitle: _internetSubtitle,
//               isGood: _isOnline,
//               onTap: null,
//             ),
//           ],
//
//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }
//
//   // ── Single row ─────────────────────────────────────────────────────────────
//   Widget _healthRow({
//     required IconData icon,
//     required Color iconColor,
//     required Color iconBg,
//     required String title,
//     required String subtitle,
//     required bool isGood,
//     bool showInfoIcon = false,
//     VoidCallback? onInfoTap,
//     VoidCallback? onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       splashColor: AppColors.tealSurface,
//       highlightColor: AppColors.tealSurface.withOpacity(0.5),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
//         child: Row(
//           children: [
//             // Icon box
//             Container(
//               width: 38, height: 38,
//               decoration: BoxDecoration(
//                   color: iconBg,
//                   borderRadius: BorderRadius.circular(10)),
//               child: Icon(icon, size: 18, color: iconColor),
//             ),
//             const SizedBox(width: 12),
//
//             // Title + subtitle
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(children: [
//                     Flexible(
//                       child: Text(title,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                               fontSize: 13.5,
//                               fontWeight: FontWeight.w600,
//                               color: AppColors.textPrimary)),
//                     ),
//                     if (showInfoIcon) ...[
//                       const SizedBox(width: 5),
//                       GestureDetector(
//                         onTap: onInfoTap,
//                         child: const Icon(Icons.info_outline_rounded,
//                             size: 15, color: AppColors.tealLight),
//                       ),
//                     ],
//                   ]),
//                   const SizedBox(height: 2),
//                   Text(subtitle,
//                       style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                           color: isGood
//                               ? AppColors.tealDark
//                               : AppColors.error)),
//                 ],
//               ),
//             ),
//
//             const SizedBox(width: 8),
//
//             // Badge
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//               decoration: BoxDecoration(
//                 color: isGood ? AppColors.tealSurface : const Color(0xFFFFEBEB),
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(
//                     color: isGood
//                         ? AppColors.tealLight.withOpacity(0.35)
//                         : AppColors.error.withOpacity(0.30)),
//               ),
//               child: Text(
//                 isGood ? 'Good' : 'Fix',
//                 style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: isGood ? AppColors.tealDark : AppColors.error),
//               ),
//             ),
//
//             // Arrow if fixable
//             if (onTap != null) ...[
//               const SizedBox(width: 4),
//               const Icon(Icons.chevron_right_rounded,
//                   size: 16, color: AppColors.tealLight),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _divider() => Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     child: Divider(height: 1, color: AppColors.divider),
//   );
// }

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../AppColors.dart';

class DeviceHealthWidget extends StatefulWidget {
  const DeviceHealthWidget({super.key});

  @override
  State<DeviceHealthWidget> createState() => _DeviceHealthWidgetState();
}

class _DeviceHealthWidgetState extends State<DeviceHealthWidget>
    with WidgetsBindingObserver {

  bool _gpsEnabled        = false;
  bool _gpsPermitted      = false;
  bool _bgLocationAllowed = false;
  bool _batteryOptGood    = false;
  bool _isOnline          = false;
  bool _loading           = true;

  StreamSubscription<geo.ServiceStatus>? _gpsServiceSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;

  static const _channel = MethodChannel(
      'com.metaxperts.GPS_Workforce_Monitor/location_monitor');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  @override
  void dispose() {
    _gpsServiceSub?.cancel();
    _connectivitySub?.cancel();
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGpsPermission();
      _checkBgLocation();
      _checkBatteryOptimization();
    }
  }

  Future<void> _initAll() async {
    await Future.wait([
      _checkGpsService(),
      _checkGpsPermission(),
      _checkBgLocation(),
      _checkBatteryOptimization(),
      _checkInternet(),
    ]);
    if (mounted) setState(() => _loading = false);

    _gpsServiceSub = geo.Geolocator.getServiceStatusStream().listen((status) {
      if (mounted) setState(() => _gpsEnabled = status == geo.ServiceStatus.enabled);
      _checkGpsPermission();
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
      });
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkGpsPermission();
      _checkBgLocation();
      _checkBatteryOptimization();
    });
  }

  Future<void> _checkGpsService() async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _gpsEnabled = enabled);
  }

  Future<void> _checkGpsPermission() async {
    final perm = await geo.Geolocator.checkPermission();
    final ok = perm == geo.LocationPermission.always ||
        perm == geo.LocationPermission.whileInUse;
    if (mounted) setState(() => _gpsPermitted = ok);
  }

  Future<void> _checkBgLocation() async {
    final perm = await geo.Geolocator.checkPermission();
    if (mounted) setState(() => _bgLocationAllowed = perm == geo.LocationPermission.always);
  }

  Future<void> _checkBatteryOptimization() async {
    bool good = false;
    try {
      final result = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      good = result ?? false;
    } catch (_) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      good = status.isGranted;
    }
    if (mounted) setState(() => _batteryOptGood = good);
  }

  Future<void> _checkInternet() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = result != ConnectivityResult.none);
  }

  bool get _gpsGood => _gpsEnabled && _gpsPermitted;

  String get _gpsSubtitle {
    if (!_gpsEnabled) return 'Location Off';
    if (!_gpsPermitted) return 'Denied';
    return 'Allowed';
  }

  String get _bgSubtitle       => _bgLocationAllowed ? 'Allowed' : 'Not Allowed';
  String get _batterySubtitle  => _batteryOptGood ? 'Disabled' : 'Enabled';
  String get _internetSubtitle => _isOnline ? 'Connected' : 'Disconnected';

  Future<void> _openLocationSettings() async {
    if (!_gpsEnabled) {
      const AndroidIntent(action: 'android.settings.LOCATION_SOURCE_SETTINGS').launch();
    } else {
      await openAppSettings();
    }
  }

  Future<void> _openBatterySettings() async {
    try {
      const AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.metaxperts.GPS_Workforce_Monitor',
      ).launch();
    } catch (_) {
      await openAppSettings();
    }
  }

  void _showBatteryInfoDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealSurface,
                  border: Border.all(
                      color: AppColors.tealLight.withOpacity(0.30), width: 1.5),
                ),
                child: const Icon(Icons.info_rounded,
                    size: 30, color: AppColors.tealDark),
              ),
              const SizedBox(height: 16),
              const Text('Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Text(
                'If battery optimization is enabled, your phone may stop background tracking.\nPlease disable it for better tracking.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5,
                    color: AppColors.textSecondary, height: 1.55),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cyanGlow,
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ── Outer white card (screenshot jaisa — light border, subtle shadow)
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9), // very light teal-white, screenshot jaisa bg
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header row (NO gradient — plain bg like screenshot) ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Green icon box — same as screenshot
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Color(0xFF3DAF93),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Text('Device Health',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _showBatteryInfoDialog,
                  child: const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.tealLight),
                ),
                const Spacer(),
                Flexible(
                  child: GestureDetector(
                    onTap: () => openAppSettings(),
                    child: Text('View Device Details →',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.tealLight,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // ── Inner white container — rows inside ───────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider.withOpacity(0.7), width: 1),
            ),
            child: _loading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.tealLight),
                ),
              ),
            )
                : Column(
              children: [
                _healthRow(
                  icon: Icons.gps_fixed_rounded,
                  iconBg: Color(0xFF3DAF93),
                  title: 'GPS Permission',
                  subtitle: _gpsSubtitle,
                  isGood: _gpsGood,
                  onTap: _gpsGood ? null : _openLocationSettings,
                ),
                _divider(),
                _healthRow(
                  icon: Icons.diamond_outlined,
                  iconBg: Color(0xFF3DAF93),
                  title: 'Background Location',
                  subtitle: _bgSubtitle,
                  isGood: _bgLocationAllowed,
                  onTap: _bgLocationAllowed ? null : () => openAppSettings(),
                ),
                _divider(),
                _healthRow(
                  icon: Icons.battery_charging_full_rounded,
                  iconBg: AppColors.warning,
                  title: 'Battery Optimization',
                  subtitle: _batterySubtitle,
                  isGood: _batteryOptGood,
                  showInfoIcon: true,
                  onInfoTap: _showBatteryInfoDialog,
                  onTap: _batteryOptGood ? null : _openBatterySettings,
                ),
                _divider(),
                _healthRow(
                  icon: Icons.wifi_rounded,
                  iconBg: Color(0xFF3DAF93),
                  title: 'Internet',
                  subtitle: _internetSubtitle,
                  isGood: _isOnline,
                  onTap: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool isGood,
    bool showInfoIcon = false,
    VoidCallback? onInfoTap,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: AppColors.tealSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // ── Icon box — rounded square, colored bg, white icon ──────────
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),

            // ── Title + subtitle ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    if (showInfoIcon) ...[
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: onInfoTap,
                        child: const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.tealLight),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isGood
                              ? AppColors.tealDark
                              : AppColors.error)),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Good / Fix badge ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isGood ? AppColors.tealSurface : const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isGood
                        ? AppColors.tealLight.withOpacity(0.35)
                        : AppColors.error.withOpacity(0.30)),
              ),
              child: Text(
                isGood ? 'Good' : 'Fix',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isGood ? AppColors.tealDark : AppColors.error),
              ),
            ),

            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.tealLight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    indent: 14,
    endIndent: 14,
    color: AppColors.divider.withOpacity(0.6),
  );
}