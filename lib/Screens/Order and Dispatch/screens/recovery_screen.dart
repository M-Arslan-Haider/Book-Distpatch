import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../AppColors.dart';
import '../../../ViewModels/login_view_model.dart';
import '../../HomeScreenComponents/navbar.dart';
import '../../HomeScreenComponents/sidebar_drawer.dart';
import '../../../Database/db_helper.dart';

class RecoveryScreen extends StatefulWidget {
  final String? preSelectedShopId;
  final String? preSelectedShopName;
  final String? preSelectedOwnerName;

  const RecoveryScreen({
    super.key,
    this.preSelectedShopId,
    this.preSelectedShopName,
    this.preSelectedOwnerName,
  });

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg = AppColors.surface;
  static const _textDark = AppColors.textPrimary;
  static const _textMuted = AppColors.textSecondary;
  static const _tealDark = AppColors.tealDark;

  // ── STATIC BALANCE ─────────────────────────────────────────────────
  static const double _staticBalance = 35000;

  // ── State ────────────────────────────────────────────────────────────
  ShopModel? _selectedShop;
  bool _isLoadingShops = true;
  String? _errorMessage;

  // ── Employee Info ──────────────────────────────────────────────────
  String _empId = '';
  String _empName = '';
  String _companyCode = '';

  // ── Recovery State ────────────────────────────────────────────────
  double _recoverBalance = 0;
  double _remainingBalance = 0;
  DateTime _lastPaymentDate = DateTime.now();
  bool _hasRecordedAny = false;

