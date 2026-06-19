// //
// // import 'dart:convert';
// // import 'dart:io';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:http/io_client.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../../Database/db_helper.dart';
// //
// //
// // // ═══════════════════════════════════════════════════════════════════════════════
// // // Wagers_register_screen.dart
// // // ═══════════════════════════════════════════════════════════════════════════════
// //
// // class WagersRegisterScreen extends StatefulWidget {
// //   const WagersRegisterScreen({super.key});
// //
// //   @override
// //   State<WagersRegisterScreen> createState() => _WagersRegisterScreenState();
// // }
// //
// // class _WagersRegisterScreenState extends State<WagersRegisterScreen> {
// //   final _formKey      = GlobalKey<FormState>();
// //   bool  _isSubmitting = false;
// //   bool  _loadingEmpId = true;
// //
// //   static const _primary = Color(0xFF0C6B64);
// //   static const _bg      = Color(0xFFE8F5F3);
// //
// //   // ── Controllers ──────────────────────────────────────────────────────────────
// //   final _empIdCtrl      = TextEditingController();   // read-only, auto-filled
// //   final _empNameCtrl    = TextEditingController();
// //   final _depIdCtrl      = TextEditingController();
// //   final _depNameCtrl    = TextEditingController();
// //   final _fatherNameCtrl = TextEditingController();
// //   final _cnicCtrl       = TextEditingController();
// //   final _contactCtrl    = TextEditingController();
// //   final _salaryCtrl     = TextEditingController();
// //   final _dobCtrl        = TextEditingController();
// //   final _emailCtrl      = TextEditingController();
// //   final _addressCtrl    = TextEditingController();
// //   final _entryTimeCtrl  = TextEditingController();
// //   final _endTimeCtrl    = TextEditingController();
// //   String? _selectedGender;
// //
// //   // ── Stored login ID & company code (hidden from UI) ───────────────────────
// //   String _loginId     = '';
// //   String _companyCode = '';   // hidden — loaded from SharedPreferences, sent via API
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadLoginIdAndGenerateEmpId();
// //   }
// //
// //   // ── Load loginId + companyCode from SharedPreferences & build next EMP_ID ──
// //   // Future<void> _loadLoginIdAndGenerateEmpId() async {
// //   //   final prefs = await SharedPreferences.getInstance();
// //   //
// //   //   // Your app stores the logged-in Wagers's ID under 'emp_id'
// //   //   _loginId     = (prefs.getInt('emp_id') ?? prefs.getString('emp_id') ?? '0').toString();
// //   //   _companyCode = DBHelper.getCompanyCode() ?? '';
// //   //
// //   //   // Counter key unique to this loginId so each user has own sequence
// //   //   final counterKey = 'emp_register_counter_$_loginId';
// //   //   int counter = (prefs.getInt(counterKey) ?? 0) + 1;
// //   //   await prefs.setInt(counterKey, counter);
// //   //
// //   //   // Format:  27  +  01 / 02 / 03 ...  (2-digit padded sequence)
// //   //   final newEmpId = '$_loginId${counter.toString().padLeft(2, '0')}';
// //   //
// //   //   setState(() {
// //   //     _empIdCtrl.text = newEmpId;
// //   //     _loadingEmpId   = false;
// //   //   });
// //   // }
// //
// //   Future<void> _loadLoginIdAndGenerateEmpId() async {
// //     final prefs = await SharedPreferences.getInstance();
// //
// //     _loginId     = (prefs.getInt('emp_id') ?? prefs.getString('emp_id') ?? '0').toString();
// //     _companyCode = (prefs.getString('company_code') ?? '').toString();
// //
// //     try {
// //       final ioClient = IOClient(
// //         HttpClient()..badCertificateCallback = (cert, host, port) => true,
// //       );
// //
// //       // Pass loginId as parameter — API filters by THIS employee only
// //       final uri = Uri.parse(
// //           'https://oracle.metaxperts.net/ords/gps_workforce/wagerid/get/?emp_id=$_loginId&company_code=$_companyCode'
// //       );
// //       final response = await ioClient.get(uri).timeout(const Duration(seconds: 10));
// //
// // // DEBUG
// //       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
// //       debugPrint('📡 WAGER ID API');
// //       debugPrint('   URL    : $uri');
// //       debugPrint('   STATUS : ${response.statusCode}');
// //       debugPrint('   BODY   : ${response.body}');
// //       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
// //
// //       if (response.statusCode == 200) {
// //         final data     = jsonDecode(response.body);
// //         final items    = data['items'] as List;
// //         final maxRaw   = items.isNotEmpty ? items[0]['max_wager_id'] : null;
// //         final maxId    = maxRaw != null ? int.tryParse(maxRaw.toString()) ?? 0 : 0;
// //
// //         int nextSuffix = 1;
// //         if (maxId > 0) {
// //           final suffixStr    = maxId.toString().substring(_loginId.length);
// //           final currentSuffix = int.tryParse(suffixStr) ?? 0;
// //           nextSuffix         = currentSuffix + 1;
// //         }
// //
// //         final newEmpId = '$_loginId${nextSuffix.toString().padLeft(2, '0')}';
// //
// //         setState(() {
// //           _empIdCtrl.text = newEmpId;
// //           _loadingEmpId   = false;
// //         });
// //       } else {
// //         _showErrorAndPop('Server error: ${response.statusCode}');
// //       }
// //     } catch (e) {
// //       _showErrorAndPop('Could not load Employee ID. Check your connection.');
// //     }
// //   }
// //
// //   void _showErrorAndPop(String msg) {
// //     setState(() => _loadingEmpId = false);
// //     Get.snackbar(
// //       'Error', msg,
// //       snackPosition:   SnackPosition.BOTTOM,
// //       backgroundColor: Colors.red.shade700,
// //       colorText:       Colors.white,
// //       duration:        const Duration(seconds: 3),
// //     );
// //   }
// //
// // // Fallback: local SharedPreferences counter (offline safety net)
// //   void _fallbackToLocalCounter(SharedPreferences prefs) {
// //     final counterKey = 'emp_register_counter_$_loginId';
// //     int counter = (prefs.getInt(counterKey) ?? 0) + 1;
// //     prefs.setInt(counterKey, counter);
// //
// //     setState(() {
// //       _empIdCtrl.text = '$_loginId${counter.toString().padLeft(2, '0')}';
// //       _loadingEmpId   = false;
// //     });
// //   }
// //
// //
// //   @override
// //   void dispose() {
// //     _empIdCtrl.dispose();      _empNameCtrl.dispose();
// //     _depIdCtrl.dispose();      _depNameCtrl.dispose();
// //     _fatherNameCtrl.dispose(); _cnicCtrl.dispose();
// //     _contactCtrl.dispose();    _salaryCtrl.dispose();
// //     _dobCtrl.dispose();        _emailCtrl.dispose();
// //     _addressCtrl.dispose();    _entryTimeCtrl.dispose();
// //     _endTimeCtrl.dispose();
// //     super.dispose();
// //   }
// //
// //   // ── Date Picker ───────────────────────────────────────────────────────────
// //   Future<void> _pickDate() async {
// //     final picked = await showDatePicker(
// //       context:     context,
// //       initialDate: DateTime(1990),
// //       firstDate:   DateTime(1950),
// //       lastDate:    DateTime.now(),
// //       builder: (ctx, child) => Theme(
// //         data: Theme.of(ctx).copyWith(
// //           colorScheme: const ColorScheme.light(
// //             primary: _primary, onPrimary: Colors.white, surface: Colors.white,
// //           ),
// //         ),
// //         child: child!,
// //       ),
// //     );
// //     if (picked != null) {
// //       _dobCtrl.text =
// //       '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
// //     }
// //   }
// //
// //   // ── Time Picker ───────────────────────────────────────────────────────────
// //   Future<void> _pickTime(TextEditingController ctrl) async {
// //     final picked = await showTimePicker(
// //       context:     context,
// //       initialTime: TimeOfDay.now(),
// //       builder: (ctx, child) => Theme(
// //         data: Theme.of(ctx).copyWith(
// //           colorScheme: const ColorScheme.light(
// //             primary: _primary, onPrimary: Colors.white, surface: Colors.white,
// //           ),
// //         ),
// //         child: child!,
// //       ),
// //     );
// //     if (picked != null) {
// //       final hour   = picked.hour.toString().padLeft(2, '0');
// //       final minute = picked.minute.toString().padLeft(2, '0');
// //       ctrl.text = '$hour:$minute';
// //     }
// //   }
// //
// //   // ── Submit ────────────────────────────────────────────────────────────────
// //   // ── Submit ────────────────────────────────────────────────────────────────
// //   // ── Submit ────────────────────────────────────────────────────────────────
// //   Future<void> _submit() async {
// //     if (!_formKey.currentState!.validate()) return;
// //
// //     // Don't show loading state - just navigate back immediately
// //     // or show a quick snackbar without blocking
// //
// //     try {
// //       final body = {
// //         'company_code':      _companyCode,
// //         'wager_id':          _empIdCtrl.text,
// //         'wager_name':        _empNameCtrl.text.trim(),
// //         'dep_id':            _depIdCtrl.text.trim(),
// //         'dep_name':          _depNameCtrl.text.trim(),
// //         'father_name':       _fatherNameCtrl.text.trim(),
// //         'cnic_no':           _cnicCtrl.text.trim(),
// //         'contact_no':        _contactCtrl.text.trim(),
// //         'email':             _emailCtrl.text.trim(),
// //         'address':           _addressCtrl.text.trim(),
// //         'gender':            _selectedGender ?? '',
// //         'dob':               _dobCtrl.text,
// //         'basic_salary':      _salaryCtrl.text,
// //         'entry_time':        _entryTimeCtrl.text,
// //         'end_time':          _endTimeCtrl.text,
// //         'timekeeper_emp_id': _loginId,
// //         'status':            'active',
// //       };
// //
// //       // Show loading snackbar (optional - just for user feedback)
// //       final loadingSnackbar = Get.snackbar(
// //         'Please wait', 'Registering Wagers...',
// //         snackPosition: SnackPosition.BOTTOM,
// //         backgroundColor: _primary.withOpacity(0.93),
// //         colorText: Colors.white,
// //         duration: const Duration(seconds: 1),
// //         borderRadius: 14,
// //       );
// //
// //       // Make API call in background
// //       http.post(
// //         Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagerregister/post/'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode(body),
// //       ).then((response) {
// //         // Handle response in background
// //         if (response.statusCode == 200 || response.statusCode == 201) {
// //           debugPrint('✅ Wager registered successfully');
// //         } else {
// //           debugPrint('❌ Registration failed: ${response.body}');
// //         }
// //       }).catchError((e) {
// //         debugPrint('❌ Network error: $e');
// //       });
// //
// //       // ✅ Immediately navigate back with success message
// //       Get.back(); // Close the register screen
// //
// //       // ✅ Show success snackbar on previous screen
// //       Get.snackbar(
// //         'Success', 'Wagers registered successfully!',
// //         snackPosition: SnackPosition.BOTTOM,
// //         backgroundColor: _primary.withOpacity(0.93),
// //         colorText: Colors.white,
// //         borderRadius: 14,
// //         margin: const EdgeInsets.all(16),
// //         duration: const Duration(seconds: 2),
// //         icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
// //       );
// //
// //     } catch (e) {
// //       // Show error on current screen
// //       Get.snackbar(
// //         'Error', 'Registration failed. Please try again.',
// //         snackPosition: SnackPosition.BOTTOM,
// //         backgroundColor: Colors.red.shade700,
// //         colorText: Colors.white,
// //         borderRadius: 14,
// //         margin: const EdgeInsets.all(16),
// //         duration: const Duration(seconds: 3),
// //       );
// //     }
// //   }
// //
// // // ── Clear Form Method ──────────────────────────────────────────────
// //   void _clearForm() {
// //     // Clear all text controllers
// //     _empNameCtrl.clear();
// //     _depIdCtrl.clear();
// //     _depNameCtrl.clear();
// //     _fatherNameCtrl.clear();
// //     _cnicCtrl.clear();
// //     _contactCtrl.clear();
// //     _salaryCtrl.clear();
// //     _dobCtrl.clear();
// //     _emailCtrl.clear();
// //     _addressCtrl.clear();
// //     _entryTimeCtrl.clear();
// //     _endTimeCtrl.clear();
// //
// //     // Clear gender selection
// //     _selectedGender = null;
// //
// //     // Reset form validation state
// //     _formKey.currentState?.reset();
// //
// //     // Note: EMP_ID is auto-generated and will be regenerated when screen reopens
// //     // because _loadLoginIdAndGenerateEmpId() runs in initState
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: _bg,
// //       body: Column(
// //         children: [
// //
// //           // ── Gradient Header ────────────────────────────────────────────
// //           Container(
// //             decoration: const BoxDecoration(
// //               gradient: LinearGradient(
// //                 colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
// //                 begin:  Alignment.topLeft,
// //                 end:    Alignment.bottomRight,
// //               ),
// //               borderRadius: BorderRadius.only(
// //                 bottomLeft:  Radius.circular(28),
// //                 bottomRight: Radius.circular(28),
// //               ),
// //             ),
// //             child: SafeArea(
// //               bottom: false,
// //               child: Padding(
// //                 padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
// //                 child: Row(
// //                   children: [
// //                     GestureDetector(
// //                       onTap: () => Get.back(),
// //                       child: Container(
// //                         width: 42, height: 42,
// //                         decoration: BoxDecoration(
// //                           color: Colors.white.withOpacity(0.2),
// //                           borderRadius: BorderRadius.circular(13),
// //                         ),
// //                         child: const Icon(Icons.arrow_back_ios_new_rounded,
// //                             color: Colors.white, size: 18),
// //                       ),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     const Expanded(
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           Text('Wagers Register',
// //                               style: TextStyle(fontSize: 22,
// //                                   fontWeight: FontWeight.w700, color: Colors.white)),
// //                           SizedBox(height: 2),
// //                           Text('Enroll a new Wagers',
// //                               style: TextStyle(fontSize: 13, color: Colors.white70)),
// //                         ],
// //                       ),
// //                     ),
// //                     Container(
// //                       width: 42, height: 42,
// //                       decoration: BoxDecoration(
// //                         color: Colors.white.withOpacity(0.2),
// //                         borderRadius: BorderRadius.circular(13),
// //                       ),
// //                       child: const Icon(Icons.person_add_alt_1_rounded,
// //                           color: Colors.white, size: 20),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //
// //           // ── Form ──────────────────────────────────────────────────────
// //           Expanded(
// //             child: Form(
// //               key: _formKey,
// //               child: ListView(
// //                 padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
// //                 children: [
// //
// //                   // ── Wagers Info ──────────────────────────────────────
// //                   _SectionHeader(icon: Icons.person_rounded, label: 'Wagers Info'),
// //                   const SizedBox(height: 12),
// //
// //                   // EMP ID — read-only, auto-generated
// //                   _FieldCard(
// //                     label:      'Wagers ID',
// //                     controller: _empIdCtrl,
// //                     icon:       Icons.badge_rounded,
// //                     hint:       _loadingEmpId ? 'Generating...' : _empIdCtrl.text,
// //                     readOnly:   true,
// //                     showLock:   true,
// //                     validator:  null,
// //                   ),
// //                   const SizedBox(height: 10),
// //
// //                   _FieldCard(
// //                     label:      'Wagers Name',
// //                     controller: _empNameCtrl,
// //                     icon:       Icons.person_rounded,
// //                     hint:       'Full name',
// //                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
// //                   ),
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Department Info ────────────────────────────────────
// //                   _SectionHeader(icon: Icons.corporate_fare_rounded, label: 'Department Info'),
// //                   const SizedBox(height: 12),
// //
// //                   _FieldCard(
// //                     label:            'Department ID',
// //                     controller:       _depIdCtrl,
// //                     icon:             Icons.corporate_fare_rounded,
// //                     hint:             'Enter department ID',
// //                     keyboardType:     TextInputType.number,
// //                     inputFormatters:  [FilteringTextInputFormatter.digitsOnly],
// //                     validator:        (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                   ),
// //                   const SizedBox(height: 10),
// //                   _FieldCard(
// //                     label:      'Department Name',
// //                     controller: _depNameCtrl,
// //                     icon:       Icons.business_rounded,
// //                     hint:       'e.g. Human Resources',
// //                     isOptional: true,
// //                     validator:  null,
// //                   ),
// //                   const SizedBox(height: 10),
// //                   _FieldCard(
// //                     label:      'Father Name',
// //                     controller: _fatherNameCtrl,
// //                     icon:       Icons.people_rounded,
// //                     hint:       "Father's full name",
// //                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
// //                   ),
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Identity & Contact ─────────────────────────────────
// //                   _SectionHeader(icon: Icons.contact_phone_rounded, label: 'Identity & Contact'),
// //                   const SizedBox(height: 12),
// //
// //                   _FieldCard(
// //                     label:           'CNIC No.',
// //                     controller:      _cnicCtrl,
// //                     icon:            Icons.credit_card_rounded,
// //                     hint:            '12345-1234567-1',
// //                     keyboardType:    TextInputType.number,
// //                     inputFormatters: [
// //                       FilteringTextInputFormatter.digitsOnly,
// //                       _CnicInputFormatter(),
// //                     ],
// //                     validator: (v) {
// //                       if (v == null || v.isEmpty) return 'Required';
// //                       if (v.replaceAll('-', '').length != 13)
// //                         return 'Enter valid 13-digit CNIC';
// //                       return null;
// //                     },
// //                   ),
// //                   const SizedBox(height: 10),
// //
// //                   // Contact — max 11 digits
// //                   _FieldCard(
// //                     label:           'Contact No.',
// //                     controller:      _contactCtrl,
// //                     icon:            Icons.phone_rounded,
// //                     hint:            '03001234567',
// //                     keyboardType:    TextInputType.phone,
// //                     inputFormatters: [
// //                       FilteringTextInputFormatter.digitsOnly,
// //                       LengthLimitingTextInputFormatter(11),
// //                     ],
// //                     validator: (v) {
// //                       if (v == null || v.isEmpty) return 'Required';
// //                       if (v.length < 10) return 'Enter valid contact number';
// //                       if (v.length > 11) return 'Maximum 11 digits allowed';
// //                       return null;
// //                     },
// //                   ),
// //                   const SizedBox(height: 10),
// //
// //                   // Email — optional
// //                   _FieldCard(
// //                     label:        'Email (optional)',
// //                     controller:   _emailCtrl,
// //                     icon:         Icons.email_rounded,
// //                     hint:         'Wagers@company.com',
// //                     keyboardType: TextInputType.emailAddress,
// //                     isOptional:   true,
// //                     validator: (v) {
// //                       if (v != null && v.isNotEmpty && !GetUtils.isEmail(v))
// //                         return 'Enter valid email';
// //                       return null;
// //                     },
// //                   ),
// //                   const SizedBox(height: 10),
// //                   _FieldCard(
// //                     label:      'Address',
// //                     controller: _addressCtrl,
// //                     icon:       Icons.location_on_rounded,
// //                     hint:       'Full residential address',
// //                     maxLines:   3,
// //                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
// //                   ),
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Personal & Salary ──────────────────────────────────
// //                   _SectionHeader(icon: Icons.tune_rounded, label: 'Personal & Salary'),
// //                   const SizedBox(height: 12),
// //
// //                   _FieldCard(
// //                     label:      'Date of Birth',
// //                     controller: _dobCtrl,
// //                     icon:       Icons.cake_rounded,
// //                     hint:       'Tap to select date',
// //                     readOnly:   true,
// //                     onTap:      _pickDate,
// //                     showArrow:  true,
// //                     validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                   ),
// //                   const SizedBox(height: 10),
// //
// //                   // Gender + Salary side by side
// //                   Row(children: [
// //                     Expanded(
// //                       child: _DropdownCard(
// //                         topLabel:      'Gender',
// //                         topLabelColor: const Color(0xFF0C6B64),
// //                         value:         _selectedGender,
// //                         icon:          Icons.wc_rounded,
// //                         items:         const ['Male', 'Female', 'Other'],
// //                         onChanged:     (v) => setState(() => _selectedGender = v),
// //                         validator:     (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                       ),
// //                     ),
// //                     const SizedBox(width: 10),
// //                     Expanded(
// //                       child: _FieldCard(
// //                         label:           'Monthly Salary',
// //                         controller:      _salaryCtrl,
// //                         icon:            Icons.payments_rounded,
// //                         hint:            'Amount in PKR',
// //                         keyboardType:    TextInputType.number,
// //                         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
// //                         validator:       (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                       ),
// //                     ),
// //                   ]),
// //
// //                   const SizedBox(height: 20),
// //
// //                   // ── Timing ─────────────────────────────────────────────
// //                   _SectionHeader(icon: Icons.access_time_rounded, label: 'Work Timing'),
// //                   const SizedBox(height: 12),
// //
// //                   // Entry + End time side by side
// //                   Row(children: [
// //                     Expanded(
// //                       child: _FieldCard(
// //                         label:      'Entry Time',
// //                         controller: _entryTimeCtrl,
// //                         icon:       Icons.login_rounded,
// //                         hint:       'Tap to select',
// //                         readOnly:   true,
// //                         onTap:      () => _pickTime(_entryTimeCtrl),
// //                         showArrow:  true,
// //                         validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                       ),
// //                     ),
// //                     const SizedBox(width: 10),
// //                     Expanded(
// //                       child: _FieldCard(
// //                         label:      'End Time',
// //                         controller: _endTimeCtrl,
// //                         icon:       Icons.logout_rounded,
// //                         hint:       'Tap to select',
// //                         readOnly:   true,
// //                         onTap:      () => _pickTime(_endTimeCtrl),
// //                         showArrow:  true,
// //                         validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
// //                       ),
// //                     ),
// //                   ]),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //
// //       // ── Submit Button ──────────────────────────────────────────────────
// //       bottomNavigationBar: Container(
// //         padding: EdgeInsets.fromLTRB(
// //             16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
// //         decoration: BoxDecoration(
// //           color: Colors.white,
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.black.withOpacity(0.07),
// //               blurRadius: 12, offset: const Offset(0, -3),
// //             )
// //           ],
// //         ),
// //         child: SizedBox(
// //           height: 52,
// //           child: ElevatedButton(
// //             onPressed: _isSubmitting ? null : _submit,
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor:         _primary,
// //               foregroundColor:         Colors.white,
// //               disabledBackgroundColor: _primary.withOpacity(0.6),
// //               shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(14)),
// //               elevation: 0,
// //             ),
// //             child: _isSubmitting
// //                 ? const SizedBox(
// //                 width: 22, height: 22,
// //                 child: CircularProgressIndicator(
// //                     strokeWidth: 2.5, color: Colors.white))
// //                 : const Row(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 Icon(Icons.person_add_alt_1_rounded, size: 20),
// //                 SizedBox(width: 8),
// //                 Text('Register Wagers',
// //                     style: TextStyle(
// //                         fontSize: 16, fontWeight: FontWeight.w700)),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Section Header  — FIX: Text wrapped in Flexible to prevent overflow
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _SectionHeader extends StatelessWidget {
// //   final IconData icon;
// //   final String   label;
// //   const _SectionHeader({required this.icon, required this.label});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Row(
// //       children: [
// //         Container(
// //           width: 4, height: 26,
// //           decoration: BoxDecoration(
// //             color: const Color(0xFF0C6B64),
// //             borderRadius: BorderRadius.circular(4),
// //           ),
// //         ),
// //         const SizedBox(width: 10),
// //         Container(
// //           width: 32, height: 32,
// //           decoration: BoxDecoration(
// //             color: const Color(0xFFD4F0ED),
// //             borderRadius: BorderRadius.circular(9),
// //           ),
// //           child: Icon(icon, color: const Color(0xFF0C6B64), size: 17),
// //         ),
// //         const SizedBox(width: 10),
// //         // ✅ FIX: Flexible prevents 6.6px overflow on right
// //         Flexible(
// //           child: Text(
// //             label,
// //             overflow: TextOverflow.ellipsis,
// //             style: const TextStyle(
// //               fontSize: 16, fontWeight: FontWeight.w700,
// //               color: Color(0xFF0C6B64),
// //             ),
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Field Card
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _FieldCard extends StatelessWidget {
// //   final String                     label;
// //   final TextEditingController      controller;
// //   final IconData                   icon;
// //   final String                     hint;
// //   final TextInputType?             keyboardType;
// //   final List<TextInputFormatter>?  inputFormatters;
// //   final String? Function(String?)? validator;
// //   final int                        maxLines;
// //   final bool                       readOnly;
// //   final VoidCallback?              onTap;
// //   final bool                       showArrow;
// //   final bool                       showLock;
// //   final bool                       isOptional;
// //
// //   static const _primary  = Color(0xFF0C6B64);
// //   static const _textDark = Color(0xFF1A2E2C);
// //
// //   const _FieldCard({
// //     required this.label,
// //     required this.controller,
// //     required this.icon,
// //     required this.hint,
// //     this.keyboardType,
// //     this.inputFormatters,
// //     this.validator,
// //     this.maxLines   = 1,
// //     this.readOnly   = false,
// //     this.onTap,
// //     this.showArrow  = false,
// //     this.showLock   = false,
// //     this.isOptional = false,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //       decoration: BoxDecoration(
// //         color: readOnly && showLock
// //             ? const Color(0xFFF5FFFE)
// //             : Colors.white,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
// //       ),
// //       child: Row(
// //         crossAxisAlignment: CrossAxisAlignment.center,
// //         children: [
// //           Icon(icon, color: _primary, size: 22),
// //           const SizedBox(width: 12),
// //           Expanded(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 Row(children: [
// //                   // ✅ FIX: Flexible prevents overflow when label is long
// //                   Flexible(
// //                     child: Text(
// //                       label,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: const TextStyle(
// //                         fontSize: 12, fontWeight: FontWeight.w500,
// //                         color: Color(0xFF6B7280),
// //                       ),
// //                     ),
// //                   ),
// //                   if (isOptional) ...[
// //                     const SizedBox(width: 4),
// //                     Container(
// //                       padding: const EdgeInsets.symmetric(
// //                           horizontal: 5, vertical: 1),
// //                       decoration: BoxDecoration(
// //                         color: const Color(0xFFE5F7F5),
// //                         borderRadius: BorderRadius.circular(4),
// //                       ),
// //                       child: const Text('Optional',
// //                           style: TextStyle(
// //                             fontSize: 9, color: Color(0xFF0C6B64),
// //                             fontWeight: FontWeight.w500,
// //                           )),
// //                     ),
// //                   ],
// //                 ]),
// //                 const SizedBox(height: 2),
// //                 TextFormField(
// //                   controller:      controller,
// //                   keyboardType:    keyboardType,
// //                   inputFormatters: inputFormatters,
// //                   validator:       validator,
// //                   maxLines:        maxLines,
// //                   readOnly:        readOnly,
// //                   onTap:           onTap,
// //                   style: TextStyle(
// //                     fontSize: 15, fontWeight: FontWeight.w600,
// //                     color: readOnly && showLock
// //                         ? const Color(0xFF0C6B64)
// //                         : _textDark,
// //                   ),
// //                   decoration: InputDecoration(
// //                     hintText:  hint,
// //                     hintStyle: const TextStyle(
// //                       fontSize: 15, fontWeight: FontWeight.w400,
// //                       color: Color(0xFFB0BAC7),
// //                     ),
// //                     isDense: true,
// //                     border:  InputBorder.none,
// //                     contentPadding: EdgeInsets.zero,
// //                     errorStyle: const TextStyle(fontSize: 11),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           if (showArrow)
// //             const Icon(Icons.chevron_right_rounded,
// //                 color: Color(0xFFB0BAC7), size: 22)
// //           else if (showLock)
// //             const Icon(Icons.lock_rounded,
// //                 color: Color(0xFF0C6B64), size: 16)
// //           else
// //             const Icon(Icons.lock_outline_rounded,
// //                 color: Color(0xFFCDD5DC), size: 18),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Dropdown Card
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _DropdownCard extends StatelessWidget {
// //   final String                     topLabel;
// //   final Color                      topLabelColor;
// //   final String?                    value;
// //   final IconData                   icon;
// //   final List<String>               items;
// //   final ValueChanged<String?>      onChanged;
// //   final String? Function(String?)? validator;
// //
// //   static const _textDark = Color(0xFF1A2E2C);
// //
// //   const _DropdownCard({
// //     required this.topLabel,
// //     required this.topLabelColor,
// //     required this.value,
// //     required this.icon,
// //     required this.items,
// //     required this.onChanged,
// //     this.validator,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Text(topLabel,
// //               style: TextStyle(
// //                 fontSize: 12, fontWeight: FontWeight.w600,
// //                 color: topLabelColor,
// //               )),
// //           const SizedBox(height: 4),
// //           DropdownButtonFormField<String>(
// //             value:      value,
// //             onChanged:  onChanged,
// //             validator:  validator,
// //             isDense:    true,
// //             isExpanded: true,
// //             style: const TextStyle(
// //               fontSize: 15, fontWeight: FontWeight.w600, color: _textDark,
// //             ),
// //             decoration: InputDecoration(
// //               isDense: true,
// //               border:  InputBorder.none,
// //               contentPadding: EdgeInsets.zero,
// //               prefixIcon: Padding(
// //                 padding: const EdgeInsets.only(right: 8),
// //                 child: Icon(icon, color: topLabelColor, size: 18),
// //               ),
// //               prefixIconConstraints:
// //               const BoxConstraints(minWidth: 26, minHeight: 0),
// //               errorStyle: const TextStyle(fontSize: 11),
// //             ),
// //             icon: const Icon(Icons.keyboard_arrow_down_rounded,
// //                 color: Color(0xFFD97706), size: 20),
// //             dropdownColor: Colors.white,
// //             borderRadius:  BorderRadius.circular(12),
// //             items: items
// //                 .map((e) => DropdownMenuItem(value: e, child: Text(e)))
// //                 .toList(),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // CNIC Formatter  →  12345-1234567-1
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _CnicInputFormatter extends TextInputFormatter {
// //   @override
// //   TextEditingValue formatEditUpdate(
// //       TextEditingValue oldValue, TextEditingValue newValue) {
// //     final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
// //     final buffer = StringBuffer();
// //     for (int i = 0; i < digits.length && i < 13; i++) {
// //       if (i == 5 || i == 12) buffer.write('-');
// //       buffer.write(digits[i]);
// //     }
// //     final text = buffer.toString();
// //     return TextEditingValue(
// //       text: text, selection: TextSelection.collapsed(offset: text.length),
// //     );
// //   }
// // }
//
//
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/io_client.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../Database/db_helper.dart';
//
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // Wagers_register_screen.dart
// // ═══════════════════════════════════════════════════════════════════════════════
//
// class WagersRegisterScreen extends StatefulWidget {
//   const WagersRegisterScreen({super.key});
//
//   @override
//   State<WagersRegisterScreen> createState() => _WagersRegisterScreenState();
// }
//
// class _WagersRegisterScreenState extends State<WagersRegisterScreen> {
//   final _formKey      = GlobalKey<FormState>();
//   bool  _isSubmitting = false;
//   bool  _loadingEmpId = true;
//
//   static const _primary = Color(0xFF0C6B64);
//   static const _bg      = Color(0xFFE8F5F3);
//
//   // ── Controllers ──────────────────────────────────────────────────────────────
//   final _empIdCtrl      = TextEditingController();   // read-only, auto-filled
//   final _empNameCtrl    = TextEditingController();
//   final _depIdCtrl      = TextEditingController();
//   final _depNameCtrl    = TextEditingController();
//   final _fatherNameCtrl = TextEditingController();
//   final _cnicCtrl       = TextEditingController();
//   final _contactCtrl    = TextEditingController();
//   final _salaryCtrl     = TextEditingController();
//   final _dobCtrl        = TextEditingController();
//   final _emailCtrl      = TextEditingController();
//   final _addressCtrl    = TextEditingController();
//   final _entryTimeCtrl  = TextEditingController();
//   final _endTimeCtrl    = TextEditingController();
//   String? _selectedGender;
//
//   // ── Stored login ID & company code (hidden from UI) ───────────────────────
//   String _loginId     = '';
//   String _companyCode = '';   // hidden — loaded from SharedPreferences, sent via API
//
//   @override
//   void initState() {
//     super.initState();
//     _loadLoginIdAndGenerateEmpId();
//   }
//
//   // ── Load loginId + companyCode from SharedPreferences & build next EMP_ID ──
//   // Future<void> _loadLoginIdAndGenerateEmpId() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //
//   //   // Your app stores the logged-in Wagers's ID under 'emp_id'
//   //   _loginId     = (prefs.getInt('emp_id') ?? prefs.getString('emp_id') ?? '0').toString();
//   //   _companyCode = DBHelper.getCompanyCode() ?? '';
//   //
//   //   // Counter key unique to this loginId so each user has own sequence
//   //   final counterKey = 'emp_register_counter_$_loginId';
//   //   int counter = (prefs.getInt(counterKey) ?? 0) + 1;
//   //   await prefs.setInt(counterKey, counter);
//   //
//   //   // Format:  27  +  01 / 02 / 03 ...  (2-digit padded sequence)
//   //   final newEmpId = '$_loginId${counter.toString().padLeft(2, '0')}';
//   //
//   //   setState(() {
//   //     _empIdCtrl.text = newEmpId;
//   //     _loadingEmpId   = false;
//   //   });
//   // }
//
//   Future<void> _loadLoginIdAndGenerateEmpId() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     _loginId     = (prefs.getInt('emp_id') ?? prefs.getString('emp_id') ?? '0').toString();
//     _companyCode = DBHelper.getCompanyCode() ?? '';
//
//     try {
//       final ioClient = IOClient(
//         HttpClient()..badCertificateCallback = (cert, host, port) => true,
//       );
//
//       // Pass loginId as parameter — API filters by THIS employee only
//       final uri = Uri.parse(
//           'https://oracle.metaxperts.net/ords/gps_workforce/wagerid/get/?emp_id=$_loginId&company_code=$_companyCode'
//       );
//       final response = await ioClient.get(uri).timeout(const Duration(seconds: 10));
//
// // DEBUG
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       debugPrint('📡 WAGER ID API');
//       debugPrint('   URL    : $uri');
//       debugPrint('   STATUS : ${response.statusCode}');
//       debugPrint('   BODY   : ${response.body}');
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//       if (response.statusCode == 200) {
//         final data     = jsonDecode(response.body);
//         final items    = data['items'] as List;
//         final maxRaw   = items.isNotEmpty ? items[0]['max_wager_id'] : null;
//         final maxId    = maxRaw != null ? int.tryParse(maxRaw.toString()) ?? 0 : 0;
//
//         int nextSuffix = 1;
//         if (maxId > 0) {
//           final suffixStr    = maxId.toString().substring(_loginId.length);
//           final currentSuffix = int.tryParse(suffixStr) ?? 0;
//           nextSuffix         = currentSuffix + 1;
//         }
//
//         final newEmpId = '$_loginId${nextSuffix.toString().padLeft(2, '0')}';
//
//         setState(() {
//           _empIdCtrl.text = newEmpId;
//           _loadingEmpId   = false;
//         });
//       } else {
//         _showErrorAndPop('Server error: ${response.statusCode}');
//       }
//     } catch (e) {
//       _showErrorAndPop('Could not load Employee ID. Check your connection.');
//     }
//   }
//
//   void _showErrorAndPop(String msg) {
//     setState(() => _loadingEmpId = false);
//     Get.snackbar(
//       'Error', msg,
//       snackPosition:   SnackPosition.BOTTOM,
//       backgroundColor: Colors.red.shade700,
//       colorText:       Colors.white,
//       duration:        const Duration(seconds: 3),
//     );
//   }
//
// // Fallback: local SharedPreferences counter (offline safety net)
//   void _fallbackToLocalCounter(SharedPreferences prefs) {
//     final counterKey = 'emp_register_counter_$_loginId';
//     int counter = (prefs.getInt(counterKey) ?? 0) + 1;
//     prefs.setInt(counterKey, counter);
//
//     setState(() {
//       _empIdCtrl.text = '$_loginId${counter.toString().padLeft(2, '0')}';
//       _loadingEmpId   = false;
//     });
//   }
//
//
//   @override
//   void dispose() {
//     _empIdCtrl.dispose();      _empNameCtrl.dispose();
//     _depIdCtrl.dispose();      _depNameCtrl.dispose();
//     _fatherNameCtrl.dispose(); _cnicCtrl.dispose();
//     _contactCtrl.dispose();    _salaryCtrl.dispose();
//     _dobCtrl.dispose();        _emailCtrl.dispose();
//     _addressCtrl.dispose();    _entryTimeCtrl.dispose();
//     _endTimeCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── Date Picker ───────────────────────────────────────────────────────────
//   Future<void> _pickDate() async {
//     final picked = await showDatePicker(
//       context:     context,
//       initialDate: DateTime(1990),
//       firstDate:   DateTime(1950),
//       lastDate:    DateTime.now(),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: const ColorScheme.light(
//             primary: _primary, onPrimary: Colors.white, surface: Colors.white,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       _dobCtrl.text =
//       '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
//     }
//   }
//
//   // ── Time Picker ───────────────────────────────────────────────────────────
//   Future<void> _pickTime(TextEditingController ctrl) async {
//     final picked = await showTimePicker(
//       context:     context,
//       initialTime: TimeOfDay.now(),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: const ColorScheme.light(
//             primary: _primary, onPrimary: Colors.white, surface: Colors.white,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) {
//       final hour   = picked.hour.toString().padLeft(2, '0');
//       final minute = picked.minute.toString().padLeft(2, '0');
//       ctrl.text = '$hour:$minute';
//     }
//   }
//
//   // ── Submit ────────────────────────────────────────────────────────────────
//   // ── Submit ────────────────────────────────────────────────────────────────
//   // ── Submit ────────────────────────────────────────────────────────────────
//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     // Don't show loading state - just navigate back immediately
//     // or show a quick snackbar without blocking
//
//     try {
//       final body = {
//         'company_code':      _companyCode,
//         'wager_id':          _empIdCtrl.text,
//         'wager_name':        _empNameCtrl.text.trim(),
//         'dep_id':            _depIdCtrl.text.trim(),
//         'dep_name':          _depNameCtrl.text.trim(),
//         'father_name':       _fatherNameCtrl.text.trim(),
//         'cnic_no':           _cnicCtrl.text.trim(),
//         'contact_no':        _contactCtrl.text.trim(),
//         'email':             _emailCtrl.text.trim(),
//         'address':           _addressCtrl.text.trim(),
//         'gender':            _selectedGender ?? '',
//         'dob':               _dobCtrl.text,
//         'basic_salary':      _salaryCtrl.text,
//         'entry_time':        _entryTimeCtrl.text,
//         'end_time':          _endTimeCtrl.text,
//         'timekeeper_emp_id': _loginId,
//         'status':            'active',
//       };
//
//       // Show loading snackbar (optional - just for user feedback)
//       final loadingSnackbar = Get.snackbar(
//         'Please wait', 'Registering Wagers...',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: _primary.withOpacity(0.93),
//         colorText: Colors.white,
//         duration: const Duration(seconds: 1),
//         borderRadius: 14,
//       );
//
//       // Make API call in background
//       http.post(
//         Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagerregister/post/'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(body),
//       ).then((response) {
//         // Handle response in background
//         if (response.statusCode == 200 || response.statusCode == 201) {
//           debugPrint('✅ Wager registered successfully');
//         } else {
//           debugPrint('❌ Registration failed: ${response.body}');
//         }
//       }).catchError((e) {
//         debugPrint('❌ Network error: $e');
//       });
//
//       // ✅ Immediately navigate back with success message
//       Get.back(); // Close the register screen
//
//       // ✅ Show success snackbar on previous screen
//       Get.snackbar(
//         'Success', 'Wagers registered successfully!',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: _primary.withOpacity(0.93),
//         colorText: Colors.white,
//         borderRadius: 14,
//         margin: const EdgeInsets.all(16),
//         duration: const Duration(seconds: 2),
//         icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
//       );
//
//     } catch (e) {
//       // Show error on current screen
//       Get.snackbar(
//         'Error', 'Registration failed. Please try again.',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.red.shade700,
//         colorText: Colors.white,
//         borderRadius: 14,
//         margin: const EdgeInsets.all(16),
//         duration: const Duration(seconds: 3),
//       );
//     }
//   }
//
// // ── Clear Form Method ──────────────────────────────────────────────
//   void _clearForm() {
//     // Clear all text controllers
//     _empNameCtrl.clear();
//     _depIdCtrl.clear();
//     _depNameCtrl.clear();
//     _fatherNameCtrl.clear();
//     _cnicCtrl.clear();
//     _contactCtrl.clear();
//     _salaryCtrl.clear();
//     _dobCtrl.clear();
//     _emailCtrl.clear();
//     _addressCtrl.clear();
//     _entryTimeCtrl.clear();
//     _endTimeCtrl.clear();
//
//     // Clear gender selection
//     _selectedGender = null;
//
//     // Reset form validation state
//     _formKey.currentState?.reset();
//
//     // Note: EMP_ID is auto-generated and will be regenerated when screen reopens
//     // because _loadLoginIdAndGenerateEmpId() runs in initState
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _bg,
//       body: Column(
//         children: [
//
//           // ── Gradient Header ────────────────────────────────────────────
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
//                 begin:  Alignment.topLeft,
//                 end:    Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.only(
//                 bottomLeft:  Radius.circular(28),
//                 bottomRight: Radius.circular(28),
//               ),
//             ),
//             child: SafeArea(
//               bottom: false,
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
//                 child: Row(
//                   children: [
//                     GestureDetector(
//                       onTap: () => Get.back(),
//                       child: Container(
//                         width: 42, height: 42,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(13),
//                         ),
//                         child: const Icon(Icons.arrow_back_ios_new_rounded,
//                             color: Colors.white, size: 18),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     const Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text('Wagers Register',
//                               style: TextStyle(fontSize: 22,
//                                   fontWeight: FontWeight.w700, color: Colors.white)),
//                           SizedBox(height: 2),
//                           Text('Enroll a new Wagers',
//                               style: TextStyle(fontSize: 13, color: Colors.white70)),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(13),
//                       ),
//                       child: const Icon(Icons.person_add_alt_1_rounded,
//                           color: Colors.white, size: 20),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           // ── Form ──────────────────────────────────────────────────────
//           Expanded(
//             child: Form(
//               key: _formKey,
//               child: ListView(
//                 padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
//                 children: [
//
//                   // ── Wagers Info ──────────────────────────────────────
//                   _SectionHeader(icon: Icons.person_rounded, label: 'Wagers Info'),
//                   const SizedBox(height: 12),
//
//                   // EMP ID — read-only, auto-generated
//                   _FieldCard(
//                     label:      'Wagers ID',
//                     controller: _empIdCtrl,
//                     icon:       Icons.badge_rounded,
//                     hint:       _loadingEmpId ? 'Generating...' : _empIdCtrl.text,
//                     readOnly:   true,
//                     showLock:   true,
//                     validator:  null,
//                   ),
//                   const SizedBox(height: 10),
//
//                   _FieldCard(
//                     label:      'Wagers Name',
//                     controller: _empNameCtrl,
//                     icon:       Icons.person_rounded,
//                     hint:       'Full name',
//                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   // ── Department Info ────────────────────────────────────
//                   _SectionHeader(icon: Icons.corporate_fare_rounded, label: 'Department Info'),
//                   const SizedBox(height: 12),
//
//                   _FieldCard(
//                     label:            'Department ID',
//                     controller:       _depIdCtrl,
//                     icon:             Icons.corporate_fare_rounded,
//                     hint:             'Enter department ID',
//                     keyboardType:     TextInputType.number,
//                     inputFormatters:  [FilteringTextInputFormatter.digitsOnly],
//                     validator:        (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                   ),
//                   const SizedBox(height: 10),
//                   _FieldCard(
//                     label:      'Department Name',
//                     controller: _depNameCtrl,
//                     icon:       Icons.business_rounded,
//                     hint:       'e.g. Human Resources',
//                     isOptional: true,
//                     validator:  null,
//                   ),
//                   const SizedBox(height: 10),
//                   _FieldCard(
//                     label:      'Father Name',
//                     controller: _fatherNameCtrl,
//                     icon:       Icons.people_rounded,
//                     hint:       "Father's full name",
//                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   // ── Identity & Contact ─────────────────────────────────
//                   _SectionHeader(icon: Icons.contact_phone_rounded, label: 'Identity & Contact'),
//                   const SizedBox(height: 12),
//
//                   _FieldCard(
//                     label:           'CNIC No.',
//                     controller:      _cnicCtrl,
//                     icon:            Icons.credit_card_rounded,
//                     hint:            '12345-1234567-1',
//                     keyboardType:    TextInputType.number,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       _CnicInputFormatter(),
//                     ],
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return 'Required';
//                       if (v.replaceAll('-', '').length != 13)
//                         return 'Enter valid 13-digit CNIC';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),
//
//                   // Contact — max 11 digits
//                   _FieldCard(
//                     label:           'Contact No.',
//                     controller:      _contactCtrl,
//                     icon:            Icons.phone_rounded,
//                     hint:            '03001234567',
//                     keyboardType:    TextInputType.phone,
//                     inputFormatters: [
//                       FilteringTextInputFormatter.digitsOnly,
//                       LengthLimitingTextInputFormatter(11),
//                     ],
//                     validator: (v) {
//                       if (v == null || v.isEmpty) return 'Required';
//                       if (v.length < 10) return 'Enter valid contact number';
//                       if (v.length > 11) return 'Maximum 11 digits allowed';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),
//
//                   // Email — optional
//                   _FieldCard(
//                     label:        'Email (optional)',
//                     controller:   _emailCtrl,
//                     icon:         Icons.email_rounded,
//                     hint:         'Wagers@company.com',
//                     keyboardType: TextInputType.emailAddress,
//                     isOptional:   true,
//                     validator: (v) {
//                       if (v != null && v.isNotEmpty && !GetUtils.isEmail(v))
//                         return 'Enter valid email';
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 10),
//                   _FieldCard(
//                     label:      'Address',
//                     controller: _addressCtrl,
//                     icon:       Icons.location_on_rounded,
//                     hint:       'Full residential address',
//                     maxLines:   3,
//                     validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
//                   ),
//
//                   const SizedBox(height: 20),
//
//                   // ── Personal & Salary ──────────────────────────────────
//                   _SectionHeader(icon: Icons.tune_rounded, label: 'Personal & Salary'),
//                   const SizedBox(height: 12),
//
//                   _FieldCard(
//                     label:      'Date of Birth',
//                     controller: _dobCtrl,
//                     icon:       Icons.cake_rounded,
//                     hint:       'Tap to select date',
//                     readOnly:   true,
//                     onTap:      _pickDate,
//                     showArrow:  true,
//                     validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                   ),
//                   const SizedBox(height: 10),
//
//                   // Gender + Salary side by side
//                   Row(children: [
//                     Expanded(
//                       child: _DropdownCard(
//                         topLabel:      'Gender',
//                         topLabelColor: const Color(0xFF0C6B64),
//                         value:         _selectedGender,
//                         icon:          Icons.wc_rounded,
//                         items:         const ['Male', 'Female', 'Other'],
//                         onChanged:     (v) => setState(() => _selectedGender = v),
//                         validator:     (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: _FieldCard(
//                         label:           'Monthly Salary',
//                         controller:      _salaryCtrl,
//                         icon:            Icons.payments_rounded,
//                         hint:            'Amount in PKR',
//                         keyboardType:    TextInputType.number,
//                         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                         validator:       (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                       ),
//                     ),
//                   ]),
//
//                   const SizedBox(height: 20),
//
//                   // ── Timing ─────────────────────────────────────────────
//                   _SectionHeader(icon: Icons.access_time_rounded, label: 'Work Timing'),
//                   const SizedBox(height: 12),
//
//                   // Entry + End time side by side
//                   Row(children: [
//                     Expanded(
//                       child: _FieldCard(
//                         label:      'Entry Time',
//                         controller: _entryTimeCtrl,
//                         icon:       Icons.login_rounded,
//                         hint:       'Tap to select',
//                         readOnly:   true,
//                         onTap:      () => _pickTime(_entryTimeCtrl),
//                         showArrow:  true,
//                         validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: _FieldCard(
//                         label:      'End Time',
//                         controller: _endTimeCtrl,
//                         icon:       Icons.logout_rounded,
//                         hint:       'Tap to select',
//                         readOnly:   true,
//                         onTap:      () => _pickTime(_endTimeCtrl),
//                         showArrow:  true,
//                         validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                       ),
//                     ),
//                   ]),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//
//       // ── Submit Button ──────────────────────────────────────────────────
//       bottomNavigationBar: Container(
//         padding: EdgeInsets.fromLTRB(
//             16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.07),
//               blurRadius: 12, offset: const Offset(0, -3),
//             )
//           ],
//         ),
//         child: SizedBox(
//           height: 52,
//           child: ElevatedButton(
//             onPressed: _isSubmitting ? null : _submit,
//             style: ElevatedButton.styleFrom(
//               backgroundColor:         _primary,
//               foregroundColor:         Colors.white,
//               disabledBackgroundColor: _primary.withOpacity(0.6),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14)),
//               elevation: 0,
//             ),
//             child: _isSubmitting
//                 ? const SizedBox(
//                 width: 22, height: 22,
//                 child: CircularProgressIndicator(
//                     strokeWidth: 2.5, color: Colors.white))
//                 : const Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.person_add_alt_1_rounded, size: 20),
//                 SizedBox(width: 8),
//                 Text('Register Wagers',
//                     style: TextStyle(
//                         fontSize: 16, fontWeight: FontWeight.w700)),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Section Header  — FIX: Text wrapped in Flexible to prevent overflow
// // ─────────────────────────────────────────────────────────────────────────────
// class _SectionHeader extends StatelessWidget {
//   final IconData icon;
//   final String   label;
//   const _SectionHeader({required this.icon, required this.label});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           width: 4, height: 26,
//           decoration: BoxDecoration(
//             color: const Color(0xFF0C6B64),
//             borderRadius: BorderRadius.circular(4),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Container(
//           width: 32, height: 32,
//           decoration: BoxDecoration(
//             color: const Color(0xFFD4F0ED),
//             borderRadius: BorderRadius.circular(9),
//           ),
//           child: Icon(icon, color: const Color(0xFF0C6B64), size: 17),
//         ),
//         const SizedBox(width: 10),
//         // ✅ FIX: Flexible prevents 6.6px overflow on right
//         Flexible(
//           child: Text(
//             label,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//               fontSize: 16, fontWeight: FontWeight.w700,
//               color: Color(0xFF0C6B64),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Field Card
// // ─────────────────────────────────────────────────────────────────────────────
// class _FieldCard extends StatelessWidget {
//   final String                     label;
//   final TextEditingController      controller;
//   final IconData                   icon;
//   final String                     hint;
//   final TextInputType?             keyboardType;
//   final List<TextInputFormatter>?  inputFormatters;
//   final String? Function(String?)? validator;
//   final int                        maxLines;
//   final bool                       readOnly;
//   final VoidCallback?              onTap;
//   final bool                       showArrow;
//   final bool                       showLock;
//   final bool                       isOptional;
//
//   static const _primary  = Color(0xFF0C6B64);
//   static const _textDark = Color(0xFF1A2E2C);
//
//   const _FieldCard({
//     required this.label,
//     required this.controller,
//     required this.icon,
//     required this.hint,
//     this.keyboardType,
//     this.inputFormatters,
//     this.validator,
//     this.maxLines   = 1,
//     this.readOnly   = false,
//     this.onTap,
//     this.showArrow  = false,
//     this.showLock   = false,
//     this.isOptional = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: readOnly && showLock
//             ? const Color(0xFFF5FFFE)
//             : Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Icon(icon, color: _primary, size: 22),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(children: [
//                   // ✅ FIX: Flexible prevents overflow when label is long
//                   Flexible(
//                     child: Text(
//                       label,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 12, fontWeight: FontWeight.w500,
//                         color: Color(0xFF6B7280),
//                       ),
//                     ),
//                   ),
//                   if (isOptional) ...[
//                     const SizedBox(width: 4),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 5, vertical: 1),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFE5F7F5),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: const Text('Optional',
//                           style: TextStyle(
//                             fontSize: 9, color: Color(0xFF0C6B64),
//                             fontWeight: FontWeight.w500,
//                           )),
//                     ),
//                   ],
//                 ]),
//                 const SizedBox(height: 2),
//                 TextFormField(
//                   controller:      controller,
//                   keyboardType:    keyboardType,
//                   inputFormatters: inputFormatters,
//                   validator:       validator,
//                   maxLines:        maxLines,
//                   readOnly:        readOnly,
//                   onTap:           onTap,
//                   style: TextStyle(
//                     fontSize: 15, fontWeight: FontWeight.w600,
//                     color: readOnly && showLock
//                         ? const Color(0xFF0C6B64)
//                         : _textDark,
//                   ),
//                   decoration: InputDecoration(
//                     hintText:  hint,
//                     hintStyle: const TextStyle(
//                       fontSize: 15, fontWeight: FontWeight.w400,
//                       color: Color(0xFFB0BAC7),
//                     ),
//                     isDense: true,
//                     border:  InputBorder.none,
//                     contentPadding: EdgeInsets.zero,
//                     errorStyle: const TextStyle(fontSize: 11),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (showArrow)
//             const Icon(Icons.chevron_right_rounded,
//                 color: Color(0xFFB0BAC7), size: 22)
//           else if (showLock)
//             const Icon(Icons.lock_rounded,
//                 color: Color(0xFF0C6B64), size: 16)
//           else
//             const Icon(Icons.lock_outline_rounded,
//                 color: Color(0xFFCDD5DC), size: 18),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Dropdown Card
// // ─────────────────────────────────────────────────────────────────────────────
// class _DropdownCard extends StatelessWidget {
//   final String                     topLabel;
//   final Color                      topLabelColor;
//   final String?                    value;
//   final IconData                   icon;
//   final List<String>               items;
//   final ValueChanged<String?>      onChanged;
//   final String? Function(String?)? validator;
//
//   static const _textDark = Color(0xFF1A2E2C);
//
//   const _DropdownCard({
//     required this.topLabel,
//     required this.topLabelColor,
//     required this.value,
//     required this.icon,
//     required this.items,
//     required this.onChanged,
//     this.validator,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(topLabel,
//               style: TextStyle(
//                 fontSize: 12, fontWeight: FontWeight.w600,
//                 color: topLabelColor,
//               )),
//           const SizedBox(height: 4),
//           DropdownButtonFormField<String>(
//             value:      value,
//             onChanged:  onChanged,
//             validator:  validator,
//             isDense:    true,
//             isExpanded: true,
//             style: const TextStyle(
//               fontSize: 15, fontWeight: FontWeight.w600, color: _textDark,
//             ),
//             decoration: InputDecoration(
//               isDense: true,
//               border:  InputBorder.none,
//               contentPadding: EdgeInsets.zero,
//               prefixIcon: Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: Icon(icon, color: topLabelColor, size: 18),
//               ),
//               prefixIconConstraints:
//               const BoxConstraints(minWidth: 26, minHeight: 0),
//               errorStyle: const TextStyle(fontSize: 11),
//             ),
//             icon: const Icon(Icons.keyboard_arrow_down_rounded,
//                 color: Color(0xFFD97706), size: 20),
//             dropdownColor: Colors.white,
//             borderRadius:  BorderRadius.circular(12),
//             items: items
//                 .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                 .toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CNIC Formatter  →  12345-1234567-1
// // ─────────────────────────────────────────────────────────────────────────────
// class _CnicInputFormatter extends TextInputFormatter {
//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue oldValue, TextEditingValue newValue) {
//     final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
//     final buffer = StringBuffer();
//     for (int i = 0; i < digits.length && i < 13; i++) {
//       if (i == 5 || i == 12) buffer.write('-');
//       buffer.write(digits[i]);
//     }
//     final text = buffer.toString();
//     return TextEditingValue(
//       text: text, selection: TextSelection.collapsed(offset: text.length),
//     );
//   }
// }


import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Database/db_helper.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// Wagers_register_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class WagersRegisterScreen extends StatefulWidget {
  const WagersRegisterScreen({super.key});

  @override
  State<WagersRegisterScreen> createState() => _WagersRegisterScreenState();
}

class _WagersRegisterScreenState extends State<WagersRegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  bool  _isSubmitting = false;
  bool  _loadingEmpId = true;

  static const _primary = Color(0xFF1A6E59); // Updated to Navbar dark teal
  static const _bg      = Color(0xFFE8F5F3);

  // ── Controllers ──────────────────────────────────────────────────────────────
  final _empIdCtrl      = TextEditingController();   // read-only, auto-filled
  final _empNameCtrl    = TextEditingController();
  final _depIdCtrl      = TextEditingController();
  final _depNameCtrl    = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _cnicCtrl       = TextEditingController();
  final _contactCtrl    = TextEditingController();
  final _salaryCtrl     = TextEditingController();
  final _dobCtrl        = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _entryTimeCtrl  = TextEditingController();
  final _endTimeCtrl    = TextEditingController();
  String? _selectedGender;

  // ── Stored login ID & company code (hidden from UI) ───────────────────────
  String _loginId     = '';
  String _companyCode = '';   // hidden — loaded from SharedPreferences, sent via API

  @override
  void initState() {
    super.initState();
    _loadLoginIdAndGenerateEmpId();
  }

  // ── Load loginId + companyCode from SharedPreferences & build next EMP_ID ──
  Future<void> _loadLoginIdAndGenerateEmpId() async {
    final prefs = await SharedPreferences.getInstance();

    _loginId     = (prefs.getInt('emp_id') ?? prefs.getString('emp_id') ?? '0').toString();
    _companyCode = DBHelper.getCompanyCode() ?? '';

    try {
      final ioClient = IOClient(
        HttpClient()..badCertificateCallback = (cert, host, port) => true,
      );

      // Pass loginId as parameter — API filters by THIS employee only
      final uri = Uri.parse(
          'https://oracle.metaxperts.net/ords/gps_workforce/wagerid/get/?emp_id=$_loginId&company_code=$_companyCode'
      );
      final response = await ioClient.get(uri).timeout(const Duration(seconds: 10));

// DEBUG
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 WAGER ID API');
      debugPrint('   URL    : $uri');
      debugPrint('   STATUS : ${response.statusCode}');
      debugPrint('   BODY   : ${response.body}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (response.statusCode == 200) {
        final data     = jsonDecode(response.body);
        final items    = data['items'] as List;
        final maxRaw   = items.isNotEmpty ? items[0]['max_wager_id'] : null;
        final maxId    = maxRaw != null ? int.tryParse(maxRaw.toString()) ?? 0 : 0;

        int nextSuffix = 1;
        if (maxId > 0) {
          final suffixStr    = maxId.toString().substring(_loginId.length);
          final currentSuffix = int.tryParse(suffixStr) ?? 0;
          nextSuffix         = currentSuffix + 1;
        }

        final newEmpId = '$_loginId${nextSuffix.toString().padLeft(2, '0')}';

        setState(() {
          _empIdCtrl.text = newEmpId;
          _loadingEmpId   = false;
        });
      } else {
        _showErrorAndPop('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorAndPop('Could not load Employee ID. Check your connection.');
    }
  }

  void _showErrorAndPop(String msg) {
    setState(() => _loadingEmpId = false);
    Get.snackbar(
      'Error', msg,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText:       Colors.white,
      duration:        const Duration(seconds: 3),
    );
  }

// Fallback: local SharedPreferences counter (offline safety net)
  void _fallbackToLocalCounter(SharedPreferences prefs) {
    final counterKey = 'emp_register_counter_$_loginId';
    int counter = (prefs.getInt(counterKey) ?? 0) + 1;
    prefs.setInt(counterKey, counter);

    setState(() {
      _empIdCtrl.text = '$_loginId${counter.toString().padLeft(2, '0')}';
      _loadingEmpId   = false;
    });
  }


  @override
  void dispose() {
    _empIdCtrl.dispose();      _empNameCtrl.dispose();
    _depIdCtrl.dispose();      _depNameCtrl.dispose();
    _fatherNameCtrl.dispose(); _cnicCtrl.dispose();
    _contactCtrl.dispose();    _salaryCtrl.dispose();
    _dobCtrl.dispose();        _emailCtrl.dispose();
    _addressCtrl.dispose();    _entryTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  // ── Date Picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime(1990),
      firstDate:   DateTime(1950),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary, onPrimary: Colors.white, surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text =
      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  // ── Time Picker ───────────────────────────────────────────────────────────
  Future<void> _pickTime(TextEditingController ctrl) async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary, onPrimary: Colors.white, surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final hour   = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      ctrl.text = '$hour:$minute';
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final body = {
        'company_code':      _companyCode,
        'wager_id':          _empIdCtrl.text,
        'wager_name':        _empNameCtrl.text.trim(),
        'dep_id':            _depIdCtrl.text.trim(),
        'dep_name':          _depNameCtrl.text.trim(),
        'father_name':       _fatherNameCtrl.text.trim(),
        'cnic_no':           _cnicCtrl.text.trim(),
        'contact_no':        _contactCtrl.text.trim(),
        'email':             _emailCtrl.text.trim(),
        'address':           _addressCtrl.text.trim(),
        'gender':            _selectedGender ?? '',
        'dob':               _dobCtrl.text,
        'basic_salary':      _salaryCtrl.text,
        'entry_time':        _entryTimeCtrl.text,
        'end_time':          _endTimeCtrl.text,
        'timekeeper_emp_id': _loginId,
        'status':            'active',
      };

      // Show loading snackbar (optional - just for user feedback)
      final loadingSnackbar = Get.snackbar(
        'Please wait', 'Registering Wagers...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _primary.withOpacity(0.93),
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
        borderRadius: 14,
      );

      // Make API call in background
      http.post(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagerregister/post/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).then((response) {
        // Handle response in background
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ Wager registered successfully');
        } else {
          debugPrint('❌ Registration failed: ${response.body}');
        }
      }).catchError((e) {
        debugPrint('❌ Network error: $e');
      });

      // ✅ Immediately navigate back with success message
      Get.back(); // Close the register screen

      // ✅ Show success snackbar on previous screen
      Get.snackbar(
        'Success', 'Wagers registered successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _primary.withOpacity(0.93),
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      );

    } catch (e) {
      // Show error on current screen
      Get.snackbar(
        'Error', 'Registration failed. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        borderRadius: 14,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    }
  }

// ── Clear Form Method ──────────────────────────────────────────────
  void _clearForm() {
    // Clear all text controllers
    _empNameCtrl.clear();
    _depIdCtrl.clear();
    _depNameCtrl.clear();
    _fatherNameCtrl.clear();
    _cnicCtrl.clear();
    _contactCtrl.clear();
    _salaryCtrl.clear();
    _dobCtrl.clear();
    _emailCtrl.clear();
    _addressCtrl.clear();
    _entryTimeCtrl.clear();
    _endTimeCtrl.clear();

    // Clear gender selection
    _selectedGender = null;

    // Reset form validation state
    _formKey.currentState?.reset();

    // Note: EMP_ID is auto-generated and will be regenerated when screen reopens
    // because _loadLoginIdAndGenerateEmpId() runs in initState
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [

          // ── Gradient Header with Navbar colors ────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3DAF93), Color(0xFF1A6E59)], // Navbar colors
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wagers Register',
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 2),
                          Text('Enroll a new Wagers',
                              style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                children: [

                  // ── Wagers Info ──────────────────────────────────────
                  _SectionHeader(icon: Icons.person_rounded, label: 'Wagers Info'),
                  const SizedBox(height: 12),

                  // EMP ID — read-only, auto-generated
                  _FieldCard(
                    label:      'Wagers ID',
                    controller: _empIdCtrl,
                    icon:       Icons.badge_rounded,
                    hint:       _loadingEmpId ? 'Generating...' : _empIdCtrl.text,
                    readOnly:   true,
                    showLock:   true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),

                  _FieldCard(
                    label:      'Wagers Name',
                    controller: _empNameCtrl,
                    icon:       Icons.person_rounded,
                    hint:       'Full name',
                    validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Department Info ────────────────────────────────────
                  _SectionHeader(icon: Icons.corporate_fare_rounded, label: 'Department Info'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:            'Department ID',
                    controller:       _depIdCtrl,
                    icon:             Icons.corporate_fare_rounded,
                    hint:             'Enter department ID',
                    keyboardType:     TextInputType.number,
                    inputFormatters:  [FilteringTextInputFormatter.digitsOnly],
                    validator:        (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  _FieldCard(
                    label:      'Department Name',
                    controller: _depNameCtrl,
                    icon:       Icons.business_rounded,
                    hint:       'e.g. Human Resources',
                    isOptional: true,
                    validator:  null,
                  ),
                  const SizedBox(height: 10),
                  _FieldCard(
                    label:      'Father Name',
                    controller: _fatherNameCtrl,
                    icon:       Icons.people_rounded,
                    hint:       "Father's full name",
                    validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Identity & Contact ─────────────────────────────────
                  _SectionHeader(icon: Icons.contact_phone_rounded, label: 'Identity & Contact'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:           'CNIC No.',
                    controller:      _cnicCtrl,
                    icon:            Icons.credit_card_rounded,
                    hint:            '12345-1234567-1',
                    keyboardType:    TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CnicInputFormatter(),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.replaceAll('-', '').length != 13)
                        return 'Enter valid 13-digit CNIC';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Contact — max 11 digits
                  _FieldCard(
                    label:           'Contact No.',
                    controller:      _contactCtrl,
                    icon:            Icons.phone_rounded,
                    hint:            '03001234567',
                    keyboardType:    TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 10) return 'Enter valid contact number';
                      if (v.length > 11) return 'Maximum 11 digits allowed';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Email — optional
                  _FieldCard(
                    label:        'Email (optional)',
                    controller:   _emailCtrl,
                    icon:         Icons.email_rounded,
                    hint:         'Wagers@company.com',
                    keyboardType: TextInputType.emailAddress,
                    isOptional:   true,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !GetUtils.isEmail(v))
                        return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _FieldCard(
                    label:      'Address',
                    controller: _addressCtrl,
                    icon:       Icons.location_on_rounded,
                    hint:       'Full residential address',
                    maxLines:   3,
                    validator:  (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Personal & Salary ──────────────────────────────────
                  _SectionHeader(icon: Icons.tune_rounded, label: 'Personal & Salary'),
                  const SizedBox(height: 12),

                  _FieldCard(
                    label:      'Date of Birth',
                    controller: _dobCtrl,
                    icon:       Icons.cake_rounded,
                    hint:       'Tap to select date',
                    readOnly:   true,
                    onTap:      _pickDate,
                    showArrow:  true,
                    validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  // Gender + Salary side by side
                  Row(children: [
                    Expanded(
                      child: _DropdownCard(
                        topLabel:      'Gender',
                        topLabelColor: const Color(0xFF1A6E59), // Updated to Navbar dark teal
                        value:         _selectedGender,
                        icon:          Icons.wc_rounded,
                        items:         const ['Male', 'Female', 'Other'],
                        onChanged:     (v) => setState(() => _selectedGender = v),
                        validator:     (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FieldCard(
                        label:           'Monthly Salary',
                        controller:      _salaryCtrl,
                        icon:            Icons.payments_rounded,
                        hint:            'Amount in PKR',
                        keyboardType:    TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator:       (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Timing ─────────────────────────────────────────────
                  _SectionHeader(icon: Icons.access_time_rounded, label: 'Work Timing'),
                  const SizedBox(height: 12),

                  // Entry + End time side by side
                  Row(children: [
                    Expanded(
                      child: _FieldCard(
                        label:      'Entry Time',
                        controller: _entryTimeCtrl,
                        icon:       Icons.login_rounded,
                        hint:       'Tap to select',
                        readOnly:   true,
                        onTap:      () => _pickTime(_entryTimeCtrl),
                        showArrow:  true,
                        validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FieldCard(
                        label:      'End Time',
                        controller: _endTimeCtrl,
                        icon:       Icons.logout_rounded,
                        hint:       'Tap to select',
                        readOnly:   true,
                        onTap:      () => _pickTime(_endTimeCtrl),
                        showArrow:  true,
                        validator:  (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Submit Button ──────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12, offset: const Offset(0, -3),
            )
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor:         _primary,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 20),
                SizedBox(width: 8),
                Text('Register Wagers',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header  — FIX: Text wrapped in Flexible to prevent overflow
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF1A6E59), // Updated to Navbar dark teal
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFD4F0ED),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: const Color(0xFF1A6E59), size: 17), // Updated to Navbar dark teal
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: Color(0xFF1A6E59), // Updated to Navbar dark teal
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Field Card
// ─────────────────────────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final String                     label;
  final TextEditingController      controller;
  final IconData                   icon;
  final String                     hint;
  final TextInputType?             keyboardType;
  final List<TextInputFormatter>?  inputFormatters;
  final String? Function(String?)? validator;
  final int                        maxLines;
  final bool                       readOnly;
  final VoidCallback?              onTap;
  final bool                       showArrow;
  final bool                       showLock;
  final bool                       isOptional;

  static const _primary  = Color(0xFF1A6E59); // Updated to Navbar dark teal
  static const _textDark = Color(0xFF1A2E2C);

  const _FieldCard({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLines   = 1,
    this.readOnly   = false,
    this.onTap,
    this.showArrow  = false,
    this.showLock   = false,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: readOnly && showLock
            ? const Color(0xFFF5FFFE)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (isOptional) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F7F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Optional',
                          style: TextStyle(
                            fontSize: 9, color: Color(0xFF1A6E59),
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                TextFormField(
                  controller:      controller,
                  keyboardType:    keyboardType,
                  inputFormatters: inputFormatters,
                  validator:       validator,
                  maxLines:        maxLines,
                  readOnly:        readOnly,
                  onTap:           onTap,
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: readOnly && showLock
                        ? const Color(0xFF1A6E59)
                        : _textDark,
                  ),
                  decoration: InputDecoration(
                    hintText:  hint,
                    hintStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w400,
                      color: Color(0xFFB0BAC7),
                    ),
                    isDense: true,
                    border:  InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFB0BAC7), size: 22)
          else if (showLock)
            const Icon(Icons.lock_rounded,
                color: Color(0xFF1A6E59), size: 16)
          else
            const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFCDD5DC), size: 18),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown Card
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownCard extends StatelessWidget {
  final String                     topLabel;
  final Color                      topLabelColor;
  final String?                    value;
  final IconData                   icon;
  final List<String>               items;
  final ValueChanged<String?>      onChanged;
  final String? Function(String?)? validator;

  static const _textDark = Color(0xFF1A2E2C);

  const _DropdownCard({
    required this.topLabel,
    required this.topLabelColor,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4F0ED), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(topLabel,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: topLabelColor,
              )),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value:      value,
            onChanged:  onChanged,
            validator:  validator,
            isDense:    true,
            isExpanded: true,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: _textDark,
            ),
            decoration: InputDecoration(
              isDense: true,
              border:  InputBorder.none,
              contentPadding: EdgeInsets.zero,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, color: topLabelColor, size: 18),
              ),
              prefixIconConstraints:
              const BoxConstraints(minWidth: 26, minHeight: 0),
              errorStyle: const TextStyle(fontSize: 11),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFD97706), size: 20),
            dropdownColor: Colors.white,
            borderRadius:  BorderRadius.circular(12),
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CNIC Formatter  →  12345-1234567-1
// ─────────────────────────────────────────────────────────────────────────────
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 13; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: text.length),
    );
  }
}