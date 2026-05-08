// ═══════════════════════════════════════════════════════════════════════════════
// FILE: lib/Services/interval_selfie_service.dart
//
// INTERVAL SELFIE VERIFICATION SERVICE
//
// Flow:
//   1. Polls http://oracle.metaxperts.net/ords/gps_workforce/presencecheck/get/
//      every 10 sec to get NOTIF_COUNT and NOTIF_TIME for this employee.
//   2. Detects clock-in via SharedPreferences (isClockedIn flag — no existing
//      logic touched).
//   3. Schedules NOTIF_COUNT notifications at 2-hour intervals after clock-in.
//   4. When notification fires → shows [IntervalSelfieButton] on HomeScreen
//      for NOTIF_TIME minutes (e.g. "5MIN" = 5 minutes).
//   5. User taps button → front camera opens → photo taken → button hides.
//   6. After NOTIF_TIME minutes (grace) → button auto-hides.
//
// ADD TO home_screen.dart (two lines only — no other changes):
//   import '../Services/interval_selfie_service.dart';
//   // In _HomeScreenState.initState(), after Get.put(SelfieNotificationPolicyService()):
//   Get.put(IntervalSelfieService());
//   // In build() SliverList, after const SelfieGraceButton():
//   const IntervalSelfieButton(),
//
// ADD TO android/app/src/main/AndroidManifest.xml:
//   <receiver android:name=".IntervalSelfieAlarmReceiver"
//             android:exported="false" />
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: adjust this path to match your project structure
// e.g. '../Database/util.dart'  or  '../Helpers/db_helper.dart'
import '../Database/db_helper.dart';
import '../Database/util.dart';

// ─── SharedPreferences key constants ─────────────────────────────────────────
const String _kNotifCount    = 'interval_selfie_notif_count';
const String _kNotifTimeMin  = 'interval_selfie_notif_time_min';
const String _kClockInTime   = 'interval_selfie_clock_in_time';
const String _kNotifsFired   = 'interval_selfie_notifs_fired';
const String _kPending       = 'interval_selfie_notif_pending';
const String _kGraceExpiry   = 'interval_selfie_grace_expiry';
const String _kSelfieDone    = 'interval_selfie_done_flag';

// Existing SharedPrefs keys (read-only — no modification)
const String _kIsClockedIn   = 'isClockedIn';         // flutter.isClockedIn via boolean
const String _kClockInAt     = 'clockInTime';          // flutter.clockInTime

