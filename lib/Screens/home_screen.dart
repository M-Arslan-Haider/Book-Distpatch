

import 'package:GPS_Workforce_Monitor/Screens/schedule_hub_screen.dart';
import 'package:GPS_Workforce_Monitor/Screens/schedule_screen.dart';
import 'package:GPS_Workforce_Monitor/Screens/sync_status_card_screen.dart';
import 'package:GPS_Workforce_Monitor/Screens/task_screen.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/interval_selfie_service.dart';
import '../Services/update_check_service.dart';
import '../Services/selfie_notification_policy_service.dart';
import '../Services/developer_options_check_service.dart';

import '../AppColors.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/break_viewmodel.dart';
import '../ViewModels/short_break_viewmodel.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/task_view_model.dart';
import 'HomeScreenComponents/DeviceHealthWidget.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'WidgetDesignes/travel_session_card.dart';
import 'actions_screen.dart';
import 'break_screen.dart';
import 'leave_report_get_screen.dart';
import 'my_task_activity_screen.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
import 'leave_screen.dart';
import 'location_session_screen.dart';
import 'short_break_screen.dart';


// ── Responsive helper ────────────────────────────────────────────────────────
extension Responsive on BuildContext {
  double get screenW => MediaQuery.of(this).size.width;
  double get screenH => MediaQuery.of(this).size.height;

  double get sf => (screenW / 390).clamp(0.78, 1.25);

  double rs(double base) => (base * sf).clamp(base * 0.78, base * 1.25);

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(rs(18), rs(12), rs(18), rs(20));

  bool get isSmall  => screenW < 370;
  bool get isMedium => screenW >= 370 && screenW < 410;
  bool get isLarge  => screenW >= 410;
}

// ── App Setup Dialog (PUBLIC - accessible from main.dart) ──
class AppSetupDialog extends StatelessWidget {
  const AppSetupDialog();

  // ✅ SharedPreferences key used to remember that the user has already
  // acknowledged this dialog (via either footer button), so it doesn't
  // pop up again on subsequent visits to HomeScreen.
  static const String prefSetupDialogAcknowledged = 'setup_dialog_acknowledged';

