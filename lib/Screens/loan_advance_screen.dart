// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../AppColors.dart';
// // import '../../constants.dart';
// //
// //
// // // ═══════════════════════════════════════════════════════════════════════════
// // // loan_advance_screen.dart
// // //
// // // New Loan / Advance Request — Bottom Sheet Screen
// // // Reads companyCode, empId, empName automatically from SharedPreferences.
// // //
// // // USAGE — in actions_screen.dart inside _ActionCardWidgetState onTap:
// // //
// // //   onTap: () {
// // //     if (card.title == 'Loan / Advance') {
// // //       showModalBottomSheet(
// // //         context: context,
// // //         isScrollControlled: true,
// // //         backgroundColor: Colors.transparent,
// // //         useSafeArea: true,
// // //         builder: (_) => const LoanAdvanceScreen(),
// // //       );
// // //     }
// // //   },
// // // ═══════════════════════════════════════════════════════════════════════════
// //
// // // ── SharedPreferences keys (same constants.dart as LoginScreen) ────────────
// // // Uses fallback key pattern (same as developer_options_check_service.dart)
// //
// // // ── Paid-Every options ─────────────────────────────────────────────────────
// // const List<String> _paidEveryOptions = ['Week', 'Month', 'Quarter'];
// //
// // // ── Model ──────────────────────────────────────────────────────────────────
// // class LoanPolicy {
// //   final String policyName;
// //   final String companyCode;
// //
// //   const LoanPolicy({required this.policyName, required this.companyCode});
// //
// //   factory LoanPolicy.fromJson(Map<String, dynamic> json) {
// //     return LoanPolicy(
// //       policyName: json['policy_name'] ?? json['POLICY_NAME'] ?? '',
// //       companyCode: json['company_code'] ?? json['COMPANY_CODE'] ?? '',
// //     );
// //   }
// // }
// //
// // // ── GET Service ────────────────────────────────────────────────────────────
// // class LoanPolicyService {
// //   static const _baseUrl =
// //       'http://oracle.metaxperts.net/ords/gps_workforce/loanpolicy/get/';
// //
// //   static Future<List<LoanPolicy>> fetchPolicies({
// //     required String companyCode,
// //   }) async {
// //     final uri = Uri.parse(_baseUrl).replace(
// //       queryParameters: {'company_code': companyCode},
// //     );
// //
// //     final response = await http
// //         .get(uri, headers: {'Content-Type': 'application/json'})
// //         .timeout(const Duration(seconds: 15));
// //
// //     if (response.statusCode == 200) {
// //       final data = jsonDecode(response.body);
// //
// //       List<dynamic> items;
// //       if (data is Map && data.containsKey('items')) {
// //         items = data['items'] as List<dynamic>;
// //       } else if (data is List) {
// //         items = data;
// //       } else {
// //         items = [];
// //       }
// //
// //       return items
// //           .map((e) => LoanPolicy.fromJson(e as Map<String, dynamic>))
// //           .toList();
// //     } else {
// //       throw Exception('Failed to load policies (${response.statusCode})');
// //     }
// //   }
// // }
// //
// // // ── POST Service ───────────────────────────────────────────────────────────
// // // Oracle INSERT bind variables → JSON keys must match exactly:
// // //   :emp_id            → emp_id
// // //   :emp_name          → emp_name
// // //   :company_code      → company_code
// // //   :amount            → amount            (LOAN_AMOUNT column)
// // //   :policy_name       → policy_name       (DEDUCTION_METHOD column)
// // //   :reason            → reason
// // //   :request_date      → request_date      (REQUEST_DATE column) "YYYY-MM-DD"
// // //   :timestamp         → timestamp         (TIME column)         "HH:MM:SS"
// // //   :paid_every        → paid_every        (CUSTOM_METHOD column)
// // //   :installments_amount → installments_amount (INSTALLMENT_AMOUNT column)
// // class LoanSubmitService {
// //   static const _submitUrl =
// //       'http://oracle.metaxperts.net/ords/gps_workforce/loanrequest/post/';
// //
// //   static Future<void> submitLoan({
// //     required String empId,
// //     required String empName,
// //     required String companyCode,
// //     required String reason,
// //     required int    amount,
// //     required String policyName,
// //     String?         paidEvery,           // only when Custom
// //     String?         installmentsAmount,  // only when Custom
// //   }) async {
// //     final now = DateTime.now();
// //     // :request_date → "YYYY-MM-DD"
// //     final requestDate =
// //         '${now.year.toString().padLeft(4, '0')}-'
// //         '${now.month.toString().padLeft(2, '0')}-'
// //         '${now.day.toString().padLeft(2, '0')}';
// //     // :timestamp → "HH:MM:SS"
// //     final timestamp =
// //         '${now.hour.toString().padLeft(2, '0')}:'
// //         '${now.minute.toString().padLeft(2, '0')}:'
// //         '${now.second.toString().padLeft(2, '0')}';
// //
// //     final Map<String, dynamic> body = {
// //       'emp_id':               int.tryParse(empId) ?? empId,
// //       'emp_name':             empName,
// //       'company_code':         companyCode,
// //       'amount':               amount,
// //       'policy_name':          policyName,
// //       'reason':               reason,
// //       'request_date':         requestDate,
// //       'timestamp':            timestamp,
// //       'paid_every':           policyName == 'Custom' ? (paidEvery ?? '')    : '',
// //       'installments_amount':  policyName == 'Custom' ? (installmentsAmount ?? '') : '',
// //       'status':               'Pending',
// //     };
// //
// //     final response = await http
// //         .post(
// //       Uri.parse(_submitUrl),
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode(body),
// //     )
// //         .timeout(const Duration(seconds: 15));
// //
// //     if (response.statusCode != 200 && response.statusCode != 201) {
// //       throw Exception('Failed to submit request (${response.statusCode})');
// //     }
// //   }
// // }
// //
// // // ═══════════════════════════════════════════════════════════════════════════
// // // Main Screen Widget
// // // ═══════════════════════════════════════════════════════════════════════════
// // class LoanAdvanceScreen extends StatefulWidget {
// //   const LoanAdvanceScreen({super.key});
// //
// //   @override
// //   State<LoanAdvanceScreen> createState() => _LoanAdvanceScreenState();
// // }
// //
// // class _LoanAdvanceScreenState extends State<LoanAdvanceScreen> {
// //   // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
// //   static const _bgColor     = AppColors.surface;
// //   static const _primary     = AppColors.cyan;
// //   static const _primaryDark = AppColors.primaryDark;
// //   static const _fieldBg     = AppColors.cyanLight;
// //   static const _borderColor = AppColors.divider;
// //   static const _textDark    = AppColors.textPrimary;
// //   static const _textGray    = AppColors.textSecondary;
// //   static const _errorRed    = AppColors.error;
// //
// //   // ── Form State ─────────────────────────────────────────────────────────
// //   final _reasonController             = TextEditingController();
// //   final _amountController             = TextEditingController();
// //   final _installmentsAmountController = TextEditingController();
// //   LoanPolicy? _selectedPolicy;
// //   static const int _maxReason = 300;
// //
// //   // ── Custom Policy Extra Fields ─────────────────────────────────────────
// //   bool    _isCustomPolicy = false;
// //   String? _paidEvery;    // → :paid_every
// //
// //   // ── Shared Prefs Data ──────────────────────────────────────────────────
// //   String _companyCode = '';
// //   String _empId       = '';
// //   String _empName     = '';
// //
// //   // ── API State ──────────────────────────────────────────────────────────
// //   List<LoanPolicy> _policies     = [];
// //   bool             _loadingPolicies = true;
// //   String?          _policyError;
// //
// //   // ── Submit / Reset State ───────────────────────────────────────────────
// //   bool _submitPressed = false;
// //   bool _resetPressed  = false;
// //   bool _submitting    = false;
// //
// //   // ── Validation ─────────────────────────────────────────────────────────
// //   bool _reasonError                = false;
// //   bool _amountError                = false;
// //   bool _policySelectError          = false;
// //   bool _installmentsAmountError    = false;
// //   bool _paidEveryError             = false;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _reasonController.addListener(() => setState(() {}));
// //     _loadPrefsAndPolicies();
// //   }
// //
// //   @override
// //   void dispose() {
// //     _reasonController.dispose();
// //     _amountController.dispose();
// //     _installmentsAmountController.dispose();
// //     super.dispose();
// //   }
// //
// //   // ── Safe pref helpers (same pattern as developer_options_check_service) ──
// //   static String? _safeGet(SharedPreferences prefs, String key) {
// //     try {
// //       final dynamic raw = prefs.get(key);
// //       if (raw == null) return null;
// //       final String val = raw.toString().trim();
// //       return val.isEmpty ? null : val;
// //     } catch (_) {
// //       return null;
// //     }
// //   }
// //
// //   static String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
// //     for (final key in keys) {
// //       final val = _safeGet(prefs, key);
// //       if (val != null) return val;
// //     }
// //     return '';
// //   }
// //
// //   // ── Load SharedPreferences then fetch policies ─────────────────────────
// //   Future<void> _loadPrefsAndPolicies() async {
// //     try {
// //       final prefs = await SharedPreferences.getInstance();
// //       setState(() {
// //         _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
// //         _empId       = _safeGetFallback(prefs, ['userId',   'emp_id', 'employeeId']);
// //         _empName     = _safeGetFallback(prefs, ['userName', 'emp_name', 'empName', 'employee_name', 'name']);
// //       });
// //       await _fetchPolicies();
// //     } catch (e) {
// //       setState(() {
// //         _policyError     = 'Could not read company info. Tap to retry.';
// //         _loadingPolicies = false;
// //       });
// //     }
// //   }
// //
// //   // ── Fetch Loan Policies from API + append "Custom" ─────────────────────
// //   Future<void> _fetchPolicies() async {
// //     setState(() {
// //       _loadingPolicies = true;
// //       _policyError     = null;
// //     });
// //     try {
// //       if (_companyCode.isEmpty) {
// //         final prefs  = await SharedPreferences.getInstance();
// //         _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
// //       }
// //       final fetched = await LoanPolicyService.fetchPolicies(
// //         companyCode: _companyCode,
// //       );
// //       setState(() {
// //         // Append "Custom" option at the end of the API list
// //         _policies = [
// //           ...fetched,
// //           LoanPolicy(policyName: 'Custom', companyCode: _companyCode),
// //         ];
// //         _loadingPolicies = false;
// //       });
// //     } catch (e) {
// //       setState(() {
// //         _policyError     = 'Could not load policies. Tap to retry.';
// //         _loadingPolicies = false;
// //       });
// //     }
// //   }
// //
// //   // ── Reset ──────────────────────────────────────────────────────────────
// //   void _reset() {
// //     HapticFeedback.lightImpact();
// //     setState(() {
// //       _reasonController.clear();
// //       _amountController.clear();
// //       _installmentsAmountController.clear();
// //       _selectedPolicy           = null;
// //       _isCustomPolicy           = false;
// //       _paidEvery                = null;
// //       _reasonError              = false;
// //       _amountError              = false;
// //       _policySelectError        = false;
// //       _installmentsAmountError  = false;
// //       _paidEveryError           = false;
// //     });
// //   }
// //
// //   // ── Submit ─────────────────────────────────────────────────────────────
// //   Future<void> _submit() async {
// //     HapticFeedback.mediumImpact();
// //
// //     final reason             = _reasonController.text.trim();
// //     final amount             = _amountController.text.trim();
// //     final installmentsAmount = _installmentsAmountController.text.trim();
// //
// //     setState(() {
// //       _reasonError             = reason.isEmpty;
// //       _amountError             = amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0;
// //       _policySelectError       = _selectedPolicy == null;
// //       _installmentsAmountError = _isCustomPolicy &&
// //           (installmentsAmount.isEmpty ||
// //               (int.tryParse(installmentsAmount) ?? 0) <= 0);
// //       _paidEveryError          = _isCustomPolicy && _paidEvery == null;
// //     });
// //
// //     if (_reasonError ||
// //         _amountError ||
// //         _policySelectError ||
// //         _installmentsAmountError ||
// //         _paidEveryError) return;
// //
// //     setState(() => _submitting = true);
// //
// //     try {
// //       await LoanSubmitService.submitLoan(
// //         empId:               _empId,
// //         empName:             _empName,
// //         companyCode:         _companyCode,
// //         reason:              reason,
// //         amount:              int.parse(amount),
// //         policyName:          _selectedPolicy!.policyName,
// //         paidEvery:           _isCustomPolicy ? _paidEvery           : null,
// //         installmentsAmount:  _isCustomPolicy ? installmentsAmount   : null,
// //       );
// //
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: const Text('Loan request submitted successfully!'),
// //             backgroundColor: _primary,
// //             behavior: SnackBarBehavior.floating,
// //             shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(12)),
// //           ),
// //         );
// //         Navigator.pop(context);
// //       }
// //     } catch (e) {
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text('Submission failed: ${e.toString()}'),
// //             backgroundColor: _errorRed,
// //             behavior: SnackBarBehavior.floating,
// //             shape: RoundedRectangleBorder(
// //                 borderRadius: BorderRadius.circular(12)),
// //           ),
// //         );
// //       }
// //     } finally {
// //       if (mounted) setState(() => _submitting = false);
// //     }
// //   }
// //
// //   // ══════════════════════════════════════════════════════════════════════
// //   @override
// //   Widget build(BuildContext context) {
// //     final bottomInset = MediaQuery.of(context).viewInsets.bottom;
// //
// //     return Container(
// //       decoration: const BoxDecoration(
// //         color: _bgColor,
// //         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// //       ),
// //       padding: EdgeInsets.only(bottom: bottomInset),
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           // ── Drag handle ──────────────────────────────────────────────
// //           const SizedBox(height: 12),
// //           Center(
// //             child: Container(
// //               width: 40,
// //               height: 4,
// //               decoration: BoxDecoration(
// //                 color: AppColors.divider,
// //                 borderRadius: BorderRadius.circular(4),
// //               ),
// //             ),
// //           ),
// //           const SizedBox(height: 16),
// //
// //           // ── Scrollable body ──────────────────────────────────────────
// //           Flexible(
// //             child: SingleChildScrollView(
// //               padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   // ── Header row ─────────────────────────────────────
// //                   Row(
// //                     children: [
// //                       const Expanded(
// //                         child: Text(
// //                           'New Loan / Advance Request',
// //                           style: TextStyle(
// //                             fontSize: 20,
// //                             fontWeight: FontWeight.w800,
// //                             color: _textDark,
// //                             letterSpacing: -0.4,
// //                           ),
// //                         ),
// //                       ),
// //                       GestureDetector(
// //                         onTap: () => Navigator.pop(context),
// //                         child: Container(
// //                           width: 36,
// //                           height: 36,
// //                           decoration: BoxDecoration(
// //                             color: AppColors.cardBg,
// //                             shape: BoxShape.circle,
// //                             border: Border.all(color: _borderColor),
// //                           ),
// //                           child: const Icon(Icons.close_rounded,
// //                               size: 18, color: _textDark),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //
// //                   const SizedBox(height: 16),
// //                   const Divider(color: _borderColor, height: 1),
// //                   const SizedBox(height: 16),
// //
// //                   // ── Breadcrumb ─────────────────────────────────────
// //                   _Breadcrumb(),
// //
// //                   const SizedBox(height: 24),
// //
// //                   // ── Reason ─────────────────────────────────────────
// //                   _FieldLabel(label: 'Reason', required: true),
// //                   const SizedBox(height: 8),
// //                   _ReasonField(
// //                     controller: _reasonController,
// //                     maxLength: _maxReason,
// //                     hasError: _reasonError,
// //                     onChanged: (_) => setState(() => _reasonError = false),
// //                   ),
// //                   const SizedBox(height: 4),
// //                   Align(
// //                     alignment: Alignment.centerRight,
// //                     child: Text(
// //                       '${_reasonController.text.length} / $_maxReason',
// //                       style: TextStyle(
// //                         fontSize: 12,
// //                         color: _reasonError ? _errorRed : _textGray,
// //                       ),
// //                     ),
// //                   ),
// //                   if (_reasonError) ...[
// //                     const SizedBox(height: 4),
// //                     const Text(
// //                       'Please enter the reason for your request.',
// //                       style: TextStyle(fontSize: 12, color: _errorRed),
// //                     ),
// //                   ],
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Amount ─────────────────────────────────────────
// //                   _FieldLabel(label: 'Amount (PKR)', required: true),
// //                   const SizedBox(height: 8),
// //                   _AmountField(
// //                     controller: _amountController,
// //                     hasError: _amountError,
// //                     onChanged: (_) => setState(() => _amountError = false),
// //                   ),
// //                   if (_amountError) ...[
// //                     const SizedBox(height: 4),
// //                     const Text(
// //                       'Please enter a valid amount.',
// //                       style: TextStyle(fontSize: 12, color: _errorRed),
// //                     ),
// //                   ],
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Return Policy label ────────────────────────────
// //                   Row(
// //                     children: [
// //                       const Text(
// //                         'Return Policy',
// //                         style: TextStyle(
// //                           fontSize: 14,
// //                           fontWeight: FontWeight.w700,
// //                           color: _textDark,
// //                         ),
// //                       ),
// //                       const SizedBox(width: 6),
// //                       Container(
// //                         width: 20,
// //                         height: 20,
// //                         decoration: BoxDecoration(
// //                           color: AppColors.cardBg,
// //                           shape: BoxShape.circle,
// //                           border: Border.all(color: _borderColor),
// //                         ),
// //                         child: const Icon(Icons.info_outline_rounded,
// //                             size: 13, color: _primary),
// //                       ),
// //                       const SizedBox(width: 4),
// //                       const Text('*',
// //                           style: TextStyle(
// //                               fontSize: 14,
// //                               color: _errorRed,
// //                               fontWeight: FontWeight.w700)),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 8),
// //
// //                   // ── Policy Dropdown (includes "Custom" from API list) ──
// //                   _PolicyDropdown(
// //                     policies: _policies,
// //                     selected: _selectedPolicy,
// //                     isLoading: _loadingPolicies,
// //                     errorMessage: _policyError,
// //                     hasValidationError: _policySelectError,
// //                     onRetry: _fetchPolicies,
// //                     onChanged: (policy) => setState(() {
// //                       _selectedPolicy    = policy;
// //                       _policySelectError = false;
// //                       _isCustomPolicy    = policy?.policyName == 'Custom';
// //                       if (!_isCustomPolicy) {
// //                         _installmentsAmountController.clear();
// //                         _paidEvery               = null;
// //                         _installmentsAmountError = false;
// //                         _paidEveryError          = false;
// //                       }
// //                     }),
// //                   ),
// //
// //                   if (_policySelectError) ...[
// //                     const SizedBox(height: 4),
// //                     const Text(
// //                       'Please select a return policy.',
// //                       style: TextStyle(fontSize: 12, color: _errorRed),
// //                     ),
// //                   ],
// //
// //                   const SizedBox(height: 6),
// //                   const Text(
// //                     'Select how you want this loan or advance to be adjusted.',
// //                     style: TextStyle(
// //                       fontSize: 12.5,
// //                       color: _primary,
// //                       fontStyle: FontStyle.italic,
// //                       height: 1.4,
// //                     ),
// //                   ),
// //
// //                   // ── Custom Policy Extra Fields (animated reveal) ────
// //                   AnimatedCrossFade(
// //                     duration: const Duration(milliseconds: 280),
// //                     crossFadeState: _isCustomPolicy
// //                         ? CrossFadeState.showSecond
// //                         : CrossFadeState.showFirst,
// //                     firstChild: const SizedBox.shrink(),
// //                     secondChild: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         const SizedBox(height: 20),
// //
// //                         // Divider with "Custom Settings" label
// //                         Row(
// //                           children: [
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                   horizontal: 10, vertical: 4),
// //                               decoration: BoxDecoration(
// //                                 color: _primary.withOpacity(0.08),
// //                                 borderRadius: BorderRadius.circular(8),
// //                                 border: Border.all(
// //                                     color: _primary.withOpacity(0.2)),
// //                               ),
// //                               child: const Row(
// //                                 mainAxisSize: MainAxisSize.min,
// //                                 children: [
// //                                   Icon(Icons.tune_rounded,
// //                                       size: 14, color: _primary),
// //                                   SizedBox(width: 6),
// //                                   Text(
// //                                     'Custom Settings',
// //                                     style: TextStyle(
// //                                       fontSize: 12,
// //                                       fontWeight: FontWeight.w700,
// //                                       color: _primary,
// //                                       letterSpacing: 0.3,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),
// //                             const SizedBox(width: 10),
// //                             const Expanded(
// //                               child: Divider(color: _borderColor, height: 1),
// //                             ),
// //                           ],
// //                         ),
// //
// //                         const SizedBox(height: 16),
// //
// //                         // ── Installments Amount → :installments_amount ──
// //                         _FieldLabel(
// //                             label: 'Installments Amount', required: true),
// //                         const SizedBox(height: 8),
// //                         _AmountField(
// //                           controller: _installmentsAmountController,
// //                           hasError: _installmentsAmountError,
// //                           onChanged: (_) => setState(
// //                                   () => _installmentsAmountError = false),
// //                         ),
// //                         if (_installmentsAmountError) ...[
// //                           const SizedBox(height: 4),
// //                           const Text(
// //                             'Please enter a valid installment amount.',
// //                             style: TextStyle(fontSize: 12, color: _errorRed),
// //                           ),
// //                         ],
// //
// //                         const SizedBox(height: 20),
// //
// //                         // ── Paid Every Dropdown → :paid_every ──────────
// //                         _FieldLabel(label: 'Paid Every', required: true),
// //                         const SizedBox(height: 8),
// //                         _PaidEveryDropdown(
// //                           value: _paidEvery,
// //                           hasValidationError: _paidEveryError,
// //                           onChanged: (val) => setState(() {
// //                             _paidEvery      = val;
// //                             _paidEveryError = false;
// //                           }),
// //                         ),
// //                         if (_paidEveryError) ...[
// //                           const SizedBox(height: 4),
// //                           const Text(
// //                             'Please select a payment frequency.',
// //                             style:
// //                             TextStyle(fontSize: 12, color: _errorRed),
// //                           ),
// //                         ],
// //                       ],
// //                     ),
// //                   ),
// //
// //                   const SizedBox(height: 28),
// //                   const Divider(color: _borderColor, height: 1),
// //                   const SizedBox(height: 16),
// //                 ],
// //               ),
// //             ),
// //           ),
// //
// //           // ── Bottom buttons ───────────────────────────────────────────
// //           Padding(
// //             padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
// //             child: Row(
// //               children: [
// //                 // Reset
// //                 Expanded(
// //                   flex: 4,
// //                   child: GestureDetector(
// //                     onTapDown: (_) {
// //                       HapticFeedback.lightImpact();
// //                       setState(() => _resetPressed = true);
// //                     },
// //                     onTapUp: (_) => setState(() => _resetPressed = false),
// //                     onTapCancel: () =>
// //                         setState(() => _resetPressed = false),
// //                     onTap: _reset,
// //                     child: AnimatedContainer(
// //                       duration: const Duration(milliseconds: 100),
// //                       height: 52,
// //                       decoration: BoxDecoration(
// //                         color: _resetPressed
// //                             ? AppColors.cyanMid
// //                             : AppColors.cardBg,
// //                         borderRadius: BorderRadius.circular(16),
// //                         border: Border.all(
// //                             color: _borderColor, width: 1.5),
// //                       ),
// //                       child: const Row(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         children: [
// //                           Icon(Icons.replay_rounded,
// //                               color: _textDark, size: 18),
// //                           SizedBox(width: 8),
// //                           Text('Reset',
// //                               style: TextStyle(
// //                                   color: _textDark,
// //                                   fontSize: 15,
// //                                   fontWeight: FontWeight.w700)),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //
// //                 const SizedBox(width: 12),
// //
// //                 // Submit
// //                 Expanded(
// //                   flex: 6,
// //                   child: GestureDetector(
// //                     onTapDown: (_) {
// //                       if (_submitting) return;
// //                       HapticFeedback.lightImpact();
// //                       setState(() => _submitPressed = true);
// //                     },
// //                     onTapUp: (_) =>
// //                         setState(() => _submitPressed = false),
// //                     onTapCancel: () =>
// //                         setState(() => _submitPressed = false),
// //                     onTap: _submitting ? null : _submit,
// //                     child: AnimatedContainer(
// //                       duration: const Duration(milliseconds: 100),
// //                       height: 52,
// //                       decoration: BoxDecoration(
// //                         color: _submitPressed ? _primaryDark : _primary,
// //                         borderRadius: BorderRadius.circular(16),
// //                         boxShadow: _submitPressed
// //                             ? []
// //                             : [
// //                           BoxShadow(
// //                             color: _primary.withOpacity(0.35),
// //                             blurRadius: 14,
// //                             offset: const Offset(0, 5),
// //                           ),
// //                         ],
// //                       ),
// //                       child: _submitting
// //                           ? const Center(
// //                         child: SizedBox(
// //                           width: 22,
// //                           height: 22,
// //                           child: CircularProgressIndicator(
// //                             color: AppColors.textOnDark,
// //                             strokeWidth: 2.5,
// //                           ),
// //                         ),
// //                       )
// //                           : const Row(
// //                         mainAxisAlignment: MainAxisAlignment.center,
// //                         children: [
// //                           Icon(Icons.send_rounded,
// //                               color: AppColors.textOnDark, size: 18),
// //                           SizedBox(width: 8),
// //                           Text('Submit',
// //                               style: TextStyle(
// //                                   color: AppColors.textOnDark,
// //                                   fontSize: 15,
// //                                   fontWeight: FontWeight.w700,
// //                                   letterSpacing: 0.2)),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ═══════════════════════════════════════════════════════════════════════════
// // // Helper Widgets
// // // ═══════════════════════════════════════════════════════════════════════════
// //
// // class _Breadcrumb extends StatelessWidget {
// //   static const _primary     = AppColors.cyan;
// //   static const _borderColor = AppColors.divider;
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //       decoration: BoxDecoration(
// //         color: AppColors.cardBg,
// //         borderRadius: BorderRadius.circular(12),
// //         border: Border.all(color: _borderColor),
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           _crumb('Requests', isActive: false),
// //           _chevron(),
// //           _crumb('Request', isActive: false),
// //           _chevron(),
// //           _crumb('Loan / Advance', isActive: true),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _crumb(String label, {required bool isActive}) => Text(
// //     label,
// //     style: TextStyle(
// //       fontSize: 12.5,
// //       fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
// //       color: isActive ? _primary : AppColors.textSecondary,
// //     ),
// //   );
// //
// //   Widget _chevron() => const Padding(
// //     padding: EdgeInsets.symmetric(horizontal: 6),
// //     child: Icon(Icons.chevron_right_rounded,
// //         size: 14, color: AppColors.textSecondary),
// //   );
// // }
// //
// // class _FieldLabel extends StatelessWidget {
// //   final String label;
// //   final bool required;
// //   const _FieldLabel({required this.label, this.required = false});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Row(
// //       children: [
// //         Text(label,
// //             style: const TextStyle(
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.w700,
// //                 color: AppColors.textPrimary)),
// //         if (required) ...[
// //           const SizedBox(width: 4),
// //           const Text('*',
// //               style: TextStyle(
// //                   fontSize: 14,
// //                   color: AppColors.error,
// //                   fontWeight: FontWeight.w700)),
// //         ],
// //       ],
// //     );
// //   }
// // }
// //
// // class _ReasonField extends StatelessWidget {
// //   final TextEditingController controller;
// //   final int maxLength;
// //   final bool hasError;
// //   final ValueChanged<String> onChanged;
// //
// //   static const _fieldBg     = AppColors.cyanLight;
// //   static const _borderColor = AppColors.divider;
// //   static const _errorRed    = AppColors.error;
// //
// //   const _ReasonField({
// //     required this.controller,
// //     required this.maxLength,
// //     required this.hasError,
// //     required this.onChanged,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: _fieldBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(
// //             color: hasError ? _errorRed : _borderColor,
// //             width: hasError ? 1.5 : 1),
// //       ),
// //       child: Material(
// //         color: Colors.transparent,
// //         child: TextField(
// //           controller: controller,
// //           maxLines: 5,
// //           maxLength: maxLength,
// //           onChanged: onChanged,
// //           style: const TextStyle(
// //               fontSize: 15, color: AppColors.textPrimary, height: 1.5),
// //           decoration: const InputDecoration(
// //             hintText: 'Purpose of loan / advance',
// //             hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
// //             contentPadding: EdgeInsets.all(16),
// //             border: InputBorder.none,
// //             counterText: '',
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // class _AmountField extends StatelessWidget {
// //   final TextEditingController controller;
// //   final bool hasError;
// //   final ValueChanged<String> onChanged;
// //
// //   static const _fieldBg     = AppColors.cyanLight;
// //   static const _borderColor = AppColors.divider;
// //   static const _errorRed    = AppColors.error;
// //
// //   const _AmountField({
// //     required this.controller,
// //     required this.hasError,
// //     required this.onChanged,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       height: 54,
// //       decoration: BoxDecoration(
// //         color: _fieldBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(
// //             color: hasError ? _errorRed : _borderColor,
// //             width: hasError ? 1.5 : 1),
// //       ),
// //       alignment: Alignment.center,
// //       child: Material(
// //         color: Colors.transparent,
// //         child: TextField(
// //           controller: controller,
// //           keyboardType: TextInputType.number,
// //           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
// //           onChanged: onChanged,
// //           textAlign: TextAlign.center,
// //           style: const TextStyle(
// //               fontSize: 22,
// //               fontWeight: FontWeight.w600,
// //               color: AppColors.textSecondary,
// //               letterSpacing: 0.5),
// //           decoration: const InputDecoration(
// //             hintText: '0',
// //             hintStyle: TextStyle(
// //                 fontSize: 22,
// //                 fontWeight: FontWeight.w600,
// //                 color: AppColors.textSecondary),
// //             contentPadding: EdgeInsets.symmetric(horizontal: 16),
// //             border: InputBorder.none,
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // class _PolicyDropdown extends StatelessWidget {
// //   final List<LoanPolicy> policies;
// //   final LoanPolicy? selected;
// //   final bool isLoading;
// //   final String? errorMessage;
// //   final bool hasValidationError;
// //   final VoidCallback onRetry;
// //   final ValueChanged<LoanPolicy?> onChanged;
// //
// //   static const _fieldBg     = AppColors.cyanLight;
// //   static const _borderColor = AppColors.divider;
// //   static const _errorRed    = AppColors.error;
// //   static const _primary     = AppColors.cyan;
// //
// //   const _PolicyDropdown({
// //     required this.policies,
// //     required this.selected,
// //     required this.isLoading,
// //     required this.errorMessage,
// //     required this.hasValidationError,
// //     required this.onRetry,
// //     required this.onChanged,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     if (isLoading) {
// //       return _shell(
// //         child: const Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             SizedBox(
// //               width: 18,
// //               height: 18,
// //               child: CircularProgressIndicator(
// //                   strokeWidth: 2, color: _primary),
// //             ),
// //             SizedBox(width: 10),
// //             Text('Loading policies...',
// //                 style:
// //                 TextStyle(fontSize: 14, color: AppColors.textSecondary)),
// //           ],
// //         ),
// //       );
// //     }
// //
// //     if (errorMessage != null) {
// //       return GestureDetector(
// //         onTap: onRetry,
// //         child: _shell(
// //           borderColor: _errorRed,
// //           child: Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               const Icon(Icons.refresh_rounded, color: _errorRed, size: 18),
// //               const SizedBox(width: 8),
// //               Flexible(
// //                 child: Text(errorMessage!,
// //                     style: const TextStyle(
// //                         fontSize: 13, color: _errorRed)),
// //               ),
// //             ],
// //           ),
// //         ),
// //       );
// //     }
// //
// //     return _shell(
// //       borderColor: hasValidationError ? _errorRed : _borderColor,
// //       child: Material(
// //         color: Colors.transparent,
// //         child: DropdownButtonHideUnderline(
// //           child: DropdownButton<LoanPolicy>(
// //             value: selected,
// //             isExpanded: true,
// //             icon: const Icon(Icons.keyboard_arrow_down_rounded,
// //                 color: AppColors.textSecondary),
// //             hint: const Text('Select return policy',
// //                 style: TextStyle(
// //                     fontSize: 15,
// //                     color: AppColors.textSecondary,
// //                     fontWeight: FontWeight.w500)),
// //             style: const TextStyle(
// //                 fontSize: 15,
// //                 color: AppColors.textPrimary,
// //                 fontWeight: FontWeight.w600),
// //             dropdownColor: AppColors.cardBg,
// //             borderRadius: BorderRadius.circular(14),
// //             onChanged: onChanged,
// //             items: policies.map((p) {
// //               final isCustom = p.policyName == 'Custom';
// //               return DropdownMenuItem<LoanPolicy>(
// //                 value: p,
// //                 child: Row(
// //                   children: [
// //                     if (isCustom) ...[
// //                       const Icon(Icons.tune_rounded,
// //                           size: 16, color: _primary),
// //                       const SizedBox(width: 6),
// //                     ],
// //                     Text(p.policyName),
// //                   ],
// //                 ),
// //               );
// //             }).toList(),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _shell(
// //       {required Widget child, Color borderColor = _borderColor}) {
// //     return Container(
// //       height: 54,
// //       padding: const EdgeInsets.symmetric(horizontal: 16),
// //       decoration: BoxDecoration(
// //         color: _fieldBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: borderColor, width: 1.2),
// //       ),
// //       alignment: Alignment.center,
// //       child: child,
// //     );
// //   }
// // }
// //
// // // ── Paid Every Dropdown ────────────────────────────────────────────────────
// // class _PaidEveryDropdown extends StatelessWidget {
// //   final String? value;
// //   final bool hasValidationError;
// //   final ValueChanged<String?> onChanged;
// //
// //   static const _fieldBg     = AppColors.cyanLight;
// //   static const _borderColor = AppColors.divider;
// //   static const _errorRed    = AppColors.error;
// //   static const _primary     = AppColors.cyan;
// //
// //   const _PaidEveryDropdown({
// //     required this.value,
// //     required this.hasValidationError,
// //     required this.onChanged,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       height: 54,
// //       padding: const EdgeInsets.symmetric(horizontal: 16),
// //       decoration: BoxDecoration(
// //         color: _fieldBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(
// //           color: hasValidationError ? _errorRed : _borderColor,
// //           width: hasValidationError ? 1.5 : 1.2,
// //         ),
// //       ),
// //       alignment: Alignment.center,
// //       child: Material(
// //         color: Colors.transparent,
// //         child: DropdownButtonHideUnderline(
// //           child: DropdownButton<String>(
// //             value: value,
// //             isExpanded: true,
// //             icon: const Icon(Icons.keyboard_arrow_down_rounded,
// //                 color: AppColors.textSecondary),
// //             hint: const Text('Select frequency',
// //                 style: TextStyle(
// //                     fontSize: 15,
// //                     color: AppColors.textSecondary,
// //                     fontWeight: FontWeight.w500)),
// //             style: const TextStyle(
// //                 fontSize: 15,
// //                 color: AppColors.textPrimary,
// //                 fontWeight: FontWeight.w600),
// //             dropdownColor: AppColors.cardBg,
// //             borderRadius: BorderRadius.circular(14),
// //             onChanged: onChanged,
// //             items: _paidEveryOptions.map((option) {
// //               IconData icon;
// //               switch (option) {
// //                 case 'Week':
// //                   icon = Icons.view_week_rounded;
// //                   break;
// //                 case 'Month':
// //                   icon = Icons.calendar_month_rounded;
// //                   break;
// //                 case 'Quarter':
// //                   icon = Icons.date_range_rounded;
// //                   break;
// //                 default:
// //                   icon = Icons.schedule_rounded;
// //               }
// //               return DropdownMenuItem<String>(
// //                 value: option,
// //                 child: Row(
// //                   children: [
// //                     Icon(icon, size: 16, color: _primary),
// //                     const SizedBox(width: 8),
// //                     Text(option),
// //                   ],
// //                 ),
// //               );
// //             }).toList(),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// //
//
//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../AppColors.dart';
// import '../../constants.dart';
// import 'HomeScreenComponents/navbar.dart';
// import 'HomeScreenComponents/sidebar_drawer.dart';
//
//
// // ═══════════════════════════════════════════════════════════════════════════
// // loan_advance_screen.dart
// //
// // New Loan / Advance Request — Full Screen
// // Reads companyCode, empId, empName automatically from SharedPreferences.
// // ═══════════════════════════════════════════════════════════════════════════
//
// // ── SharedPreferences keys (same constants.dart as LoginScreen) ────────────
// // Uses fallback key pattern (same as developer_options_check_service.dart)
//
// // ── Paid-Every options ─────────────────────────────────────────────────────
// const List<String> _paidEveryOptions = ['Week', 'Month', 'Quarter'];
//
// // ── Model ──────────────────────────────────────────────────────────────────
// class LoanPolicy {
//   final String policyName;
//   final String companyCode;
//
//   const LoanPolicy({required this.policyName, required this.companyCode});
//
//   factory LoanPolicy.fromJson(Map<String, dynamic> json) {
//     return LoanPolicy(
//       policyName: json['policy_name'] ?? json['POLICY_NAME'] ?? '',
//       companyCode: json['company_code'] ?? json['COMPANY_CODE'] ?? '',
//     );
//   }
// }
//
// // ── GET Service ────────────────────────────────────────────────────────────
// class LoanPolicyService {
//   static const _baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/loanpolicy/get/';
//
//   static Future<List<LoanPolicy>> fetchPolicies({
//     required String companyCode,
//   }) async {
//     final uri = Uri.parse(_baseUrl).replace(
//       queryParameters: {'company_code': companyCode},
//     );
//
//     final response = await http
//         .get(uri, headers: {'Content-Type': 'application/json'})
//         .timeout(const Duration(seconds: 15));
//
//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//
//       List<dynamic> items;
//       if (data is Map && data.containsKey('items')) {
//         items = data['items'] as List<dynamic>;
//       } else if (data is List) {
//         items = data;
//       } else {
//         items = [];
//       }
//
//       return items
//           .map((e) => LoanPolicy.fromJson(e as Map<String, dynamic>))
//           .toList();
//     } else {
//       throw Exception('Failed to load policies (${response.statusCode})');
//     }
//   }
// }
//
// // ── POST Service ───────────────────────────────────────────────────────────
// class LoanSubmitService {
//   static const _submitUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/loanrequest/post/';
//
//   static Future<void> submitLoan({
//     required String empId,
//     required String empName,
//     required String companyCode,
//     required String reason,
//     required int    amount,
//     required String policyName,
//     String?         paidEvery,
//     String?         installmentsAmount,
//   }) async {
//     final now = DateTime.now();
//     final requestDate =
//         '${now.year.toString().padLeft(4, '0')}-'
//         '${now.month.toString().padLeft(2, '0')}-'
//         '${now.day.toString().padLeft(2, '0')}';
//     final timestamp =
//         '${now.hour.toString().padLeft(2, '0')}:'
//         '${now.minute.toString().padLeft(2, '0')}:'
//         '${now.second.toString().padLeft(2, '0')}';
//
//     final Map<String, dynamic> body = {
//       'emp_id':               int.tryParse(empId) ?? empId,
//       'emp_name':             empName,
//       'company_code':         companyCode,
//       'amount':               amount,
//       'policy_name':          policyName,
//       'reason':               reason,
//       'request_date':         requestDate,
//       'timestamp':            timestamp,
//       'paid_every':           policyName == 'Custom' ? (paidEvery ?? '')    : '',
//       'installments_amount':  policyName == 'Custom' ? (installmentsAmount ?? '') : '',
//       'status':               'Pending',
//     };
//
//     final response = await http
//         .post(
//       Uri.parse(_submitUrl),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(body),
//     )
//         .timeout(const Duration(seconds: 15));
//
//     if (response.statusCode != 200 && response.statusCode != 201) {
//       throw Exception('Failed to submit request (${response.statusCode})');
//     }
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════════════════
// // Main Screen Widget
// // ═══════════════════════════════════════════════════════════════════════════
// class LoanAdvanceScreen extends StatefulWidget {
//   const LoanAdvanceScreen({super.key});
//
//   @override
//   State<LoanAdvanceScreen> createState() => _LoanAdvanceScreenState();
// }
//
// class _LoanAdvanceScreenState extends State<LoanAdvanceScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   // ── Design Tokens (mapped to AppColors) ──────────────────────────────
//   static const _bgColor     = AppColors.surface;
//   static const _primary     = AppColors.cyan;
//   static const _primaryDark = AppColors.primaryDark;
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _textDark    = AppColors.textPrimary;
//   static const _textGray    = AppColors.textSecondary;
//   static const _errorRed    = AppColors.error;
//
//   // ── Form State ─────────────────────────────────────────────────────────
//   final _reasonController             = TextEditingController();
//   final _amountController             = TextEditingController();
//   final _installmentsAmountController = TextEditingController();
//   LoanPolicy? _selectedPolicy;
//   static const int _maxReason = 300;
//
//   // ── Custom Policy Extra Fields ─────────────────────────────────────────
//   bool    _isCustomPolicy = false;
//   String? _paidEvery;
//
//   // ── Shared Prefs Data ──────────────────────────────────────────────────
//   String _companyCode = '';
//   String _empId       = '';
//   String _empName     = '';
//
//   // ── API State ──────────────────────────────────────────────────────────
//   List<LoanPolicy> _policies     = [];
//   bool             _loadingPolicies = true;
//   String?          _policyError;
//
//   // ── Submit / Reset State ───────────────────────────────────────────────
//   bool _submitPressed = false;
//   bool _resetPressed  = false;
//   bool _submitting    = false;
//
//   // ── Validation ─────────────────────────────────────────────────────────
//   bool _reasonError                = false;
//   bool _amountError                = false;
//   bool _policySelectError          = false;
//   bool _installmentsAmountError    = false;
//   bool _paidEveryError             = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _reasonController.addListener(() => setState(() {}));
//     _loadPrefsAndPolicies();
//   }
//
//   @override
//   void dispose() {
//     _reasonController.dispose();
//     _amountController.dispose();
//     _installmentsAmountController.dispose();
//     super.dispose();
//   }
//
//   // ── Safe pref helpers ──────────────────────────────────────────────────
//   static String? _safeGet(SharedPreferences prefs, String key) {
//     try {
//       final dynamic raw = prefs.get(key);
//       if (raw == null) return null;
//       final String val = raw.toString().trim();
//       return val.isEmpty ? null : val;
//     } catch (_) {
//       return null;
//     }
//   }
//
//   static String _safeGetFallback(SharedPreferences prefs, List<String> keys) {
//     for (final key in keys) {
//       final val = _safeGet(prefs, key);
//       if (val != null) return val;
//     }
//     return '';
//   }
//
//   // ── Load SharedPreferences then fetch policies ─────────────────────────
//   Future<void> _loadPrefsAndPolicies() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       setState(() {
//         _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
//         _empId       = _safeGetFallback(prefs, ['userId',   'emp_id', 'employeeId']);
//         _empName     = _safeGetFallback(prefs, ['userName', 'emp_name', 'empName', 'employee_name', 'name']);
//       });
//       await _fetchPolicies();
//     } catch (e) {
//       setState(() {
//         _policyError     = 'Could not read company info. Tap to retry.';
//         _loadingPolicies = false;
//       });
//     }
//   }
//
//   // ── Fetch Loan Policies from API + append "Custom" ─────────────────────
//   Future<void> _fetchPolicies() async {
//     setState(() {
//       _loadingPolicies = true;
//       _policyError     = null;
//     });
//     try {
//       if (_companyCode.isEmpty) {
//         final prefs  = await SharedPreferences.getInstance();
//         _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
//       }
//       final fetched = await LoanPolicyService.fetchPolicies(
//         companyCode: _companyCode,
//       );
//       setState(() {
//         _policies = [
//           ...fetched,
//           LoanPolicy(policyName: 'Custom', companyCode: _companyCode),
//         ];
//         _loadingPolicies = false;
//       });
//     } catch (e) {
//       setState(() {
//         _policyError     = 'Could not load policies. Tap to retry.';
//         _loadingPolicies = false;
//       });
//     }
//   }
//
//   // ── Reset ──────────────────────────────────────────────────────────────
//   void _reset() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       _reasonController.clear();
//       _amountController.clear();
//       _installmentsAmountController.clear();
//       _selectedPolicy           = null;
//       _isCustomPolicy           = false;
//       _paidEvery                = null;
//       _reasonError              = false;
//       _amountError              = false;
//       _policySelectError        = false;
//       _installmentsAmountError  = false;
//       _paidEveryError           = false;
//     });
//   }
//
//   // ── Submit ─────────────────────────────────────────────────────────────
//   Future<void> _submit() async {
//     HapticFeedback.mediumImpact();
//
//     final reason             = _reasonController.text.trim();
//     final amount             = _amountController.text.trim();
//     final installmentsAmount = _installmentsAmountController.text.trim();
//
//     setState(() {
//       _reasonError             = reason.isEmpty;
//       _amountError             = amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0;
//       _policySelectError       = _selectedPolicy == null;
//       _installmentsAmountError = _isCustomPolicy &&
//           (installmentsAmount.isEmpty ||
//               (int.tryParse(installmentsAmount) ?? 0) <= 0);
//       _paidEveryError          = _isCustomPolicy && _paidEvery == null;
//     });
//
//     if (_reasonError ||
//         _amountError ||
//         _policySelectError ||
//         _installmentsAmountError ||
//         _paidEveryError) return;
//
//     setState(() => _submitting = true);
//
//     try {
//       await LoanSubmitService.submitLoan(
//         empId:               _empId,
//         empName:             _empName,
//         companyCode:         _companyCode,
//         reason:              reason,
//         amount:              int.parse(amount),
//         policyName:          _selectedPolicy!.policyName,
//         paidEvery:           _isCustomPolicy ? _paidEvery           : null,
//         installmentsAmount:  _isCustomPolicy ? installmentsAmount   : null,
//       );
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Loan request submitted successfully!'),
//             backgroundColor: _primary,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Submission failed: ${e.toString()}'),
//             backgroundColor: _errorRed,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12)),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: _bgColor,
//       appBar: Navbar(
//         userName: _empName,
//         userInitials: _empName.trim().split(' ').length >= 2
//             ? '${_empName.trim().split(' ')[0][0]}${_empName.trim().split(' ')[1][0]}'.toUpperCase()
//             : _empName.isNotEmpty ? _empName[0].toUpperCase() : '?',
//         scaffoldKey: _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           physics: const BouncingScrollPhysics(),
//           padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── Back Button + Title ─────────────────────────────────────
//               Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () {
//                       HapticFeedback.lightImpact();
//                       Navigator.pop(context);
//                     },
//                     child: Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: AppColors.cardBg,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: _borderColor),
//                       ),
//                       child: const Icon(
//                         Icons.arrow_back_ios_new_rounded,
//                         size: 16,
//                         color: AppColors.textPrimary,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   const Expanded(
//                     child: Text(
//                       'New Loan / Advance Request',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w800,
//                         color: AppColors.textPrimary,
//                         letterSpacing: -0.4,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//
//               const SizedBox(height: 16),
//               const Divider(color: _borderColor, height: 1),
//               const SizedBox(height: 16),
//
//               // ── Breadcrumb ─────────────────────────────────────
//               _Breadcrumb(),
//
//               const SizedBox(height: 24),
//
//               // ── Reason ─────────────────────────────────────────
//               _FieldLabel(label: 'Reason', required: true),
//               const SizedBox(height: 8),
//               _ReasonField(
//                 controller: _reasonController,
//                 maxLength: _maxReason,
//                 hasError: _reasonError,
//                 onChanged: (_) => setState(() => _reasonError = false),
//               ),
//               const SizedBox(height: 4),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: Text(
//                   '${_reasonController.text.length} / $_maxReason',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: _reasonError ? _errorRed : _textGray,
//                   ),
//                 ),
//               ),
//               if (_reasonError) ...[
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Please enter the reason for your request.',
//                   style: TextStyle(fontSize: 12, color: _errorRed),
//                 ),
//               ],
//
//               const SizedBox(height: 20),
//
//               // ── Amount ─────────────────────────────────────────
//               _FieldLabel(label: 'Amount (PKR)', required: true),
//               const SizedBox(height: 8),
//               _AmountField(
//                 controller: _amountController,
//                 hasError: _amountError,
//                 onChanged: (_) => setState(() => _amountError = false),
//               ),
//               if (_amountError) ...[
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Please enter a valid amount.',
//                   style: TextStyle(fontSize: 12, color: _errorRed),
//                 ),
//               ],
//
//               const SizedBox(height: 20),
//
//               // ── Return Policy label ────────────────────────────
//               Row(
//                 children: [
//                   const Text(
//                     'Return Policy',
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700,
//                       color: _textDark,
//                     ),
//                   ),
//                   const SizedBox(width: 6),
//                   Container(
//                     width: 20,
//                     height: 20,
//                     decoration: BoxDecoration(
//                       color: AppColors.cardBg,
//                       shape: BoxShape.circle,
//                       border: Border.all(color: _borderColor),
//                     ),
//                     child: const Icon(Icons.info_outline_rounded,
//                         size: 13, color: _primary),
//                   ),
//                   const SizedBox(width: 4),
//                   const Text('*',
//                       style: TextStyle(
//                           fontSize: 14,
//                           color: _errorRed,
//                           fontWeight: FontWeight.w700)),
//                 ],
//               ),
//               const SizedBox(height: 8),
//
//               // ── Policy Dropdown ──────────────────────────────────────────
//               _PolicyDropdown(
//                 policies: _policies,
//                 selected: _selectedPolicy,
//                 isLoading: _loadingPolicies,
//                 errorMessage: _policyError,
//                 hasValidationError: _policySelectError,
//                 onRetry: _fetchPolicies,
//                 onChanged: (policy) => setState(() {
//                   _selectedPolicy    = policy;
//                   _policySelectError = false;
//                   _isCustomPolicy    = policy?.policyName == 'Custom';
//                   if (!_isCustomPolicy) {
//                     _installmentsAmountController.clear();
//                     _paidEvery               = null;
//                     _installmentsAmountError = false;
//                     _paidEveryError          = false;
//                   }
//                 }),
//               ),
//
//               if (_policySelectError) ...[
//                 const SizedBox(height: 4),
//                 const Text(
//                   'Please select a return policy.',
//                   style: TextStyle(fontSize: 12, color: _errorRed),
//                 ),
//               ],
//
//               const SizedBox(height: 6),
//               const Text(
//                 'Select how you want this loan or advance to be adjusted.',
//                 style: TextStyle(
//                   fontSize: 12.5,
//                   color: _primary,
//                   fontStyle: FontStyle.italic,
//                   height: 1.4,
//                 ),
//               ),
//
//               // ── Custom Policy Extra Fields ──────────────────────────────
//               AnimatedCrossFade(
//                 duration: const Duration(milliseconds: 280),
//                 crossFadeState: _isCustomPolicy
//                     ? CrossFadeState.showSecond
//                     : CrossFadeState.showFirst,
//                 firstChild: const SizedBox.shrink(),
//                 secondChild: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SizedBox(height: 20),
//
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 10, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: _primary.withOpacity(0.08),
//                             borderRadius: BorderRadius.circular(8),
//                             border: Border.all(
//                                 color: _primary.withOpacity(0.2)),
//                           ),
//                           child: const Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.tune_rounded,
//                                   size: 14, color: _primary),
//                               SizedBox(width: 6),
//                               Text(
//                                 'Custom Settings',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w700,
//                                   color: _primary,
//                                   letterSpacing: 0.3,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         const Expanded(
//                           child: Divider(color: _borderColor, height: 1),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 16),
//
//                     // ── Installments Amount ────────────────────────────────
//                     _FieldLabel(
//                         label: 'Installments Amount', required: true),
//                     const SizedBox(height: 8),
//                     _AmountField(
//                       controller: _installmentsAmountController,
//                       hasError: _installmentsAmountError,
//                       onChanged: (_) => setState(
//                               () => _installmentsAmountError = false),
//                     ),
//                     if (_installmentsAmountError) ...[
//                       const SizedBox(height: 4),
//                       const Text(
//                         'Please enter a valid installment amount.',
//                         style: TextStyle(fontSize: 12, color: _errorRed),
//                       ),
//                     ],
//
//                     const SizedBox(height: 20),
//
//                     // ── Paid Every Dropdown ────────────────────────────────
//                     _FieldLabel(label: 'Paid Every', required: true),
//                     const SizedBox(height: 8),
//                     _PaidEveryDropdown(
//                       value: _paidEvery,
//                       hasValidationError: _paidEveryError,
//                       onChanged: (val) => setState(() {
//                         _paidEvery      = val;
//                         _paidEveryError = false;
//                       }),
//                     ),
//                     if (_paidEveryError) ...[
//                       const SizedBox(height: 4),
//                       const Text(
//                         'Please select a payment frequency.',
//                         style:
//                         TextStyle(fontSize: 12, color: _errorRed),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 28),
//               const Divider(color: _borderColor, height: 1),
//               const SizedBox(height: 20),
//
//               // ── Bottom buttons ───────────────────────────────────────────
//               Row(
//                 children: [
//                   // Reset
//                   Expanded(
//                     flex: 4,
//                     child: GestureDetector(
//                       onTapDown: (_) {
//                         HapticFeedback.lightImpact();
//                         setState(() => _resetPressed = true);
//                       },
//                       onTapUp: (_) => setState(() => _resetPressed = false),
//                       onTapCancel: () =>
//                           setState(() => _resetPressed = false),
//                       onTap: _reset,
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 100),
//                         height: 52,
//                         decoration: BoxDecoration(
//                           color: _resetPressed
//                               ? AppColors.cyanMid
//                               : AppColors.cardBg,
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                               color: _borderColor, width: 1.5),
//                         ),
//                         child: const Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.replay_rounded,
//                                 color: _textDark, size: 18),
//                             SizedBox(width: 8),
//                             Text('Reset',
//                                 style: TextStyle(
//                                     color: _textDark,
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.w700)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(width: 12),
//
//                   // Submit
//                   Expanded(
//                     flex: 6,
//                     child: GestureDetector(
//                       onTapDown: (_) {
//                         if (_submitting) return;
//                         HapticFeedback.lightImpact();
//                         setState(() => _submitPressed = true);
//                       },
//                       onTapUp: (_) =>
//                           setState(() => _submitPressed = false),
//                       onTapCancel: () =>
//                           setState(() => _submitPressed = false),
//                       onTap: _submitting ? null : _submit,
//                       child: AnimatedContainer(
//                         duration: const Duration(milliseconds: 100),
//                         height: 52,
//                         decoration: BoxDecoration(
//                           color: _submitPressed ? _primaryDark : _primary,
//                           borderRadius: BorderRadius.circular(16),
//                           boxShadow: _submitPressed
//                               ? []
//                               : [
//                             BoxShadow(
//                               color: _primary.withOpacity(0.35),
//                               blurRadius: 14,
//                               offset: const Offset(0, 5),
//                             ),
//                           ],
//                         ),
//                         child: _submitting
//                             ? const Center(
//                           child: SizedBox(
//                             width: 22,
//                             height: 22,
//                             child: CircularProgressIndicator(
//                               color: AppColors.textOnDark,
//                               strokeWidth: 2.5,
//                             ),
//                           ),
//                         )
//                             : const Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.send_rounded,
//                                 color: AppColors.textOnDark, size: 18),
//                             SizedBox(width: 8),
//                             Text('Submit',
//                                 style: TextStyle(
//                                     color: AppColors.textOnDark,
//                                     fontSize: 15,
//                                     fontWeight: FontWeight.w700,
//                                     letterSpacing: 0.2)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════════════════
// // Helper Widgets
// // ═══════════════════════════════════════════════════════════════════════════
//
// class _Breadcrumb extends StatelessWidget {
//   static const _primary     = AppColors.cyan;
//   static const _borderColor = AppColors.divider;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _borderColor),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           _crumb('Requests', isActive: false),
//           _chevron(),
//           _crumb('Request', isActive: false),
//           _chevron(),
//           _crumb('Loan / Advance', isActive: true),
//         ],
//       ),
//     );
//   }
//
//   Widget _crumb(String label, {required bool isActive}) => Text(
//     label,
//     style: TextStyle(
//       fontSize: 12.5,
//       fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
//       color: isActive ? _primary : AppColors.textSecondary,
//     ),
//   );
//
//   Widget _chevron() => const Padding(
//     padding: EdgeInsets.symmetric(horizontal: 6),
//     child: Icon(Icons.chevron_right_rounded,
//         size: 14, color: AppColors.textSecondary),
//   );
// }
//
// class _FieldLabel extends StatelessWidget {
//   final String label;
//   final bool required;
//   const _FieldLabel({required this.label, this.required = false});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Text(label,
//             style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.textPrimary)),
//         if (required) ...[
//           const SizedBox(width: 4),
//           const Text('*',
//               style: TextStyle(
//                   fontSize: 14,
//                   color: AppColors.error,
//                   fontWeight: FontWeight.w700)),
//         ],
//       ],
//     );
//   }
// }
//
// class _ReasonField extends StatelessWidget {
//   final TextEditingController controller;
//   final int maxLength;
//   final bool hasError;
//   final ValueChanged<String> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _ReasonField({
//     required this.controller,
//     required this.maxLength,
//     required this.hasError,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: _fieldBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//             color: hasError ? _errorRed : _borderColor,
//             width: hasError ? 1.5 : 1),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: TextField(
//           controller: controller,
//           maxLines: 5,
//           maxLength: maxLength,
//           onChanged: onChanged,
//           style: const TextStyle(
//               fontSize: 15, color: AppColors.textPrimary, height: 1.5),
//           decoration: const InputDecoration(
//             hintText: 'Purpose of loan / advance',
//             hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
//             contentPadding: EdgeInsets.all(16),
//             border: InputBorder.none,
//             counterText: '',
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _AmountField extends StatelessWidget {
//   final TextEditingController controller;
//   final bool hasError;
//   final ValueChanged<String> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _AmountField({
//     required this.controller,
//     required this.hasError,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 54,
//       decoration: BoxDecoration(
//         color: _fieldBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//             color: hasError ? _errorRed : _borderColor,
//             width: hasError ? 1.5 : 1),
//       ),
//       alignment: Alignment.center,
//       child: Material(
//         color: Colors.transparent,
//         child: TextField(
//           controller: controller,
//           keyboardType: TextInputType.number,
//           inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//           onChanged: onChanged,
//           textAlign: TextAlign.center,
//           style: const TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.w600,
//               color: AppColors.textSecondary,
//               letterSpacing: 0.5),
//           decoration: const InputDecoration(
//             hintText: '0',
//             hintStyle: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textSecondary),
//             contentPadding: EdgeInsets.symmetric(horizontal: 16),
//             border: InputBorder.none,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _PolicyDropdown extends StatelessWidget {
//   final List<LoanPolicy> policies;
//   final LoanPolicy? selected;
//   final bool isLoading;
//   final String? errorMessage;
//   final bool hasValidationError;
//   final VoidCallback onRetry;
//   final ValueChanged<LoanPolicy?> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//   static const _primary     = AppColors.cyan;
//
//   const _PolicyDropdown({
//     required this.policies,
//     required this.selected,
//     required this.isLoading,
//     required this.errorMessage,
//     required this.hasValidationError,
//     required this.onRetry,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (isLoading) {
//       return _shell(
//         child: const Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 18,
//               height: 18,
//               child: CircularProgressIndicator(
//                   strokeWidth: 2, color: _primary),
//             ),
//             SizedBox(width: 10),
//             Text('Loading policies...',
//                 style:
//                 TextStyle(fontSize: 14, color: AppColors.textSecondary)),
//           ],
//         ),
//       );
//     }
//
//     if (errorMessage != null) {
//       return GestureDetector(
//         onTap: onRetry,
//         child: _shell(
//           borderColor: _errorRed,
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.refresh_rounded, color: _errorRed, size: 18),
//               const SizedBox(width: 8),
//               Flexible(
//                 child: Text(errorMessage!,
//                     style: const TextStyle(
//                         fontSize: 13, color: _errorRed)),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return _shell(
//       borderColor: hasValidationError ? _errorRed : _borderColor,
//       child: Material(
//         color: Colors.transparent,
//         child: DropdownButtonHideUnderline(
//           child: DropdownButton<LoanPolicy>(
//             value: selected,
//             isExpanded: true,
//             icon: const Icon(Icons.keyboard_arrow_down_rounded,
//                 color: AppColors.textSecondary),
//             hint: const Text('Select return policy',
//                 style: TextStyle(
//                     fontSize: 15,
//                     color: AppColors.textSecondary,
//                     fontWeight: FontWeight.w500)),
//             style: const TextStyle(
//                 fontSize: 15,
//                 color: AppColors.textPrimary,
//                 fontWeight: FontWeight.w600),
//             dropdownColor: AppColors.cardBg,
//             borderRadius: BorderRadius.circular(14),
//             onChanged: onChanged,
//             items: policies.map((p) {
//               final isCustom = p.policyName == 'Custom';
//               return DropdownMenuItem<LoanPolicy>(
//                 value: p,
//                 child: Row(
//                   children: [
//                     if (isCustom) ...[
//                       const Icon(Icons.tune_rounded,
//                           size: 16, color: _primary),
//                       const SizedBox(width: 6),
//                     ],
//                     Text(p.policyName),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _shell(
//       {required Widget child, Color borderColor = _borderColor}) {
//     return Container(
//       height: 54,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: _fieldBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: borderColor, width: 1.2),
//       ),
//       alignment: Alignment.center,
//       child: child,
//     );
//   }
// }
//
// // ── Paid Every Dropdown ────────────────────────────────────────────────────
// class _PaidEveryDropdown extends StatelessWidget {
//   final String? value;
//   final bool hasValidationError;
//   final ValueChanged<String?> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//   static const _primary     = AppColors.cyan;
//
//   const _PaidEveryDropdown({
//     required this.value,
//     required this.hasValidationError,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 54,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: BoxDecoration(
//         color: _fieldBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//           color: hasValidationError ? _errorRed : _borderColor,
//           width: hasValidationError ? 1.5 : 1.2,
//         ),
//       ),
//       alignment: Alignment.center,
//       child: Material(
//         color: Colors.transparent,
//         child: DropdownButtonHideUnderline(
//           child: DropdownButton<String>(
//             value: value,
//             isExpanded: true,
//             icon: const Icon(Icons.keyboard_arrow_down_rounded,
//                 color: AppColors.textSecondary),
//             hint: const Text('Select frequency',
//                 style: TextStyle(
//                     fontSize: 15,
//                     color: AppColors.textSecondary,
//                     fontWeight: FontWeight.w500)),
//             style: const TextStyle(
//                 fontSize: 15,
//                 color: AppColors.textPrimary,
//                 fontWeight: FontWeight.w600),
//             dropdownColor: AppColors.cardBg,
//             borderRadius: BorderRadius.circular(14),
//             onChanged: onChanged,
//             items: _paidEveryOptions.map((option) {
//               IconData icon;
//               switch (option) {
//                 case 'Week':
//                   icon = Icons.view_week_rounded;
//                   break;
//                 case 'Month':
//                   icon = Icons.calendar_month_rounded;
//                   break;
//                 case 'Quarter':
//                   icon = Icons.date_range_rounded;
//                   break;
//                 default:
//                   icon = Icons.schedule_rounded;
//               }
//               return DropdownMenuItem<String>(
//                 value: option,
//                 child: Row(
//                   children: [
//                     Icon(icon, size: 16, color: _primary),
//                     const SizedBox(width: 8),
//                     Text(option),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';
import '../../constants.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';

