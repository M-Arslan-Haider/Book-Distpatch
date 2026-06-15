
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../ViewModels/login_view_model.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// wagers_attendance_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class WagersAttendanceScreen extends StatefulWidget {
  const WagersAttendanceScreen({super.key});

  @override
  State<WagersAttendanceScreen> createState() => _WagersAttendanceScreenState();
}

class _WagersAttendanceScreenState extends State<WagersAttendanceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg        = Color(0xFFF4F6FB);
  static const _teal      = Color(0xFF0C6B64);
  static const _tealLight = Color(0xFFE0F5F3);
  static const _textDark  = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  List<Map<String, dynamic>> _all      = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _loading = true;
  String _error   = '';
  final  _searchCtrl = TextEditingController();

  // Track which wagers are currently being posted (to show loading on button)
  final Set<String> _clockInLoading  = {};
  final Set<String> _clockOutLoading = {};

  // Timer tracking for each wager
  final Map<String, Timer?> _timers = {};
  final Map<String, int> _elapsedSeconds = {};
  final Map<String, bool> _isClockedIn = {};
  final Map<String, String> _attendanceIds = {};

  // Track serial numbers per day per wager (in-memory cache)
  final Map<String, int> _serialCounter = {};

  @override
  void initState() {
    super.initState();
    _loadPersistedState(); // Load saved clocked-in state
    _fetchWagers();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    // Don't cancel timers on dispose - they should keep running
    super.dispose();
  }

  // Load persisted clocked-in state from SharedPreferences
  Future<void> _loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();

    // Load all saved wager states
    final savedWagers = prefs.getStringList('clocked_in_wagers') ?? [];

    for (String wagerId in savedWagers) {
      final savedSeconds = prefs.getInt('elapsed_seconds_$wagerId') ?? 0;
      final savedAttendanceId = prefs.getString('attendance_id_$wagerId') ?? '';
      final savedStartTime = prefs.getInt('start_time_$wagerId') ?? 0;

      setState(() {
        _isClockedIn[wagerId] = true;
        _elapsedSeconds[wagerId] = savedSeconds;
        _attendanceIds[wagerId] = savedAttendanceId;
      });

      // Calculate elapsed time based on saved start time
      if (savedStartTime > 0) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final elapsedSinceStart = (currentTime - savedStartTime) ~/ 1000;
        setState(() {
          _elapsedSeconds[wagerId] = savedSeconds + elapsedSinceStart;
        });
      }

      // Restart timer for this wager
      _startTimer(wagerId);
    }
  }

  // Save clocked-in state to SharedPreferences
  Future<void> _saveClockedInState(String wagerId, int elapsedSeconds, String attendanceId) async {
    final prefs = await SharedPreferences.getInstance();

    // Add to list of clocked in wagers
    List<String> clockedInWagers = prefs.getStringList('clocked_in_wagers') ?? [];
    if (!clockedInWagers.contains(wagerId)) {
      clockedInWagers.add(wagerId);
      await prefs.setStringList('clocked_in_wagers', clockedInWagers);
    }

    // Save elapsed seconds
    await prefs.setInt('elapsed_seconds_$wagerId', elapsedSeconds);

    // Save start time
    await prefs.setInt('start_time_$wagerId', DateTime.now().millisecondsSinceEpoch);

    // Save attendance ID
    await prefs.setString('attendance_id_$wagerId', attendanceId);
  }

  // Remove clocked-in state from SharedPreferences
  Future<void> _removeClockedInState(String wagerId) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove from list
    List<String> clockedInWagers = prefs.getStringList('clocked_in_wagers') ?? [];
    clockedInWagers.remove(wagerId);
    await prefs.setStringList('clocked_in_wagers', clockedInWagers);

    // Remove individual entries
    await prefs.remove('elapsed_seconds_$wagerId');
    await prefs.remove('start_time_$wagerId');
    await prefs.remove('attendance_id_$wagerId');
  }

  // ── Serial Counter Persistence ─────────────────────────────────────────────
  Future<void> _saveSerialCounter(String wagerId, int serial, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final key = 'serial_counter_${wagerId}_$dateKey';
    await prefs.setInt(key, serial);
    debugPrint('💾 [SERIAL] Saved: $key = $serial');
  }

  Future<int> _loadSerialCounter(String wagerId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final key = 'serial_counter_${wagerId}_$dateKey';
    final savedSerial = prefs.getInt(key);

    if (savedSerial != null) {
      debugPrint('📂 [SERIAL] Loaded: $key = $savedSerial');
      return savedSerial;
    }

    debugPrint('📂 [SERIAL] No saved serial for $key, starting from 1');
    return 1;
  }

  // Format elapsed time as HH:MM:SS
  String _formatElapsedTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Start timer for a specific wager
  void _startTimer(String wagerId) {
    _timers[wagerId]?.cancel();

    _timers[wagerId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds[wagerId] = (_elapsedSeconds[wagerId] ?? 0) + 1;
        });
        // Update persisted state every 30 seconds
        if ((_elapsedSeconds[wagerId] ?? 0) % 30 == 0) {
          _saveClockedInState(wagerId, _elapsedSeconds[wagerId] ?? 0, _attendanceIds[wagerId] ?? '');
        }
      }
    });
  }

  // Stop timer for a specific wager
  void _stopTimer(String wagerId) {
    _timers[wagerId]?.cancel();
    _timers[wagerId] = null;
  }

  // Reset timer for a specific wager
  void _resetTimer(String wagerId) async {
    _stopTimer(wagerId);
    await _removeClockedInState(wagerId);
    setState(() {
      _elapsedSeconds[wagerId] = 0;
      _isClockedIn[wagerId] = false;
      _attendanceIds.remove(wagerId);
    });
  }

  // ── Selfie Capture ────────────────────────────────────────────────────────
  Future<String?> _captureSelfie() async {
    debugPrint('📸 [SELFIE] Starting selfie capture...');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (photo == null) {
        debugPrint('📸 [SELFIE] User cancelled — no photo taken');
        return null;
      }

      debugPrint('📸 [SELFIE] Photo path: ${photo.path}');

      Uint8List bytes = await photo.readAsBytes();
      debugPrint('📸 [SELFIE] Original size: ${bytes.length} bytes (${(bytes.length / 1024).toStringAsFixed(2)} KB)');

      // Compress if larger than 60 KB
      bytes = await _compressImageIfNeeded(bytes);

      if (bytes.isEmpty) {
        debugPrint('❌ [SELFIE] Bytes are 0');
        return null;
      }

      // Convert to base64 for API
      final base64Image = base64Encode(bytes);
      debugPrint('📸 [SELFIE] Base64 length: ${base64Image.length} chars');

      return base64Image;
    } catch (e) {
      debugPrint('❌ [SELFIE] Error capturing / compressing photo: $e');
      return null;
    }
  }

  // ── Image Compression Helper ──────────────────────────────────────────────
  Future<Uint8List> _compressImageIfNeeded(Uint8List bytes) async {
    const int maxBytes = 60 * 1024; // 60 KB

    if (bytes.length <= maxBytes) {
      debugPrint('📸 [COMPRESS] Image within limit — no compression needed');
      return bytes;
    }

    debugPrint('📸 [COMPRESS] Image exceeds 60 KB (${(bytes.length / 1024).toStringAsFixed(1)} KB) — compressing...');

    try {
      Uint8List current = bytes;
      int attempt = 0;

      while (current.length > maxBytes && attempt < 5) {
        attempt++;

        final codec = await ui.instantiateImageCodec(current);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        double scale = (maxBytes / current.length);
        scale = scale.clamp(0.1, 0.9);

        final int newWidth  = (image.width * scale).toInt().clamp(1, image.width);
        final int newHeight = (image.height * scale).toInt().clamp(1, image.height);

        final recorder = ui.PictureRecorder();
        final canvas   = Canvas(recorder);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
          Paint(),
        );
        final picture  = recorder.endRecording();
        final resized  = await picture.toImage(newWidth, newHeight);
        final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) break;

        current = byteData.buffer.asUint8List();
        debugPrint('📸 [COMPRESS] Attempt $attempt → ${(current.length / 1024).toStringAsFixed(1)} KB (${newWidth}x$newHeight)');

        if (newWidth <= 50 || newHeight <= 50) {
          debugPrint('⚠️ [COMPRESS] Image too small to reduce further — stopping');
          break;
        }
      }

      debugPrint('📸 [COMPRESS] Final size: ${(current.length / 1024).toStringAsFixed(1)} KB after $attempt attempt(s)');
      return current;
    } catch (e) {
      debugPrint('❌ [COMPRESS] Compression failed: $e — returning original bytes');
    }

    return bytes;
  }

  // ── ID Generator with Serial (persists across app restarts) ────────────────
  // Format: {COMPANY_CODE}-ATD-WAG-{WAGER_ID}-{DD}-{MMM}-{SERIAL}
  Future<String> _buildAttendanceId({required String wagerId}) async {
    final now = DateTime.now();
    final day = DateFormat('dd').format(now);
    final month = DateFormat('MMM').format(now).toUpperCase();
    final wPart = wagerId.padLeft(4, '0');

    // Create a key for this wager and date
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final serialKey = '$wagerId-$dateKey';

    // Get serial from memory first, if not found, load from SharedPreferences
    int serial = _serialCounter[serialKey] ?? 0;

    if (serial == 0) {
      // Load from SharedPreferences
      serial = await _loadSerialCounter(wagerId, now);
      _serialCounter[serialKey] = serial;
    }

    final loginVM = Get.find<LoginViewModel>();
    final companyCode = loginVM.currentUser.value?.company_code?.toString() ?? '';

    final serialFormatted = serial.toString().padLeft(3, '0');
    final id = companyCode.isNotEmpty
        ? '$companyCode-ATD-WAG-$wPart-$day-$month-$serialFormatted'
        : 'ATD-WAG-$wPart-$day-$month-$serialFormatted';

    // Increment serial for next time (on same day) and save
    final nextSerial = serial + 1;
    _serialCounter[serialKey] = nextSerial;
    await _saveSerialCounter(wagerId, nextSerial, now);

    debugPrint('🆔 Generated ID: $id (Serial: $serial for date: $dateKey)');
    debugPrint('📈 [SERIAL] Next serial for $wagerId on $dateKey will be: $nextSerial');

    return id;
  }

  // ── Get Current Location ────────────────────────────────────────────────────
  Future<Position?> _getLocation() async {
    debugPrint('📍 [LOCATION] Checking permission…');
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      debugPrint('📍 [LOCATION] Permission status: $perm');

      if (perm == LocationPermission.denied) {
        debugPrint('📍 [LOCATION] Requesting permission…');
        perm = await Geolocator.requestPermission();
        debugPrint('📍 [LOCATION] After request: $perm');
      }

      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        debugPrint('❌ [LOCATION] Permission denied — returning null');
        return null;
      }

      debugPrint('📍 [LOCATION] Getting current position (high accuracy, 10s timeout)…');
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      debugPrint('✅ [LOCATION] Got position: lat=${pos.latitude}, lng=${pos.longitude}, accuracy=${pos.accuracy}m');
      return pos;
    } catch (e, stack) {
      debugPrint('❌ [LOCATION] Exception: $e');
      debugPrint('❌ [LOCATION] Stack: $stack');
      return null;
    }
  }

  // ── HTTP Client (bypass SSL for oracle.metaxperts.net) ─────────────────────
  IOClient _buildClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(httpClient);
  }

  // ── Clock In with Selfie ────────────────────────────────────────────────────
  Future<void> _clockIn(Map<String, dynamic> wager) async {
    final wagerId   = _val(wager, ['wager_id',   'WAGER_ID']);
    final wagerName = _val(wager, ['wager_name', 'WAGER_NAME']);

    debugPrint('🟢 [CLOCK-IN] ===== START =====');
    debugPrint('🟢 [CLOCK-IN] Wager: $wagerName | ID: $wagerId');

    // ── Take Selfie First ─────────────────────────────────────────────────────
    debugPrint('📸 [CLOCK-IN] Capturing selfie before clock-in...');
    final String? selfieBase64 = await _captureSelfie();

    if (selfieBase64 == null || selfieBase64.isEmpty) {
      debugPrint('❌ [CLOCK-IN] Selfie capture failed or cancelled');
      _showSnack(
        '📸 Selfie required to clock in',
        const Color(0xFFDC2626),
      );
      return;
    }

    debugPrint('✅ [CLOCK-IN] Selfie captured successfully (${selfieBase64.length} chars)');

    setState(() => _clockInLoading.add(wagerId));

    try {
      final loginVM     = Get.find<LoginViewModel>();
      final user        = loginVM.currentUser.value;
      final prefs       = await SharedPreferences.getInstance();

      final companyCode = user?.company_code?.toString()
          ?? prefs.getString('company_code')
          ?? prefs.getString('companyCode')
          ?? '';

      debugPrint('🟢 [CLOCK-IN] company_code: "$companyCode"');

      // Get location
      debugPrint('🟢 [CLOCK-IN] Fetching location…');
      final pos = await _getLocation();
      final lat = pos?.latitude.toStringAsFixed(7)  ?? '';
      final lng = pos?.longitude.toStringAsFixed(7) ?? '';
      debugPrint('🟢 [CLOCK-IN] Location → lat="$lat" lng="$lng"');

      final now = DateTime.now();
      // Generate attendance ID with serial (will be reused for clock-out)
      final attendanceId = await _buildAttendanceId(wagerId: wagerId);
      _attendanceIds[wagerId] = attendanceId;

      final attendanceInDate = DateFormat('MM/dd/yyyy').format(now);
      final attendanceInTime = DateFormat('hh:mm a').format(now);

      debugPrint('🟢 [CLOCK-IN] Generated ID: $attendanceId');
      debugPrint('🟢 [CLOCK-IN] Date: $attendanceInDate | Time: $attendanceInTime');

      final body = {
        'attendance_in_id':   attendanceId,
        'attendance_in_date': attendanceInDate,
        'attendance_in_time': attendanceInTime,
        'wager_id':           wagerId,
        'wager_name':         wagerName,
        'lat_in':             lat,
        'lng_in':             lng,
        'address':            '',
        'posted':             '0',
        'profile':            selfieBase64,  // ✅ Store selfie in profile column
        'company_code':       companyCode,
      };

      final bodyJson = jsonEncode(body);

      debugPrint('╔══ CLOCK IN POST ═══════════════════════════════');
      debugPrint('║ URL: http://oracle.metaxperts.net/ords/gps_workforce/wagerattendancein/post/');
      debugPrint('║ Wager: $wagerName ($wagerId)');
      debugPrint('║ ID: $attendanceId');
      debugPrint('║ Selfie Length: ${selfieBase64.length} chars');
      debugPrint('║ LatLng: $lat, $lng');
      debugPrint('╚════════════════════════════════════════════════');

      debugPrint('🟢 [CLOCK-IN] Sending POST…');
      final response = await _buildClient()
          .post(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagerattendancein/post/'),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('🟢 [CLOCK-IN] Response Status: ${response.statusCode}');
      debugPrint('🟢 [CLOCK-IN] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [CLOCK-IN] SUCCESS for $wagerName at $attendanceInTime');

        // Start the timer and save state
        setState(() {
          _isClockedIn[wagerId] = true;
          _elapsedSeconds[wagerId] = 0;
        });
        _startTimer(wagerId);
        await _saveClockedInState(wagerId, 0, attendanceId);

        _showSnack(
          '✅ $wagerName clocked in at $attendanceInTime with selfie',
          const Color(0xFF059669),
        );
      } else {
        debugPrint('❌ [CLOCK-IN] FAILED — status ${response.statusCode}');
        _showSnack(
          'Clock-in failed (${response.statusCode})',
          const Color(0xFFDC2626),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ [CLOCK-IN] EXCEPTION: $e');
      debugPrint('❌ [CLOCK-IN] Stack: $stack');
      _showSnack('Clock-in error: $e', const Color(0xFFDC2626));
    } finally {
      setState(() => _clockInLoading.remove(wagerId));
      debugPrint('🟢 [CLOCK-IN] ===== END =====');
    }
  }

  // ── Clock Out with Selfie ────────────────────────────────────────────────────
  Future<void> _clockOut(Map<String, dynamic> wager) async {
    final wagerId   = _val(wager, ['wager_id',   'WAGER_ID']);
    final wagerName = _val(wager, ['wager_name', 'WAGER_NAME']);

    debugPrint('🔴 [CLOCK-OUT] ===== START =====');
    debugPrint('🔴 [CLOCK-OUT] Wager: $wagerName | ID: $wagerId');

    // ── Take Selfie First ─────────────────────────────────────────────────────
    debugPrint('📸 [CLOCK-OUT] Capturing selfie before clock-out...');
    final String? selfieBase64 = await _captureSelfie();

    if (selfieBase64 == null || selfieBase64.isEmpty) {
      debugPrint('❌ [CLOCK-OUT] Selfie capture failed or cancelled');
      _showSnack(
        '📸 Selfie required to clock out',
        const Color(0xFFDC2626),
      );
      return;
    }

    debugPrint('✅ [CLOCK-OUT] Selfie captured successfully (${selfieBase64.length} chars)');

    setState(() => _clockOutLoading.add(wagerId));

    try {
      final loginVM     = Get.find<LoginViewModel>();
      final user        = loginVM.currentUser.value;
      final prefs       = await SharedPreferences.getInstance();

      final companyCode = user?.company_code?.toString()
          ?? prefs.getString('company_code')
          ?? prefs.getString('companyCode')
          ?? '';

      debugPrint('🔴 [CLOCK-OUT] company_code: "$companyCode"');

      // Get location
      debugPrint('🔴 [CLOCK-OUT] Fetching location…');
      final pos = await _getLocation();
      final lat = pos?.latitude.toStringAsFixed(7)  ?? '';
      final lng = pos?.longitude.toStringAsFixed(7) ?? '';
      debugPrint('🔴 [CLOCK-OUT] Location → lat="$lat" lng="$lng"');

      final now = DateTime.now();
      // Use the same attendance ID from clock-in
      final attendanceId = _attendanceIds[wagerId] ?? await _buildAttendanceId(wagerId: wagerId);
      final attendanceOutDate = DateFormat('dd-MMM-yyyy').format(now);
      final attendanceOutTime = DateFormat('hh:mm a').format(now);

      // Calculate total time worked
      final elapsedSeconds = _elapsedSeconds[wagerId] ?? 0;
      final totalTime = _formatElapsedTime(elapsedSeconds);

      debugPrint('🔴 [CLOCK-OUT] Using ID: $attendanceId');
      debugPrint('🔴 [CLOCK-OUT] Date: $attendanceOutDate | Time: $attendanceOutTime');
      debugPrint('🔴 [CLOCK-OUT] Total Time Worked: $totalTime');

      final body = {
        'attendance_out_id':   attendanceId,
        'attendance_out_date': attendanceOutDate,
        'attendance_out_time': attendanceOutTime,
        'wager_id':            wagerId,
        'wager_name':          wagerName,
        'lat_out':             lat,
        'lng_out':             lng,
        'address':             '',
        'total_time':          totalTime,
        'posted':              '0',
        'clock_out_image':     selfieBase64,  // ✅ Store selfie in clock_out_image column
        'company_code':        companyCode,
      };

      final bodyJson = jsonEncode(body);

      debugPrint('╔══ CLOCK OUT POST ══════════════════════════════');
      debugPrint('║ URL: http://oracle.metaxperts.net/ords/gps_workforce/wagerattendanceout/post/');
      debugPrint('║ Wager: $wagerName ($wagerId)');
      debugPrint('║ ID: $attendanceId');
      debugPrint('║ Total Time: $totalTime');
      debugPrint('║ Selfie Length: ${selfieBase64.length} chars');
      debugPrint('║ LatLng: $lat, $lng');
      debugPrint('╚════════════════════════════════════════════════');

      debugPrint('🔴 [CLOCK-OUT] Sending POST…');
      final response = await _buildClient()
          .post(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagerattendanceout/post/'),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('🔴 [CLOCK-OUT] Response Status: ${response.statusCode}');
      debugPrint('🔴 [CLOCK-OUT] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [CLOCK-OUT] SUCCESS for $wagerName at $attendanceOutTime');

        // Stop and reset timer, remove persisted state
        _resetTimer(wagerId);

        _showSnack(
          '✅ $wagerName clocked out at $attendanceOutTime (Total: $totalTime) with selfie',
          const Color(0xFF059669),
        );
      } else {
        debugPrint('❌ [CLOCK-OUT] FAILED — status ${response.statusCode}');
        _showSnack(
          'Clock-out failed (${response.statusCode})',
          const Color(0xFFDC2626),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ [CLOCK-OUT] EXCEPTION: $e');
      debugPrint('❌ [CLOCK-OUT] Stack: $stack');
      _showSnack('Clock-out error: $e', const Color(0xFFDC2626));
    } finally {
      setState(() => _clockOutLoading.remove(wagerId));
      debugPrint('🔴 [CLOCK-OUT] ===== END =====');
    }
  }

  // ── Snack bar helper ────────────────────────────────────────────────────────
  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        backgroundColor: bg,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin:    const EdgeInsets.all(16),
        duration:  const Duration(seconds: 3),
      ),
    );
  }

  // ── API fetch ───────────────────────────────────────────────────────────────
  Future<void> _fetchWagers() async {
    debugPrint('📋 [FETCH] _fetchWagers called');
    setState(() { _loading = true; _error = ''; });

    final loginVM = Get.find<LoginViewModel>();
    final user    = loginVM.currentUser.value;
    final prefs   = await SharedPreferences.getInstance();

    final empId = user?.emp_id?.toString()
        ?? prefs.get('emp_id')?.toString()
        ?? prefs.getString('userId')
        ?? '';
    final companyCode = user?.company_code?.toString()
        ?? prefs.getString('company_code')
        ?? prefs.getString('companyCode')
        ?? '';

    debugPrint('📋 [FETCH] emp_id: "$empId"');
    debugPrint('📋 [FETCH] company_code: "$companyCode"');

    final uri = Uri.parse(
      'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
    ).replace(queryParameters: {
      'emp_id':       empId,
      'company_code': companyCode,
    });

    debugPrint('📋 [FETCH] URL: $uri');

    try {
      final response = await _buildClient().get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📋 [FETCH] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];

        final active = items
            .map((e) => Map<String, dynamic>.from(e))
            .where((w) =>
        (w['STATUS'] ?? w['status'] ?? '')
            .toString()
            .toUpperCase() == 'ACTIVE')
            .toList();

        debugPrint('📋 [FETCH] Active: ${active.length} / ${items.length}');

        setState(() {
          _all      = active;
          _filtered = List.from(active);
          _loading  = false;
        });
      } else {
        setState(() {
          _error   = 'Error ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ [FETCH] Exception: $e');
      setState(() {
        _error   = 'Exception:\n$e';
        _loading = false;
      });
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((w) {
        final name   = _val(w, ['wager_name',  'WAGER_NAME']).toLowerCase();
        final father = _val(w, ['father_name', 'FATHER_NAME']).toLowerCase();
        final id     = _val(w, ['wager_id',    'WAGER_ID']).toLowerCase();
        return name.contains(q) || father.contains(q) || id.contains(q);
      }).toList();
    });
  }

  String _val(Map<String, dynamic> w, List<String> keys) {
    for (final k in keys) {
      final v = w[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Employee Attendance',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _teal,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon:      const Icon(Icons.menu, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      drawer: AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderStrip(count: _filtered.length, loading: _loading),

          if (!_loading && _error.isEmpty)
            _SearchBar(controller: _searchCtrl),

          Expanded(
            child: _loading
                ? const _LoadingView()
                : _error.isNotEmpty
                ? _ErrorView(message: _error, onRetry: _fetchWagers)
                : _filtered.isEmpty
                ? const _EmptyView()
                : RefreshIndicator(
              color:     _teal,
              onRefresh: _fetchWagers,
              child: ListView.builder(
                padding:   const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final wager   = _filtered[i];
                  final wId     = _val(wager, ['wager_id', 'WAGER_ID']);
                  return _WagerCard(
                    wager:          wager,
                    index:          i,
                    valFn:          _val,
                    clockInLoading:  _clockInLoading.contains(wId),
                    clockOutLoading: _clockOutLoading.contains(wId),
                    isClockedIn:     _isClockedIn[wId] ?? false,
                    elapsedTime:     _elapsedSeconds[wId] ?? 0,
                    onClockIn:  () => _clockIn(wager),
                    onClockOut: () => _clockOut(wager),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header Strip
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderStrip extends StatelessWidget {
  final int  count;
  final bool loading;
  const _HeaderStrip({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: const BoxDecoration(
        color:        Color(0xFF0C6B64),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Employee Attendance',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loading ? 'Fetching records…' : '$count active wager(s)',
            style: const TextStyle(color: Color(0xFFB2DDD9), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText:   'Search by name, father name or ID…',
          hintStyle:  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF6B7280), size: 20),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: Color(0xFF6B7280)),
              onPressed: () => controller.clear(),
            )
                : const SizedBox.shrink(),
          ),
          filled:         true,
          fillColor:      Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: Color(0xFF0C6B64), width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wager Card
// ─────────────────────────────────────────────────────────────────────────────
class _WagerCard extends StatelessWidget {
  final Map<String, dynamic>                               wager;
  final int                                                index;
  final String Function(Map<String, dynamic>, List<String>) valFn;
  final bool          clockInLoading;
  final bool          clockOutLoading;
  final bool          isClockedIn;
  final int           elapsedTime;
  final VoidCallback  onClockIn;
  final VoidCallback  onClockOut;

  static const _teal      = Color(0xFF0C6B64);
  static const _tealLight = Color(0xFFE0F5F3);
  static const _textDark  = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  const _WagerCard({
    required this.wager,
    required this.index,
    required this.valFn,
    required this.clockInLoading,
    required this.clockOutLoading,
    required this.isClockedIn,
    required this.elapsedTime,
    required this.onClockIn,
    required this.onClockOut,
  });

  String _formatElapsedTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final wagerName  = valFn(wager, ['wager_name',  'WAGER_NAME']);
    final fatherName = valFn(wager, ['father_name', 'FATHER_NAME']);
    final wagerId    = valFn(wager, ['wager_id',    'WAGER_ID']);

    final nameParts = wagerName.trim().split(' ');
    final initials  = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : wagerName.isNotEmpty ? wagerName[0].toUpperCase() : '??';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:        _teal.withOpacity(0.06),
            blurRadius:   14,
            spreadRadius: 0,
            offset:       const Offset(0, 4),
          ),
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: avatar + name + timer ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width:  46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: _tealLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color:      _teal,
                        fontWeight: FontWeight.w700,
                        fontSize:   16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wagerName,
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      _textDark,
                          height:     1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isClockedIn) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tealLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, size: 12, color: _teal),
                              const SizedBox(width: 4),
                              Text(
                                _formatElapsedTime(elapsedTime),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),

          // ── Detail rows ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                _DetailRow(
                  icon:  Icons.tag_rounded,
                  label: 'Wager ID',
                  value: wagerId,
                ),
                _DetailRow(
                  icon:   Icons.person_outline_rounded,
                  label:  'Father Name',
                  value:  fatherName,
                  isLast: true,
                ),
              ],
            ),
          ),

          // ── Clock In / Clock Out buttons ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                // Clock In
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isClockedIn || clockInLoading) ? null : onClockIn,
                    icon: clockInLoading
                        ? const SizedBox(
                      width:  14,
                      height: 14,
                      child:  CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       Color(0xFF0C6B64),
                      ),
                    )
                        : const Icon(Icons.login_rounded, size: 16),
                    label: Text(clockInLoading ? 'Posting…' : 'Clock In'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0C6B64),
                      side: const BorderSide(
                          color: Color(0xFF0C6B64), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Clock Out
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!isClockedIn || clockOutLoading) ? null : onClockOut,
                    icon: clockOutLoading
                        ? const SizedBox(
                      width:  14,
                      height: 14,
                      child:  CircularProgressIndicator(
                        strokeWidth: 2,
                        color:       Color(0xFFDC2626),
                      ),
                    )
                        : const Icon(Icons.logout_rounded, size: 16),
                    label: Text(clockOutLoading ? 'Posting…' : 'Clock Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(
                          color: Color(0xFFDC2626), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Row
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 7),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize:   12,
                color:      Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize:   12,
                color:      Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / Error / Empty
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: Color(0xFF0C6B64), strokeWidth: 2.5),
          SizedBox(height: 14),
          Text('Loading wagers…',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String       message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C6B64),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text('No active wagers found',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
        ],
      ),
    );
  }
}