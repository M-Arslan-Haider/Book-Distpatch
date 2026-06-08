import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';
import '../../constants.dart';


// ═══════════════════════════════════════════════════════════════════════════
// loan_advance_screen.dart
//
// New Loan / Advance Request — Bottom Sheet Screen
// Reads companyCode, empId, empName automatically from SharedPreferences.
//
// USAGE — in actions_screen.dart inside _ActionCardWidgetState onTap:
//
//   onTap: () {
//     if (card.title == 'Loan / Advance') {
//       showModalBottomSheet(
//         context: context,
//         isScrollControlled: true,
//         backgroundColor: Colors.transparent,
//         useSafeArea: true,
//         builder: (_) => const LoanAdvanceScreen(),
//       );
//     }
//   },
// ═══════════════════════════════════════════════════════════════════════════

// ── SharedPreferences keys (same constants.dart as LoginScreen) ────────────
// Uses fallback key pattern (same as developer_options_check_service.dart)

// ── Paid-Every options ─────────────────────────────────────────────────────
const List<String> _paidEveryOptions = ['Week', 'Month', 'Quarter'];

// ── Model ──────────────────────────────────────────────────────────────────
class LoanPolicy {
  final String policyName;
  final String companyCode;

  const LoanPolicy({required this.policyName, required this.companyCode});

  factory LoanPolicy.fromJson(Map<String, dynamic> json) {
    return LoanPolicy(
      policyName: json['policy_name'] ?? json['POLICY_NAME'] ?? '',
      companyCode: json['company_code'] ?? json['COMPANY_CODE'] ?? '',
    );
  }
}

// ── GET Service ────────────────────────────────────────────────────────────
class LoanPolicyService {
  static const _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/loanpolicy/get/';

  static Future<List<LoanPolicy>> fetchPolicies({
    required String companyCode,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'company_code': companyCode},
    );

    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      List<dynamic> items;
      if (data is Map && data.containsKey('items')) {
        items = data['items'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }

      return items
          .map((e) => LoanPolicy.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load policies (${response.statusCode})');
    }
  }
}

// ── POST Service ───────────────────────────────────────────────────────────
// Oracle INSERT bind variables → JSON keys must match exactly:
//   :emp_id            → emp_id
//   :emp_name          → emp_name
//   :company_code      → company_code
//   :amount            → amount            (LOAN_AMOUNT column)
//   :policy_name       → policy_name       (DEDUCTION_METHOD column)
//   :reason            → reason
//   :request_date      → request_date      (REQUEST_DATE column) "YYYY-MM-DD"
//   :timestamp         → timestamp         (TIME column)         "HH:MM:SS"
//   :paid_every        → paid_every        (CUSTOM_METHOD column)
//   :installments_amount → installments_amount (INSTALLMENT_AMOUNT column)
class LoanSubmitService {
  static const _submitUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/loanrequest/post/';

  static Future<void> submitLoan({
    required String empId,
    required String empName,
    required String companyCode,
    required String reason,
    required int    amount,
    required String policyName,
    String?         paidEvery,           // only when Custom
    String?         installmentsAmount,  // only when Custom
  }) async {
    final now = DateTime.now();
    // :request_date → "YYYY-MM-DD"
    final requestDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    // :timestamp → "HH:MM:SS"
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final Map<String, dynamic> body = {
      'emp_id':               int.tryParse(empId) ?? empId,
      'emp_name':             empName,
      'company_code':         companyCode,
      'amount':               amount,
      'policy_name':          policyName,
      'reason':               reason,
      'request_date':         requestDate,
      'timestamp':            timestamp,
      'paid_every':           policyName == 'Custom' ? (paidEvery ?? '')    : '',
      'installments_amount':  policyName == 'Custom' ? (installmentsAmount ?? '') : '',
      'status':               'Pending',
    };

    final response = await http
        .post(
      Uri.parse(_submitUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit request (${response.statusCode})');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Main Screen Widget
// ═══════════════════════════════════════════════════════════════════════════
class LoanAdvanceScreen extends StatefulWidget {
  const LoanAdvanceScreen({super.key});

  @override
  State<LoanAdvanceScreen> createState() => _LoanAdvanceScreenState();
}

class _LoanAdvanceScreenState extends State<LoanAdvanceScreen> {
  // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
  static const _bgColor     = AppColors.surface;
  static const _primary     = AppColors.cyan;
  static const _primaryDark = AppColors.primaryDark;
  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _textDark    = AppColors.textPrimary;
  static const _textGray    = AppColors.textSecondary;
  static const _errorRed    = AppColors.error;

  // ── Form State ─────────────────────────────────────────────────────────
  final _reasonController             = TextEditingController();
  final _amountController             = TextEditingController();
  final _installmentsAmountController = TextEditingController();
  LoanPolicy? _selectedPolicy;
  static const int _maxReason = 300;

  // ── Custom Policy Extra Fields ─────────────────────────────────────────
  bool    _isCustomPolicy = false;
  String? _paidEvery;    // → :paid_every

  // ── Shared Prefs Data ──────────────────────────────────────────────────
  String _companyCode = '';
  String _empId       = '';
  String _empName     = '';

  // ── API State ──────────────────────────────────────────────────────────
  List<LoanPolicy> _policies     = [];
  bool             _loadingPolicies = true;
  String?          _policyError;

  // ── Submit / Reset State ───────────────────────────────────────────────
  bool _submitPressed = false;
  bool _resetPressed  = false;
  bool _submitting    = false;

  // ── Validation ─────────────────────────────────────────────────────────
  bool _reasonError                = false;
  bool _amountError                = false;
  bool _policySelectError          = false;
  bool _installmentsAmountError    = false;
  bool _paidEveryError             = false;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() => setState(() {}));
    _loadPrefsAndPolicies();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _installmentsAmountController.dispose();
    super.dispose();
  }

  // ── Safe pref helpers (same pattern as developer_options_check_service) ──
  static String? _safeGet(SharedPreferences prefs, String key) {
    try {
      final dynamic raw = prefs.get(key);
      if (raw == null) return null;
      final String val = raw.toString().trim();
      return val.isEmpty ? null : val;
    } catch (_) {
      return null;
    }
  }

  static String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final val = _safeGet(prefs, key);
      if (val != null) return val;
    }
    return '';
  }