// ═══════════════════════════════════════════════════════════════════════════
// loan_advance_screen.dart
//
// New Loan / Advance Request — Full Screen
// Reads companyCode, empId, empName automatically from SharedPreferences.
// ═══════════════════════════════════════════════════════════════════════════

// ── Loan Type Options ─────────────────────────────────────────────────────
enum LoanType {
  advanceSalary,
  installments,
}

const Map<LoanType, String> loanTypeLabels = {
  LoanType.advanceSalary: 'Advance Salary',
  LoanType.installments: 'Installments',
};

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
class LoanSubmitService {
  static const _submitUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/loanrequest/post/';

  static Future<void> submitLoan({
    required String empId,
    required String empName,
    required String companyCode,
    required String reason,
    required int amount,
    required String loanType,
    required int numInstallments,
    required String startMonth, // Format: MON-YYYY
    required int installmentAmount,
  }) async {
    final now = DateTime.now();
    final requestDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final Map<String, dynamic> body = {
      'emp_id': int.tryParse(empId) ?? empId,
      'emp_name': empName,
      'company_code': companyCode,
      'amount': amount,
      'policy_name': loanType == 'Advance Salary' ? 'Advance Salary' : 'Installments',
      'reason': reason,
      'request_date': requestDate,
      'timestamp': timestamp,
      'installments_amount': installmentAmount,
      'status': 'Pending',
      'loan_type': loanType,
      'num_instamments': numInstallments,
      'start_month': startMonth,
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Design Tokens ──────────────────────────────────────────────────────
  static const _bgColor = AppColors.surface;
  static const _primary = AppColors.cyan;
  static const _primaryDark = AppColors.primaryDark;
  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _textDark = AppColors.textPrimary;
  static const _textGray = AppColors.textSecondary;
  static const _errorRed = AppColors.error;
  static const _successGreen = Color(0xFF16A34A);

  // ── Form State ─────────────────────────────────────────────────────────
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _numInstallmentsController = TextEditingController();

  LoanType? _selectedLoanType;
  String? _selectedStartMonth;

  static const int _maxReason = 300;

  // ── Shared Prefs Data ──────────────────────────────────────────────────
  String _companyCode = '';
  String _empId = '';
  String _empName = '';

  // ── API State ──────────────────────────────────────────────────────────
  List<LoanPolicy> _policies = [];
  bool _loadingPolicies = true;
  String? _policyError;

  // ── Submit / Reset State ───────────────────────────────────────────────
  bool _submitPressed = false;
  bool _resetPressed = false;
  bool _submitting = false;

  // ── Validation ─────────────────────────────────────────────────────────
  bool _reasonError = false;
  bool _amountError = false;
  bool _loanTypeError = false;
  bool _numInstallmentsError = false;
  bool _installmentAmountError = false;
  bool _startMonthError = false;
  String? _totalMismatchError;

  // ── Month Lists ────────────────────────────────────────────────────────
  late final List<String> _monthLabels;
  late final List<String> _yearLabels;

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {
      _clearTotalMismatch();
      _autoFillInstallmentFields();
    }));
    _numInstallmentsController.addListener(() => setState(() {
      _clearTotalMismatch();
    }));
    _installmentAmountController.addListener(() => setState(() {
      _clearTotalMismatch();
    }));

