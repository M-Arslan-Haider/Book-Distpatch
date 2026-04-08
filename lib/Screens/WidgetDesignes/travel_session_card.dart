
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../AppColors.dart';
import '../../ViewModels/attendance_view_model.dart';
import '../../ViewModels/location_view_model.dart';
import '../../ViewModels/travel_session_view_model.dart';
import '../location_session_screen.dart';

class TravelSessionCard extends StatefulWidget {
  const TravelSessionCard({super.key});

  @override
  State<TravelSessionCard> createState() => _TravelSessionCardState();
}

class _TravelSessionCardState extends State<TravelSessionCard> {
  final TravelViewModel    _travelVM     = Get.find<TravelViewModel>();
  final AttendanceViewModel _attendanceVM = Get.find<AttendanceViewModel>();
  final LocationViewModel  _locationVM   = Get.find<LocationViewModel>();

  Timer? _geofenceTimer;
  bool   _checkingGeofence = false;

  @override
  void initState() {
    super.initState();
    _geofenceTimer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _checkGeofence(),
    );
  }

  @override
  void dispose() {
    _geofenceTimer?.cancel();
    super.dispose();
  }

  // ── Geo-fence check ────────────────────────────────────────────────────────
  Future<void> _checkGeofence() async {
    if (!_travelVM.isInTravelMode ||
        !_travelVM.hasPendingLocation ||
        _travelVM.pendingLocation == null ||
        _checkingGeofence) return;

    _checkingGeofence = true;
    try {
      final loc    = _travelVM.pendingLocation!;
      final tLat   = (loc['lat']    ?? 0.0).toDouble();
      final tLng   = (loc['lng']    ?? 0.0).toDouble();
      final radius = (loc['radius'] ?? 100).toDouble();

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, tLat, tLng);

      if (dist <= radius) {
        final id = await _empId();
        if (id.isNotEmpty) unawaited(_travelVM.completeLocationSwitch(empId: id));
      }
    } catch (_) {}
    _checkingGeofence = false;
  }

  Future<String> _empId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.get('emp_id')?.toString() ?? '';
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _onStartTravel(BuildContext context) async {
    final id = await _empId();
    if (id.isEmpty) return;
    await _travelVM.startTravel(empId: id);
  }

  Future<void> _onSwitchLocation(BuildContext context) async {
    if (!_travelVM.isInTravelMode) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
    );
    if (result == null) return;

    final id = await _empId();
    await _travelVM.selectNewLocation({
      'location_id'  : result['location_id']   ?? 0,
      'location_name': result['location_name'] ?? 'Unknown',
      'lat'          : (result['lat']    ?? 0.0).toDouble(),
      'lng'          : (result['lng']    ?? 0.0).toDouble(),
      'radius'       : (result['radius'] ?? 100).toDouble(),
    });
    await _travelVM.completeLocationSwitch(empId: id);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // return Obx(() {
    //   if (!_attendanceVM.isClockedIn.value) return const SizedBox.shrink();
    return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, prefsSnap) {
          final geoFlag = (prefsSnap.data?.getString('geoFencing') ?? 'yes').toLowerCase().trim();
          if (geoFlag == 'no') return const SizedBox.shrink(); // ← hide entire card

          return Obx(() {
            if (!_attendanceVM.isClockedIn.value) return const SizedBox.shrink();

      final inTravel  = _travelVM.isInTravelMode;
      final hasPending = _travelVM.hasPendingLocation &&
          _travelVM.pendingLocation != null;

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                      Icons.route_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Travel Session',
                  style: TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                if (inTravel) _statusBadge('Active', AppColors.cyanBright),
              ],
            ),

            const SizedBox(height: 12),

            // // ── Status tiles ─────────────────────────────────────────
            // if (inTravel)
            //   _infoTile(
            //     icon:  Icons.directions_car_rounded,
            //     title: _travelVM.getTravelStatus(),
            //     color: AppColors.cyanBright,
            //   ),
            //
            // if (hasPending)
            //   _infoTile(
            //     icon:  Icons.location_searching_rounded,
            //     title: 'Traveling to ${_travelVM.pendingLocation!['location_name']}',
            //     color: AppColors.skyBlueDk,
            //   ),
            //
            // if (!inTravel && _travelVM.getCurrentLocationName().isNotEmpty)
            //   _infoTile(
            //     icon:  Icons.location_on_rounded,
            //     title: _travelVM.getCurrentLocationName(),
            //     color: AppColors.primary,
            //   ),

            // // ── Outside radius warning ────────────────────────────────
            // if (_travelVM.isOutsideRadius.value) ...[
            //   const SizedBox(height: 8),
            //   Container(
            //     padding: const EdgeInsets.symmetric(
            //         horizontal: 12, vertical: 10),
            //     decoration: BoxDecoration(
            //       color:        AppColors.error.withOpacity(0.07),
            //       borderRadius: BorderRadius.circular(12),
            //       border:       Border.all(
            //           color: AppColors.error.withOpacity(0.25), width: 1),
            //     ),
            //     child: Row(
            //       children: [
            //         Container(
            //           width: 28, height: 28,
            //           decoration: BoxDecoration(
            //             color:        AppColors.error.withOpacity(0.12),
            //             borderRadius: BorderRadius.circular(8),
            //           ),
            //           child: Icon(Icons.warning_amber_rounded,
            //               color: AppColors.error, size: 15),
            //         ),
            //         const SizedBox(width: 10),
            //         Expanded(
            //           child: Text(
            //             'You are outside the allowed area. Move closer.',
            //             style: TextStyle(
            //               color:    AppColors.error,
            //               fontSize: 11,
            //               fontWeight: FontWeight.w500,
            //               height:   1.4,
            //             ),
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ],

            const SizedBox(height: 12),

            // ── Action buttons ────────────────────────────────────────

