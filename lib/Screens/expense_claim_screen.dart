// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../AppColors.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════
// // expense_claim_screen.dart
// //
// // New Expense Claim Request — Bottom Sheet Screen
// // Reads companyCode, empId, empName automatically from SharedPreferences.
// //
// // USAGE — in actions_screen.dart inside _ActionCardWidgetState onTap:
// //
// //   onTap: () {
// //     if (card.title == 'Expense Claim') {
// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(builder: (_) => const ExpenseClaimScreen()),
// //       );
// //     }
// //   },
// // ═══════════════════════════════════════════════════════════════════════════
//
// // ── Claim Period Type options ───────────────────────────────────────────────
// const List<String> _claimPeriodOptions = [
//   'Date Based',
//   'Time Based',
//   'Mileage Base',
// ];
//
// // ── POST Service ────────────────────────────────────────────────────────────
// class ExpenseClaimSubmitService {
//   static const _submitUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/expense/post/';
//
//   static Future<void> submitClaim({
//     required String empId,
//     required String empName,
//     required String companyCode,
//     required String expenseType,
//     required String claimPeriodType,
//     required int amount,
//     required String description,
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
//       'emp_id':       empId,          // VARCHAR2(50) — String
//       'emp_name':     empName,
//       'company_code': companyCode,
//       'expense_type': expenseType,
//       'claim_period': claimPeriodType,
//       'amount':       amount,
//       'description':  description.length > 255
//           ? description.substring(0, 255)
//           : description,
//       'request_date': requestDate,
//       'timestamp':    timestamp,
//       'status':       'Pending',
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
//       throw Exception('Failed to submit claim (${response.statusCode})');
//     }
//   }
// }
//
// // ── Expense Type GET Service ────────────────────────────────────────────────
// class ExpenseTypeService {
//   static const _url =
//       'http://oracle.metaxperts.net/ords/gps_workforce/expensetype/get/';
//
//   static Future<List<String>> fetchTypes(String companyCode) async {
//     if (companyCode.isEmpty) return [];
//     final uri = Uri.parse(_url)
//         .replace(queryParameters: {'company_code': companyCode});
//     final response = await http.get(
//       uri,
//       headers: {'Accept': 'application/json'},
//     ).timeout(const Duration(seconds: 15));
//     if (response.statusCode != 200) {
//       throw Exception('Failed to load expense types (${response.statusCode})');
//     }
//     final data = jsonDecode(response.body);
//     final List<dynamic> items =
//     data is List ? data : ((data['items'] ?? []) as List<dynamic>);
//     return items
//         .map<String>((item) => (item['expense_name'] ?? '').toString().trim())
//         .where((name) => name.isNotEmpty)
//         .toList();
//   }
// }
//
// // ═══════════════════════════════════════════════════════════════════════════
// // Main Screen Widget
// // ═══════════════════════════════════════════════════════════════════════════
// class ExpenseClaimScreen extends StatefulWidget {
//   const ExpenseClaimScreen({super.key});
//
//   @override
//   State<ExpenseClaimScreen> createState() => _ExpenseClaimScreenState();
// }
//
// class _ExpenseClaimScreenState extends State<ExpenseClaimScreen> {
//   // ── Design Tokens  (mapped to AppColors) ──────────────────────────────
//   static const _bgColor     = AppColors.surface;
//   static const _primary     = AppColors.cyan;
//   static const _primaryDark = AppColors.primaryDark;
//   static const _borderColor = AppColors.divider;
//   static const _textDark    = AppColors.textPrimary;
//   static const _textGray    = AppColors.textSecondary;
//   static const _errorRed    = AppColors.error;
//
//   // ── Expense Types (loaded from API) ───────────────────────────────────
//   List<String> _expenseTypeOptions  = [];
//   bool         _loadingExpenseTypes = true;
//
//   // ── Form State ─────────────────────────────────────────────────────────
//   final _descriptionController = TextEditingController();
//   final _amountController      = TextEditingController();
//   static const int _maxDescription = 300;
//
//   // ── Date Based controllers ─────────────────────────────────────────────
//   final _fromDateController = TextEditingController();
//   final _toDateController   = TextEditingController();
//   DateTime? _fromDate;
//   DateTime? _toDate;
//
//   // ── Time Based controllers ─────────────────────────────────────────────
//   final _tbDateController   = TextEditingController();
//   final _fromTimeController = TextEditingController();
//   final _toTimeController   = TextEditingController();
//   DateTime?  _tbDate;
//   TimeOfDay? _fromTime;
//   TimeOfDay? _toTime;
//
//   // ── Mileage Base controllers ───────────────────────────────────────────
//   final _kilometersController   = TextEditingController();
//   final _fromLocationController = TextEditingController();
//   final _toLocationController   = TextEditingController();
//   final _purposeController      = TextEditingController();
//
//   String? _selectedExpenseType;
//   String? _selectedClaimPeriod;
//
//   // ── Shared Prefs Data ──────────────────────────────────────────────────
//   String _companyCode = '';
//   String _empId       = '';
//   String _empName     = '';
//
//   // ── Submit / Reset State ───────────────────────────────────────────────
//   bool _submitPressed = false;
//   bool _resetPressed  = false;
//   bool _submitting    = false;
//
//   // ── Validation ─────────────────────────────────────────────────────────
//   bool _descriptionError    = false;
//   bool _amountError         = false;
//   bool _expenseTypeError    = false;
//   bool _claimPeriodError    = false;
//   // Date Based
//   bool _fromDateError       = false;
//   bool _toDateError         = false;
//   // Time Based
//   bool _tbDateError         = false;
//   bool _fromTimeError       = false;
//   bool _toTimeError         = false;
//   // Mileage Base
//   bool _kilometersError     = false;
//   bool _fromLocationError   = false;
//   bool _toLocationError     = false;
//   bool _purposeError        = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _descriptionController.addListener(() => setState(() {}));
//     _purposeController.addListener(() => setState(() {}));
//     _loadPrefs();
//   }
//
//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     _amountController.dispose();
//     _fromDateController.dispose();
//     _toDateController.dispose();
//     _tbDateController.dispose();
//     _fromTimeController.dispose();
//     _toTimeController.dispose();
//     _kilometersController.dispose();
//     _fromLocationController.dispose();
//     _toLocationController.dispose();
//     _purposeController.dispose();
//     super.dispose();
//   }
//
//   // ── Safe pref helpers (same pattern as loan_advance_screen) ────────────
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
//   // ── Load SharedPreferences ─────────────────────────────────────────────
//   Future<void> _loadPrefs() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
//       setState(() {
//         _companyCode = companyCode;
//         _empId       = _safeGetFallback(prefs, ['userId', 'emp_id', 'employeeId']);
//         _empName     = _safeGetFallback(prefs, ['userName', 'emp_name', 'empName', 'employee_name', 'name']);
//       });
//       await _fetchExpenseTypes(companyCode);
//     } catch (_) {
//       if (mounted) setState(() => _loadingExpenseTypes = false);
//     }
//   }
//
//   // ── Fetch Expense Types from API ───────────────────────────────────────
//   Future<void> _fetchExpenseTypes(String companyCode) async {
//     try {
//       final types = await ExpenseTypeService.fetchTypes(companyCode);
//       if (mounted) {
//         setState(() {
//           _expenseTypeOptions  = types;
//           _loadingExpenseTypes = false;
//         });
//       }
//     } catch (_) {
//       if (mounted) setState(() => _loadingExpenseTypes = false);
//     }
//   }
//
//   // ── Reset ──────────────────────────────────────────────────────────────
//   void _reset() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       _descriptionController.clear();
//       _amountController.clear();
//       _selectedExpenseType  = null;
//       _selectedClaimPeriod  = null;
//       _descriptionError     = false;
//       _amountError          = false;
//       _expenseTypeError     = false;
//       _claimPeriodError     = false;
//       // Date Based
//       _fromDateController.clear(); _toDateController.clear();
//       _fromDate = null; _toDate = null;
//       _fromDateError = false; _toDateError = false;
//       // Time Based
//       _tbDateController.clear(); _fromTimeController.clear(); _toTimeController.clear();
//       _tbDate = null; _fromTime = null; _toTime = null;
//       _tbDateError = false; _fromTimeError = false; _toTimeError = false;
//       // Mileage Base
//       _kilometersController.clear(); _fromLocationController.clear();
//       _toLocationController.clear(); _purposeController.clear();
//       _kilometersError = false; _fromLocationError = false;
//       _toLocationError = false; _purposeError = false;
//     });
//   }
//
//   // ── Submit ─────────────────────────────────────────────────────────────
//   // ── Submit ─────────────────────────────────────────────────────────────
//   // ── Submit ─────────────────────────────────────────────────────────────
//   Future<void> _submit() async {
//     HapticFeedback.mediumImpact();
//
//     final description = _descriptionController.text.trim();
//     final amount = _amountController.text.trim();
//
//     final bool isDateBased = _selectedClaimPeriod == 'Date Based';
//     final bool isTimeBased = _selectedClaimPeriod == 'Time Based';
//     final bool isMileageBase = _selectedClaimPeriod == 'Mileage Base';
//     final km = _kilometersController.text.trim();
//
//     setState(() {
//       _expenseTypeError = _selectedExpenseType == null;
//       _claimPeriodError = _selectedClaimPeriod == null;
//       _amountError = !isMileageBase && (amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0);
//       _descriptionError = !isMileageBase && description.isEmpty;
//       _fromDateError = isDateBased && _fromDate == null;
//       _toDateError = isDateBased && _toDate == null;
//       _tbDateError = isTimeBased && _tbDate == null;
//       _fromTimeError = isTimeBased && _fromTime == null;
//       _toTimeError = isTimeBased && _toTime == null;
//       _kilometersError = isMileageBase && (km.isEmpty || (int.tryParse(km) ?? 0) <= 0);
//       _fromLocationError = isMileageBase && _fromLocationController.text.trim().isEmpty;
//       _toLocationError = isMileageBase && _toLocationController.text.trim().isEmpty;
//       _purposeError = isMileageBase && _purposeController.text.trim().isEmpty;
//     });
//
//     if (_expenseTypeError || _claimPeriodError || _amountError || _descriptionError ||
//         _fromDateError || _toDateError || _tbDateError || _fromTimeError || _toTimeError ||
//         _kilometersError || _fromLocationError || _toLocationError || _purposeError) return;
//
//     setState(() => _submitting = true);
//
//     try {
//       final int submitAmount;
//       String submitDescription;
//
//       if (isMileageBase) {
//         submitAmount = int.parse(km);
//         // For mileage, combine location and purpose into description
//         submitDescription =
//         'From:${_fromLocationController.text.trim()}|'
//             'To:${_toLocationController.text.trim()}|'
//             'Purpose:${_purposeController.text.trim()}';
//       } else {
//         // For Date Based and Time Based - ONLY use the user's description
//         submitAmount = int.parse(amount);
//         submitDescription = description;
//       }
//
//       // Truncate if needed
//       if (submitDescription.length > 255) {
//         submitDescription = submitDescription.substring(0, 255);
//       }
//
//       await ExpenseClaimSubmitService.submitClaim(
//         empId: _empId,
//         empName: _empName,
//         companyCode: _companyCode,
//         expenseType: _selectedExpenseType!,
//         claimPeriodType: _selectedClaimPeriod!,
//         amount: submitAmount,
//         description: submitDescription,
//       );
//
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Expense claim submitted successfully!'),
//             backgroundColor: _primary,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
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
//               borderRadius: BorderRadius.circular(12),
//             ),
//           ),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _submitting = false);
//     }
//   }
//
//   // ── Date Picker ────────────────────────────────────────────────────────
//   Future<void> _pickDate(
//       TextEditingController ctrl, void Function(DateTime) onPicked) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2035),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: ColorScheme.light(primary: AppColors.cyan),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null && mounted) {
//       final formatted =
//           '${picked.day.toString().padLeft(2, '0')}/'
//           '${picked.month.toString().padLeft(2, '0')}/'
//           '${picked.year}';
//       setState(() {
//         ctrl.text = formatted;
//         onPicked(picked);
//       });
//     }
//   }
//
//   // ── Time Picker ────────────────────────────────────────────────────────
//   Future<void> _pickTime(
//       TextEditingController ctrl, void Function(TimeOfDay) onPicked) async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.now(),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: ColorScheme.light(primary: AppColors.cyan),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null && mounted) {
//       final h = picked.hourOfPeriod.toString().padLeft(2, '0');
//       final m = picked.minute.toString().padLeft(2, '0');
//       final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
//       setState(() {
//         ctrl.text = '$h:$m $period';
//         onPicked(picked);
//       });
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _bgColor,
//       body: SafeArea(
//         child: Column(
//           children: [
//             // ── Drag handle ──────────────────────────────────────────
//             const SizedBox(height: 12),
//             Center(
//               child: Container(
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: AppColors.divider,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//
//             // ── Scrollable body ──────────────────────────────────────
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // ── Header row ─────────────────────────────────────
//                     Row(
//                       children: [
//                         const Expanded(
//                           child: Text(
//                             'New Expense Claim',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: _textDark,
//                               letterSpacing: -0.4,
//                             ),
//                           ),
//                         ),
//                         GestureDetector(
//                           onTap: () => Navigator.pop(context),
//                           child: Container(
//                             width: 36,
//                             height: 36,
//                             decoration: BoxDecoration(
//                               color: AppColors.cardBg,
//                               shape: BoxShape.circle,
//                               border: Border.all(color: _borderColor),
//                             ),
//                             child: const Icon(Icons.close_rounded,
//                                 size: 18, color: _textDark),
//                           ),
//                         ),
//                       ],
//                     ),
//
//                     const SizedBox(height: 16),
//                     const Divider(color: _borderColor, height: 1),
//                     const SizedBox(height: 16),
//
//                     // ── Breadcrumb ─────────────────────────────────────
//                     _ExpenseBreadcrumb(),
//
//                     const SizedBox(height: 24),
//
//                     // ── Expense Type ───────────────────────────────────
//                     _FieldLabel(label: 'Expense Type', required: true),
//                     const SizedBox(height: 8),
//                     _SimpleDropdown(
//                       options: _expenseTypeOptions,
//                       value: _selectedExpenseType,
//                       hint: _loadingExpenseTypes
//                           ? 'Loading types…'
//                           : 'Select expense type',
//                       icon: Icons.category_rounded,
//                       hasValidationError: _expenseTypeError,
//                       onChanged: (val) => setState(() {
//                         _selectedExpenseType = val;
//                         _expenseTypeError    = false;
//                       }),
//                     ),
//                     if (_expenseTypeError) ...[
//                       const SizedBox(height: 4),
//                       const Text(
//                         'Please select an expense type.',
//                         style: TextStyle(fontSize: 12, color: _errorRed),
//                       ),
//                     ],
//
//                     const SizedBox(height: 20),
//
//                     // ── Claim Period Type ──────────────────────────────
//                     _FieldLabel(label: 'Claim Period Type', required: true),
//                     const SizedBox(height: 8),
//                     _SimpleDropdown(
//                       options: _claimPeriodOptions,
//                       value: _selectedClaimPeriod,
//                       hint: 'Select claim period',
//                       icon: Icons.date_range_rounded,
//                       hasValidationError: _claimPeriodError,
//                       onChanged: (val) => setState(() {
//                         _selectedClaimPeriod = val;
//                         _claimPeriodError    = false;
//                       }),
//                     ),
//                     if (_claimPeriodError) ...[
//                       const SizedBox(height: 4),
//                       const Text(
//                         'Please select a claim period type.',
//                         style: TextStyle(fontSize: 12, color: _errorRed),
//                       ),
//                     ],
//
//                     const SizedBox(height: 20),
//
//                     // ── Conditional fields per Claim Period Type ───────
//                     if (_selectedClaimPeriod == 'Date Based') ...[
//                       // Amount
//                       _FieldLabel(label: 'Amount (PKR)', required: true),
//                       const SizedBox(height: 8),
//                       _AmountField(
//                         controller: _amountController,
//                         hasError: _amountError,
//                         onChanged: (_) => setState(() => _amountError = false),
//                       ),
//                       if (_amountError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please enter a valid amount.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // From Date
//                       _FieldLabel(label: 'From Date', required: true),
//                       const SizedBox(height: 8),
//                       _DatePickerField(
//                         controller: _fromDateController,
//                         hint: 'dd/mm/yyyy',
//                         hasError: _fromDateError,
//                         onTap: () => _pickDate(_fromDateController, (d) {
//                           _fromDate = d; _fromDateError = false;
//                         }),
//                       ),
//                       if (_fromDateError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please select a from date.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // To Date
//                       _FieldLabel(label: 'To Date', required: true),
//                       const SizedBox(height: 8),
//                       _DatePickerField(
//                         controller: _toDateController,
//                         hint: 'dd/mm/yyyy',
//                         hasError: _toDateError,
//                         onTap: () => _pickDate(_toDateController, (d) {
//                           _toDate = d; _toDateError = false;
//                         }),
//                       ),
//                       if (_toDateError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please select a to date.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // Description
//                       _FieldLabel(label: 'Description', required: true),
//                       const SizedBox(height: 8),
//                       _DescriptionField(
//                         controller: _descriptionController,
//                         maxLength: _maxDescription,
//                         hasError: _descriptionError,
//                         onChanged: (_) => setState(() => _descriptionError = false),
//                       ),
//                       const SizedBox(height: 4),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: Text(
//                           '${_descriptionController.text.length} / $_maxDescription',
//                           style: TextStyle(fontSize: 12,
//                               color: _descriptionError ? _errorRed : _textGray),
//                         ),
//                       ),
//                       if (_descriptionError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please describe your expense.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                     ] else if (_selectedClaimPeriod == 'Time Based') ...[
//                       // Amount
//                       _FieldLabel(label: 'Amount (PKR)', required: true),
//                       const SizedBox(height: 8),
//                       _AmountField(
//                         controller: _amountController,
//                         hasError: _amountError,
//                         onChanged: (_) => setState(() => _amountError = false),
//                       ),
//                       if (_amountError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please enter a valid amount.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // Date
//                       _FieldLabel(label: 'Date', required: true),
//                       const SizedBox(height: 8),
//                       _DatePickerField(
//                         controller: _tbDateController,
//                         hint: 'dd/mm/yyyy',
//                         hasError: _tbDateError,
//                         onTap: () => _pickDate(_tbDateController, (d) {
//                           _tbDate = d; _tbDateError = false;
//                         }),
//                       ),
//                       if (_tbDateError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please select a date.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // From Time
//                       _FieldLabel(label: 'From Time', required: true),
//                       const SizedBox(height: 8),
//                       _TimePickerField(
//                         controller: _fromTimeController,
//                         hasError: _fromTimeError,
//                         onTap: () => _pickTime(_fromTimeController, (t) {
//                           _fromTime = t; _fromTimeError = false;
//                         }),
//                       ),
//                       if (_fromTimeError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please select a from time.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // To Time
//                       _FieldLabel(label: 'To Time', required: true),
//                       const SizedBox(height: 8),
//                       _TimePickerField(
//                         controller: _toTimeController,
//                         hasError: _toTimeError,
//                         onTap: () => _pickTime(_toTimeController, (t) {
//                           _toTime = t; _toTimeError = false;
//                         }),
//                       ),
//                       if (_toTimeError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please select a to time.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // Description
//                       _FieldLabel(label: 'Description', required: true),
//                       const SizedBox(height: 8),
//                       _DescriptionField(
//                         controller: _descriptionController,
//                         maxLength: _maxDescription,
//                         hasError: _descriptionError,
//                         onChanged: (_) => setState(() => _descriptionError = false),
//                       ),
//                       const SizedBox(height: 4),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: Text(
//                           '${_descriptionController.text.length} / $_maxDescription',
//                           style: TextStyle(fontSize: 12,
//                               color: _descriptionError ? _errorRed : _textGray),
//                         ),
//                       ),
//                       if (_descriptionError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please describe your expense.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                     ] else if (_selectedClaimPeriod == 'Mileage Base') ...[
//                       // Kilometers
//                       _FieldLabel(label: 'Number of Kilometers Travelled', required: true),
//                       const SizedBox(height: 8),
//                       _AmountField(
//                         controller: _kilometersController,
//                         hasError: _kilometersError,
//                         onChanged: (_) => setState(() => _kilometersError = false),
//                       ),
//                       if (_kilometersError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please enter the kilometers travelled.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // From Location
//                       _FieldLabel(label: 'From Location', required: true),
//                       const SizedBox(height: 8),
//                       _TextInputField(
//                         controller: _fromLocationController,
//                         hint: 'e.g. DHA Phase 6 Office',
//                         hasError: _fromLocationError,
//                         onChanged: (_) => setState(() => _fromLocationError = false),
//                       ),
//                       if (_fromLocationError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please enter the from location.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // To Location
//                       _FieldLabel(label: 'To Location', required: true),
//                       const SizedBox(height: 8),
//                       _TextInputField(
//                         controller: _toLocationController,
//                         hint: 'e.g. Faisal Town Client Site',
//                         hasError: _toLocationError,
//                         onChanged: (_) => setState(() => _toLocationError = false),
//                       ),
//                       if (_toLocationError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please enter the to location.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                       const SizedBox(height: 20),
//                       // Purpose of Travel
//                       _FieldLabel(label: 'Purpose of Travel', required: true),
//                       const SizedBox(height: 8),
//                       _DescriptionField(
//                         controller: _purposeController,
//                         maxLength: _maxDescription,
//                         hasError: _purposeError,
//                         onChanged: (_) => setState(() => _purposeError = false),
//                       ),
//                       const SizedBox(height: 4),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: Text(
//                           '${_purposeController.text.length} / $_maxDescription',
//                           style: TextStyle(fontSize: 12,
//                               color: _purposeError ? _errorRed : _textGray),
//                         ),
//                       ),
//                       if (_purposeError) ...[
//                         const SizedBox(height: 4),
//                         const Text('Please describe the purpose of travel.',
//                             style: TextStyle(fontSize: 12, color: _errorRed)),
//                       ],
//                     ],
//
//                     const SizedBox(height: 28),
//                     const Divider(color: _borderColor, height: 1),
//                     const SizedBox(height: 16),
//                   ],
//                 ),
//               ),
//             ),
//
//             // ── Bottom buttons ───────────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
//               child: Row(
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
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// // ═══════════════════════════════════════════════════════════════════════════
// // Helper Widgets
// // ═══════════════════════════════════════════════════════════════════════════
//
// class _ExpenseBreadcrumb extends StatelessWidget {
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
//           _crumb('Actions', isActive: false),
//           _chevron(),
//           _crumb('Expense', isActive: false),
//           _chevron(),
//           _crumb('New Claim', isActive: true),
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
// class _SimpleDropdown extends StatelessWidget {
//   final List<String> options;
//   final String? value;
//   final String hint;
//   final IconData icon;
//   final bool hasValidationError;
//   final ValueChanged<String?> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//   static const _primary     = AppColors.cyan;
//
//   const _SimpleDropdown({
//     required this.options,
//     required this.value,
//     required this.hint,
//     required this.icon,
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
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: value,
//           isExpanded: true,
//           icon: const Icon(Icons.keyboard_arrow_down_rounded,
//               color: AppColors.textSecondary),
//           hint: Text(hint,
//               style: const TextStyle(
//                   fontSize: 15,
//                   color: AppColors.textSecondary,
//                   fontWeight: FontWeight.w500)),
//           style: const TextStyle(
//               fontSize: 15,
//               color: AppColors.textPrimary,
//               fontWeight: FontWeight.w600),
//           dropdownColor: AppColors.cardBg,
//           borderRadius: BorderRadius.circular(14),
//           onChanged: onChanged,
//           items: options.map((option) {
//             return DropdownMenuItem<String>(
//               value: option,
//               child: Row(
//                 children: [
//                   Icon(icon, size: 16, color: _primary),
//                   const SizedBox(width: 8),
//                   Text(option),
//                 ],
//               ),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }
// }
//
// class _DescriptionField extends StatelessWidget {
//   final TextEditingController controller;
//   final int maxLength;
//   final bool hasError;
//   final ValueChanged<String> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _DescriptionField({
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
//       child: TextField(
//         controller: controller,
//         maxLines: 5,
//         maxLength: maxLength,
//         onChanged: onChanged,
//         style: const TextStyle(
//             fontSize: 15, color: AppColors.textPrimary, height: 1.5),
//         decoration: const InputDecoration(
//           hintText: 'Describe your expense in detail',
//           hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
//           contentPadding: EdgeInsets.all(16),
//           border: InputBorder.none,
//           counterText: '',
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
//       child: TextField(
//         controller: controller,
//         keyboardType: TextInputType.number,
//         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//         onChanged: onChanged,
//         textAlign: TextAlign.center,
//         style: const TextStyle(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: AppColors.textSecondary,
//             letterSpacing: 0.5),
//         decoration: const InputDecoration(
//           hintText: '0',
//           hintStyle: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.w600,
//               color: AppColors.textSecondary),
//           contentPadding: EdgeInsets.symmetric(horizontal: 16),
//           border: InputBorder.none,
//         ),
//       ),
//     );
//   }
// }
//
// // ── Date Picker Field ────────────────────────────────────────────────────────
// class _DatePickerField extends StatelessWidget {
//   final TextEditingController controller;
//   final String hint;
//   final bool hasError;
//   final VoidCallback onTap;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _DatePickerField({
//     required this.controller,
//     required this.hint,
//     required this.hasError,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: 54,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         decoration: BoxDecoration(
//           color: _fieldBg,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: hasError ? _errorRed : _borderColor,
//             width: hasError ? 1.5 : 1.2,
//           ),
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 controller.text.isEmpty ? hint : controller.text,
//                 style: TextStyle(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                   color: controller.text.isEmpty
//                       ? AppColors.textSecondary
//                       : AppColors.textPrimary,
//                 ),
//               ),
//             ),
//             const Icon(Icons.calendar_today_rounded,
//                 size: 20, color: AppColors.textSecondary),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ── Time Picker Field ────────────────────────────────────────────────────────
// class _TimePickerField extends StatelessWidget {
//   final TextEditingController controller;
//   final bool hasError;
//   final VoidCallback onTap;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _TimePickerField({
//     required this.controller,
//     required this.hasError,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: 54,
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         decoration: BoxDecoration(
//           color: _fieldBg,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: hasError ? _errorRed : _borderColor,
//             width: hasError ? 1.5 : 1.2,
//           ),
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 controller.text.isEmpty ? '--:-- --' : controller.text,
//                 style: TextStyle(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                   color: controller.text.isEmpty
//                       ? AppColors.textSecondary
//                       : AppColors.textPrimary,
//                 ),
//               ),
//             ),
//             const Icon(Icons.access_time_rounded,
//                 size: 20, color: AppColors.textSecondary),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ── Single-line Text Input Field ─────────────────────────────────────────────
// class _TextInputField extends StatelessWidget {
//   final TextEditingController controller;
//   final String hint;
//   final bool hasError;
//   final ValueChanged<String> onChanged;
//
//   static const _fieldBg     = AppColors.cyanLight;
//   static const _borderColor = AppColors.divider;
//   static const _errorRed    = AppColors.error;
//
//   const _TextInputField({
//     required this.controller,
//     required this.hint,
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
//           color: hasError ? _errorRed : _borderColor,
//           width: hasError ? 1.5 : 1.2,
//         ),
//       ),
//       alignment: Alignment.center,
//       child: TextField(
//         controller: controller,
//         onChanged: onChanged,
//         style: const TextStyle(
//             fontSize: 15,
//             color: AppColors.textPrimary,
//             fontWeight: FontWeight.w500),
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: const TextStyle(
//               color: AppColors.textSecondary, fontSize: 15),
//           contentPadding:
//           const EdgeInsets.symmetric(horizontal: 16),
//           border: InputBorder.none,
//         ),
//       ),
//     );
//   }
// }
//

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// expense_claim_screen.dart
//
// New Expense Claim Request — Full Screen with Gradient Header
// Reads companyCode, empId, empName automatically from SharedPreferences.
// ═══════════════════════════════════════════════════════════════════════════

// ── Claim Period Type options ───────────────────────────────────────────────
const List<String> _claimPeriodOptions = [
  'Date Based',
  'Time Based',
  'Mileage Base',
];

// ── POST Service ────────────────────────────────────────────────────────────
// class ExpenseClaimSubmitService {
//   static const _submitUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/expense/post/';
//
//   static Future<void> submitClaim({
//     required String empId,
//     required String empName,
//     required String companyCode,
//     required String expenseType,
//     required String claimPeriodType,
//     required int amount,
//     required String description,
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
//       'emp_id':       empId,
//       'emp_name':     empName,
//       'company_code': companyCode,
//       'expense_type': expenseType,
//       'claim_period': claimPeriodType,
//       'amount':       amount,
//       'description':  description.length > 255
//           ? description.substring(0, 255)
//           : description,
//       'request_date': requestDate,
//       'timestamp':    timestamp,
//       'status':       'Pending',
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
//       throw Exception('Failed to submit claim (${response.statusCode})');
//     }
//   }
// }

// ── POST Service ────────────────────────────────────────────────────────────
class ExpenseClaimSubmitService {
  static const _submitUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/expense/post/';

  static Future<void> submitClaim({
    required String empId,
    required String empName,
    required String companyCode,
    required String expenseType,
    required String claimPeriodType,
    required int amount,
    required String description,
    // Date Based fields
    String? fromDate,
    String? toDate,
    // Time Based fields
    String? claimDate,
    String? fromTime,
    String? toTime,
    // Mileage Base fields
    String? fromLocation,
    String? toLocation,
    int? distanceTravelled,
    String? reasonForTravel,
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

    // Build the body with all possible fields
    final Map<String, dynamic> body = {
      'emp_id': empId,
      'emp_name': empName,
      'company_code': companyCode,
      'expense_type': expenseType,
      'claim_period': claimPeriodType,
      'amount': amount,
      'description': description.length > 255
          ? description.substring(0, 255)
          : description,
      'request_date': requestDate,
      'timestamp': timestamp,
      'status': 'Pending',
    };

    // Add conditional fields based on claim period type
    if (claimPeriodType == 'Date Based') {
      body['from_date'] = fromDate ?? '';
      body['to_date'] = toDate ?? '';
      // Set time fields to null or empty for Date Based
      body['from_time'] = null;
      body['to_time'] = null;
      body['from_location'] = null;
      body['to_location'] = null;
      body['distance_travelled'] = null;
      body['reason_for_travel'] = null;
    } else if (claimPeriodType == 'Time Based') {
      body['claim_date'] = claimDate ?? '';
      body['from_time'] = fromTime ?? '';
      body['to_time'] = toTime ?? '';
      // Set date fields to null or empty for Time Based
      body['from_date'] = null;
      body['to_date'] = null;
      body['from_location'] = null;
      body['to_location'] = null;
      body['distance_travelled'] = null;
      body['reason_for_travel'] = null;
    } else if (claimPeriodType == 'Mileage Base') {
      body['from_location'] = fromLocation ?? '';
      body['to_location'] = toLocation ?? '';
      body['distance_travelled'] = distanceTravelled ?? 0;
      body['reason_for_travel'] = reasonForTravel ?? '';
      // Set date/time fields to null or empty for Mileage Base
      body['from_date'] = null;
      body['to_date'] = null;
      body['claim_date'] = null;
      body['from_time'] = null;
      body['to_time'] = null;
    }

    final response = await http
        .post(
      Uri.parse(_submitUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit claim (${response.statusCode})');
    }
  }
}


// ── Expense Type GET Service ────────────────────────────────────────────────
class ExpenseTypeService {
  static const _url =
      'http://oracle.metaxperts.net/ords/gps_workforce/expensetype/get/';

  static Future<List<String>> fetchTypes(String companyCode) async {
    if (companyCode.isEmpty) return [];
    final uri = Uri.parse(_url)
        .replace(queryParameters: {'company_code': companyCode});
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to load expense types (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final List<dynamic> items =
    data is List ? data : ((data['items'] ?? []) as List<dynamic>);
    return items
        .map<String>((item) => (item['expense_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Main Screen Widget
// ═══════════════════════════════════════════════════════════════════════════
class ExpenseClaimScreen extends StatefulWidget {
  const ExpenseClaimScreen({super.key});

  @override
  State<ExpenseClaimScreen> createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends State<ExpenseClaimScreen>
    with SingleTickerProviderStateMixin {
  // ── Design Tokens ──────────────────────────────────────────────────────
  static const _bgColor     = AppColors.surface;
  static const _primary     = AppColors.cyan;
  static const _primaryDark = AppColors.primaryDark;
  static const _borderColor = AppColors.divider;
  static const _textDark    = AppColors.textPrimary;
  static const _textGray    = AppColors.textSecondary;
  static const _errorRed    = AppColors.error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── Expense Types (loaded from API) ───────────────────────────────────
  List<String> _expenseTypeOptions  = [];
  bool         _loadingExpenseTypes = true;

  // ── Form State ─────────────────────────────────────────────────────────
  final _descriptionController = TextEditingController();
  final _amountController      = TextEditingController();
  static const int _maxDescription = 300;

  // ── Date Based controllers ─────────────────────────────────────────────
  final _fromDateController = TextEditingController();
  final _toDateController   = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  // ── Time Based controllers ─────────────────────────────────────────────
  final _tbDateController   = TextEditingController();
  final _fromTimeController = TextEditingController();
  final _toTimeController   = TextEditingController();
  DateTime?  _tbDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;

  // ── Mileage Base controllers ───────────────────────────────────────────
  final _kilometersController   = TextEditingController();
  final _fromLocationController = TextEditingController();
  final _toLocationController   = TextEditingController();
  final _purposeController      = TextEditingController();

  String? _selectedExpenseType;
  String? _selectedClaimPeriod;

  // ── Shared Prefs Data ──────────────────────────────────────────────────
  String _companyCode = '';
  String _empId       = '';
  String _empName     = '';

  // ── Submit / Reset State ───────────────────────────────────────────────
  bool _submitPressed = false;
  bool _resetPressed  = false;
  bool _submitting    = false;

  // ── Validation ─────────────────────────────────────────────────────────
  bool _descriptionError    = false;
  bool _amountError         = false;
  bool _expenseTypeError    = false;
  bool _claimPeriodError    = false;
  bool _fromDateError       = false;
  bool _toDateError         = false;
  bool _tbDateError         = false;
  bool _fromTimeError       = false;
  bool _toTimeError         = false;
  bool _kilometersError     = false;
  bool _fromLocationError   = false;
  bool _toLocationError     = false;
  bool _purposeError        = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _descriptionController.addListener(() => setState(() {}));
    _purposeController.addListener(() => setState(() {}));
    _loadPrefs();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _tbDateController.dispose();
    _fromTimeController.dispose();
    _toTimeController.dispose();
    _kilometersController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _purposeController.dispose();
    super.dispose();
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

  // ── Load SharedPreferences ─────────────────────────────────────────────
  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyCode = _safeGetFallback(prefs, ['companyCode', 'company_code']);
      setState(() {
        _companyCode = companyCode;
        _empId       = _safeGetFallback(prefs, ['userId', 'emp_id', 'employeeId']);
        _empName     = _safeGetFallback(prefs, ['userName', 'emp_name', 'empName', 'employee_name', 'name']);
      });
      await _fetchExpenseTypes(companyCode);
    } catch (_) {
      if (mounted) setState(() => _loadingExpenseTypes = false);
    }
  }

  // ── Fetch Expense Types from API ───────────────────────────────────────
  Future<void> _fetchExpenseTypes(String companyCode) async {
    try {
      final types = await ExpenseTypeService.fetchTypes(companyCode);
      if (mounted) {
        setState(() {
          _expenseTypeOptions  = types;
          _loadingExpenseTypes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingExpenseTypes = false);
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────
  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _descriptionController.clear();
      _amountController.clear();
      _selectedExpenseType  = null;
      _selectedClaimPeriod  = null;
      _descriptionError     = false;
      _amountError          = false;
      _expenseTypeError     = false;
      _claimPeriodError     = false;
      _fromDateController.clear(); _toDateController.clear();
      _fromDate = null; _toDate = null;
      _fromDateError = false; _toDateError = false;
      _tbDateController.clear(); _fromTimeController.clear(); _toTimeController.clear();
      _tbDate = null; _fromTime = null; _toTime = null;
      _tbDateError = false; _fromTimeError = false; _toTimeError = false;
      _kilometersController.clear(); _fromLocationController.clear();
      _toLocationController.clear(); _purposeController.clear();
      _kilometersError = false; _fromLocationError = false;
      _toLocationError = false; _purposeError = false;
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────
  // Future<void> _submit() async {
  //   HapticFeedback.mediumImpact();
  //
  //   final description = _descriptionController.text.trim();
  //   final amount = _amountController.text.trim();
  //
  //   final bool isDateBased = _selectedClaimPeriod == 'Date Based';
  //   final bool isTimeBased = _selectedClaimPeriod == 'Time Based';
  //   final bool isMileageBase = _selectedClaimPeriod == 'Mileage Base';
  //   final km = _kilometersController.text.trim();
  //
  //   setState(() {
  //     _expenseTypeError = _selectedExpenseType == null;
  //     _claimPeriodError = _selectedClaimPeriod == null;
  //     _amountError = !isMileageBase && (amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0);
  //     _descriptionError = !isMileageBase && description.isEmpty;
  //     _fromDateError = isDateBased && _fromDate == null;
  //     _toDateError = isDateBased && _toDate == null;
  //     _tbDateError = isTimeBased && _tbDate == null;
  //     _fromTimeError = isTimeBased && _fromTime == null;
  //     _toTimeError = isTimeBased && _toTime == null;
  //     _kilometersError = isMileageBase && (km.isEmpty || (int.tryParse(km) ?? 0) <= 0);
  //     _fromLocationError = isMileageBase && _fromLocationController.text.trim().isEmpty;
  //     _toLocationError = isMileageBase && _toLocationController.text.trim().isEmpty;
  //     _purposeError = isMileageBase && _purposeController.text.trim().isEmpty;
  //   });
  //
  //   if (_expenseTypeError || _claimPeriodError || _amountError || _descriptionError ||
  //       _fromDateError || _toDateError || _tbDateError || _fromTimeError || _toTimeError ||
  //       _kilometersError || _fromLocationError || _toLocationError || _purposeError) return;
  //
  //   setState(() => _submitting = true);
  //
  //   try {
  //     final int submitAmount;
  //     String submitDescription;
  //
  //     if (isMileageBase) {
  //       submitAmount = int.parse(km);
  //       submitDescription =
  //       'From:${_fromLocationController.text.trim()}|'
  //           'To:${_toLocationController.text.trim()}|'
  //           'Purpose:${_purposeController.text.trim()}';
  //     } else {
  //       submitAmount = int.parse(amount);
  //       submitDescription = description;
  //     }
  //
  //     if (submitDescription.length > 255) {
  //       submitDescription = submitDescription.substring(0, 255);
  //     }
  //
  //     await ExpenseClaimSubmitService.submitClaim(
  //       empId: _empId,
  //       empName: _empName,
  //       companyCode: _companyCode,
  //       expenseType: _selectedExpenseType!,
  //       claimPeriodType: _selectedClaimPeriod!,
  //       amount: submitAmount,
  //       description: submitDescription,
  //     );
  //
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: const Text('Expense claim submitted successfully!'),
  //           backgroundColor: _primary,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       );
  //       Navigator.pop(context);
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Submission failed: ${e.toString()}'),
  //           backgroundColor: _errorRed,
  //           behavior: SnackBarBehavior.floating,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) setState(() => _submitting = false);
  //   }
  // }

  // ── Submit ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    HapticFeedback.mediumImpact();

    final description = _descriptionController.text.trim();
    final amount = _amountController.text.trim();

    final bool isDateBased = _selectedClaimPeriod == 'Date Based';
    final bool isTimeBased = _selectedClaimPeriod == 'Time Based';
    final bool isMileageBase = _selectedClaimPeriod == 'Mileage Base';
    final km = _kilometersController.text.trim();

    setState(() {
      _expenseTypeError = _selectedExpenseType == null;
      _claimPeriodError = _selectedClaimPeriod == null;
      _amountError = !isMileageBase && (amount.isEmpty || (int.tryParse(amount) ?? 0) <= 0);
      _descriptionError = !isMileageBase && description.isEmpty;
      _fromDateError = isDateBased && _fromDate == null;
      _toDateError = isDateBased && _toDate == null;
      _tbDateError = isTimeBased && _tbDate == null;
      _fromTimeError = isTimeBased && _fromTime == null;
      _toTimeError = isTimeBased && _toTime == null;
      _kilometersError = isMileageBase && (km.isEmpty || (int.tryParse(km) ?? 0) <= 0);
      _fromLocationError = isMileageBase && _fromLocationController.text.trim().isEmpty;
      _toLocationError = isMileageBase && _toLocationController.text.trim().isEmpty;
      _purposeError = isMileageBase && _purposeController.text.trim().isEmpty;
    });

    if (_expenseTypeError || _claimPeriodError || _amountError || _descriptionError ||
        _fromDateError || _toDateError || _tbDateError || _fromTimeError || _toTimeError ||
        _kilometersError || _fromLocationError || _toLocationError || _purposeError) return;

    setState(() => _submitting = true);

    try {
      final int submitAmount;
      String submitDescription;

      // Format dates for database (YYYY-MM-DD)
      String formatDate(DateTime date) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      // Format time for database (HH:MM:SS)
      String formatTime(TimeOfDay time) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      }

      String? fromDate;
      String? toDate;
      String? claimDate;
      String? fromTime;
      String? toTime;
      String? fromLocation;
      String? toLocation;
      int? distanceTravelled;
      String? reasonForTravel;

      if (isDateBased) {
        submitAmount = int.parse(amount);
        submitDescription = description;
        fromDate = formatDate(_fromDate!);
        toDate = formatDate(_toDate!);
      } else if (isTimeBased) {
        submitAmount = int.parse(amount);
        submitDescription = description;
        claimDate = formatDate(_tbDate!);
        fromTime = formatTime(_fromTime!);
        toTime = formatTime(_toTime!);
      } else { // Mileage Base
        submitAmount = int.parse(km);
        fromLocation = _fromLocationController.text.trim();
        toLocation = _toLocationController.text.trim();
        reasonForTravel = _purposeController.text.trim();
        distanceTravelled = submitAmount;
        // For mileage, combine location and purpose into description
        submitDescription =
        'From:$fromLocation|To:$toLocation|Purpose:$reasonForTravel';
      }

      // Truncate if needed
      if (submitDescription.length > 255) {
        submitDescription = submitDescription.substring(0, 255);
      }

      await ExpenseClaimSubmitService.submitClaim(
        empId: _empId,
        empName: _empName,
        companyCode: _companyCode,
        expenseType: _selectedExpenseType!,
        claimPeriodType: _selectedClaimPeriod!,
        amount: submitAmount,
        description: submitDescription,
        // Date Based fields
        fromDate: fromDate,
        toDate: toDate,
        // Time Based fields
        claimDate: claimDate,
        fromTime: fromTime,
        toTime: toTime,
        // Mileage Base fields
        fromLocation: fromLocation,
        toLocation: toLocation,
        distanceTravelled: distanceTravelled,
        reasonForTravel: reasonForTravel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense claim submitted successfully!'),
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


  // ── Date Picker ────────────────────────────────────────────────────────
  Future<void> _pickDate(
      TextEditingController ctrl, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.cyan),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      final formatted =
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
      setState(() {
        ctrl.text = formatted;
        onPicked(picked);
      });
    }
  }

  // ── Time Picker ────────────────────────────────────────────────────────
  Future<void> _pickTime(
      TextEditingController ctrl, void Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.cyan),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      final h = picked.hourOfPeriod.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() {
        ctrl.text = '$h:$m $period';
        onPicked(picked);
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Breadcrumb ─────────────────────────────────────
                    _ExpenseBreadcrumb(),

                    const SizedBox(height: 24),

                    // ── Expense Type ───────────────────────────────────
                    _FieldLabel(label: 'Expense Type', required: true),
                    const SizedBox(height: 8),
                    _SimpleDropdown(
                      options: _expenseTypeOptions,
                      value: _selectedExpenseType,
                      hint: _loadingExpenseTypes
                          ? 'Loading types…'
                          : 'Select expense type',
                      icon: Icons.category_rounded,
                      hasValidationError: _expenseTypeError,
                      onChanged: (val) => setState(() {
                        _selectedExpenseType = val;
                        _expenseTypeError    = false;
                      }),
                    ),
                    if (_expenseTypeError) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Please select an expense type.',
                        style: TextStyle(fontSize: 12, color: _errorRed),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Claim Period Type ──────────────────────────────
                    _FieldLabel(label: 'Claim Period Type', required: true),
                    const SizedBox(height: 8),
                    _SimpleDropdown(
                      options: _claimPeriodOptions,
                      value: _selectedClaimPeriod,
                      hint: 'Select claim period',
                      icon: Icons.date_range_rounded,
                      hasValidationError: _claimPeriodError,
                      onChanged: (val) => setState(() {
                        _selectedClaimPeriod = val;
                        _claimPeriodError    = false;
                      }),
                    ),
                    if (_claimPeriodError) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Please select a claim period type.',
                        style: TextStyle(fontSize: 12, color: _errorRed),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Conditional fields ─────────────────────────────
                    if (_selectedClaimPeriod == 'Date Based') ...[
                      _FieldLabel(label: 'Amount (PKR)', required: true),
                      const SizedBox(height: 8),
                      _AmountField(
                        controller: _amountController,
                        hasError: _amountError,
                        onChanged: (_) => setState(() => _amountError = false),
                      ),
                      if (_amountError) ...[
                        const SizedBox(height: 4),
                        const Text('Please enter a valid amount.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'From Date', required: true),
                      const SizedBox(height: 8),
                      _DatePickerField(
                        controller: _fromDateController,
                        hint: 'dd/mm/yyyy',
                        hasError: _fromDateError,
                        onTap: () => _pickDate(_fromDateController, (d) {
                          _fromDate = d; _fromDateError = false;
                        }),
                      ),
                      if (_fromDateError) ...[
                        const SizedBox(height: 4),
                        const Text('Please select a from date.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'To Date', required: true),
                      const SizedBox(height: 8),
                      _DatePickerField(
                        controller: _toDateController,
                        hint: 'dd/mm/yyyy',
                        hasError: _toDateError,
                        onTap: () => _pickDate(_toDateController, (d) {
                          _toDate = d; _toDateError = false;
                        }),
                      ),
                      if (_toDateError) ...[
                        const SizedBox(height: 4),
                        const Text('Please select a to date.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'Description', required: true),
                      const SizedBox(height: 8),
                      _DescriptionField(
                        controller: _descriptionController,
                        maxLength: _maxDescription,
                        hasError: _descriptionError,
                        onChanged: (_) => setState(() => _descriptionError = false),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_descriptionController.text.length} / $_maxDescription',
                          style: TextStyle(fontSize: 12,
                              color: _descriptionError ? _errorRed : _textGray),
                        ),
                      ),
                      if (_descriptionError) ...[
                        const SizedBox(height: 4),
                        const Text('Please describe your expense.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                    ] else if (_selectedClaimPeriod == 'Time Based') ...[
                      _FieldLabel(label: 'Amount (PKR)', required: true),
                      const SizedBox(height: 8),
                      _AmountField(
                        controller: _amountController,
                        hasError: _amountError,
                        onChanged: (_) => setState(() => _amountError = false),
                      ),
                      if (_amountError) ...[
                        const SizedBox(height: 4),
                        const Text('Please enter a valid amount.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'Date', required: true),
                      const SizedBox(height: 8),
                      _DatePickerField(
                        controller: _tbDateController,
                        hint: 'dd/mm/yyyy',
                        hasError: _tbDateError,
                        onTap: () => _pickDate(_tbDateController, (d) {
                          _tbDate = d; _tbDateError = false;
                        }),
                      ),
                      if (_tbDateError) ...[
                        const SizedBox(height: 4),
                        const Text('Please select a date.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'From Time', required: true),
                      const SizedBox(height: 8),
                      _TimePickerField(
                        controller: _fromTimeController,
                        hasError: _fromTimeError,
                        onTap: () => _pickTime(_fromTimeController, (t) {
                          _fromTime = t; _fromTimeError = false;
                        }),
                      ),
                      if (_fromTimeError) ...[
                        const SizedBox(height: 4),
                        const Text('Please select a from time.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'To Time', required: true),
                      const SizedBox(height: 8),
                      _TimePickerField(
                        controller: _toTimeController,
                        hasError: _toTimeError,
                        onTap: () => _pickTime(_toTimeController, (t) {
                          _toTime = t; _toTimeError = false;
                        }),
                      ),
                      if (_toTimeError) ...[
                        const SizedBox(height: 4),
                        const Text('Please select a to time.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'Description', required: true),
                      const SizedBox(height: 8),
                      _DescriptionField(
                        controller: _descriptionController,
                        maxLength: _maxDescription,
                        hasError: _descriptionError,
                        onChanged: (_) => setState(() => _descriptionError = false),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_descriptionController.text.length} / $_maxDescription',
                          style: TextStyle(fontSize: 12,
                              color: _descriptionError ? _errorRed : _textGray),
                        ),
                      ),
                      if (_descriptionError) ...[
                        const SizedBox(height: 4),
                        const Text('Please describe your expense.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                    ] else if (_selectedClaimPeriod == 'Mileage Base') ...[
                      _FieldLabel(label: 'Number of Kilometers Travelled', required: true),
                      const SizedBox(height: 8),
                      _AmountField(
                        controller: _kilometersController,
                        hasError: _kilometersError,
                        onChanged: (_) => setState(() => _kilometersError = false),
                      ),
                      if (_kilometersError) ...[
                        const SizedBox(height: 4),
                        const Text('Please enter the kilometers travelled.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'From Location', required: true),
                      const SizedBox(height: 8),
                      _TextInputField(
                        controller: _fromLocationController,
                        hint: 'e.g. DHA Phase 6 Office',
                        hasError: _fromLocationError,
                        onChanged: (_) => setState(() => _fromLocationError = false),
                      ),
                      if (_fromLocationError) ...[
                        const SizedBox(height: 4),
                        const Text('Please enter the from location.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'To Location', required: true),
                      const SizedBox(height: 8),
                      _TextInputField(
                        controller: _toLocationController,
                        hint: 'e.g. Faisal Town Client Site',
                        hasError: _toLocationError,
                        onChanged: (_) => setState(() => _toLocationError = false),
                      ),
                      if (_toLocationError) ...[
                        const SizedBox(height: 4),
                        const Text('Please enter the to location.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                      const SizedBox(height: 20),
                      _FieldLabel(label: 'Purpose of Travel', required: true),
                      const SizedBox(height: 8),
                      _DescriptionField(
                        controller: _purposeController,
                        maxLength: _maxDescription,
                        hasError: _purposeError,
                        onChanged: (_) => setState(() => _purposeError = false),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_purposeController.text.length} / $_maxDescription',
                          style: TextStyle(fontSize: 12,
                              color: _purposeError ? _errorRed : _textGray),
                        ),
                      ),
                      if (_purposeError) ...[
                        const SizedBox(height: 4),
                        const Text('Please describe the purpose of travel.',
                            style: TextStyle(fontSize: 12, color: _errorRed)),
                      ],
                    ],

                    const SizedBox(height: 28),
                    const Divider(color: _borderColor, height: 1),
                    const SizedBox(height: 20),

                    // ── Bottom buttons ─────────────────────────────────
                    Row(
                      children: [
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
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
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -30, child: _decorCircle(160, 0.08)),
          Positioned(bottom: -40, left: -20, child: _decorCircle(110, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Expense Claim',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          _empName.isNotEmpty ? _empName : 'Loading…',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
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

  Widget _decorCircle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _ExpenseBreadcrumb extends StatelessWidget {
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
          _crumb('Actions', isActive: false),
          _chevron(),
          _crumb('Expense', isActive: false),
          _chevron(),
          _crumb('New Claim', isActive: true),
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

class _SimpleDropdown extends StatelessWidget {
  final List<String> options;
  final String? value;
  final String hint;
  final IconData icon;
  final bool hasValidationError;
  final ValueChanged<String?> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;
  static const _primary     = AppColors.cyan;

  const _SimpleDropdown({
    required this.options,
    required this.value,
    required this.hint,
    required this.icon,
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          hint: Text(hint,
              style: const TextStyle(
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
          items: options.map((option) {
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
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _DescriptionField({
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
      child: TextField(
        controller: controller,
        maxLines: 5,
        maxLength: maxLength,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 15, color: AppColors.textPrimary, height: 1.5),
        decoration: const InputDecoration(
          hintText: 'Describe your expense in detail',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          contentPadding: EdgeInsets.all(16),
          border: InputBorder.none,
          counterText: '',
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
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasError;
  final VoidCallback onTap;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _DatePickerField({
    required this.controller,
    required this.hint,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty ? hint : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: controller.text.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback onTap;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _TimePickerField({
    required this.controller,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.text.isEmpty ? '--:-- --' : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: controller.text.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.access_time_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasError;
  final ValueChanged<String> onChanged;

  static const _fieldBg     = AppColors.cyanLight;
  static const _borderColor = AppColors.divider;
  static const _errorRed    = AppColors.error;

  const _TextInputField({
    required this.controller,
    required this.hint,
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
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontSize: 15),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}