  // ── Load SharedPreferences then fetch policies ─────────────────────────
  Future<void> _loadPrefsAndPolicies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
        _empId       = _safeGetFallback(prefs, ['userId',   'emp_id', 'employeeId']);
        _empName     = _safeGetFallback(prefs, ['userName', 'emp_name', 'empName', 'employee_name', 'name']);
      });
      await _fetchPolicies();
    } catch (e) {
      setState(() {
        _policyError     = 'Could not read company info. Tap to retry.';
        _loadingPolicies = false;
      });
    }
  }

  // ── Fetch Loan Policies from API + append "Custom" ─────────────────────
  Future<void> _fetchPolicies() async {
    setState(() {
      _loadingPolicies = true;
      _policyError     = null;
    });
    try {
      if (_companyCode.isEmpty) {
        final prefs  = await SharedPreferences.getInstance();
        _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
      }
      final fetched = await LoanPolicyService.fetchPolicies(
        companyCode: _companyCode,
      );
      setState(() {
        // Append "Custom" option at the end of the API list
        _policies = [
          ...fetched,
          LoanPolicy(policyName: 'Custom', companyCode: _companyCode),
        ];
        _loadingPolicies = false;
      });
    } catch (e) {
      setState(() {
        _policyError     = 'Could not load policies. Tap to retry.';
        _loadingPolicies = false;
      });
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────
  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _reasonController.clear();
      _amountController.clear();
      _installmentsAmountController.clear();
      _selectedPolicy           = null;
      _isCustomPolicy           = false;
      _paidEvery                = null;
      _reasonError              = false;
      _amountError              = false;
      _policySelectError        = false;
      _installmentsAmountError  = false;
      _paidEveryError           = false;
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    HapticFeedback.mediumImpact();

    final reason             = _reasonController.text.trim();
    final amount             = _amountController.text.trim();
    final installmentsAmount = _installmentsAmountController.text.trim();

    setState(() {
      _reasonError             = reason.isEmpty;
      _amountError             = amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0;
      _policySelectError       = _selectedPolicy == null;
      _installmentsAmountError = _isCustomPolicy &&
          (installmentsAmount.isEmpty ||
              (int.tryParse(installmentsAmount) ?? 0) <= 0);
      _paidEveryError          = _isCustomPolicy && _paidEvery == null;
    });

    if (_reasonError ||
        _amountError ||
        _policySelectError ||
        _installmentsAmountError ||
        _paidEveryError) return;

    setState(() => _submitting = true);

    try {
      await LoanSubmitService.submitLoan(
        empId:               _empId,
        empName:             _empName,
        companyCode:         _companyCode,
        reason:              reason,
        amount:              int.parse(amount),
        policyName:          _selectedPolicy!.policyName,
        paidEvery:           _isCustomPolicy ? _paidEvery           : null,
        installmentsAmount:  _isCustomPolicy ? installmentsAmount   : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Loan request submitted successfully!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: _errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Scrollable body ──────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'New Loan / Advance Request',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: _textDark),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: _borderColor, height: 1),
                  const SizedBox(height: 16),

                  // ── Breadcrumb ─────────────────────────────────────
                  _Breadcrumb(),

                  const SizedBox(height: 24),

                  // ── Reason ─────────────────────────────────────────
                  _FieldLabel(label: 'Reason', required: true),
                  const SizedBox(height: 8),
                  _ReasonField(
                    controller: _reasonController,
                    maxLength: _maxReason,
                    hasError: _reasonError,
                    onChanged: (_) => setState(() => _reasonError = false),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_reasonController.text.length} / $_maxReason',
                      style: TextStyle(
                        fontSize: 12,
                        color: _reasonError ? _errorRed : _textGray,
                      ),
                    ),
                  ),
                  if (_reasonError) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Please enter the reason for your request.',
                      style: TextStyle(fontSize: 12, color: _errorRed),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Amount ─────────────────────────────────────────
                  _FieldLabel(label: 'Amount (PKR)', required: true),
                  const SizedBox(height: 8),
                  _AmountField(
                    controller: _amountController,
                    hasError: _amountError,
                    onChanged: (_) => setState(() => _amountError = false),
                  ),
                  if (_amountError) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Please enter a valid amount.',
                      style: TextStyle(fontSize: 12, color: _errorRed),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Return Policy label ────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Return Policy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: _borderColor),
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            size: 13, color: _primary),
                      ),
                      const SizedBox(width: 4),
                      const Text('*',
                          style: TextStyle(
                              fontSize: 14,
                              color: _errorRed,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Policy Dropdown (includes "Custom" from API list) ──
                  _PolicyDropdown(
                    policies: _policies,
                    selected: _selectedPolicy,
                    isLoading: _loadingPolicies,
                    errorMessage: _policyError,
                    hasValidationError: _policySelectError,
                    onRetry: _fetchPolicies,
                    onChanged: (policy) => setState(() {
                      _selectedPolicy    = policy;
                      _policySelectError = false;
                      _isCustomPolicy    = policy?.policyName == 'Custom';
                      if (!_isCustomPolicy) {
                        _installmentsAmountController.clear();
                        _paidEvery               = null;
                        _installmentsAmountError = false;
                        _paidEveryError          = false;
                      }
                    }),
                  ),

                  if (_policySelectError) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Please select a return policy.',
                      style: TextStyle(fontSize: 12, color: _errorRed),
                    ),
                  ],

                  const SizedBox(height: 6),
                  const Text(
                    'Select how you want this loan or advance to be adjusted.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _primary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),

                  // ── Custom Policy Extra Fields (animated reveal) ────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 280),
                    crossFadeState: _isCustomPolicy
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Divider with "Custom Settings" label
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _primary.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded,
                                      size: 14, color: _primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Custom Settings',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Divider(color: _borderColor, height: 1),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Installments Amount → :installments_amount ──
                        _FieldLabel(
                            label: 'Installments Amount', required: true),
                        const SizedBox(height: 8),
                        _AmountField(
                          controller: _installmentsAmountController,
                          hasError: _installmentsAmountError,
                          onChanged: (_) => setState(
                                  () => _installmentsAmountError = false),
                        ),
                        if (_installmentsAmountError) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Please enter a valid installment amount.',
                            style: TextStyle(fontSize: 12, color: _errorRed),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Paid Every Dropdown → :paid_every ──────────
                        _FieldLabel(label: 'Paid Every', required: true),
                        const SizedBox(height: 8),
                        _PaidEveryDropdown(
                          value: _paidEvery,
                          hasValidationError: _paidEveryError,
                          onChanged: (val) => setState(() {
                            _paidEvery      = val;
                            _paidEveryError = false;
                          }),
                        ),
                        if (_paidEveryError) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Please select a payment frequency.',
                            style:
                            TextStyle(fontSize: 12, color: _errorRed),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: _borderColor, height: 1),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Bottom buttons ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                // Reset
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onTapDown: (_) {
                      HapticFeedback.lightImpact();
                      setState(() => _resetPressed = true);
                    },
                    onTapUp: (_) => setState(() => _resetPressed = false),
                    onTapCancel: () =>
                        setState(() => _resetPressed = false),
                    onTap: _reset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 52,
                      decoration: BoxDecoration(
                        color: _resetPressed
                            ? AppColors.cyanMid
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _borderColor, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded,
                              color: _textDark, size: 18),
                          SizedBox(width: 8),
                          Text('Reset',
                              style: TextStyle(
                                  color: _textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Submit
                Expanded(
                  flex: 6,
                  child: GestureDetector(
                    onTapDown: (_) {
                      if (_submitting) return;
                      HapticFeedback.lightImpact();
                      setState(() => _submitPressed = true);
                    },
                    onTapUp: (_) =>
                        setState(() => _submitPressed = false),
                    onTapCancel: () =>
                        setState(() => _submitPressed = false),
                    onTap: _submitting ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 52,
                      decoration: BoxDecoration(
                        color: _submitPressed ? _primaryDark : _primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _submitPressed
                            ? []
                            : [
                          BoxShadow(
                            color: _primary.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _submitting
                          ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.textOnDark,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded,
                              color: AppColors.textOnDark, size: 18),
                          SizedBox(width: 8),
                          Text('Submit',
                              style: TextStyle(
                                  color: AppColors.textOnDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2)),
                        ],
                      ),
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

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _Breadcrumb extends StatelessWidget {
  static const _primary     = AppColors.cyan;
  static const _borderColor = AppColors.divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _crumb('Requests', isActive: false),
          _chevron(),
          _crumb('Request', isActive: false),
          _chevron(),
          _crumb('Loan / Advance', isActive: true),
        ],
      ),
    );
  }

  Widget _crumb(String label, {required bool isActive}) => Text(
    label,
    style: TextStyle(
      fontSize: 12.5,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: isActive ? _primary : AppColors.textSecondary,
    ),
  );

  Widget _chevron() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: Icon(Icons.chevron_right_rounded,
        size: 14, color: AppColors.textSecondary),
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*',
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class _ReasonField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _ReasonField({
    required this.controller,
    required this.maxLength,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasError ? _errorRed : _borderColor,
            width: hasError ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: maxLength,
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'Purpose of loan / advance',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            contentPadding: EdgeInsets.all(16),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _AmountField({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasError ? _errorRed : _borderColor,
            width: hasError ? 1.5 : 1),
      ),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5),
          decoration: const InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _PolicyDropdown extends StatelessWidget {
  final List<LoanPolicy> policies;
  final LoanPolicy? selected;
  final bool isLoading;
  final String? errorMessage;
  final bool hasValidationError;
  final VoidCallback onRetry;
  final ValueChanged<LoanPolicy?> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;
  static const _primary     = AppColors.cyan;

  const _PolicyDropdown({
    required this.policies,
    required this.selected,
    required this.isLoading,
    required this.errorMessage,
    required this.hasValidationError,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _shell(
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _primary),
            ),
            SizedBox(width: 10),
            Text('Loading policies...',
                style:
                TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return GestureDetector(
        onTap: onRetry,
        child: _shell(
          borderColor: _errorRed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, color: _errorRed, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(errorMessage!,
                    style: const TextStyle(
                        fontSize: 13, color: _errorRed)),
              ),
            ],
          ),
        ),
      );
    }

    return _shell(
      borderColor: hasValidationError ? _errorRed : _borderColor,
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<LoanPolicy>(
            value: selected,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
            hint: const Text('Select return policy',
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600),
            dropdownColor: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            onChanged: onChanged,
            items: policies.map((p) {
              final isCustom = p.policyName == 'Custom';
              return DropdownMenuItem<LoanPolicy>(
                value: p,
                child: Row(
                  children: [
                    if (isCustom) ...[
                      const Icon(Icons.tune_rounded,
                          size: 16, color: _primary),
                      const SizedBox(width: 6),
                    ],
                    Text(p.policyName),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _shell(
      {required Widget child, Color borderColor = _borderColor}) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ── Paid Every Dropdown ────────────────────────────────────────────────────
class _PaidEveryDropdown extends StatelessWidget {
  final String? value;
  final bool hasValidationError;
  final ValueChanged<String?> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;
  static const _primary     = AppColors.cyan;

  const _PaidEveryDropdown({
    required this.value,
    required this.hasValidationError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValidationError ? _errorRed : _borderColor,
          width: hasValidationError ? 1.5 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
            hint: const Text('Select frequency',
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600),
            dropdownColor: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            onChanged: onChanged,
            items: _paidEveryOptions.map((option) {
              IconData icon;
              switch (option) {
                case 'Week':
                  icon = Icons.view_week_rounded;
                  break;
                case 'Month':
                  icon = Icons.calendar_month_rounded;
                  break;
                case 'Quarter':
                  icon = Icons.date_range_rounded;
                  break;
                default:
                  icon = Icons.schedule_rounded;
              }
              return DropdownMenuItem<String>(
                value: option,
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: _primary),
                    const SizedBox(width: 8),
                    Text(option),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}