  // ── Pending sync tracking ──────────────────────────────────────────
  double _lastAmount = 0;
  String _lastMode = 'Cash';
  bool _hasPendingSync = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🟢 [RecoveryScreen] initState called');
    debugPrint('🟢 [RecoveryScreen] preSelectedShopId: ${widget.preSelectedShopId}');
    _loadEmployeeInfo();
    _fetchShops();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  // 1. Load Employee Info
  // ════════════════════════════════════════════════════════════════════
  Future<void> _loadEmployeeInfo() async {
    debugPrint('🔄 [RecoveryScreen] _loadEmployeeInfo started');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      _empId = prefs.getString('userId') ??
          prefs.getString('user_id') ??
          prefs.getString('emp_id') ??
          prefs.getString('empId') ??
          prefs.getString('employee_id') ??
          prefs.getString('employeeId') ?? '';

      _empName = prefs.getString('userName') ??
          prefs.getString('user_name') ??
          prefs.getString('emp_name') ??
          prefs.getString('empName') ??
          prefs.getString('name') ??
          prefs.getString('full_name') ??
          prefs.getString('fullName') ?? '';

      _companyCode = prefs.getString('company_code') ??
          prefs.getString('companyCode') ??
          DBHelper.getCompanyCode() ??
          '';

      debugPrint('✅ [RecoveryScreen] Employee Info loaded:');
      debugPrint('   empId: $_empId');
      debugPrint('   empName: $_empName');
      debugPrint('   companyCode: $_companyCode');

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('❌ [RecoveryScreen] Error loading employee info: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 2. Fetch Shops
  // ════════════════════════════════════════════════════════════════════
  Future<void> _fetchShops() async {
    debugPrint('🔄 [RecoveryScreen] _fetchShops started');
    setState(() {
      _isLoadingShops = true;
      _errorMessage = null;
    });

    try {
      if (_empId.isEmpty || _companyCode.isEmpty) {
        debugPrint('⚠️ [RecoveryScreen] empId or companyCode empty, reloading...');
        await _loadEmployeeInfo();
        if (_empId.isEmpty || _companyCode.isEmpty) {
          throw Exception('Employee ID or Company Code not found.');
        }
      }

      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/addshopget/get/$_empId/$_companyCode';
      debugPrint('📡 [RecoveryScreen] Calling API: $url');

      final response = await http.get(Uri.parse(url));
      debugPrint('📥 [RecoveryScreen] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
          debugPrint('📦 [RecoveryScreen] Response is a List, items count: ${items.length}');
        } else if (decoded['items'] is List) {
          items = decoded['items'];
          debugPrint('📦 [RecoveryScreen] Response has "items" key, items count: ${items.length}');
        }

        final allShops = items.map((e) => ShopModel.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('✅ [RecoveryScreen] Parsed ${allShops.length} shops');

        ShopModel? foundShop;
        if (widget.preSelectedShopId != null && allShops.isNotEmpty) {
          debugPrint('🔍 [RecoveryScreen] Looking for shop with ID: ${widget.preSelectedShopId}');
          try {
            foundShop = allShops.firstWhere(
                  (shop) => shop.shopId == widget.preSelectedShopId,
            );
            debugPrint('✅ [RecoveryScreen] Found shop: ${foundShop.shopName}');
          } catch (_) {
            debugPrint('⚠️ [RecoveryScreen] Shop not found, using first shop');
            foundShop = allShops.isNotEmpty ? allShops.first : null;
          }
        } else if (allShops.isNotEmpty) {
          debugPrint('ℹ️ [RecoveryScreen] No preSelectedShopId, using first shop');
          foundShop = allShops.first;
        }

        setState(() {
          _selectedShop = foundShop;
          _isLoadingShops = false;
        });

        if (_selectedShop != null) {
          debugPrint('✅ [RecoveryScreen] Selected shop: ${_selectedShop!.shopName} (${_selectedShop!.shopId})');
          _loadShopRecoveryState(_selectedShop!.shopId);
        }
      } else {
        debugPrint('❌ [RecoveryScreen] API error: ${response.statusCode}');
        throw Exception('Failed to load shops. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [RecoveryScreen] _fetchShops error: $e');
      setState(() {
        _errorMessage = 'Error loading shops: $e';
        _isLoadingShops = false;
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 3. Load per-shop recovery state from SharedPreferences
  // ════════════════════════════════════════════════════════════════════
  Future<void> _loadShopRecoveryState(String shopId) async {
    debugPrint('🔄 [RecoveryScreen] _loadShopRecoveryState for shopId: $shopId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'shop_recovery_state_$shopId';
      final raw = prefs.getString(key);

      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        debugPrint('📦 [RecoveryScreen] Parsed data: $data');
        setState(() {
          _recoverBalance = (data['recover_balance'] ?? 0).toDouble();
          _remainingBalance = (data['remaining_balance'] ?? _staticBalance).toDouble();
          _lastPaymentDate = DateTime.tryParse(data['last_payment_date']?.toString() ?? '') ?? DateTime.now();
          _lastAmount = (data['last_amount'] ?? 0).toDouble();
          _lastMode = data['last_mode']?.toString() ?? 'Cash';
          _hasPendingSync = data['has_pending_sync'] == true;
          _hasRecordedAny = true;
        });
        debugPrint('✅ [RecoveryScreen] Loaded recovery state:');
        debugPrint('   recoverBalance: $_recoverBalance');
        debugPrint('   remainingBalance: $_remainingBalance');
        debugPrint('   hasPendingSync: $_hasPendingSync');
      } else {
        debugPrint('ℹ️ [RecoveryScreen] No saved state found, using defaults');
        setState(() {
          _recoverBalance = 0;
          _remainingBalance = 0;
          _lastPaymentDate = DateTime.now();
          _lastAmount = 0;
          _lastMode = 'Cash';
          _hasPendingSync = false;
          _hasRecordedAny = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [RecoveryScreen] Error loading shop recovery state: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 4. Save per-shop recovery state to SharedPreferences
  // ════════════════════════════════════════════════════════════════════
  Future<void> _saveShopRecoveryState(String shopId) async {
    debugPrint('🔄 [RecoveryScreen] _saveShopRecoveryState for shopId: $shopId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'shop_recovery_state_$shopId';
      final data = {
        'recover_balance': _recoverBalance,
        'remaining_balance': _remainingBalance,
        'last_payment_date': _lastPaymentDate.toIso8601String(),
        'last_amount': _lastAmount,
        'last_mode': _lastMode,
        'has_pending_sync': _hasPendingSync,
      };
      debugPrint('📦 [RecoveryScreen] Saving data: $data');
      await prefs.setString(key, jsonEncode(data));
      debugPrint('✅ [RecoveryScreen] Saved successfully');
    } catch (e) {
      debugPrint('❌ [RecoveryScreen] Error saving shop recovery state: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 5. Show Recover Payment Bottom Sheet
  // ════════════════════════════════════════════════════════════════════
  void _showRecoverPayment() {
    debugPrint('🔄 [RecoveryScreen] _showRecoverPayment called');
    if (_selectedShop == null) {
      debugPrint('⚠️ [RecoveryScreen] No shop selected');
      Get.snackbar(
        'Error',
        'Please select a shop first.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Calculate remaining balance (total - already recovered)
    final remaining = _staticBalance - _recoverBalance;
    debugPrint('✅ [RecoveryScreen] Showing payment sheet for: ${_selectedShop!.shopName}');
    debugPrint('   remainingBalance: $remaining');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecoverPaymentSheet(
        shop: _selectedShop!,
        remainingBalance: remaining,
        onSubmit: (amount, mode) {
          debugPrint('📤 [RecoveryScreen] onSubmit called with amount: $amount, mode: $mode');
          _submitRecoveryToServer(amount, mode);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // 6. SUBMIT RECOVERY DIRECTLY TO SERVER
  // ════════════════════════════════════════════════════════════════════
  Future<void> _submitRecoveryToServer(double amount, String mode) async {
    debugPrint('🚀 [RecoveryScreen] _submitRecoveryToServer started');
    debugPrint('   amount: $amount');
    debugPrint('   mode: $mode');
    debugPrint('   current recoverBalance: $_recoverBalance');
    debugPrint('   current remainingBalance: $_remainingBalance');

    if (_selectedShop == null) {
      debugPrint('❌ [RecoveryScreen] No shop selected, aborting');
      return;
    }

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final newRecoverBalance = _recoverBalance + amount;
    final newRemainingBalance = _staticBalance - newRecoverBalance;

    debugPrint('📊 [RecoveryScreen] New values:');
    debugPrint('   newRecoverBalance: $newRecoverBalance');
    debugPrint('   newRemainingBalance: $newRemainingBalance');

    // ── Prepare payload for API ──────────────────────────────────────
    final payload = {
      'SHOP_ID': _selectedShop!.shopId,
      'SHOP_NAME': _selectedShop!.shopName,
      'EMP_ID': _empId,
      'EMP_NAME': _empName,
      'COMPANY_CODE': _companyCode,
      'BALANCE': _staticBalance,
      'AMOUNT_RECEIVED': amount,
      'PAYMENT_MODE': mode,
      'RECOVER_BALANCE': newRecoverBalance,
      'REMAINING_BALANCE': newRemainingBalance,
      'PAYMENT_DATE': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
    };

    debugPrint('📤 [RecoveryScreen] Payload:');
    debugPrint('   ${jsonEncode(payload)}');

    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/recovery_balance/post/';
      debugPrint('📡 [RecoveryScreen] POST to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      debugPrint('📥 [RecoveryScreen] Response status: ${response.statusCode}');
      debugPrint('📥 [RecoveryScreen] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [RecoveryScreen] API call SUCCESS!');

        // ── ✅ UPDATE UI STATE ──────────────────────────────────────
        setState(() {
          _recoverBalance = newRecoverBalance;
          _remainingBalance = newRemainingBalance;
          _lastPaymentDate = now;
          _hasRecordedAny = true;  // ← THIS MAKES VALUES APPEAR
          _lastAmount = amount;
          _lastMode = mode;
          _hasPendingSync = false;
        });

        await _saveShopRecoveryState(_selectedShop!.shopId);

        debugPrint('✅ [RecoveryScreen] State updated successfully');
        debugPrint('   new recoverBalance: $_recoverBalance');
        debugPrint('   new remainingBalance: $_remainingBalance');

        Get.snackbar(
          '✅ Success',
          'Recovery recorded for ${_selectedShop!.shopName}',
          backgroundColor: _tealDark,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        debugPrint('❌ [RecoveryScreen] API returned error: ${response.statusCode}');

        setState(() {
          _recoverBalance = newRecoverBalance;
          _remainingBalance = newRemainingBalance;
          _lastPaymentDate = now;
          _hasRecordedAny = true;
          _lastAmount = amount;
          _lastMode = mode;
          _hasPendingSync = true;
        });

        await _saveShopRecoveryState(_selectedShop!.shopId);

        Get.snackbar(
          '⚠️ Saved Locally',
          'Server error. Recovery saved locally. Tap "Retry Submit" to send.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('❌ [RecoveryScreen] Exception: $e');

      setState(() {
        _recoverBalance = newRecoverBalance;
        _remainingBalance = newRemainingBalance;
        _lastPaymentDate = now;
        _hasRecordedAny = true;
        _lastAmount = amount;
        _lastMode = mode;
        _hasPendingSync = true;
      });

      await _saveShopRecoveryState(_selectedShop!.shopId);

      Get.snackbar(
        '📶 Offline Saved',
        'No internet. Recovery saved locally. Will retry when online.',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
      debugPrint('🏁 [RecoveryScreen] _submitRecoveryToServer finished');
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 7. RETRY SUBMIT PENDING RECOVERY
  // ════════════════════════════════════════════════════════════════════
  Future<void> _retrySubmitToServer() async {
    debugPrint('🔄 [RecoveryScreen] _retrySubmitToServer called');
    debugPrint('   hasPendingSync: $_hasPendingSync');

    if (_selectedShop == null) {
      Get.snackbar(
        'Error',
        'Please select a shop first.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!_hasPendingSync) {
      Get.snackbar(
        'All Synced',
        'No pending recovery to submit.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'SHOP_ID': _selectedShop!.shopId,
      'SHOP_NAME': _selectedShop!.shopName,
      'EMP_ID': _empId,
      'EMP_NAME': _empName,
      'COMPANY_CODE': _companyCode,
      'BALANCE': _staticBalance,
      'AMOUNT_RECEIVED': _lastAmount,
      'PAYMENT_MODE': _lastMode,
      'RECOVER_BALANCE': _recoverBalance,
      'REMAINING_BALANCE': _remainingBalance,
      'PAYMENT_DATE': DateFormat('yyyy-MM-dd HH:mm:ss').format(_lastPaymentDate),
    };

    try {
      final url = 'http://oracle.metaxperts.net/ords/gps_workforce/recovery_balance/post/';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _hasPendingSync = false);
        await _saveShopRecoveryState(_selectedShop!.shopId);

        Get.snackbar(
          '✅ Synced',
          'Pending recovery submitted successfully!',
          backgroundColor: _tealDark,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      Get.snackbar(
        '❌ Error',
        'Could not submit: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // 8. Build UI
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name = loginVM.currentUser.value?.emp_name ?? 'User';
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(
        userName: name,
        userInitials: initials,
        scaffoldKey: _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Get.back();
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Icon(Icons.arrow_back_rounded, color: _textDark, size: 22),
                ),
              ),
              const SizedBox(height: 8),

              // Title
              const Text(
                'Customer Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textDark),
              ),
              const SizedBox(height: 2),
              Text(
                _selectedShop != null
                    ? '${_selectedShop!.shopName} - ${_selectedShop!.ownerName}'
                    : 'Select a shop to view account',
                style: const TextStyle(fontSize: 13, color: _textMuted),
              ),

              const SizedBox(height: 16),

              if (_isLoadingShops)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.tealDark)),
                )
              else
                Column(
                  children: [
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(_errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchShops,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),

                    // ── Shop Display ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.iconBgTeal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.tealDark,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedShop?.shopName ?? 'No shop selected',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_selectedShop != null)
                                  Text(
                                    _selectedShop!.ownerName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.tealDark,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Account Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _AccountRow(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: _tealDark,
                            label: 'Balance',
                            value: 'Rs ${NumberFormat('#,##0').format(_staticBalance)}',
                          ),
                          const Divider(height: 1, color: AppColors.tealSurface),
                          _AccountRow(
                            icon: Icons.savings_outlined,
                            iconColor: _tealDark,
                            label: 'Recover Balance',
                            value: _hasRecordedAny
                                ? 'Rs ${NumberFormat('#,##0').format(_recoverBalance)}'
                                : '-',
                          ),
                          const Divider(height: 1, color: AppColors.tealSurface),
                          _AccountRow(
                            icon: Icons.pending_actions_outlined,
                            iconColor: _tealDark,
                            label: 'Remaining Balance',
                            value: _hasRecordedAny
                                ? 'Rs ${NumberFormat('#,##0').format(_remainingBalance)}'
                                : '-',
                          ),
                          const Divider(height: 1, color: AppColors.tealSurface),
                          _AccountRow(
                            icon: Icons.calendar_today_outlined,
                            iconColor: _tealDark,
                            label: 'Date',
                            value: DateFormat('yyyy-MM-dd').format(_lastPaymentDate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Overdue Warning (Yellow Box) ──────────────────
                    if (_hasRecordedAny && _remainingBalance > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6DD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF5E1A4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C4A03), height: 1.35),
                                  children: [
                                    const TextSpan(text: 'This shop has balance '),
                                    TextSpan(
                                      text: 'Rs ${NumberFormat('#,##0').format(_remainingBalance)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    const TextSpan(text: '. Consider recovering payment.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Receive Payment Button ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _showRecoverPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tealDark,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.tealLight, _tealDark]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _isSubmitting
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Receive Payment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Retry Submit Button ──────────────────────────
                    if (_hasPendingSync)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _retrySubmitToServer,
                          icon: Icon(
                            Icons.cloud_upload_outlined,
                            size: 18,
                            color: _isSubmitting ? _textMuted : Colors.orange,
                          ),
                          label: Text(
                            _isSubmitting ? 'Submitting...' : 'Retry Submit (Pending)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _isSubmitting ? _textMuted : Colors.orange,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(
                              color: Colors.orange,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      )
                    else if (_hasRecordedAny)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_done_outlined, color: Colors.green.shade700, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'All Synced',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Account Row Widget
// ════════════════════════════════════════════════════════════════════════
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _AccountRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// SHOP MODEL
// ════════════════════════════════════════════════════════════════════════
class ShopModel {
  final String id;
  final String empId;
  final String empName;
  final String companyCode;
  final String shopName;
  final String shopId;
  final String shopType;
  final String ownerName;
  final String contactNumber;
  final String city;
  final String address;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String? createdDate;
  final String? createdTime;

  const ShopModel({
    required this.id,
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.shopName,
    required this.shopId,
    required this.shopType,
    required this.ownerName,
    required this.contactNumber,
    required this.city,
    required this.address,
    this.notes,
    this.latitude,
    this.longitude,
    this.createdDate,
    this.createdTime,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ShopModel(
      id: json['id']?.toString() ?? '',
      empId: json['emp_id']?.toString() ?? '',
      empName: json['emp_name']?.toString() ?? '',
      companyCode: json['company_code']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      shopType: json['shop_type']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      notes: json['notes']?.toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      createdDate: json['created_date']?.toString(),
      createdTime: json['created_time']?.toString(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// RECOVER PAYMENT BOTTOM SHEET// ════════════════════════════════════════════════════════════════════════
class _RecoverPaymentSheet extends StatefulWidget {
  final ShopModel shop;
  final double remainingBalance;
  final Function(double amount, String mode) onSubmit;

  const _RecoverPaymentSheet({
    required this.shop,
    required this.remainingBalance,
    required this.onSubmit,
  });

  @override
  State<_RecoverPaymentSheet> createState() => _RecoverPaymentSheetState();
}

class _RecoverPaymentSheetState extends State<_RecoverPaymentSheet> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMode = 'Cash';
  final List<String> _modes = ['Cash', 'Cheque', 'Online Transfer'];

  @override
  void initState() {
    super.initState();
    debugPrint('🟢 [_RecoverPaymentSheet] initState');
    debugPrint('   shop: ${widget.shop.shopName}');
    debugPrint('   remainingBalance: ${widget.remainingBalance}');
  }

  @override
  void dispose() {
    _amountController.dispose();
    debugPrint('🔴 [_RecoverPaymentSheet] dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Receive Payment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.shop.shopName,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Amount Received (Rs)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  debugPrint('💰 [_RecoverPaymentSheet] Amount changed: $value');
                },
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Mode',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMode,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textPrimary,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  dropdownColor: Colors.white,
                  items: _modes.map((mode) {
                    return DropdownMenuItem<String>(
                      value: mode,
                      child: Text(
                        mode,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      debugPrint('🔄 [_RecoverPaymentSheet] Mode changed to: $value');
                      setState(() => _selectedMode = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      debugPrint('❌ [_RecoverPaymentSheet] Cancel button pressed');
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
                      debugPrint('📤 [_RecoverPaymentSheet] Record button pressed');
                      debugPrint('   amount: $amount');
                      debugPrint('   mode: $_selectedMode');
                      debugPrint('   remainingBalance: ${widget.remainingBalance}');

                      if (amount <= 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a valid amount.',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      if (amount > widget.remainingBalance) {
                        Get.snackbar(
                          'Error',
                          'Amount cannot exceed remaining balance.',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                      debugPrint('✅ [_RecoverPaymentSheet] Valid input, calling onSubmit');
                      Navigator.pop(context);
                      widget.onSubmit(amount, _selectedMode);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Record',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}