// ─── Notification channel ─────────────────────────────────────────────────────
const String _channelId      = 'interval_selfie_channel';
const String _channelName    = 'Interval Selfie Verification';
const String _channelDesc    = 'Periodic selfie verification during shift';
const String _actionOpenCamera = 'open_camera';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class IntervalSelfieService extends GetxController with WidgetsBindingObserver {
  static IntervalSelfieService get to => Get.find<IntervalSelfieService>();

  // ── Reactive state (consumed by IntervalSelfieButton widget) ───────────────
  final RxBool isButtonVisible    = false.obs;
  final RxInt  graceSecondsLeft   = 0.obs;
  final RxBool isFetching         = false.obs;

  // ── Policy ─────────────────────────────────────────────────────────────────
  int _notifCount       = 0;   // NOTIF_COUNT from backend (e.g. 3)
  int _notifTimeMinutes = 0;   // NOTIF_TIME parsed to minutes (e.g. "5MIN" → 5)

  // ── Identity ───────────────────────────────────────────────────────────────
  String _empId       = '';
  String _empName     = '';   // populated from API in _fetchPolicyFromApi
  String _companyCode = '';

  // ── Internal clock-in tracking ─────────────────────────────────────────────
  bool      _wasClockedIn   = false;
  DateTime? _clockInTime;
  int       _notifsFired    = 0;

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer?       _pollTimer;
  Timer?       _buttonHideTimer;
  Timer?       _graceCountdownTimer;
  Timer? _foregroundCheckTimer;
  final List<Timer> _notifTimers = [];

  // ── Notifications plugin ───────────────────────────────────────────────────
  late FlutterLocalNotificationsPlugin _notifPlugin;
  int _notifIdBase = 9300;

  // ── MethodChannel — same channel used by timer_card.dart ──────────────────
  static const _platform = MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor');

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this); // ✅ FIX: Register lifecycle observer
    _initNotificationsPlugin();
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] ✅ Service created');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ FIX: Unregister lifecycle observer
    _cancelAll();
    super.onClose();
  }

  // ✅ FIX: Directly observe app lifecycle — independent of TimerCard or HomeScreen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📸 [INTERVAL SELFIE] App resumed — checking pending notification');
      _checkPendingOnResume();
      _checkActiveNotification(); // ✅ FIX: pending=false hone par bhi active notif check karo
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API (called from HomeScreen)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize with employee credentials.
  /// Call from HomeScreen._loadUserData() after reading empId/companyCode.
  Future<void> initialize(String empId, String companyCode) async {
    if (empId.isEmpty || companyCode.isEmpty) {
      debugPrint('❌ [INTERVAL SELFIE] initialize: empId or companyCode empty — skipping');
      return;
    }

    _empId       = empId;
    _companyCode = companyCode;

    // ✅ FIX: Cold start par _wasClockedIn ko SharedPrefs se initialize karo.
    // Agar _wasClockedIn = false rehta hai aur user already clocked-in hai,
    // to pehle poll tick mein _checkClockInStateChange() galti se "fresh clock-in"
    // samajh leta hai aur Kotlin ka pending=true flag delete kar deta hai
    // (prefs.remove(_kPending) + _hideButton()), jis se button disappear ho jata hai.
    final initPrefs = await SharedPreferences.getInstance();
    await initPrefs.reload();
    _wasClockedIn = initPrefs.getBool(_kIsClockedIn) ?? false;

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] initialize');
    debugPrint('📸 [INTERVAL SELFIE]   empId         = "$_empId"');
    debugPrint('📸 [INTERVAL SELFIE]   companyCode   = "$_companyCode"');
    debugPrint('📸 [INTERVAL SELFIE]   _wasClockedIn = $_wasClockedIn (SharedPrefs se loaded)');

    await _fetchPolicyFromApi();
    _startPolling();
    _startForegroundCheck();

    // ✅ FIX: Check for pending notification immediately on initialize
    await _checkPendingOnResume();

    debugPrint('📸 [INTERVAL SELFIE] initialize DONE');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }


  /// Call when user taps the IntervalSelfieButton.
  Future<void> onSelfieButtonTapped([BuildContext? context]) async {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] Button tapped — launching camera');
    debugPrint('══════════════════════════════════════════════════════');

    try {
      final Uint8List? photo = await _captureAndCompressPhoto();

      if (photo != null && photo.isNotEmpty) {
        debugPrint('📸 [INTERVAL SELFIE] ✅ Photo captured (${photo.length} bytes) — hiding button');

        // Hide button immediately
        _hideButton();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kSelfieDone, true);
        await prefs.remove(_kPending);
        await prefs.remove(_kGraceExpiry);

        debugPrint('📸 [INTERVAL SELFIE] Pending flag cleared in SharedPrefs');

        // ── NEW: upload selfie to API (offline-safe, fire-and-forget) ──────────
        _uploadSelfie(photo); // intentionally not awaited — UI stays responsive

        if (context != null && context.mounted) {
          Get.snackbar(
            '✅ Selfie Captured',
            'Interval verification complete',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
          );
        }
      } else {
        debugPrint('📸 [INTERVAL SELFIE] Camera cancelled — button stays visible');
      }
    } catch (e, st) {
      debugPrint('❌ [INTERVAL SELFIE] onSelfieButtonTapped error: $e');
      debugPrint('❌ [INTERVAL SELFIE] Stack: $st');
    }
  }

  /// Public method to force check pending notification (called from HomeScreen on resume)
  Future<void> checkPendingOnResume() async {
    await _checkPendingOnResume();
    await _checkActiveNotification(); // ✅ FIX: active notification bhi check karo
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION PLUGIN INIT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initNotificationsPlugin() async {
    _notifPlugin = FlutterLocalNotificationsPlugin();

    if (await _notifPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled() ==
        false) {
      debugPrint('⚠️ [INTERVAL SELFIE] Notifications not enabled — permission may be needed');
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('📸 [INTERVAL SELFIE] Notification tapped actionId=${response.actionId} payload=${response.payload}');

        if (response.actionId == _actionOpenCamera) {
          // Open camera directly from the notification button.
          await onSelfieButtonTapped(Get.context);
          return;
        }

        if (response.payload == 'interval_selfie') {
          // ✅ FIX: pending flag pe depend mat karo — directly button show karo.
          await _showButtonFromNotificationTap();
        }
      },
    );

    await _notifPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ [INTERVAL SELFIE] Notification plugin initialized (channel=$_channelId)');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POLLING — every 10 seconds
  // Fetches NOTIF_COUNT + NOTIF_TIME, and checks clock-in state change.
  // ═══════════════════════════════════════════════════════════════════════════

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      debugPrint('🔄 [INTERVAL SELFIE] Poll tick');
      await _fetchPolicyFromApi();
      await _checkClockInStateChange();
      await _checkPendingOnResume();
      await _syncPendingSelfies(); // ── NEW: retry any offline-saved selfies
    });
    debugPrint('✅ [INTERVAL SELFIE] Polling started (interval = 10s)');
  }
  // void _startPolling() {
  //   _pollTimer?.cancel();
  //   _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
  //     debugPrint('🔄 [INTERVAL SELFIE] Poll tick');
  //     await _fetchPolicyFromApi();
  //     await _checkClockInStateChange();
  //     await _checkPendingOnResume();
  //   });
  //   debugPrint('✅ [INTERVAL SELFIE] Polling started (interval = 10s)');
  // }

  void _startForegroundCheck() {
    _foregroundCheckTimer?.cancel();
    _foregroundCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkPendingOnResume();
      await _checkActiveNotification(); // ✅ FIX: active notification bhi check karo
    });
    debugPrint('✅ [INTERVAL SELFIE] Foreground check started (every 3s)');
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // API FETCH
  // GET http://oracle.metaxperts.net/ords/gps_workforce/presencecheck/get/
  //   ?emp_id=<id>&company_code=<code>
  // Reads: NOTIF_COUNT, NOTIF_TIME
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchPolicyFromApi() async {
    if (_empId.isEmpty || _companyCode.isEmpty) return;
    if (isFetching.value) {
      debugPrint('⏳ [INTERVAL SELFIE] Already fetching — skip');
      return;
    }

    isFetching.value = true;

    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/presencecheck/get/'
          '?emp_id=${Uri.encodeComponent(_empId)}'
          '&company_code=${Uri.encodeComponent(_companyCode)}';

      debugPrint('🌐 [INTERVAL SELFIE] GET $url');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      debugPrint('🌐 [INTERVAL SELFIE] HTTP ${response.statusCode}');
      debugPrint('🌐 [INTERVAL SELFIE] Body (first 300): ${response.body.substring(0, response.body.length.clamp(0, 300))}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // ORDS can return: {"items":[{...}]} or [{...}] or {...}
        Map<String, dynamic>? item;
        if (decoded is Map<String, dynamic>) {
          final items = decoded['items'];
          if (items is List && items.isNotEmpty) {
            item = items.first as Map<String, dynamic>;
          } else {
            // Flat map (direct row)
            if (decoded.containsKey('NOTIF_COUNT') || decoded.containsKey('notif_count')) {
              item = decoded;
            }
          }
        } else if (decoded is List && decoded.isNotEmpty) {
          item = decoded.first as Map<String, dynamic>;
        }

        if (item != null) {
          final rawCount   = item['NOTIF_COUNT']   ?? item['notif_count']   ?? 0;
          final rawTimeStr = (item['NOTIF_TIME']   ?? item['notif_time']    ?? '').toString();
          final empName    = item['EMP_NAME']       ?? item['emp_name']      ?? '';
          final empId      = item['EMP_ID']         ?? item['emp_id']        ?? '';

          final newCount   = int.tryParse(rawCount.toString()) ?? 0;
          final newTimeMin = _parseNotifTime(rawTimeStr);

          debugPrint('📦 [INTERVAL SELFIE] API response:');
          debugPrint('📦 [INTERVAL SELFIE]   EMP_ID       = $empId');
          debugPrint('📦 [INTERVAL SELFIE]   EMP_NAME     = $empName');
          debugPrint('📦 [INTERVAL SELFIE]   NOTIF_COUNT  = $newCount  (raw=$rawCount)');
          debugPrint('📦 [INTERVAL SELFIE]   NOTIF_TIME   = $rawTimeStr → ${newTimeMin}min');

          final bool policyChanged =
              newCount != _notifCount || newTimeMin != _notifTimeMinutes;

          _notifCount       = newCount;
          _notifTimeMinutes = newTimeMin;
          if (empName.toString().isNotEmpty) _empName = empName.toString(); // ── NEW

          debugPrint('📦 [INTERVAL SELFIE]   policyChanged = $policyChanged');

          // Persist for Kotlin background service
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_kNotifCount,   _notifCount);
          await prefs.setInt(_kNotifTimeMin, _notifTimeMinutes);

          debugPrint('💾 [INTERVAL SELFIE] Policy saved to SharedPrefs');
        } else {
          debugPrint('⚠️ [INTERVAL SELFIE] API: item is null — no policy data found');
        }
      } else {
        debugPrint('⚠️ [INTERVAL SELFIE] API HTTP error: ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint('⏱️ [INTERVAL SELFIE] API timeout after 8s');
    } catch (e) {
      debugPrint('❌ [INTERVAL SELFIE] API fetch error: $e');
    } finally {
      isFetching.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOCK-IN STATE DETECTION
  // Reads isClockedIn from SharedPrefs every poll tick.
  // When false → true transition detected, schedules notifications.
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _checkClockInStateChange() async {
    final prefs      = await SharedPreferences.getInstance();
    final nowClocked = prefs.getBool(_kIsClockedIn) ?? false;

    debugPrint('🔍 [INTERVAL SELFIE] isClockedIn=$nowClocked  _wasClockedIn=$_wasClockedIn');

    if (nowClocked && !_wasClockedIn) {
      // ── Just clocked IN ────────────────────────────────────────────────────
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📸 [INTERVAL SELFIE] ✅ CLOCK-IN DETECTED');

      final clockInStr = prefs.getString(_kClockInAt) ?? '';
      DateTime clockInTime;
      try {
        clockInTime = clockInStr.isNotEmpty
            ? DateTime.parse(clockInStr)
            : DateTime.now();
      } catch (_) {
        clockInTime = DateTime.now();
      }

      _clockInTime = clockInTime;
      _notifsFired = 0;

      // ── Write clockInTime in Kotlin-compatible format ──────────────────────
      final clockInIso = clockInTime.toIso8601String().substring(0, 19);
      await prefs.setString(_kClockInTime, clockInIso);
      await prefs.setInt(_kNotifsFired, 0);
      await prefs.remove(_kSelfieDone);
      await prefs.remove(_kGraceExpiry);
      await prefs.remove(_kPending);

      debugPrint('📸 [INTERVAL SELFIE]   clockInTime  = $_clockInTime');
      debugPrint('📸 [INTERVAL SELFIE]   clockInIso   = $clockInIso  (saved for Kotlin)');
      debugPrint('📸 [INTERVAL SELFIE]   notifCount   = $_notifCount  (before fresh fetch)');
      debugPrint('📸 [INTERVAL SELFIE]   notifTimeMin = $_notifTimeMinutes  (before fresh fetch)');

      // ── STEP 1: Fetch fresh policy from API — saves to SharedPrefs ──────────
      debugPrint('📸 [INTERVAL SELFIE]   → Fetching fresh policy from API...');
      await _fetchPolicyFromApi();
      debugPrint('📸 [INTERVAL SELFIE]   → After fetch: notifCount=$_notifCount  notifTimeMin=$_notifTimeMinutes');

      // ── STEP 2: Schedule Flutter-side in-process timers ─────────────────────
      _scheduleNotifications();

      // ── STEP 3: Tell Kotlin (background service) to schedule AlarmManager ───
      try {
        await _platform.invokeMethod('scheduleIntervalSelfieAlarms');
        debugPrint('📸 [INTERVAL SELFIE]   → ✅ Kotlin scheduleAll() triggered via MethodChannel');
      } catch (e) {
        debugPrint('⚠️ [INTERVAL SELFIE]   → MethodChannel scheduleIntervalSelfieAlarms failed: $e');
        debugPrint('⚠️ [INTERVAL SELFIE]      (Flutter timers still active — foreground will work)');
      }

      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
    } else if (!nowClocked && _wasClockedIn) {
      // ── Just clocked OUT ───────────────────────────────────────────────────
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📸 [INTERVAL SELFIE] 🛑 CLOCK-OUT DETECTED — cancelling all timers');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');

      _cancelNotifTimers();
      _hideButton();
      _clockInTime   = null;
      _notifsFired   = 0;

      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.remove(_kPending);
      await prefs2.remove(_kGraceExpiry);
      await prefs2.remove(_kClockInTime);
      await prefs2.setInt(_kNotifsFired, 0);
    }

    _wasClockedIn = nowClocked;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCHEDULE NOTIFICATIONS — RANDOM INTERVALS
  //
  // Strategy:
  //   • Shift divided into NOTIF_COUNT slots of 2h each.
  //   • Each notification fires at a RANDOM minute within its slot.
  //   • All notifications guaranteed to fire — none missed.
  //
  // Slot #i  =  [(i-1)*120 … i*120) minutes after clock-in
  // Example (2 notifs):
  //   Slot 1: 0–120min   → fires at e.g. 47min after clock-in
  //   Slot 2: 120–240min → fires at e.g. 173min after clock-in
  // ═══════════════════════════════════════════════════════════════════════════

  void _scheduleNotifications() {
    _cancelNotifTimers();

    if (_notifCount <= 0) {
      debugPrint('📸 [INTERVAL SELFIE] NOTIF_COUNT=0 — nothing to schedule');
      return;
    }
    if (_clockInTime == null) {
      debugPrint('❌ [INTERVAL SELFIE] _clockInTime is null — cannot schedule');
      return;
    }

    final rng = Random();
    final now = DateTime.now();

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] SCHEDULING RANDOM NOTIFICATIONS');
    debugPrint('📸 [INTERVAL SELFIE]   clockInTime  = $_clockInTime');
    debugPrint('📸 [INTERVAL SELFIE]   notifCount   = $_notifCount');
    debugPrint('📸 [INTERVAL SELFIE]   notifTimeMin = $_notifTimeMinutes');
    debugPrint('📸 [INTERVAL SELFIE]   Strategy     = random within each 2h slot');
    debugPrint('──────────────────────────────────────────────────────');

    int scheduled = 0;
    for (int i = 1; i <= _notifCount; i++) {
      // Slot i covers [(i-1)*120 … i*120) minutes after clock-in
      final slotStartMin = (i - 1) * 120;
      final slotEndMin   = i * 120;
      final randomOffsetMin = slotStartMin + rng.nextInt(slotEndMin - slotStartMin);

      final fireAt = _clockInTime!.add(Duration(minutes: randomOffsetMin));
      final delay  = fireAt.difference(now);

      debugPrint('📸 [INTERVAL SELFIE]   Notif #$i:');
      debugPrint('📸 [INTERVAL SELFIE]     slot         = ${slotStartMin}min – ${slotEndMin}min after clock-in');
      debugPrint('📸 [INTERVAL SELFIE]     randomOffset = ${randomOffsetMin}min after clock-in');
      debugPrint('📸 [INTERVAL SELFIE]     fireAt       = $fireAt');
      debugPrint('📸 [INTERVAL SELFIE]     delay        = ${delay.inMinutes}min ${delay.inSeconds % 60}sec from NOW');

      if (delay.isNegative) {
        debugPrint('📸 [INTERVAL SELFIE]     ↳ ⚠️ slot already past — skipped');
        continue;
      }

      final capturedIndex = i;
      final timer = Timer(delay, () => _onNotificationFired(capturedIndex));
      _notifTimers.add(timer);
      scheduled++;
      debugPrint('📸 [INTERVAL SELFIE]     ↳ ✅ Timer set — fires in ${delay.inMinutes}min ${delay.inSeconds % 60}sec');
    }

    debugPrint('──────────────────────────────────────────────────────');
    debugPrint('📸 [INTERVAL SELFIE] Scheduled $scheduled / $_notifCount notification(s)');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  void _onNotificationFired(int index) {
    _notifsFired++;
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] 🔔 NOTIFICATION #$index FIRED');
    debugPrint('📸 [INTERVAL SELFIE]   total fired so far = $_notifsFired');
    debugPrint('📸 [INTERVAL SELFIE]   notifTimeMinutes   = $_notifTimeMinutes');
    debugPrint('📸 [INTERVAL SELFIE]   ⏱️ NOTIFICATION WILL LAST FOR: $_notifTimeMinutes minute(s)');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    // Save to SharedPrefs for Kotlin (background case)
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setBool(_kPending, true);
      await prefs.setInt(_kNotifsFired, _notifsFired);
      final expiry = DateTime.now().add(Duration(minutes: _notifTimeMinutes));
      await prefs.setString(_kGraceExpiry, expiry.toIso8601String());

      debugPrint('💾 [INTERVAL SELFIE]   ⏱️ Grace period expires at: $expiry (in $_notifTimeMinutes minutes)');
      debugPrint('💾 [INTERVAL SELFIE] Pending=true  expiry=$expiry saved to SharedPrefs');
    });

    _sendLocalNotification(index);
    _showButtonForGracePeriod();
  }

  Future<void> _sendLocalNotification(int index) async {
    // Keep a fixed ID per session so we can cancel this exact notification
    // after the selfie is taken or the grace period expires.
    // Do NOT increment here — we want to update/cancel by the same ID.
    final int notifId = _notifIdBase;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,           // MAX so heads-up banner appears
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      autoCancel: false,                    // KEEP notification until selfie done
      ongoing: false,
      color: const Color(0xFF00BCD4),
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,               // Force heads-up on locked screen
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionOpenCamera,
          'Open Camera',
          showsUserInterface: true,         // Bring app to foreground
          cancelNotification: true,         // Dismiss notification after tap
          inputs: const [],
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifPlugin.show(
      notifId,
      '📸 Interval Selfie Verification',
      'Please take your verification selfie now ($index of $_notifCount)',
      details,
      payload: 'interval_selfie',
    );

    debugPrint('🔔 [INTERVAL SELFIE] Local notification #$index sent (id=$notifId)');
  }

  /// Cancel the active interval selfie notification (called after selfie taken or grace expired).
  Future<void> _cancelActiveNotification() async {
    try {
      await _notifPlugin.cancel(_notifIdBase);
      debugPrint('🔔 [INTERVAL SELFIE] Notification cancelled (id=$_notifIdBase)');
    } catch (e) {
      debugPrint('⚠️ [INTERVAL SELFIE] Failed to cancel notification: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUTTON SHOW / HIDE
  // Button visible for _notifTimeMinutes (from NOTIF_TIME e.g. "5MIN" = 5min)
  // ═══════════════════════════════════════════════════════════════════════════

  void _showButtonForGracePeriod() {
    if (_notifTimeMinutes <= 0) {
      debugPrint('⚠️ [INTERVAL SELFIE] notifTimeMinutes=0 — button will not show');
      return;
    }

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] ▶ SHOWING BUTTON');
    debugPrint('📸 [INTERVAL SELFIE]   duration = ${_notifTimeMinutes} minutes');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    isButtonVisible.value   = true;
    graceSecondsLeft.value  = _notifTimeMinutes * 60;

    _buttonHideTimer?.cancel();
    _graceCountdownTimer?.cancel();

    // Auto-hide after NOTIF_TIME
    _buttonHideTimer = Timer(Duration(minutes: _notifTimeMinutes), () {
      debugPrint('⏱️ [INTERVAL SELFIE] Grace period expired — auto-hiding button');
      _hideButton();

      // ✅ Also clear SharedPrefs when timer expires
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_kPending);
        prefs.remove(_kGraceExpiry);
      });
    });

    // 1-second countdown for UI display
    _graceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (graceSecondsLeft.value > 0) {
        graceSecondsLeft.value--;
        if (graceSecondsLeft.value % 30 == 0) {
          debugPrint('⏱️ [INTERVAL SELFIE] Grace countdown: ${graceSecondsLeft.value}s left');
        }
      } else {
        t.cancel();
      }
    });
  }

  void _hideButton() {
    isButtonVisible.value  = false;
    graceSecondsLeft.value = 0;
    _buttonHideTimer?.cancel();
    _graceCountdownTimer?.cancel();
    _cancelActiveNotification();   // Dismiss the notification from the shade
    debugPrint('📸 [INTERVAL SELFIE] Button hidden');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESUME CHECK
  // When app resumes or HomeScreen rebuilds, check if there's a pending
  // notification from background (set by Kotlin IntervalSelfieAlarmReceiver).
  // ═══════════════════════════════════════════════════════════════════════════

  // ✅ FIX: Notification tap par directly button show karo.
  // pending flag pe depend nahi karte — sirf isClockedIn check karo aur
  // _notifTimeMinutes se grace period set karo. Agar _notifTimeMinutes=0 hai
  // (API fetch nahi hua) toh SharedPrefs se padhte hain.
  Future<void> _showButtonFromNotificationTap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final isClockedIn = prefs.getBool(_kIsClockedIn) ?? false;
    if (!isClockedIn) {
      debugPrint('📸 [INTERVAL SELFIE] _showButtonFromNotificationTap: not clocked in — skip');
      return;
    }

    // Already visible — no need to restart timers
    if (isButtonVisible.value) {
      debugPrint('📸 [INTERVAL SELFIE] _showButtonFromNotificationTap: button already visible');
      return;
    }

    // Grace minutes: use in-memory value, fall back to SharedPrefs
    int graceMin = _notifTimeMinutes;
    if (graceMin <= 0) {
      graceMin = prefs.getInt(_kNotifTimeMin) ?? 0;
    }
    if (graceMin <= 0) graceMin = 5; // last resort default — 5 minutes

    debugPrint('📸 [INTERVAL SELFIE] _showButtonFromNotificationTap: showing button graceMin=$graceMin');

    // Write pending + expiry so _checkPendingOnResume can also pick it up
    final expiry = DateTime.now().add(Duration(minutes: graceMin));
    await prefs.setBool(_kPending, true);
    await prefs.setString(_kGraceExpiry, expiry.toIso8601String());

    _notifTimeMinutes = graceMin;
    _showButtonForGracePeriod();
  }

  // ✅ FIX: Active notification bar check — agar flutter_local_notifications se
  // koi interval selfie notification active hai toh button show karo.
  // Yeh pending=false case ko cover karta hai jab Kotlin ne pending set nahi kiya.
  Future<void> _checkActiveNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final isClockedIn = prefs.getBool(_kIsClockedIn) ?? false;
      if (!isClockedIn || isButtonVisible.value) return;

      final List<ActiveNotification>? active = await _notifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();

      if (active == null) return;

      final bool hasInterval = active.any((n) =>
      n.id == _notifIdBase ||
          (n.channelId == _channelId));

      debugPrint('📸 [INTERVAL SELFIE] _checkActiveNotification: hasInterval=$hasInterval activeCount=${active.length}');

      if (hasInterval) {
        await _showButtonFromNotificationTap();
      }
    } catch (e) {
      debugPrint('⚠️ [INTERVAL SELFIE] _checkActiveNotification error: $e');
    }
  }

  Future<void> _checkPendingOnResume() async {
    final prefs   = await SharedPreferences.getInstance();
    await prefs.reload(); // ✅ FIX: Kotlin ne SharedPrefs mein likha hoga — reload() se fresh values milti hain

    // ✅ FIX: Agar user clocked out hai toh button kabhi mat dikhao.
    // Clockout ke baad _initializeSelfieServiceAfterShiftEnd() is function ko
    // call karta hai — lekin isClockedIn = false hai, isliye yahan early return
    // karo aur pending flag bhi clear karo taaki button galti se show na ho.
    final isClockedIn = prefs.getBool(_kIsClockedIn) ?? false;
    if (!isClockedIn) {
      debugPrint('🔍 [INTERVAL SELFIE] _checkPendingOnResume: not clocked in — skipping, clearing pending');
      await prefs.remove(_kPending);
      await prefs.remove(_kGraceExpiry);
      _hideButton();
      return;
    }

    final pending = prefs.getBool(_kPending) ?? false;

    debugPrint('🔍 [INTERVAL SELFIE] _checkPendingOnResume: pending=$pending');

    if (!pending) return;

    // Check if still within grace window
    final expiryStr = prefs.getString(_kGraceExpiry);
    if (expiryStr == null || expiryStr.isEmpty) {
      debugPrint('⚠️ [INTERVAL SELFIE] pending=true but no grace expiry — clearing');
      await prefs.remove(_kPending);
      return;
    }

    DateTime expiry;
    try {
      expiry = DateTime.parse(expiryStr);
    } catch (e) {
      debugPrint('⚠️ [INTERVAL SELFIE] Invalid expiry string: $expiryStr');
      await prefs.remove(_kPending);
      await prefs.remove(_kGraceExpiry);
      return;
    }

    final now       = DateTime.now();
    final remaining = expiry.difference(now);

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      debugPrint('⏱️ [INTERVAL SELFIE] Grace period already expired at $expiry — clearing');
      await prefs.remove(_kPending);
      await prefs.remove(_kGraceExpiry);
      _hideButton();
      return;
    }

    // Still within grace — restore button with remaining time
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📸 [INTERVAL SELFIE] RESUMING GRACE PERIOD');
    debugPrint('📸 [INTERVAL SELFIE]   expiry    = $expiry');
    debugPrint('📸 [INTERVAL SELFIE]   remaining = ${remaining.inSeconds}s');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    isButtonVisible.value  = true;
    graceSecondsLeft.value = remaining.inSeconds;

    _buttonHideTimer?.cancel();
    _graceCountdownTimer?.cancel();

    _buttonHideTimer = Timer(remaining, () {
      debugPrint('⏱️ [INTERVAL SELFIE] Resumed grace period expired — hiding button');
      _hideButton();
      prefs.remove(_kPending);
      prefs.remove(_kGraceExpiry);
    });

    _graceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (graceSecondsLeft.value > 0) {
        graceSecondsLeft.value--;
      } else {
        t.cancel();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMERA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Uint8List?> _captureAndCompressPhoto() async {
    try {
      debugPrint('📷 [INTERVAL SELFIE] Opening front camera...');

      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
      );

      if (photo == null) {
        debugPrint('📷 [INTERVAL SELFIE] Camera cancelled by user');
        return null;
      }

      Uint8List bytes = await photo.readAsBytes();
      debugPrint('📷 [INTERVAL SELFIE] Raw photo: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');

      bytes = await _compressBytes(bytes);
      debugPrint('📷 [INTERVAL SELFIE] After compression: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');

      return bytes.isEmpty ? null : bytes;
    } catch (e) {
      debugPrint('❌ [INTERVAL SELFIE] Camera error: $e');
      return null;
    }
  }

  Future<Uint8List> _compressBytes(Uint8List bytes) async {
    const int maxBytes = 60 * 1024; // 60 KB
    if (bytes.length <= maxBytes) {
      debugPrint('📷 [INTERVAL SELFIE COMPRESS] Within limit — no compression needed');
      return bytes;
    }

    debugPrint('📷 [INTERVAL SELFIE COMPRESS] Compressing ${(bytes.length / 1024).toStringAsFixed(1)} KB...');

    try {
      Uint8List current = bytes;
      int attempt = 0;

      while (current.length > maxBytes) {
        attempt++;

        final codec    = await ui.instantiateImageCodec(current);
        final frame    = await codec.getNextFrame();
        final image    = frame.image;
        final scale    = (maxBytes / current.length).clamp(0.1, 0.9);
        final newW     = (image.width * scale).toInt().clamp(1, image.width);
        final newH     = (image.height * scale).toInt().clamp(1, image.height);

        final recorder = ui.PictureRecorder();
        final canvas   = Canvas(recorder);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, newW.toDouble(), newH.toDouble()),
          Paint(),
        );
        final picture  = recorder.endRecording();
        final resized  = await picture.toImage(newW, newH);
        final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) break;
        current = byteData.buffer.asUint8List();

        debugPrint('📷 [INTERVAL SELFIE COMPRESS] Attempt $attempt → ${(current.length / 1024).toStringAsFixed(1)} KB (${newW}x$newH)');

        if (newW <= 50 || newH <= 50) {
          debugPrint('⚠️ [INTERVAL SELFIE COMPRESS] Image too small — stopping');
          break;
        }
      }

      debugPrint('📷 [INTERVAL SELFIE COMPRESS] Final: ${(current.length / 1024).toStringAsFixed(1)} KB after $attempt attempt(s)');
      return current;
    } catch (e) {
      debugPrint('❌ [INTERVAL SELFIE COMPRESS] Error: $e — returning original');
      return bytes;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse NOTIF_TIME string to minutes.
  /// "5MIN" → 5    "10MIN" → 10    "1HR" → 60    "30" → 30
  int _parseNotifTime(String raw) {
    if (raw.isEmpty) return 0;
    try {
      final upper = raw.trim().toUpperCase();
      debugPrint('🔍 [INTERVAL SELFIE] _parseNotifTime raw="$raw" upper="$upper"');

      if (upper.contains('HR') || upper.contains('HOUR')) {
        final digits = upper.replaceAll(RegExp(r'[^0-9]'), '');
        final minutes = (int.tryParse(digits) ?? 0) * 60;
        debugPrint('🔍 [INTERVAL SELFIE] _parseNotifTime → ${minutes}min (hours)');
        return minutes;
      }
      if (upper.contains('MIN')) {
        final digits  = upper.replaceAll(RegExp(r'[^0-9]'), '');
        final minutes = int.tryParse(digits) ?? 0;
        debugPrint('🔍 [INTERVAL SELFIE] _parseNotifTime → ${minutes}min (minutes)');
        return minutes;
      }
      // Plain number — assume minutes
      final digits  = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final minutes = int.tryParse(digits) ?? 0;
      debugPrint('🔍 [INTERVAL SELFIE] _parseNotifTime → ${minutes}min (plain number)');
      return minutes;
    } catch (e) {
      debugPrint('⚠️ [INTERVAL SELFIE] _parseNotifTime error: $e  raw="$raw"');
      return 0;
    }
  }

  void _cancelNotifTimers() {
    final count = _notifTimers.length;
    for (final t in _notifTimers) {
      t.cancel();
    }
    _notifTimers.clear();
    if (count > 0) debugPrint('🛑 [INTERVAL SELFIE] Cancelled $count notification timer(s)');
  }

  void _cancelAll() {
    _pollTimer?.cancel();
    _buttonHideTimer?.cancel();
    _graceCountdownTimer?.cancel();
    _cancelNotifTimers();
    debugPrint('🛑 [INTERVAL SELFIE] All timers cancelled');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SELFIE UPLOAD — API POST + OFFLINE QUEUE
  //
  // Endpoint:
  //   POST http://oracle.metaxperts.net/ords/gps_workforce/presencecheckpost/selfie/
  //   Content-Type: application/json
  //   Body: { emp_id, emp_name, company_code, body (base64), image_mime_type,
  //           latitude, longitude, captured_at }
  //
  // Offline behaviour:
  //   • If POST fails → row saved to selfie_log (posted=0).
  //   • Every poll tick (_syncPendingSelfies) retries unposted rows.
  //   • On success → row marked posted=1 (never deleted, kept for audit).
  // ═══════════════════════════════════════════════════════════════════════════

  /// Entry point — called (un-awaited) immediately after photo is taken.
  Future<void> _uploadSelfie(Uint8List photo) async {
    final capturedAt   = DateTime.now().toIso8601String().substring(0, 19);
    final loc          = await _getCurrentLocation();

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('📤 [SELFIE UPLOAD] Starting upload');
    debugPrint('📤 [SELFIE UPLOAD]   empId       = $_empId');
    debugPrint('📤 [SELFIE UPLOAD]   empName     = $_empName');
    debugPrint('📤 [SELFIE UPLOAD]   companyCode = $_companyCode');
    debugPrint('📤 [SELFIE UPLOAD]   capturedAt  = $capturedAt');
    debugPrint('📤 [SELFIE UPLOAD]   lat/lng     = ${loc.lat} / ${loc.lng}');
    debugPrint('📤 [SELFIE UPLOAD]   imageSize   = ${(photo.length / 1024).toStringAsFixed(1)} KB (raw bytes)');
    debugPrint('══════════════════════════════════════════════════════');

    final success = await _postSelfieToApi(
      empId:      _empId,
      empName:    _empName,
      companyCode: _companyCode,
      imageBytes: photo,           // raw bytes — ORDS :body receives binary directly
      lat:        loc.lat,
      lng:        loc.lng,
      capturedAt: capturedAt,
    );

    if (success) {
      debugPrint('✅ [SELFIE UPLOAD] Posted to API successfully');
    } else {
      debugPrint('📴 [SELFIE UPLOAD] API failed — saving offline for later sync');
      // DB stores base64 text (SQLite has no BLOB column here)
      await _saveSelfieOffline(
        empId:       _empId,
        empName:     _empName,
        companyCode: _companyCode,
        base64Image: base64Encode(photo),
        lat:         loc.lat,
        lng:         loc.lng,
        capturedAt:  capturedAt,
      );
    }
  }

  /// HTTP POST to the Oracle ORDS selfie endpoint.
  ///
  /// ORDS :body is a reserved implicit parameter = raw request body as BLOB.
  /// Therefore:
  ///   • HTTP body  → raw image bytes  (Content-Type: image/jpeg)
  ///   • All other  → URL query params (?emp_id=...&emp_name=...&...)
  ///
  /// Returns true only on HTTP 2xx.
  Future<bool> _postSelfieToApi({
    required String    empId,
    required String    empName,
    required String    companyCode,
    required Uint8List imageBytes,   // raw binary — NOT base64
    required double    lat,
    required double    lng,
    required String    capturedAt,
  }) async {
    const String _baseUrl =
        'http://oracle.metaxperts.net/ords/gps_workforce/presencecheckpost/selfie/';

    // Build URL with all non-image fields as query parameters
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'emp_id'         : empId,
      'emp_name'       : empName,
      'company_code'   : companyCode,
      'image_mime_type': 'image/jpeg',
      'latitude'       : lat.toString(),
      'longitude'      : lng.toString(),
      'captured_at'    : capturedAt,
    });

    try {
      // ── REQUEST DEBUG ──────────────────────────────────────────────────────
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📤 [SELFIE POST] ➜ REQUEST');
      debugPrint('📤 [SELFIE POST]   URL          : $uri');
      debugPrint('📤 [SELFIE POST]   Method       : POST');
      debugPrint('📤 [SELFIE POST]   Content-Type : image/jpeg');
      debugPrint('📤 [SELFIE POST]   ── Query Params ──');
      debugPrint('📤 [SELFIE POST]   emp_id         = $empId');
      debugPrint('📤 [SELFIE POST]   emp_name       = $empName');
      debugPrint('📤 [SELFIE POST]   company_code   = $companyCode');
      debugPrint('📤 [SELFIE POST]   image_mime_type= image/jpeg');
      debugPrint('📤 [SELFIE POST]   latitude       = $lat');
      debugPrint('📤 [SELFIE POST]   longitude      = $lng');
      debugPrint('📤 [SELFIE POST]   captured_at    = $capturedAt');
      debugPrint('📤 [SELFIE POST]   ── Body ──');
      debugPrint('📤 [SELFIE POST]   raw image bytes= ${imageBytes.length} bytes (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');
      debugPrint('📤 [SELFIE POST]   (ORDS :body binds this to SELFIE_IMAGE BLOB)');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📤 [SELFIE POST]   Sending request — waiting for server...');

      final response = await http
          .post(
        uri,
        headers: {
          'Content-Type': 'image/jpeg',
          'Accept':       'application/json',
        },
        body: imageBytes,   // raw bytes → ORDS :body → SELFIE_IMAGE BLOB
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('');
          debugPrint('══════════════════════════════════════════════════════');
          debugPrint('⏱️ [SELFIE POST] TIMEOUT — no response after 20s');
          debugPrint('⏱️ [SELFIE POST]   Server: $_baseUrl');
          debugPrint('⏱️ [SELFIE POST]   Selfie will be saved offline and retried');
          debugPrint('══════════════════════════════════════════════════════');
          debugPrint('');
          throw TimeoutException('Selfie POST timed out after 20s', const Duration(seconds: 20));
        },
      );

      // ── RESPONSE DEBUG ─────────────────────────────────────────────────────
      final bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('📥 [SELFIE POST] ← RESPONSE');
      debugPrint('📥 [SELFIE POST]   Status Code  : ${response.statusCode}');
      debugPrint('📥 [SELFIE POST]   Status Text  : ${isSuccess ? "✅ SUCCESS" : "❌ FAILED"}');
      debugPrint('📥 [SELFIE POST]   Content-Type : ${response.headers['content-type'] ?? 'N/A'}');
      debugPrint('📥 [SELFIE POST]   Body Length  : ${response.body.length} chars');
      debugPrint('📥 [SELFIE POST]   Body         : ${response.body.substring(0, response.body.length.clamp(0, 500))}');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');

      return isSuccess;
    } catch (e) {
      debugPrint('');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('❌ [SELFIE POST] EXCEPTION');
      debugPrint('❌ [SELFIE POST]   Error: $e');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return false;
    }
  }

  /// Save a failed selfie to the local selfie_log table.
  Future<void> _saveSelfieOffline({
    required String empId,
    required String empName,
    required String companyCode,
    required String base64Image,
    required double lat,
    required double lng,
    required String capturedAt,
  }) async {
    try {
      final db = DBHelper();
      await db.insert(DBHelper.selfieLogTable, {
        'emp_id'         : empId,
        'emp_name'       : empName,
        'company_code'   : companyCode,
        'selfie_image'   : base64Image,
        'image_mime_type': 'image/jpeg',
        'latitude'       : lat,
        'longitude'      : lng,
        'captured_at'    : capturedAt,
        'posted'         : 0,
      });
      debugPrint('💾 [SELFIE UPLOAD] Offline row saved — will retry on next poll');
    } catch (e) {
      debugPrint('❌ [SELFIE UPLOAD] _saveSelfieOffline error: $e');
    }
  }

  /// Called every poll tick — retries any rows in selfie_log with posted=0.
  Future<void> _syncPendingSelfies() async {
    try {
      final db       = DBHelper();
      final unposted = await db.getUnposted(DBHelper.selfieLogTable);

      if (unposted.isEmpty) return;

      debugPrint('');
      debugPrint('🔄 [SELFIE SYNC] Found ${unposted.length} unsynced selfie(s) — retrying...');

      for (final row in unposted) {
        final rowId = row['id']?.toString() ?? '';
        if (rowId.isEmpty) continue;

        final success = await _postSelfieToApi(
          empId:       row['emp_id']?.toString()       ?? '',
          empName:     row['emp_name']?.toString()     ?? '',
          companyCode: row['company_code']?.toString() ?? '',
          imageBytes:  base64Decode(row['selfie_image']?.toString() ?? ''), // decode DB base64 → bytes
          lat:         (row['latitude']  as num?)?.toDouble() ?? 0.0,
          lng:         (row['longitude'] as num?)?.toDouble() ?? 0.0,
          capturedAt:  row['captured_at']?.toString()  ?? '',
        );

        if (success) {
          await db.markAsPosted(DBHelper.selfieLogTable, 'id', rowId);
          debugPrint('✅ [SELFIE SYNC] Synced selfie id=$rowId (captured ${row['captured_at']})');
        } else {
          debugPrint('📴 [SELFIE SYNC] Still offline — selfie id=$rowId will retry next poll');
          break; // No internet yet — stop trying until next tick
        }
      }
    } catch (e) {
      debugPrint('❌ [SELFIE SYNC] _syncPendingSelfies error: $e');
    }
  }

  /// Get current GPS position.
  /// Falls back to (0.0, 0.0) if permission denied or timeout.
  Future<({double lat, double lng})> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ [SELFIE UPLOAD] Location service disabled — using 0.0,0.0');
        return (lat: 0.0, lng: 0.0);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [SELFIE UPLOAD] Location permission denied — using 0.0,0.0');
        return (lat: 0.0, lng: 0.0);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));

      debugPrint('📍 [SELFIE UPLOAD] Location: ${pos.latitude}, ${pos.longitude}');
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      debugPrint('⚠️ [SELFIE UPLOAD] _getCurrentLocation error: $e — using 0.0,0.0');
      return (lat: 0.0, lng: 0.0);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET — IntervalSelfieButton
//
// Placed in HomeScreen between SelfieGraceButton and QuickActions.
// Only visible when IntervalSelfieService.to.isButtonVisible == true.
// ═══════════════════════════════════════════════════════════════════════════════

class IntervalSelfieButton extends StatelessWidget {
  const IntervalSelfieButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Guard: if service not yet registered, render nothing
    if (!Get.isRegistered<IntervalSelfieService>()) {
      debugPrint('⚠️ [INTERVAL SELFIE BUTTON] Service not registered — widget invisible');
      return const SizedBox.shrink();
    }

    return Obx(() {
      final service = IntervalSelfieService.to;

      if (!service.isButtonVisible.value) return const SizedBox.shrink();

      final secondsLeft = service.graceSecondsLeft.value;
      final minutes     = secondsLeft ~/ 60;
      final seconds     = secondsLeft % 60;
      final countdown   = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      debugPrint('📸 [INTERVAL SELFIE BUTTON] Rendering — graceLeft=$countdown');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onTap: () => service.onSelfieButtonTapped(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Camera icon ──────────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_front_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // ── Text ─────────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interval Selfie Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap to verify your presence · expires in $countdown',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Arrow ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}