  // ✅ Saves the "don't show again" flag, then closes the dialog.
  static Future<void> _dismissPermanently(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefSetupDialogAcknowledged, true);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3DAF93), Color(0xFF1A6E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.checklist_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Before You Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Please ensure the following requirements are met',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'براہ کرم درج ذیل شرائط کو یقینی بنائیں',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Requirements List ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Column(
                  children: const [
                    _RequirementTile(
                      icon: Icons.gps_fixed_rounded,
                      title: 'Location Services (GPS) are enabled',
                      urduTitle: 'لوکیشن سروسز (GPS) فعال ہیں',
                    ),
                    _RequirementTile(
                      icon: Icons.radar_rounded,
                      title: 'High Accuracy mode is selected',
                      urduTitle: 'ہائی ایکوریسی موڈ منتخب ہے',
                    ),
                    _RequirementTile(
                      icon: Icons.schedule_rounded,
                      title: 'Automatic Date & Time are enabled',
                      urduTitle: 'خودکار تاریخ اور وقت فعال ہیں',
                    ),
                    _RequirementTile(
                      icon: Icons.wifi_rounded,
                      title: 'Internet connection is active',
                      urduTitle: 'انٹرنیٹ کنکشن فعال ہے',
                    ),
                    _RequirementTile(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Required permissions are granted',
                      urduTitle: 'مطلوبہ اجازتیں دی گئی ہیں',
                    ),
                    _RequirementTile(
                      icon: Icons.battery_charging_full_rounded,
                      title: 'Battery Saver mode is disabled',
                      urduTitle: 'بیٹری سیور موڈ غیر فعال ہے',
                    ),
                    _RequirementTile(
                      icon: Icons.location_off_rounded,
                      title: 'Mock/Fake Location is disabled',
                      urduTitle: 'جھوٹی لوکیشن غیر فعال ہے',
                    ),
                    _RequirementTile(
                      icon: Icons.vpn_lock_rounded,
                      title: 'VPN or location spoofing tools are not being used',
                      urduTitle: 'VPN یا لوکیشن اسپوفنگ ٹولز استعمال نہیں ہو رہے',
                    ),
                    _RequirementTile(
                      icon: Icons.phone_android_rounded,
                      title: 'Keep the app active while attendance is being recorded',
                      urduTitle: 'حاضری ریکارڈ ہونے کے دوران ایپ کو فعال رکھیں',
                    ),
                  ],
                ),
              ),
            ),

            // ── Warning Message (Redesigned - Full Width) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFEF3C7).withOpacity(0.9),
                      const Color(0xFFFFF8E1).withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // ── English Message ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Failure to meet these requirements may prevent accurate attendance or location tracking.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF78350F),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Urdu Message ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          right: BorderSide(
                            color: const Color(0xFFF59E0B).withOpacity(0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'ان شرائط کو پورا نہ کرنے سے حاضری یا لوکیشن ٹریکنگ درست نہیں ہو سکتی',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF78350F),
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.blueGrey.shade100, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _dismissPermanently(context),
                    child: Text(
                      'Baad Mein',
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _dismissPermanently(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3DAF93),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text(
                      'Samajh Gaya',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single requirement tile ──
class _RequirementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String urduTitle;

  const _RequirementTile({
    required this.icon,
    required this.title,
    required this.urduTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3DAF93).withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF3DAF93).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3DAF93),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  urduTitle,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueGrey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF4ADE80),
            size: 16,
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── ViewModels ─────────────────────────────────────────────────────────────
  final LocationViewModel locationVM              = Get.put(LocationViewModel());
  final AttendanceViewModel attendanceViewModel   = Get.put(AttendanceViewModel());
  final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
  final BreakViewModel breakViewModel             = Get.put(BreakViewModel());
  final ShortBreakViewModel shortBreakVM          = Get.put(ShortBreakViewModel());
  final TaskViewModel taskVM                      = Get.put(TaskViewModel());

  // ── State ──────────────────────────────────────────────────────────────────
  String _empName  = '';
  String _empId    = '';
  String _empRole  = '';
  int _navIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  // Last sync time for navbar
  String _lastSyncTime = 'Just now';

  // ✅ Flag to track if dialog is currently showing
  bool _isDialogShowing = false;

  // ✅ Cooldown timestamp to prevent multiple dialog opens
  DateTime? _lastDialogClosedTime;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addObserver(this);

    Get.put(SelfieNotificationPolicyService());
    Get.put(IntervalSelfieService());

    _loadUserData();
    taskVM.fetchAssignedTasks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
      _checkDeveloperOptions();
      // ✅ Show setup dialog - HAR BAR home screen open ho to show
      _showSetupDialog();
    });

    FlutterForegroundTask.startService(
      notificationTitle: 'Shift Active',
      notificationText: 'GPS & time tracking running…',
      callback: startCallback,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [HOME] App resumed — re-checking developer options...');
      _checkDeveloperOptions();

      // ✅ HAR BAR jab app foreground mein aaye to show dialog
      // Thoda delay do taake screen properly load ho jaye
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showSetupDialog();
        }
      });
    }
  }

  // ── Show Setup Dialog - HAR BAR show hoga ──────────────────────────────
  void _showSetupDialog() {
    // ✅ Check if dialog is currently showing
    if (_isDialogShowing) {
      debugPrint('⚠️ Dialog already showing, skipping...');
      return;
    }

    // ✅ Check if any other dialog is open
    if (Get.isDialogOpen == true) {
      debugPrint('⚠️ Another dialog already open, skipping...');
      return;
    }

    // ✅ COOLDOWN: Don't show dialog if it was just closed (within 2 seconds)
    if (_lastDialogClosedTime != null) {
      final elapsed = DateTime.now().difference(_lastDialogClosedTime!);
      if (elapsed.inSeconds < 2) {
        debugPrint('⏳ Cooldown active (${elapsed.inMilliseconds}ms), skipping dialog...');
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('📋 Showing setup dialog...');
        _isDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AppSetupDialog(),
        ).then((_) {
          _isDialogShowing = false;
          // ✅ Set cooldown timestamp when dialog closes
          _lastDialogClosedTime = DateTime.now();
          debugPrint('📋 Setup dialog closed at ${_lastDialogClosedTime}');
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!mounted) return;
    setState(() {
      _empName = prefs.getString('userName')    ?? 'Employee';
      _empId   = prefs.getString('userId')      ?? '--';
      _empRole = prefs.getString('designation') ?? 'Staff';
    });

    String empId = prefs.getInt('emp_id')?.toString()
        ?? prefs.getString('emp_id')
        ?? '';
    if (empId.isEmpty) empId = _empId;
    final String companyCode = prefs.getString('company_code') ?? '';

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🏠 [HOME] _loadUserData: empId="$empId"  companyCode="$companyCode"');

    if (empId.isNotEmpty && companyCode.isNotEmpty) {
      SelfieNotificationPolicyService.to.initialize(empId, companyCode);
      IntervalSelfieService.to.initialize(empId, companyCode);
    } else {
      debugPrint('❌ [HOME] empId or companyCode empty — selfie service NOT initialized');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  // ── Force Update Check ────────────────────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    final required = await UpdateCheckService.isUpdateRequired();
    if (required && mounted) _showForceUpdateDialog();
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cyan.withOpacity(0.30), width: 1),
              boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.cyan.withOpacity(0.20), AppColors.greenTeal.withOpacity(0.20)]),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.40), width: 1.5),
                  ),
                  child: const Icon(Icons.system_update_alt_rounded, color: AppColors.cyan, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Update Required', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 12),
                Text('A newer version is available. Please update to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.5, height: 1.55)),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.cyan, AppColors.greenTeal]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(UpdateCheckService.playStoreUrl);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      label: const Text('Update Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkDeveloperOptions() async {
    final result = await DeveloperOptionsCheckService.checkAndPost();
    if (result.isDeveloperOptionsEnabled && mounted) _showDeveloperOptionsDialog();
  }

  void _showDeveloperOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.60), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 72, height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
                  ),
                  child: const Icon(Icons.developer_mode_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Developer Options Enabled', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Developer Options are currently ON.\nPlease turn them OFF to use the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13.5, height: 1.6)),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        const MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor')
                            .invokeMethod('openDeveloperSettings').catchError((_) {});
                      },
                      icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                      label: const Text('Open Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doSync() async {
    setState(() {
      _lastSyncTime = 'Just now';
    });

    Get.showSnackbar(GetSnackBar(
      message: 'Syncing data...',
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.cyan,
      icon: const Icon(Icons.sync, color: Colors.white),
      borderRadius: 10,
      margin: const EdgeInsets.all(12),
    ));

    await attendanceViewModel.syncUnposted();
    await attendanceOutViewModel.syncUnposted();

    setState(() {
      _lastSyncTime = DateTime.now().toString().substring(11, 16);
    });

    Get.showSnackbar(const GetSnackBar(
      message: 'Data synced successfully',
      duration: Duration(seconds: 2),
      backgroundColor: AppColors.greenTeal,
      icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
      borderRadius: 10,
      margin: EdgeInsets.all(12),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN BUILD - FIXED NAVBAR + PROFILE SECTION (NO SCROLL)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Get user initials for navbar
    String initials = _empName.isNotEmpty ?
    _empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'AK';
    if (initials.length < 2 && _empName.isNotEmpty) initials = _empName.substring(0, 1) + (_empName.length > 1 ? _empName.substring(1, 2) : 'K');
    if (initials.isEmpty) initials = 'AK';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            // ✅ Navbar - FIXED at top
            Navbar(
              userName: _empName.isEmpty ? 'Ahmed Khan' : _empName,
              userInitials: initials,
              lastSync: _lastSyncTime,
              scaffoldKey: _scaffoldKey,
            ),

            // ✅ Baaki sab SCROLLABLE
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [

                    // ✅ ProfileSection
                    const SliverToBoxAdapter(
                      child: ProfileSection(),
                    ),

                    // ✅ Main Content
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: context.rs(18),
                        right: context.rs(18),
                        top: context.rs(8),
                        bottom: context.rs(20),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUnifiedSessionCard(),
                          SizedBox(height: context.rs(14)),
                          const SelfieGraceButton(),
                          const IntervalSelfieButton(),
                          SizedBox(height: context.rs(11)),
                          _buildQuickActions(),
                          SizedBox(height: context.rs(22)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
                            child: SyncStatusCard(onSyncNow: _doSync),
                          ),
                          SizedBox(height: context.rs(14)),
                          // ✅ Device Health Card
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
                            child: const DeviceHealthWidget(),
                          ),
                          SizedBox(height: context.rs(30)),
                        ]),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),

        // ✅ Bottom Navigation Bar
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _navIndex,
          chatBadgeCount: 0,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALL EXISTING WIDGETS (unchanged from your original code)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUnifiedSessionCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TimerCard is now a self-contained dark green card
          const TimerCard(),
          SizedBox(height: context.rs(12)),
          // TravelSessionCard sits cleanly below
          const TravelSessionCard(),
        ],
      ),
    );
  }

  Widget _buildDividerWithIcon() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(20), vertical: context.rs(6)),
      child: Row(
        children: [
          Expanded(child: _gradientLine()),
          Container(
            margin: EdgeInsets.symmetric(horizontal: context.rs(8)),
            padding: EdgeInsets.all(context.rs(4)),
            decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.swap_vert_rounded, size: context.rs(10), color: AppColors.cyan.withOpacity(0.55)),
          ),
          Expanded(child: _gradientLine()),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ───────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: context.rs(28), height: context.rs(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E),
                  borderRadius: BorderRadius.circular(context.rs(8)),
                ),
                child: Icon(Icons.flash_on_rounded,
                    size: context.rs(15), color: Colors.white),
              ),
              SizedBox(width: context.rs(8)),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: const Color(0xFF123A34),
                  fontSize: context.rs(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('debug_force_deadzone', true);
            },
            icon: const Icon(Icons.location_off),
            label: const Text('Test Dead Zone'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),

          SizedBox(height: context.rs(22)),

          SizedBox(height: context.rs(12)),

          // ── Row 1 — Leave / Tasks ─────────────────────────────────────────
          Row(
            children: [
              _quickActionCard(
                icon: Icons.beach_access_rounded,
                label: 'Leave',
                iconBg: const Color(0xFF0F766E),
                onTap: () => Get.to(() => ActionsScreen()),
              ),
              SizedBox(width: context.rs(12)),
              _quickActionCard(
                icon: Icons.checklist_rounded,
                label: 'Tasks',
                iconBg: const Color(0xFF7C4DEC),
                onTap: () => Get.to(
                      () => TaskScreen(
                    currentIndex: 3,
                    chatBadgeCount: 0,
                    onNavTap: (int index) {
                      // When navigating from TaskScreen back, update bottom nav index
                      setState(() {
                        _navIndex = index;
                      });
                      // Pop back to home screen if needed
                      if (Get.isDialogOpen != true) {
                        Get.back();
                      }
                    },
                  ),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
            ],
          ),

          SizedBox(height: context.rs(12)),

          // ── Row 2 — Break / Schedule ───────────────────────────────────
          Row(
            children: [
              _quickActionCard(
                icon: Icons.free_breakfast_rounded,
                label: 'Break',
                iconBg: const Color(0xFF12B897),
                onTap: () => Get.to(
                      () => BreaksScreen(
                    currentIndex: 5,
                    chatBadgeCount: 0,
                    onNavTap: (int index) {
                      setState(() {
                        _navIndex = index;
                      });
                      if (Get.isDialogOpen != true) {
                        Get.back();
                      }
                    },
                  ),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              SizedBox(width: context.rs(12)),
              _quickActionCard(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                iconBg: const Color(0xFF7C4DEC),
                onTap: () {
                  Get.to(
                        () => ScheduleHubScreen(
                      currentIndex: 2,
                      chatBadgeCount: 0,
                      onNavTap: (int index) {
                        setState(() {
                          _navIndex = index;
                        });
                        if (Get.isDialogOpen != true) {
                          Get.back();
                        }
                      },
                    ),
                    transition: Transition.rightToLeft,
                    duration: const Duration(milliseconds: 300),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Action card — white background
  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: context.rs(16)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(context.rs(16)),
            border: Border.all(color: const Color(0xFFE7E5D9), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: context.rs(10),
                offset: Offset(0, context.rs(3)),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: context.rs(46),
                height: context.rs(46),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(context.rs(14)),
                ),
                child: Icon(icon, size: context.rs(22), color: Colors.white),
              ),
              SizedBox(height: context.rs(10)),
              Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.rs(12.5),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F5C53),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(width: context.rs(4), height: context.rs(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: context.rs(8)),
      Container(width: context.rs(28), height: context.rs(28),
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(8))),
          child: Icon(icon, size: context.rs(14), color: color)),
      SizedBox(width: context.rs(8)),
      Flexible(child: Text(title, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.primary, fontSize: context.rs(13), fontWeight: FontWeight.w700, letterSpacing: 0.3))),
    ]);
  }

  Widget _gradientLine() => Container(height: 1,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.divider, Colors.transparent])),
  );
}

// ── Foreground task ──────────────────────────────────────────────────────────
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool restart) async {}
}