// ── Action buttons ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    title:    'Start Travel',
                    icon:     Icons.play_arrow_rounded,
                    color:    AppColors.cyanBright,
                    gradient: const LinearGradient(
                      colors: [AppColors.greenTeal, AppColors.cyanBright],
                      begin:  Alignment.centerLeft,
                      end:    Alignment.centerRight,
                    ),
                    loading:  _travelVM.isStartingTravel.value,
                    disabled: _travelVM.isTravelMode.value,
                    onTap:    () => _onStartTravel(context),
                  ),
                ),
                const SizedBox(width: 8), // Reduced from 10
                Expanded(
                  child: _actionButton(
                    title:    'Switch',
                    icon:     Icons.swap_horiz_rounded,
                    color:    AppColors.primary,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.cyan],
                      begin:  Alignment.centerLeft,
                      end:    Alignment.centerRight,
                    ),
                    loading:  _travelVM.isSwitchingLocation.value,
                    onTap:    () => _onSwitchLocation(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
          });      // closes Obx
        },
    );           // closes FutureBuilder
  }              // closes build

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String   title,
    required Color    color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.18), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Also update the _actionButton helper method:
  Widget _actionButton({
    required String       title,
    required IconData     icon,
    required Color        color,
    required LinearGradient gradient,
    required VoidCallback onTap,
    bool loading  = false,
    bool disabled = false,
  }) {
    final isOff = loading || disabled;

    return GestureDetector(
      onTap: isOff ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 38, // Reduced from 44
        decoration: BoxDecoration(
          gradient:     isOff ? null : gradient,
          color:        isOff ? color.withOpacity(0.07) : null,
          borderRadius: BorderRadius.circular(10), // Reduced from 12
          border:       Border.all(
              color: isOff ? color.withOpacity(0.20) : Colors.transparent,
              width: 1),
          boxShadow: isOff
              ? []
              : [
            BoxShadow(
              color:      color.withOpacity(0.22), // Reduced opacity
              blurRadius: 8, // Reduced from 12
              offset:     const Offset(0, 3), // Reduced from 4
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 12, height: 12, // Reduced from 14
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isOff ? color : Colors.white),
              )
            else
              Container(
                width: 22, height: 22, // Reduced from 26
                decoration: BoxDecoration(
                  color: isOff
                      ? color.withOpacity(0.10)
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6), // Reduced from 7
                ),
                child: Icon(icon,
                    size: 12, // Reduced from 14
                    color: isOff ? color : Colors.white),
              ),
            const SizedBox(width: 6), // Reduced from 7
            Text(
              title,
              style: TextStyle(
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w600, // Reduced from 700
                letterSpacing: 0.2,
                color: isOff ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  }