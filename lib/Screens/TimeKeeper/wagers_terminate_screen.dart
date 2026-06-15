// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/io_client.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
//
// import '../../ViewModels/login_view_model.dart';
// import '../HomeScreenComponents/navbar.dart';
// import '../HomeScreenComponents/sidebar_drawer.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // wagers_terminate_screen.dart
// // ═══════════════════════════════════════════════════════════════════════════════
//
// class WagersTerminateScreen extends StatefulWidget {
//   const WagersTerminateScreen({super.key});
//
//   @override
//   State<WagersTerminateScreen> createState() => _WagersTerminateScreenState();
// }
//
// class _WagersTerminateScreenState extends State<WagersTerminateScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   // ── Palette (same as other screens) ────────────────────────────────────────
//   static const _bg        = Color(0xFFF4F6FB);
//   static const _teal      = Color(0xFF0C6B64);
//   static const _tealLight = Color(0xFFE0F5F3);
//   static const _red       = Color(0xFFDC2626);
//   static const _redLight  = Color(0xFFFEF2F2);
//   static const _textDark  = Color(0xFF1F2937);
//   static const _textMuted = Color(0xFF6B7280);
//   static const _border    = Color(0xFFE5E7EB);
//
//   // ── State ───────────────────────────────────────────────────────────────────
//   List<Map<String, dynamic>> _wagers       = [];
//   bool                       _loadingWagers = true;
//   String                     _fetchError   = '';
//
//   Map<String, dynamic>? _selectedWager;
//
//   final _reasonCtrl  = TextEditingController();
//   final _remarksCtrl = TextEditingController();
//   bool  _submitting  = false;
//   DateTime? _terminationDate;
//
//   // Termination reason options
//   static const List<String> _reasonOptions = [
//     'Misconduct',
//     'Poor Performance',
//     'Contract Ended',
//     'Redundancy',
//     'Resignation',
//     'Health Issues',
//     'Absconding',
//     'Other',
//   ];
//   String? _selectedReason;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchWagers();
//   }
//
//   @override
//   void dispose() {
//     _reasonCtrl.dispose();
//     _remarksCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── Fetch active wagers (same API as WagersDetailScreen) ───────────────────
//   Future<void> _fetchWagers() async {
//     setState(() { _loadingWagers = true; _fetchError = ''; });
//
//     final loginVM     = Get.find<LoginViewModel>();
//     final user        = loginVM.currentUser.value;
//     final prefs       = await SharedPreferences.getInstance();
//
//     final empId       = user?.emp_id?.toString()
//         ?? prefs.get('emp_id')?.toString()
//         ?? prefs.getString('userId')
//         ?? '';
//     final companyCode = user?.company_code?.toString()
//         ?? prefs.getString('company_code')
//         ?? prefs.getString('companyCode')
//         ?? '';
//
//     final uri = Uri.parse(
//       'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
//     ).replace(queryParameters: {
//       'emp_id':       empId,
//       'company_code': companyCode,
//     });
//
//     debugPrint('╔══ TERMINATE – WAGER FETCH ════════════════════');
//     debugPrint('║ URL: $uri');
//
//     try {
//       final httpClient = HttpClient()
//         ..badCertificateCallback = (cert, host, port) => true;
//       final ioClient = IOClient(httpClient);
//
//       final response = await ioClient
//           .get(uri, headers: {'Content-Type': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('║ STATUS: ${response.statusCode}');
//       debugPrint('╚═══════════════════════════════════════════════');
//
//       if (response.statusCode == 200) {
//         final decoded  = jsonDecode(response.body);
//         final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
//         setState(() {
//           _wagers        = items.map((e) => Map<String, dynamic>.from(e)).toList();
//           _loadingWagers = false;
//         });
//       } else {
//         setState(() {
//           _fetchError    = 'Error ${response.statusCode}: ${response.body}';
//           _loadingWagers = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _fetchError    = 'Exception: $e';
//         _loadingWagers = false;
//       });
//     }
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────────────
//   String _val(Map<String, dynamic> w, List<String> keys) {
//     for (final k in keys) {
//       final v = w[k];
//       if (v != null && v.toString().trim().isNotEmpty) return v.toString();
//     }
//     return '—';
//   }
//
//   String get _selectedId   => _selectedWager == null ? '' :
//   _val(_selectedWager!, ['wager_id', 'wagerId', 'id', 'emp_id']);
//   String get _selectedName => _selectedWager == null ? '' :
//   _val(_selectedWager!, ['emp_name', 'name', 'wager_name', 'employee_name']);
//
//   void _onWagerSelected(Map<String, dynamic>? wager) {
//     setState(() {
//       _selectedWager  = wager;
//       _selectedReason = null;
//       _terminationDate = null;
//       _remarksCtrl.clear();
//     });
//   }
//
//   // ── Submit ──────────────────────────────────────────────────────────────────
//   Future<void> _submitTermination() async {
//     if (_selectedWager == null) {
//       _showSnack('Pehle employee select karein', isError: true);
//       return;
//     }
//     if (_selectedReason == null || _selectedReason!.isEmpty) {
//       _showSnack('Termination reason select karein', isError: true);
//       return;
//     }
//     if (_terminationDate == null) {
//       _showSnack('Termination date select karein', isError: true);
//       return;
//     }
//     if (_remarksCtrl.text.trim().isEmpty) {
//       _showSnack('Remarks likhna zaroori hai', isError: true);
//       return;
//     }
//
//     // Confirm dialog
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
//             SizedBox(width: 8),
//             Text(
//               'Confirm Termination',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//             ),
//           ],
//         ),
//         content: Text(
//           'Kya aap "$_selectedName" ko terminate karna chahte hain?\n\nYeh action undo nahi ho sakti.',
//           style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _red,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             child: const Text('Terminate', style: TextStyle(fontWeight: FontWeight.w700)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirmed != true) return;
//
//     setState(() => _submitting = true);
//
//     // TODO: Replace with actual terminate API endpoint when available
//     debugPrint('╔══ TERMINATE SUBMIT ═══════════════════════════');
//     debugPrint('║ Wager ID  : $_selectedId');
//     debugPrint('║ Wager Name: $_selectedName');
//     debugPrint('║ Reason    : $_selectedReason');
//     debugPrint('║ Date      : $_terminationDate');
//     debugPrint('║ Remarks   : ${_remarksCtrl.text.trim()}');
//     debugPrint('╚═══════════════════════════════════════════════');
//
//     // Simulate API call (replace with real endpoint)
//     await Future.delayed(const Duration(seconds: 2));
//
//     setState(() => _submitting = false);
//     _showSnack('Wager "$_selectedName" successfully terminate ho gaya', isError: false);
//
//     // Reset form
//     setState(() {
//       _selectedWager  = null;
//       _selectedReason = null;
//       _terminationDate = null;
//       _remarksCtrl.clear();
//     });
//   }
//
//   void _showSnack(String msg, {required bool isError}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(
//               isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
//               color: Colors.white,
//               size:  18,
//             ),
//             const SizedBox(width: 8),
//             Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
//           ],
//         ),
//         backgroundColor: isError ? _red : _teal,
//         behavior:        SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         margin: const EdgeInsets.all(16),
//       ),
//     );
//   }
//
//   // ── Build ────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final loginVM  = Get.find<LoginViewModel>();
//     final name     = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';
//     final parts    = name.trim().split(' ');
//     final initials = parts.length >= 2
//         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
//         : name.isNotEmpty ? name[0].toUpperCase() : 'TK';
//
//     return Scaffold(
//       key:             _scaffoldKey,
//       backgroundColor: _bg,
//       appBar: Navbar(
//         userName:     name,
//         userInitials: initials,
//         scaffoldKey:  _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       body: Column(
//         children: [
//           // ── Header strip ────────────────────────────────────────────────────
//           _HeaderStrip(),
//
//           // ── Scrollable form body ─────────────────────────────────────────────
//           Expanded(
//             child: _loadingWagers
//                 ? _buildLoading()
//                 : _fetchError.isNotEmpty
//                 ? _buildError()
//                 : SingleChildScrollView(
//               padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Section: Employee Selection
//                   _SectionLabel(label: 'EMPLOYEE SELECTION', icon: Icons.person_search_rounded),
//                   const SizedBox(height: 12),
//                   _buildEmployeeDropdown(),
//
//                   // Auto-filled info card
//                   if (_selectedWager != null) ...[
//                     const SizedBox(height: 16),
//                     _buildInfoCard(),
//                   ],
//
//                   const SizedBox(height: 24),
//
//                   // Section: Termination Details
//                   _SectionLabel(label: 'TERMINATION DETAILS', icon: Icons.gavel_rounded),
//                   const SizedBox(height: 12),
//                   _buildReasonDropdown(),
//                   const SizedBox(height: 14),
//                   _buildTerminationDateField(),
//                   const SizedBox(height: 14),
//                   _buildRemarksField(),
//
//                   const SizedBox(height: 32),
//
//                   // Submit Button
//                   _buildSubmitButton(),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Employee Dropdown ────────────────────────────────────────────────────────
//   Widget _buildEmployeeDropdown() {
//     return Container(
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _border),
//         boxShadow: [
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset:     const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: DropdownButtonHideUnderline(
//         child: ButtonTheme(
//           alignedDropdown: true,
//           child: DropdownButton<Map<String, dynamic>>(
//             value:       _selectedWager,
//             hint: const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 4),
//               child: Text(
//                 'Employee select karein...',
//                 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
//               ),
//             ),
//             isExpanded:   true,
//             icon:         const Icon(Icons.keyboard_arrow_down_rounded, color: _teal),
//             borderRadius: BorderRadius.circular(14),
//             padding:      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//             items: _wagers.map((w) {
//               final id   = _val(w, ['wager_id', 'wagerId', 'id', 'emp_id']);
//               final name = _val(w, ['emp_name', 'name', 'wager_name', 'employee_name']);
//               return DropdownMenuItem<Map<String, dynamic>>(
//                 value: w,
//                 child: Row(
//                   children: [
//                     Container(
//                       width:  34,
//                       height: 34,
//                       decoration: BoxDecoration(
//                         color:        _tealLight,
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: const Icon(Icons.person_rounded, color: _teal, size: 18),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         mainAxisSize:       MainAxisSize.min,
//                         children: [
//                           Text(
//                             name,
//                             style: const TextStyle(
//                               fontSize:   14,
//                               fontWeight: FontWeight.w600,
//                               color:      _textDark,
//                             ),
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           Text(
//                             'ID: $id',
//                             style: const TextStyle(
//                               fontSize: 11,
//                               color:    _textMuted,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }).toList(),
//             onChanged: _onWagerSelected,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Auto-filled Info Card ────────────────────────────────────────────────────
//   Widget _buildInfoCard() {
//     final w          = _selectedWager!;
//     final contact    = _val(w, ['contact', 'phone', 'mobile', 'contact_no']);
//     final fatherName = _val(w, ['father_name', 'fatherName', 'father', 'f_name']);
//
//     return Container(
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border:       Border.all(color: _tealLight, width: 1.5),
//         boxShadow: [
//           BoxShadow(
//             color:      _teal.withOpacity(0.07),
//             blurRadius: 12,
//             offset:     const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Card header
//           Container(
//             padding:      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             decoration: BoxDecoration(
//               color:        _tealLight,
//               borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
//             ),
//             child: const Row(
//               children: [
//                 Icon(Icons.info_outline_rounded, color: _teal, size: 16),
//                 SizedBox(width: 6),
//                 Text(
//                   'Selected Employee Details',
//                   style: TextStyle(
//                     fontSize:   13,
//                     fontWeight: FontWeight.w700,
//                     color:      _teal,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Detail rows
//           Padding(
//             padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
//             child: Column(
//               children: [
//                 _InfoRow(icon: Icons.badge_outlined,         label: 'Wager ID',    value: _selectedId),
//                 _InfoRow(icon: Icons.person_outline,         label: 'Name',        value: _selectedName),
//                 _InfoRow(icon: Icons.phone_outlined,         label: 'Contact',     value: contact),
//                 _InfoRow(icon: Icons.person_2_outlined,      label: 'Father Name', value: fatherName, isLast: true),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Reason Dropdown ──────────────────────────────────────────────────────────
//   Widget _buildReasonDropdown() {
//     return Container(
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(
//           color: _selectedReason != null ? _red.withOpacity(0.4) : _border,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset:     const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: DropdownButtonHideUnderline(
//         child: ButtonTheme(
//           alignedDropdown: true,
//           child: DropdownButton<String>(
//             value:       _selectedReason,
//             hint: const Padding(
//               padding: EdgeInsets.symmetric(horizontal: 4),
//               child: Text(
//                 'Termination reason select karein...',
//                 style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
//               ),
//             ),
//             isExpanded:   true,
//             icon:         const Icon(Icons.keyboard_arrow_down_rounded, color: _red),
//             borderRadius: BorderRadius.circular(14),
//             padding:      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//             items: _reasonOptions.map((r) => DropdownMenuItem<String>(
//               value: r,
//               child: Row(
//                 children: [
//                   Container(
//                     width:  8,
//                     height: 8,
//                     decoration: BoxDecoration(
//                       color:  _red,
//                       shape:  BoxShape.circle,
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Text(
//                     r,
//                     style: const TextStyle(fontSize: 14, color: _textDark),
//                   ),
//                 ],
//               ),
//             )).toList(),
//             onChanged: (v) => setState(() => _selectedReason = v),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Termination Date Field ───────────────────────────────────────────────────
//   Widget _buildTerminationDateField() {
//     final hasDate     = _terminationDate != null;
//     final displayText = hasDate
//         ? '${_terminationDate!.day.toString().padLeft(2, '0')}/'
//         '${_terminationDate!.month.toString().padLeft(2, '0')}/'
//         '${_terminationDate!.year}'
//         : 'Termination date select karein...';
//
//     return GestureDetector(
//       onTap: () async {
//         final picked = await showDatePicker(
//           context:      context,
//           initialDate:  _terminationDate ?? DateTime.now(),
//           firstDate:    DateTime(2000),
//           lastDate:     DateTime(2100),
//           builder: (context, child) => Theme(
//             data: Theme.of(context).copyWith(
//               colorScheme: const ColorScheme.light(
//                 primary:    _red,
//                 onPrimary:  Colors.white,
//                 surface:    Colors.white,
//                 onSurface:  _textDark,
//               ),
//               dialogBackgroundColor: Colors.white,
//             ),
//             child: child!,
//           ),
//         );
//         if (picked != null) setState(() => _terminationDate = picked);
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
//         decoration: BoxDecoration(
//           color:        Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: hasDate ? _red.withOpacity(0.4) : _border,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color:      Colors.black.withOpacity(0.04),
//               blurRadius: 8,
//               offset:     const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               width:  36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color:        hasDate ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6),
//                 borderRadius: BorderRadius.circular(9),
//               ),
//               child: Icon(
//                 Icons.calendar_today_rounded,
//                 color: hasDate ? _red : _textMuted,
//                 size:  18,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize:       MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'Termination Date',
//                     style: TextStyle(
//                       fontSize:   11,
//                       fontWeight: FontWeight.w600,
//                       color:      _textMuted,
//                       letterSpacing: 0.3,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     displayText,
//                     style: TextStyle(
//                       fontSize:   14,
//                       fontWeight: hasDate ? FontWeight.w700 : FontWeight.w400,
//                       color:      hasDate ? _textDark : const Color(0xFF9CA3AF),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(
//               Icons.keyboard_arrow_down_rounded,
//               color: hasDate ? _red : _textMuted,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Remarks Field ────────────────────────────────────────────────────────────
//   Widget _buildRemarksField() {
//     return Container(
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border:       Border.all(color: _border),
//         boxShadow: [
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset:     const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: TextField(
//         controller:  _remarksCtrl,
//         maxLines:    4,
//         minLines:    4,
//         keyboardType: TextInputType.multiline,
//         textInputAction: TextInputAction.newline,
//         style: const TextStyle(fontSize: 14, color: _textDark),
//         decoration: InputDecoration(
//           hintText:    'Termination ke bare mein remarks likhein...',
//           hintStyle:   const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
//           prefixIcon: const Padding(
//             padding: EdgeInsets.only(left: 12, top: 12),
//             child: Icon(Icons.edit_note_rounded, color: _textMuted, size: 20),
//           ),
//           prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
//           contentPadding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
//           border:         InputBorder.none,
//           filled:         false,
//         ),
//       ),
//     );
//   }
//
//   // ── Submit Button ────────────────────────────────────────────────────────────
//   Widget _buildSubmitButton() {
//     return SizedBox(
//       width: double.infinity,
//       height: 52,
//       child: ElevatedButton.icon(
//         onPressed: _submitting ? null : _submitTermination,
//         icon: _submitting
//             ? const SizedBox(
//           width: 18,
//           height: 18,
//           child: CircularProgressIndicator(
//             strokeWidth: 2,
//             color:       Colors.white,
//           ),
//         )
//             : const Icon(Icons.gavel_rounded, size: 20),
//         label: Text(
//           _submitting ? 'Processing...' : 'Terminate Wager',
//           style: const TextStyle(
//             fontSize:   15,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _red,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: _red.withOpacity(0.6),
//           disabledForegroundColor: Colors.white,
//           elevation:  0,
//           shadowColor: Colors.transparent,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         ),
//       ),
//     );
//   }
//
//   // ── Loading / Error states ───────────────────────────────────────────────────
//   Widget _buildLoading() {
//     return const Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
//           SizedBox(height: 14),
//           Text(
//             'Active wagers load ho rahe hain...',
//             style: TextStyle(color: _textMuted, fontSize: 13),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildError() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
//             const SizedBox(height: 12),
//             Text(
//               _fetchError,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: _textMuted, fontSize: 13),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: _fetchWagers,
//               icon:  const Icon(Icons.refresh_rounded, size: 18),
//               label: const Text('Dobara try karein'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _teal,
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
//                 textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Header Strip
// // ─────────────────────────────────────────────────────────────────────────────
// class _HeaderStrip extends StatelessWidget {
//   const _HeaderStrip();
//
//   static const _teal      = Color(0xFF0C6B64);
//   static const _tealLight = Color(0xFFE0F5F3);
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width:   double.infinity,
//       padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
//       ),
//       child: Row(
//         children: [
//           // Back button
//           GestureDetector(
//             onTap: () => Navigator.of(context).maybePop(),
//             child: Container(
//               width:  38,
//               height: 38,
//               decoration: BoxDecoration(
//                 color:        _tealLight,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Icon(Icons.arrow_back_ios_new_rounded,
//                   color: _teal, size: 16),
//             ),
//           ),
//           const SizedBox(width: 12),
//
//           // Icon + Title
//           Container(
//             width:  42,
//             height: 42,
//             decoration: BoxDecoration(
//               color:        const Color(0xFFFEF2F2),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(Icons.gavel_rounded,
//                 color: Color(0xFFDC2626), size: 22),
//           ),
//           const SizedBox(width: 12),
//           const Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize:       MainAxisSize.min,
//             children: [
//               Text(
//                 'Wager Terminate',
//                 style: TextStyle(
//                   fontSize:   16,
//                   fontWeight: FontWeight.w800,
//                   color:      Color(0xFF1F2937),
//                 ),
//               ),
//               Text(
//                 'Active wager ko terminate karein',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color:    Color(0xFF6B7280),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Section Label
// // ─────────────────────────────────────────────────────────────────────────────
// class _SectionLabel extends StatelessWidget {
//   final String   label;
//   final IconData icon;
//   const _SectionLabel({required this.label, required this.icon});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
//         const SizedBox(width: 6),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize:      11,
//             fontWeight:    FontWeight.w700,
//             color:         Color(0xFF6B7280),
//             letterSpacing: 1.0,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Info Row (inside auto-filled card)
// // ─────────────────────────────────────────────────────────────────────────────
// class _InfoRow extends StatelessWidget {
//   final IconData icon;
//   final String   label;
//   final String   value;
//   final bool     isLast;
//   const _InfoRow({
//     required this.icon,
//     required this.label,
//     required this.value,
//     this.isLast = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
//           const SizedBox(width: 7),
//           SizedBox(
//             width: 78,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontSize:   12,
//                 color:      Color(0xFF6B7280),
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(
//                 fontSize:   12,
//                 color:      Color(0xFF1F2937),
//                 fontWeight: FontWeight.w600,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../ViewModels/login_view_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// wagers_terminate_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class WagersTerminateScreen extends StatefulWidget {
  const WagersTerminateScreen({super.key});

  @override
  State<WagersTerminateScreen> createState() => _WagersTerminateScreenState();
}

class _WagersTerminateScreenState extends State<WagersTerminateScreen> {

  // ── Palette ─────────────────────────────────────────────────────────────────
  static const _bg        = Color(0xFFE8F5F3);   // same as register screen
  static const _teal      = Color(0xFF0C6B64);
  static const _tealLight = Color(0xFFE0F5F3);
  static const _red       = Color(0xFFDC2626);
  static const _redLight  = Color(0xFFFEF2F2);
  static const _textDark  = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);
  static const _border    = Color(0xFFE5E7EB);

  // ── State ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _wagers        = [];
  bool                       _loadingWagers = true;
  String                     _fetchError   = '';

  Map<String, dynamic>? _selectedWager;

  final _reasonCtrl  = TextEditingController();
  final _remarksCtrl = TextEditingController();
  bool  _submitting  = false;
  DateTime? _terminationDate;

  static const List<String> _reasonOptions = [
    'Misconduct',
    'Poor Performance',
    'Contract Ended',
    'Redundancy',
    'Resignation',
    'Health Issues',
    'Absconding',
    'Other',
  ];
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _fetchWagers();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ── Fetch active wagers ─────────────────────────────────────────────────────
  Future<void> _fetchWagers() async {
    setState(() { _loadingWagers = true; _fetchError = ''; });

    final loginVM     = Get.find<LoginViewModel>();
    final user        = loginVM.currentUser.value;
    final prefs       = await SharedPreferences.getInstance();

    final empId       = user?.emp_id?.toString()
        ?? prefs.get('emp_id')?.toString()
        ?? prefs.getString('userId')
        ?? '';
    final companyCode = user?.company_code?.toString()
        ?? prefs.getString('company_code')
        ?? prefs.getString('companyCode')
        ?? '';

    final uri = Uri.parse(
      'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
    ).replace(queryParameters: {
      'emp_id':       empId,
      'company_code': companyCode,
    });

    debugPrint('╔══ TERMINATE – WAGER FETCH ════════════════════');
    debugPrint('║ URL: $uri');

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);

      final response = await ioClient
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('║ STATUS: ${response.statusCode}');
      debugPrint('╚═══════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final decoded  = jsonDecode(response.body);
        final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
        setState(() {
          _wagers        = items.map((e) => Map<String, dynamic>.from(e)).toList();
          _loadingWagers = false;
        });
      } else {
        setState(() {
          _fetchError    = 'Error ${response.statusCode}: ${response.body}';
          _loadingWagers = false;
        });
      }
    } catch (e) {
      setState(() {
        _fetchError    = 'Exception: $e';
        _loadingWagers = false;
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _val(Map<String, dynamic> w, List<String> keys) {
    for (final k in keys) {
      final v = w[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '—';
  }

  String get _selectedId   => _selectedWager == null ? '' :
  _val(_selectedWager!, ['wager_id', 'wagerId', 'id', 'emp_id']);
  String get _selectedName => _selectedWager == null ? '' :
  _val(_selectedWager!, ['emp_name', 'name', 'wager_name', 'employee_name']);

  void _onWagerSelected(Map<String, dynamic>? wager) {
    setState(() {
      _selectedWager  = wager;
      _selectedReason = null;
      _terminationDate = null;
      _remarksCtrl.clear();
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  // Future<void> _submitTermination() async {
  //   if (_selectedWager == null) {
  //     _showSnack('Pehle employee select karein', isError: true);
  //     return;
  //   }
  //   if (_selectedReason == null || _selectedReason!.isEmpty) {
  //     _showSnack('Termination reason select karein', isError: true);
  //     return;
  //   }
  //   if (_terminationDate == null) {
  //     _showSnack('Termination date select karein', isError: true);
  //     return;
  //   }
  //   if (_remarksCtrl.text.trim().isEmpty) {
  //     _showSnack('Remarks likhna zaroori hai', isError: true);
  //     return;
  //   }
  //
  //   final confirmed = await showDialog<bool>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Row(
  //         children: [
  //           Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
  //           SizedBox(width: 8),
  //           Text(
  //             'Confirm Termination',
  //             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  //           ),
  //         ],
  //       ),
  //       content: Text(
  //         'Kya aap "$_selectedName" ko terminate karna chahte hain?\n\nYeh action undo nahi ho sakti.',
  //         style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
  //         ),
  //         ElevatedButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: _red,
  //             foregroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //           ),
  //           child: const Text('Terminate', style: TextStyle(fontWeight: FontWeight.w700)),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirmed != true) return;
  //
  //   setState(() => _submitting = true);
  //
  //   debugPrint('╔══ TERMINATE SUBMIT ═══════════════════════════');
  //   debugPrint('║ Wager ID  : $_selectedId');
  //   debugPrint('║ Wager Name: $_selectedName');
  //   debugPrint('║ Reason    : $_selectedReason');
  //   debugPrint('║ Date      : $_terminationDate');
  //   debugPrint('║ Remarks   : ${_remarksCtrl.text.trim()}');
  //   debugPrint('╚═══════════════════════════════════════════════');
  //
  //   await Future.delayed(const Duration(seconds: 2));
  //
  //   setState(() => _submitting = false);
  //   _showSnack('Wager "$_selectedName" successfully terminate ho gaya', isError: false);
  //
  //   setState(() {
  //     _selectedWager  = null;
  //     _selectedReason = null;
  //     _terminationDate = null;
  //     _remarksCtrl.clear();
  //   });
  // }
  // ── Submit Termination to API ──────────────────────────────────────────────────
  Future<void> _submitTermination() async {
    if (_selectedWager == null) {
      _showSnack('Pehle employee select karein', isError: true);
      return;
    }
    if (_selectedReason == null || _selectedReason!.isEmpty) {
      _showSnack('Termination reason select karein', isError: true);
      return;
    }
    if (_terminationDate == null) {
      _showSnack('Termination date select karein', isError: true);
      return;
    }
    if (_remarksCtrl.text.trim().isEmpty) {
      _showSnack('Remarks likhna zaroori hai', isError: true);
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text(
              'Confirm Termination',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Kya aap "$_selectedName" ko terminate karna chahte hain?\n\nYeh action undo nahi ho sakti.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Terminate', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);

    // Get user info
    final loginVM = Get.find<LoginViewModel>();
    final user = loginVM.currentUser.value;
    final prefs = await SharedPreferences.getInstance();

    // Get terminated_by_id (logged in user ID)
    final terminatedById = user?.emp_id?.toString()
        ?? prefs.get('emp_id')?.toString()
        ?? prefs.getString('userId')
        ?? '';

    final companyCode = user?.company_code?.toString()
        ?? prefs.getString('company_code')
        ?? prefs.getString('companyCode')
        ?? '';

    final terminatedByName = user?.emp_name ?? '';

    // Get father name from selected wager
    final fatherName = _val(_selectedWager!, ['father_name', 'fatherName', 'father', 'f_name']);

    // Format date as YYYY-MM-DD
    final String formattedDate = _terminationDate != null
        ? '${_terminationDate!.year}-${_terminationDate!.month.toString().padLeft(2, '0')}-${_terminationDate!.day.toString().padLeft(2, '0')}'
        : '';

    // Prepare request body as per your API
    final Map<String, dynamic> requestBody = {
      'wager_id': _selectedId,
      'wager_name': _selectedName,
      'father_name': fatherName != '—' ? fatherName : '',
      'termination_date': formattedDate,
      'termination_reason': _selectedReason,
      'remarks': _remarksCtrl.text.trim(),
      'company_code': companyCode,
      'terminated_by_id': terminatedById,
      'terminated_by_name': terminatedByName,
      'status': 'TERMINATED',
    };

    debugPrint('╔══ TERMINATE API CALL ═══════════════════════════');
    debugPrint('║ URL: http://oracle.metaxperts.net/ords/gps_workforce/wagertermination/post/');
    debugPrint('║ Request Body: ${jsonEncode(requestBody)}');
    debugPrint('╚═══════════════════════════════════════════════════');

    try {
      // Create HTTP client with certificate handling
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);

      // Make POST request
      final response = await ioClient.post(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/wagertermination/post/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('║ Response Status: ${response.statusCode}');
      debugPrint('║ Response Body: ${response.body}');
      debugPrint('╚═══════════════════════════════════════════════════');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decodedResponse = jsonDecode(response.body);

          // Check if response indicates success
          if (decodedResponse['success'] == true ||
              decodedResponse['status'] == 'success' ||
              response.statusCode == 200) {
            _showSnack('Wager "$_selectedName" successfully terminate ho gaya', isError: false);

            // Reset form
            setState(() {
              _selectedWager = null;
              _selectedReason = null;
              _terminationDate = null;
              _remarksCtrl.clear();
            });

            // Refresh wager list
            await _fetchWagers();
          } else {
            _showSnack(decodedResponse['message'] ?? 'Termination failed', isError: true);
          }
        } catch (e) {
          // If response is not JSON but success
          _showSnack('Wager "$_selectedName" successfully terminate ho gaya', isError: false);
          setState(() {
            _selectedWager = null;
            _selectedReason = null;
            _terminationDate = null;
            _remarksCtrl.clear();
          });
          await _fetchWagers();
        }
      } else {
        _showSnack('Server Error: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      debugPrint('║ Error: $e');
      _showSnack('Network Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size:  18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? _red : _teal,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // ── No appBar, no Drawer — gradient header only ───────────────────────
      body: Column(
        children: [

          // ── Gradient Header (same style as Register screen) ─────────────────
          _WagersGradientHeader(
            title:    'Wager Terminate',
            subtitle: 'Active wager ko terminate karein',
            icon:     Icons.gavel_rounded,
            rightIconBg: Colors.white.withOpacity(0.2),
          ),

          // ── Scrollable form body ─────────────────────────────────────────────
          Expanded(
            child: _loadingWagers
                ? _buildLoading()
                : _fetchError.isNotEmpty
                ? _buildError()
                : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'EMPLOYEE SELECTION', icon: Icons.person_search_rounded),
                  const SizedBox(height: 12),
                  _buildEmployeeDropdown(),

                  if (_selectedWager != null) ...[
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                  ],

                  const SizedBox(height: 24),

                  _SectionLabel(label: 'TERMINATION DETAILS', icon: Icons.gavel_rounded),
                  const SizedBox(height: 12),
                  _buildReasonDropdown(),
                  const SizedBox(height: 14),
                  _buildTerminationDateField(),
                  const SizedBox(height: 14),
                  _buildRemarksField(),

                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Employee Dropdown ────────────────────────────────────────────────────────
  Widget _buildEmployeeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<Map<String, dynamic>>(
            value:       _selectedWager,
            hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Employee select karein...',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
            isExpanded:   true,
            icon:         const Icon(Icons.keyboard_arrow_down_rounded, color: _teal),
            borderRadius: BorderRadius.circular(14),
            padding:      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            items: _wagers.map((w) {
              final id   = _val(w, ['wager_id', 'wagerId', 'id', 'emp_id']);
              final name = _val(w, ['emp_name', 'name', 'wager_name', 'employee_name']);
              return DropdownMenuItem<Map<String, dynamic>>(
                value: w,
                child: Row(
                  children: [
                    Container(
                      width:  34,
                      height: 34,
                      decoration: BoxDecoration(
                        color:        _tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, color: _teal, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize:       MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color:      _textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: $id',
                            style: const TextStyle(
                              fontSize: 11,
                              color:    _textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: _onWagerSelected,
          ),
        ),
      ),
    );
  }

  // ── Auto-filled Info Card ────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    final w          = _selectedWager!;
    final contact    = _val(w, ['contact', 'phone', 'mobile', 'contact_no']);
    final fatherName = _val(w, ['father_name', 'fatherName', 'father', 'f_name']);

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _tealLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color:      _teal.withOpacity(0.07),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        _tealLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _teal, size: 16),
                SizedBox(width: 6),
                Text(
                  'Selected Employee Details',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      _teal,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                _InfoRow(icon: Icons.badge_outlined,    label: 'Wager ID',    value: _selectedId),
                _InfoRow(icon: Icons.person_outline,    label: 'Name',        value: _selectedName),
                _InfoRow(icon: Icons.phone_outlined,    label: 'Contact',     value: contact),
                _InfoRow(icon: Icons.person_2_outlined, label: 'Father Name', value: fatherName, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reason Dropdown ──────────────────────────────────────────────────────────
  Widget _buildReasonDropdown() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selectedReason != null ? _red.withOpacity(0.4) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value:       _selectedReason,
            hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Termination reason select karein...',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
            isExpanded:   true,
            icon:         const Icon(Icons.keyboard_arrow_down_rounded, color: _red),
            borderRadius: BorderRadius.circular(14),
            padding:      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            items: _reasonOptions.map((r) => DropdownMenuItem<String>(
              value: r,
              child: Row(
                children: [
                  Container(
                    width:  8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:  _red,
                      shape:  BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    r,
                    style: const TextStyle(fontSize: 14, color: _textDark),
                  ),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedReason = v),
          ),
        ),
      ),
    );
  }

  // ── Termination Date Field ───────────────────────────────────────────────────
  Widget _buildTerminationDateField() {
    final hasDate     = _terminationDate != null;
    final displayText = hasDate
        ? '${_terminationDate!.day.toString().padLeft(2, '0')}/'
        '${_terminationDate!.month.toString().padLeft(2, '0')}/'
        '${_terminationDate!.year}'
        : 'Termination date select karein...';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context:      context,
          initialDate:  _terminationDate ?? DateTime.now(),
          firstDate:    DateTime(2000),
          lastDate:     DateTime(2100),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary:    _red,
                onPrimary:  Colors.white,
                surface:    Colors.white,
                onSurface:  _textDark,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _terminationDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? _red.withOpacity(0.4) : _border,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        hasDate ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: hasDate ? _red : _textMuted,
                size:  18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  const Text(
                    'Termination Date',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      _textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.w400,
                      color:      hasDate ? _textDark : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasDate ? _red : _textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── Remarks Field ────────────────────────────────────────────────────────────
  Widget _buildRemarksField() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller:  _remarksCtrl,
        maxLines:    4,
        minLines:    4,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText:    'Termination ke bare mein remarks likhein...',
          hintStyle:   const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, top: 12),
            child: Icon(Icons.edit_note_rounded, color: _textMuted, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          contentPadding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          border:         InputBorder.none,
          filled:         false,
        ),
      ),
    );
  }

  // ── Submit Button ────────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submitTermination,
        icon: _submitting
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color:       Colors.white,
          ),
        )
            : const Icon(Icons.gavel_rounded, size: 20),
        label: Text(
          _submitting ? 'Processing...' : 'Terminate Wager',
          style: const TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _red.withOpacity(0.6),
          disabledForegroundColor: Colors.white,
          elevation:  0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── Loading / Error states ───────────────────────────────────────────────────
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
          SizedBox(height: 14),
          Text(
            'Active wagers load ho rahe hain...',
            style: TextStyle(color: _textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              _fetchError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchWagers,
              icon:  const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Dobara try karein'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED Gradient AppBar Widget — same across all Wagers screens
// ─────────────────────────────────────────────────────────────────────────────
class _WagersGradientHeader extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final IconData icon;
  final Color    rightIconBg;

  const _WagersGradientHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.rightIconBg = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C6B64), Color(0xFF1AAD9E)],
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
              // Back button
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
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize:   22,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              // Right icon badge
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: rightIconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         Color(0xFF6B7280),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isLast;
  const _InfoRow({
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
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 7),
          SizedBox(
            width: 78,
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
                fontWeight: FontWeight.w600,
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