    _monthLabels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final currentYear = DateTime.now().year;
    _yearLabels = [
      (currentYear - 1).toString(),
      currentYear.toString(),
      (currentYear + 1).toString(),
    ];

    _loadPrefsAndPolicies();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _installmentAmountController.dispose();
    _numInstallmentsController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  void _clearTotalMismatch() {
    if (_totalMismatchError != null) {
      setState(() => _totalMismatchError = null);
    }
  }

  void _autoFillInstallmentFields() {
    if (_selectedLoanType == LoanType.advanceSalary) {
      final amount = _amountController.text.trim();
      if (amount.isNotEmpty) {
        final parsed = int.tryParse(amount);
        if (parsed != null && parsed > 0) {
          _installmentAmountController.text = amount;
          _numInstallmentsController.text = '1';
        }
      }
    }
  }

  // ── Safe pref helpers ──────────────────────────────────────────────────
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
        _empId = _safeGetFallback(prefs, ['userId', 'emp_id', 'employeeId']);
        _empName = _safeGetFallback(prefs, [
          'userName',
          'emp_name',
          'empName',
          'employee_name',
          'name'
        ]);
      });
      await _fetchPolicies();
    } catch (e) {
      setState(() {
        _policyError = 'Could not read company info. Tap to retry.';
        _loadingPolicies = false;
      });
    }
  }

  // ── Fetch Loan Policies from API ─────────────────────────────────────
  Future<void> _fetchPolicies() async {
    setState(() {
      _loadingPolicies = true;
      _policyError = null;
    });
    try {
      if (_companyCode.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
      }
      final fetched = await LoanPolicyService.fetchPolicies(
        companyCode: _companyCode,
      );
      setState(() {
        _policies = fetched;
        _loadingPolicies = false;
      });
    } catch (e) {
      setState(() {
        _policyError = 'Could not load policies. Tap to retry.';
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
      _installmentAmountController.clear();
      _numInstallmentsController.clear();
      _selectedLoanType = null;
      _selectedStartMonth = null;
      _totalMismatchError = null;
      _reasonError = false;
      _amountError = false;
      _loanTypeError = false;
      _numInstallmentsError = false;
      _installmentAmountError = false;
      _startMonthError = false;
    });
  }

  // ── Validate Total Amount ─────────────────────────────────────────────
  bool _validateTotalAmount() {
    if (_selectedLoanType != LoanType.installments) return true;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final numInstallments = int.tryParse(_numInstallmentsController.text.trim()) ?? 0;
    final installmentAmount = int.tryParse(_installmentAmountController.text.trim()) ?? 0;

    if (amount > 0 && numInstallments > 0 && installmentAmount > 0) {
      final total = numInstallments * installmentAmount;
      if (total != amount) {
        setState(() {
          _totalMismatchError =
          'Total installment amount ($numInstallments × $installmentAmount = $total) does not match the loan amount ($amount)';
        });
        return false;
      }
    }
    return true;
  }

  // ── Get available months based on loan type ────────────────────────────
  List<String> _getAvailableMonths() {
    final now = DateTime.now();
    final currentMonthIndex = now.month - 1;
    final currentYear = now.year;

    final months = <String>[];
    int maxMonths = _selectedLoanType == LoanType.advanceSalary ? 2 : 3;

    for (int i = 0; i < maxMonths; i++) {
      final monthIndex = (currentMonthIndex + i) % 12;
      final yearOffset = (currentMonthIndex + i) ~/ 12;
      final year = currentYear + yearOffset;
      months.add('${_monthLabels[monthIndex]}-$year');
    }

    return months;
  }

  // ── Submit ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    HapticFeedback.mediumImpact();

    final reason = _reasonController.text.trim();
    final amount = _amountController.text.trim();
    final installmentAmount = _installmentAmountController.text.trim();
    final numInstallments = _numInstallmentsController.text.trim();

    // Clear previous total mismatch error
    _totalMismatchError = null;

    setState(() {
      _reasonError = reason.isEmpty;
      _amountError = amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0;
      _loanTypeError = _selectedLoanType == null;
      _startMonthError = _selectedStartMonth == null;

      if (_selectedLoanType == LoanType.installments) {
        _numInstallmentsError =
            numInstallments.isEmpty || (int.tryParse(numInstallments) ?? 0) <= 0;
        _installmentAmountError =
            installmentAmount.isEmpty || (int.tryParse(installmentAmount) ?? 0) <= 0;
      } else {
        _numInstallmentsError = false;
        _installmentAmountError = false;
      }
    });

    // If any validation error, return
    if (_reasonError ||
        _amountError ||
        _loanTypeError ||
        _startMonthError ||
        _numInstallmentsError ||
        _installmentAmountError) {
      return;
    }

    // Validate total amount for installments
    if (_selectedLoanType == LoanType.installments) {
      if (!_validateTotalAmount()) {
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      final amountInt = int.parse(amount);
      final installmentAmountInt = _selectedLoanType == LoanType.advanceSalary
          ? amountInt
          : int.parse(installmentAmount);
      final numInstallmentsInt = _selectedLoanType == LoanType.advanceSalary
          ? 1
          : int.parse(numInstallments);

      await LoanSubmitService.submitLoan(
        empId: _empId,
        empName: _empName,
        companyCode: _companyCode,
        reason: reason,
        amount: amountInt,
        loanType: _selectedLoanType == LoanType.advanceSalary
            ? 'Advance Salary'
            : 'Installments',
        numInstallments: numInstallmentsInt,
        startMonth: _selectedStartMonth!,
        installmentAmount: installmentAmountInt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Loan request submitted successfully!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
              borderRadius: BorderRadius.circular(12),
            ),
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgColor,
      appBar: Navbar(
        userName: _empName,
        userInitials: _empName.trim().split(' ').length >= 2
            ? '${_empName.trim().split(' ')[0][0]}${_empName.trim().split(' ')[1][0]}'
            .toUpperCase()
            : _empName.isNotEmpty
            ? _empName[0].toUpperCase()
            : '?',
        scaffoldKey: _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back Button + Title ─────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'New Loan / Advance Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: _borderColor, height: 1),
              const SizedBox(height: 16),

              // ── Breadcrumb ──────────────────────────────────────────────
              _Breadcrumb(),

              const SizedBox(height: 24),

              // ── Loan Type Dropdown ──────────────────────────────────────
              _FieldLabel(label: 'Loan Type', required: true),
              const SizedBox(height: 8),
              _LoanTypeDropdown(
                selectedType: _selectedLoanType,
                hasError: _loanTypeError,
                onChanged: (type) => setState(() {
                  _selectedLoanType = type;
                  _loanTypeError = false;
                  _totalMismatchError = null;
                  _selectedStartMonth = null;
                  _startMonthError = false;
                  // Auto-fill for Advance Salary
                  if (type == LoanType.advanceSalary) {
                    _autoFillInstallmentFields();
                  } else {
                    _installmentAmountController.clear();
                    _numInstallmentsController.clear();
                  }
                }),
              ),
              if (_loanTypeError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Please select a loan type.',
                  style: TextStyle(fontSize: 12, color: _errorRed),
                ),
              ],

              const SizedBox(height: 20),

              // ── Amount ──────────────────────────────────────────────────
              _FieldLabel(label: 'Amount (PKR)', required: true),
              const SizedBox(height: 8),
              _AmountField(
                controller: _amountController,
                hasError: _amountError,
                onChanged: (_) => setState(() {
                  _amountError = false;
                  if (_selectedLoanType == LoanType.advanceSalary) {
                    _autoFillInstallmentFields();
                  }
                }),
              ),
              if (_amountError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Please enter a valid amount.',
                  style: TextStyle(fontSize: 12, color: _errorRed),
                ),
              ],

              const SizedBox(height: 20),

              // ── Reason ──────────────────────────────────────────────────
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

              // ── Installment Fields (only for Installments) ─────────────
              if (_selectedLoanType == LoanType.installments) ...[
                // Number of Installments
                _FieldLabel(label: 'Number of Installments', required: true),
                const SizedBox(height: 8),
                _NumInstallmentsField(
                  controller: _numInstallmentsController,
                  hasError: _numInstallmentsError,
                  onChanged: (_) => setState(() {
                    _numInstallmentsError = false;
                    _clearTotalMismatch();
                  }),
                ),
                if (_numInstallmentsError) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Please enter a valid number of installments.',
                    style: TextStyle(fontSize: 12, color: _errorRed),
                  ),
                ],

                const SizedBox(height: 20),

                // Installment Amount
                _FieldLabel(label: 'Installment Amount (PKR)', required: true),
                const SizedBox(height: 8),
                _InstallmentAmountField(
                  controller: _installmentAmountController,
                  hasError: _installmentAmountError,
                  onChanged: (_) => setState(() {
                    _installmentAmountError = false;
                    _clearTotalMismatch();
                  }),
                ),
                if (_installmentAmountError) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Please enter a valid installment amount.',
                    style: TextStyle(fontSize: 12, color: _errorRed),
                  ),
                ],

                // Total Mismatch Error
                if (_totalMismatchError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _errorRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _errorRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 18, color: _errorRed),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _totalMismatchError!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _errorRed,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],

              // ── Start Month ─────────────────────────────────────────────
              _FieldLabel(
                label: _selectedLoanType == LoanType.installments
                    ? 'Deduction Start Month'
                    : 'Select Month',
                required: true,
              ),
              const SizedBox(height: 8),
              _StartMonthDropdown(
                selectedMonth: _selectedStartMonth,
                hasError: _startMonthError,
                availableMonths: _getAvailableMonths(),
                onChanged: (month) => setState(() {
                  _selectedStartMonth = month;
                  _startMonthError = false;
                }),
                loanType: _selectedLoanType,
              ),
              if (_startMonthError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Please select a start month.',
                  style: TextStyle(fontSize: 12, color: _errorRed),
                ),
              ],

              const SizedBox(height: 28),
              const Divider(color: _borderColor, height: 1),
              const SizedBox(height: 20),

              // ── Bottom buttons ───────────────────────────────────────────
              Row(
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
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded,
                                color: AppColors.textOnDark,
                                size: 18),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _Breadcrumb extends StatelessWidget {
  static const _primary = AppColors.cyan;
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

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;

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

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;

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

// ── Loan Type Dropdown ────────────────────────────────────────────────────
class _LoanTypeDropdown extends StatelessWidget {
  final LoanType? selectedType;
  final bool hasError;
  final ValueChanged<LoanType> onChanged;

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;
  static const _primary = AppColors.cyan;

  const _LoanTypeDropdown({
    required this.selectedType,
    required this.hasError,
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
          color: hasError ? _errorRed : _borderColor,
          width: hasError ? 1.5 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<LoanType>(
            value: selectedType,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
            hint: const Text(
              'Select loan type',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            dropdownColor: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            items: LoanType.values.map((type) {
              return DropdownMenuItem<LoanType>(
                value: type,
                child: Row(
                  children: [
                    Icon(
                      type == LoanType.advanceSalary
                          ? Icons.attach_money_rounded
                          : Icons.calendar_month_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    const SizedBox(width: 10),
                    Text(loanTypeLabels[type]!),
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

// ── Number of Installments Field ──────────────────────────────────────────
class _NumInstallmentsField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;

  const _NumInstallmentsField({
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
          width: hasError ? 1.5 : 1.2,
        ),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter number of installments',
            hintStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ── Installment Amount Field ──────────────────────────────────────────────
class _InstallmentAmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;

  const _InstallmentAmountField({
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
          width: hasError ? 1.5 : 1.2,
        ),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter installment amount',
            hintStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ── Start Month Dropdown ──────────────────────────────────────────────────
class _StartMonthDropdown extends StatelessWidget {
  final String? selectedMonth;
  final bool hasError;
  final List<String> availableMonths;
  final ValueChanged<String> onChanged;
  final LoanType? loanType;

  static const _fieldBg = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed = AppColors.error;
  static const _primary = AppColors.cyan;

  const _StartMonthDropdown({
    required this.selectedMonth,
    required this.hasError,
    required this.availableMonths,
    required this.onChanged,
    this.loanType,
  });

  @override
  Widget build(BuildContext context) {
    final hintText = loanType == LoanType.installments
        ? 'Select Deduction Start Month'
        : 'Select Month';

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? _errorRed : _borderColor,
          width: hasError ? 1.5 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedMonth,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary),
            hint: Text(
              hintText,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            dropdownColor: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            items: availableMonths.map((month) {
              return DropdownMenuItem<String>(
                value: month,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: _primary),
                    const SizedBox(width: 10),
                    Text(month),
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