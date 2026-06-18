// //
// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:http/io_client.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'dart:io';
// //
// // import '../../ViewModels/login_view_model.dart';
// // import '../HomeScreenComponents/sidebar_drawer.dart';
// //
// // // ═══════════════════════════════════════════════════════════════════════════════
// // // wagers_detail_screen.dart
// // // ═══════════════════════════════════════════════════════════════════════════════
// //
// // class WagersDetailScreen extends StatefulWidget {
// //   const WagersDetailScreen({super.key});
// //
// //   @override
// //   State<WagersDetailScreen> createState() => _WagersDetailScreenState();
// // }
// //
// // class _WagersDetailScreenState extends State<WagersDetailScreen> {
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   // ── Palette (matches TimekeeperScreen teal) ─────────────────────────────────
// //   static const _bg         = Color(0xFFF4F6FB);
// //   static const _teal       = Color(0xFF0C6B64);
// //   static const _tealLight  = Color(0xFFE0F5F3);
// //   static const _textDark   = Color(0xFF1F2937);
// //   static const _textMuted  = Color(0xFF6B7280);
// //   static const _cardWhite  = Colors.white;
// //
// //   // ── State ───────────────────────────────────────────────────────────────────
// //   List<Map<String, dynamic>> _wagers = [];
// //   List<Map<String, dynamic>> _filtered = [];
// //   bool   _loading = true;
// //   String _error   = '';
// //   final  _searchCtrl = TextEditingController();
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _fetchWagers();
// //     _searchCtrl.addListener(_applySearch);
// //   }
// //
// //   @override
// //   void dispose() {
// //     _searchCtrl.dispose();
// //     super.dispose();
// //   }
// //
// //   // ── API ─────────────────────────────────────────────────────────────────────
// //   Future<void> _fetchWagers() async {
// //     setState(() { _loading = true; _error = ''; });
// //
// //     // Pull credentials — user model first, SharedPreferences as fallback
// //     final loginVM = Get.find<LoginViewModel>();
// //     final user    = loginVM.currentUser.value;
// //
// //     final prefs       = await SharedPreferences.getInstance();
// //     final empId       = user?.emp_id?.toString()
// //         ?? prefs.get('emp_id')?.toString()
// //         ?? prefs.getString('userId')
// //         ?? '';
// //     final companyCode = user?.company_code?.toString()
// //         ?? prefs.getString('company_code')
// //         ?? prefs.getString('companyCode')
// //         ?? '';
// //
// //     final uri = Uri.parse(
// //       'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
// //     ).replace(queryParameters: {
// //       'emp_id':       empId,
// //       'company_code': companyCode,
// //     });
// //
// //     debugPrint('╔══ WAGER FETCH START ══════════════════════════');
// //     debugPrint('║ URL         : $uri');
// //     debugPrint('║ emp_id      : $empId');
// //     debugPrint('║ company_code: $companyCode');
// //
// //     try {
// //       final httpClient = HttpClient()
// //         ..badCertificateCallback = (cert, host, port) => true;
// //       final ioClient = IOClient(httpClient);
// //
// //       final response = await ioClient.get(
// //         uri,
// //         headers: {'Content-Type': 'application/json'},
// //       ).timeout(const Duration(seconds: 15));
// //
// //       debugPrint('║ STATUS : ${response.statusCode}');
// //       debugPrint('║ HEADERS: ${response.headers}');
// //       debugPrint('║ BODY   : ${response.body}');
// //       debugPrint('╚═══════════════════════════════════════════════');
// //
// //       if (response.statusCode == 200) {
// //         final decoded = jsonDecode(response.body);
// //         debugPrint('✅ Decoded keys: ${decoded.keys}');
// //
// //         final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
// //         debugPrint('✅ Item count: ${items.length}');
// //         if (items.isNotEmpty) debugPrint('✅ First item: ${items[0]}');
// //
// //         setState(() {
// //           _wagers   = items.map((e) => Map<String, dynamic>.from(e)).toList();
// //           _filtered = List.from(_wagers);
// //           _loading  = false;
// //         });
// //       } else {
// //         debugPrint('❌ Non-200 response: ${response.statusCode}');
// //         debugPrint('❌ Body: ${response.body}');
// //         setState(() {
// //           _error   = 'Error ${response.statusCode}\n\n${response.body}';
// //           _loading = false;
// //         });
// //       }
// //     } catch (e, stack) {
// //       debugPrint('❌ EXCEPTION: $e');
// //       debugPrint('❌ STACKTRACE:\n$stack');
// //       setState(() {
// //         _error   = 'Exception:\n$e';
// //         _loading = false;
// //       });
// //     }
// //   }
// //
// //   void _applySearch() {
// //     final q = _searchCtrl.text.trim().toLowerCase();
// //     setState(() {
// //       _filtered = q.isEmpty
// //           ? List.from(_wagers)
// //           : _wagers.where((w) {
// //         return w.values.any(
// //               (v) => v != null && v.toString().toLowerCase().contains(q),
// //         );
// //       }).toList();
// //     });
// //   }
// //
// //   // ── Helpers ─────────────────────────────────────────────────────────────────
// //   String _val(Map<String, dynamic> w, List<String> keys) {
// //     for (final k in keys) {
// //       final v = w[k];
// //       if (v != null && v.toString().trim().isNotEmpty) return v.toString();
// //     }
// //     return '—';
// //   }
// //
// //   // ── Build ────────────────────────────────────────────────────────────────────
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       key:             _scaffoldKey,
// //       backgroundColor: _bg,
// //       appBar: AppBar(
// //         title: const Text(
// //           'Wagers Detail',
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontSize: 18,
// //             fontWeight: FontWeight.w700,
// //           ),
// //         ),
// //         backgroundColor: _teal,
// //         elevation: 0,
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back, color: Colors.white),
// //           onPressed: () => Navigator.of(context).pop(),
// //         ),
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.menu, color: Colors.white),
// //             onPressed: () => _scaffoldKey.currentState?.openDrawer(),
// //           ),
// //         ],
// //       ),
// //       drawer: AppDrawer(),
// //       body: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // ── Header strip ──────────────────────────────────────────────────
// //           _HeaderStrip(
// //             count:   _filtered.length,
// //             loading: _loading,
// //           ),
// //
// //           // ── Search bar ────────────────────────────────────────────────────
// //           if (!_loading && _error.isEmpty)
// //             _SearchBar(controller: _searchCtrl),
// //
// //           // ── Body ──────────────────────────────────────────────────────────
// //           Expanded(
// //             child: _loading
// //                 ? const _LoadingView()
// //                 : _error.isNotEmpty
// //                 ? _ErrorView(message: _error, onRetry: _fetchWagers)
// //                 : _filtered.isEmpty
// //                 ? const _EmptyView()
// //                 : RefreshIndicator(
// //               color:    _teal,
// //               onRefresh: _fetchWagers,
// //               child: ListView.builder(
// //                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
// //                 itemCount: _filtered.length,
// //                 itemBuilder: (_, i) => _WagerCard(
// //                   wager:   _filtered[i],
// //                   index:   i,
// //                   valFn:   _val,
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Header Strip
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _HeaderStrip extends StatelessWidget {
// //   final int  count;
// //   final bool loading;
// //   const _HeaderStrip({required this.count, required this.loading});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       width:   double.infinity,
// //       padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
// //       decoration: const BoxDecoration(
// //         color: Color(0xFF0C6B64),
// //         borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             children: [
// //               const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
// //               const SizedBox(width: 8),
// //               const Text(
// //                 'Wagers Detail',
// //                 style: TextStyle(
// //                   color:      Colors.white,
// //                   fontSize:   18,
// //                   fontWeight: FontWeight.w700,
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(height: 4),
// //           Text(
// //             loading ? 'Fetching records…' : '$count registered wager(s)',
// //             style: const TextStyle(
// //               color:    Color(0xFFB2DDD9),
// //               fontSize: 13,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Search Bar
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _SearchBar extends StatelessWidget {
// //   final TextEditingController controller;
// //   const _SearchBar({required this.controller});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Padding(
// //       padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
// //       child: TextField(
// //         controller:  controller,
// //         style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
// //         decoration: InputDecoration(
// //           hintText:       'Search wagers…',
// //           hintStyle:      const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
// //           prefixIcon:     const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
// //           suffixIcon: ValueListenableBuilder(
// //             valueListenable: controller,
// //             builder: (_, v, __) => v.text.isNotEmpty
// //                 ? IconButton(
// //               icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
// //               onPressed: () => controller.clear(),
// //             )
// //                 : const SizedBox.shrink(),
// //           ),
// //           filled:      true,
// //           fillColor:   Colors.white,
// //           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //           border: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(12),
// //             borderSide:   BorderSide.none,
// //           ),
// //           enabledBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(12),
// //             borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
// //           ),
// //           focusedBorder: OutlineInputBorder(
// //             borderRadius: BorderRadius.circular(12),
// //             borderSide:   const BorderSide(color: Color(0xFF0C6B64), width: 1.5),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Wager Card
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _WagerCard extends StatelessWidget {
// //   final Map<String, dynamic>              wager;
// //   final int                               index;
// //   final String Function(Map<String, dynamic>, List<String>) valFn;
// //
// //   const _WagerCard({
// //     required this.wager,
// //     required this.index,
// //     required this.valFn,
// //   });
// //
// //   static const _teal      = Color(0xFF0C6B64);
// //   static const _tealLight = Color(0xFFE0F5F3);
// //   static const _textDark  = Color(0xFF1F2937);
// //   static const _textMuted = Color(0xFF6B7280);
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     // ── Exact column names from WAGERS_DETAIL view ───────────────────────────
// //     final name        = valFn(wager, ['wager_name']);
// //     final wagerId     = valFn(wager, ['wager_id']);
// //     final department  = valFn(wager, ['dep_name', 'dep_id']);
// //     final fatherName  = valFn(wager, ['father_name']);
// //     final cnic        = valFn(wager, ['cnic_no']);
// //     final contact     = valFn(wager, ['contact_no']);
// //     final email       = valFn(wager, ['email']);
// //     final gender      = valFn(wager, ['gender']);
// //     final dob         = valFn(wager, ['dob']);
// //     final salary      = valFn(wager, ['basic_salary']);
// //     final entryTime   = valFn(wager, ['entry_time']);
// //     final endTime     = valFn(wager, ['end_time']);
// //     final status      = valFn(wager, ['status']);
// //     // kept for avatar/badge reuse
// //     final empNo       = wagerId;
// //     final designation = department;
// //     final joinDate    = dob;
// //
// //     // Status badge color
// //     final isActive = status.toLowerCase() == 'active' ||
// //         status == '1' || status.toLowerCase() == 'true';
// //     final statusColor  = isActive ? const Color(0xFF059669) : const Color(0xFFD97706);
// //     final statusBg     = isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
// //     final statusLabel  = status == '—' ? 'Unknown' : (isActive ? 'Active' : 'Inactive');
// //
// //     // Avatar initials
// //     final nameParts  = name.trim().split(' ');
// //     final initials   = nameParts.length >= 2
// //         ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
// //         : name.isNotEmpty ? name[0].toUpperCase() : '??';
// //
// //     return Container(
// //       margin: const EdgeInsets.only(bottom: 12),
// //       decoration: BoxDecoration(
// //         color:        Colors.white,
// //         borderRadius: BorderRadius.circular(16),
// //         boxShadow: [
// //           BoxShadow(
// //             color:        _teal.withOpacity(0.06),
// //             blurRadius:   14,
// //             spreadRadius: 0,
// //             offset:       const Offset(0, 4),
// //           ),
// //           BoxShadow(
// //             color:      Colors.black.withOpacity(0.03),
// //             blurRadius: 5,
// //             offset:     const Offset(0, 2),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         children: [
// //           // ── Top row: avatar + name + status ────────────────────────────
// //           Padding(
// //             padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
// //             child: Row(
// //               crossAxisAlignment: CrossAxisAlignment.center,
// //               children: [
// //                 // Avatar circle
// //                 Container(
// //                   width:  46,
// //                   height: 46,
// //                   decoration: const BoxDecoration(
// //                     color: _tealLight,
// //                     shape: BoxShape.circle,
// //                   ),
// //                   child: Center(
// //                     child: Text(
// //                       initials,
// //                       style: const TextStyle(
// //                         color:      _teal,
// //                         fontWeight: FontWeight.w700,
// //                         fontSize:   16,
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //                 const SizedBox(width: 12),
// //                 Expanded(
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       Text(
// //                         name,
// //                         style: const TextStyle(
// //                           fontSize:   15,
// //                           fontWeight: FontWeight.w700,
// //                           color:      _textDark,
// //                           height:     1.2,
// //                         ),
// //                         maxLines: 1,
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                       const SizedBox(height: 2),
// //                       Text(
// //                         department,
// //                         style: const TextStyle(
// //                           fontSize:   12,
// //                           color:      _textMuted,
// //                           fontWeight: FontWeight.w400,
// //                         ),
// //                         maxLines: 1,
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //                 // Status badge
// //                 Container(
// //                   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
// //                   decoration: BoxDecoration(
// //                     color:        statusBg,
// //                     borderRadius: BorderRadius.circular(20),
// //                   ),
// //                   child: Text(
// //                     statusLabel,
// //                     style: TextStyle(
// //                       fontSize:   11,
// //                       fontWeight: FontWeight.w600,
// //                       color:      statusColor,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //
// //           // ── Divider ─────────────────────────────────────────────────────
// //           const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
// //
// //           // ── Detail rows ─────────────────────────────────────────────────
// //           Padding(
// //             padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
// //             child: Column(
// //               children: [
// //                 _DetailRow(icon: Icons.tag_rounded,                   label: 'Wager ID',    value: wagerId),
// //                 _DetailRow(icon: Icons.business_outlined,             label: 'Department',  value: department),
// //                 _DetailRow(icon: Icons.person_outline_rounded,        label: 'Father Name', value: fatherName),
// //                 _DetailRow(icon: Icons.credit_card_outlined,          label: 'CNIC',        value: cnic),
// //                 _DetailRow(icon: Icons.phone_outlined,                label: 'Contact',     value: contact),
// //                 _DetailRow(icon: Icons.email_outlined,                label: 'Email',       value: email),
// //                 _DetailRow(icon: Icons.wc_rounded,                    label: 'Gender',      value: gender),
// //                 _DetailRow(icon: Icons.cake_outlined,                 label: 'DOB',         value: dob),
// //                 _DetailRow(icon: Icons.payments_outlined,             label: 'Salary',      value: salary == '—' ? '—' : 'PKR $salary'),
// //                 _DetailRow(icon: Icons.login_rounded,                 label: 'Entry Time',  value: entryTime),
// //                 _DetailRow(icon: Icons.logout_rounded,                label: 'End Time',    value: endTime, isLast: true),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class _DetailRow extends StatelessWidget {
// //   final IconData icon;
// //   final String   label;
// //   final String   value;
// //   final bool     isLast;
// //   const _DetailRow({
// //     required this.icon,
// //     required this.label,
// //     required this.value,
// //     this.isLast = false,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Padding(
// //       padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
// //       child: Row(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
// //           const SizedBox(width: 7),
// //           SizedBox(
// //             width: 82,
// //             child: Text(
// //               label,
// //               style: const TextStyle(
// //                 fontSize:   12,
// //                 color:      Color(0xFF6B7280),
// //                 fontWeight: FontWeight.w500,
// //               ),
// //             ),
// //           ),
// //           Expanded(
// //             child: Text(
// //               value,
// //               style: const TextStyle(
// //                 fontSize:   12,
// //                 color:      Color(0xFF1F2937),
// //                 fontWeight: FontWeight.w500,
// //               ),
// //               maxLines: 1,
// //               overflow: TextOverflow.ellipsis,
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Loading / Error / Empty states
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _LoadingView extends StatelessWidget {
// //   const _LoadingView();
// //   @override
// //   Widget build(BuildContext context) {
// //     return const Center(
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           CircularProgressIndicator(
// //             color:       Color(0xFF0C6B64),
// //             strokeWidth: 2.5,
// //           ),
// //           SizedBox(height: 14),
// //           Text(
// //             'Loading wagers…',
// //             style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class _ErrorView extends StatelessWidget {
// //   final String message;
// //   final VoidCallback onRetry;
// //   const _ErrorView({required this.message, required this.onRetry});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Center(
// //       child: Padding(
// //         padding: const EdgeInsets.all(32),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
// //             const SizedBox(height: 12),
// //             Text(
// //               message,
// //               textAlign: TextAlign.center,
// //               style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
// //             ),
// //             const SizedBox(height: 20),
// //             ElevatedButton.icon(
// //               onPressed: onRetry,
// //               icon:  const Icon(Icons.refresh_rounded, size: 18),
// //               label: const Text('Retry'),
// //               style: ElevatedButton.styleFrom(
// //                 backgroundColor: const Color(0xFF0C6B64),
// //                 foregroundColor: Colors.white,
// //                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
// //                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
// //                 textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // class _EmptyView extends StatelessWidget {
// //   const _EmptyView();
// //   @override
// //   Widget build(BuildContext context) {
// //     return const Center(
// //       child: Column(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
// //           SizedBox(height: 12),
// //           Text(
// //             'No wagers found',
// //             style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
//
//
// ///offline
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/io_client.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:io';
//
// import '../../ViewModels/login_view_model.dart';
// import '../../Repositories/LoginRepositories/login_repository.dart';
// import '../HomeScreenComponents/sidebar_drawer.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // wagers_detail_screen.dart
// // ═══════════════════════════════════════════════════════════════════════════════
//
// class WagersDetailScreen extends StatefulWidget {
//   const WagersDetailScreen({super.key});
//
//   @override
//   State<WagersDetailScreen> createState() => _WagersDetailScreenState();
// }
//
// class _WagersDetailScreenState extends State<WagersDetailScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   // ── Palette (matches TimekeeperScreen teal) ─────────────────────────────────
//   static const _bg         = Color(0xFFF4F6FB);
//   static const _teal       = Color(0xFF0C6B64);
//   static const _tealLight  = Color(0xFFE0F5F3);
//   static const _textDark   = Color(0xFF1F2937);
//   static const _textMuted  = Color(0xFF6B7280);
//   static const _cardWhite  = Colors.white;
//
//   // ── State ───────────────────────────────────────────────────────────────────
//   List<Map<String, dynamic>> _wagers = [];
//   List<Map<String, dynamic>> _filtered = [];
//   bool   _loading = true;
//   bool   _isOffline = false; // true when showing cached (not live) data
//   String _error   = '';
//   final  _searchCtrl = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchWagers();
//     _searchCtrl.addListener(_applySearch);
//   }
//
//   @override
//   void dispose() {
//     _searchCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────────────
//   // Returns the already-registered LoginRepository GetxService if available,
//   // else a plain fallback instance (wagerCacheKey() is stateless either way).
//   LoginRepository _resolveLoginRepo() {
//     try {
//       return Get.find<LoginRepository>();
//     } catch (_) {
//       return LoginRepository();
//     }
//   }
//
//   // ── API ─────────────────────────────────────────────────────────────────────
//   Future<void> _fetchWagers() async {
//     setState(() { _loading = true; _error = ''; });
//
//     // Pull credentials — user model first, SharedPreferences as fallback
//     final loginVM = Get.find<LoginViewModel>();
//     final user    = loginVM.currentUser.value;
//
//     final prefs       = await SharedPreferences.getInstance();
//     final empId       = user?.emp_id?.toString()
//         ?? prefs.get('emp_id')?.toString()
//         ?? prefs.getString('userId')
//         ?? '';
//     final companyCode = user?.company_code?.toString()
//         ?? prefs.getString('company_code')
//         ?? prefs.getString('companyCode')
//         ?? '';
//
//     // Same cache key the LoginRepository writes to right after login.
//     final loginRepo = _resolveLoginRepo();
//     final cacheKey   = loginRepo.wagerCacheKey(empId, companyCode);
//
//     final uri = Uri.parse(
//       'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
//     ).replace(queryParameters: {
//       'emp_id':       empId,
//       'company_code': companyCode,
//     });
//
//     debugPrint('╔══ WAGER FETCH START ══════════════════════════');
//     debugPrint('║ URL         : $uri');
//     debugPrint('║ emp_id      : $empId');
//     debugPrint('║ company_code: $companyCode');
//
//     try {
//       final httpClient = HttpClient()
//         ..badCertificateCallback = (cert, host, port) => true;
//       final ioClient = IOClient(httpClient);
//
//       final response = await ioClient.get(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//       ).timeout(const Duration(seconds: 15));
//
//       debugPrint('║ STATUS : ${response.statusCode}');
//       debugPrint('║ HEADERS: ${response.headers}');
//       debugPrint('║ BODY   : ${response.body}');
//       debugPrint('╚═══════════════════════════════════════════════');
//
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(response.body);
//         debugPrint('✅ Decoded keys: ${decoded.keys}');
//
//         final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
//         debugPrint('✅ Item count: ${items.length}');
//         if (items.isNotEmpty) debugPrint('✅ First item: ${items[0]}');
//
//         // ── Sync: refresh the offline cache with the latest live data ──────
//         await prefs.setString(cacheKey, jsonEncode(items));
//
//         setState(() {
//           _wagers    = items.map((e) => Map<String, dynamic>.from(e)).toList();
//           _filtered  = List.from(_wagers);
//           _loading   = false;
//           _isOffline = false;
//         });
//       } else {
//         debugPrint('❌ Non-200 response: ${response.statusCode}');
//         debugPrint('❌ Body: ${response.body}');
//         await _loadFromCacheOrShowError(
//           prefs,
//           cacheKey,
//           'Error ${response.statusCode}\n\n${response.body}',
//         );
//       }
//     } catch (e, stack) {
//       debugPrint('❌ EXCEPTION: $e');
//       debugPrint('❌ STACKTRACE:\n$stack');
//       await _loadFromCacheOrShowError(prefs, cacheKey, 'Exception:\n$e');
//     }
//   }
//
//   // ── Offline fallback ───────────────────────────────────────────────────────
//   // Called when the live API call fails (e.g. no internet). Looks up the
//   // cache written at login time (or by the last successful live fetch here)
//   // and shows that instead of an error, whenever it exists.
//   Future<void> _loadFromCacheOrShowError(
//       SharedPreferences prefs,
//       String cacheKey,
//       String errorMessage,
//       ) async {
//     final cached = prefs.getString(cacheKey);
//
//     if (cached != null && cached.isNotEmpty) {
//       try {
//         final items = jsonDecode(cached) as List<dynamic>;
//         debugPrint('📦 [WAGERS] Offline — showing $cacheKey (${items.length} item[s])');
//         setState(() {
//           _wagers    = items.map((e) => Map<String, dynamic>.from(e)).toList();
//           _filtered  = List.from(_wagers);
//           _loading   = false;
//           _isOffline = true;
//           _error     = '';
//         });
//         return;
//       } catch (e) {
//         debugPrint('⚠️ [WAGERS] Cached data corrupt: $e');
//       }
//     }
//
//     // No usable cache — show the original error state.
//     setState(() {
//       _error     = errorMessage;
//       _loading   = false;
//       _isOffline = false;
//     });
//   }
//
//   void _applySearch() {
//     final q = _searchCtrl.text.trim().toLowerCase();
//     setState(() {
//       _filtered = q.isEmpty
//           ? List.from(_wagers)
//           : _wagers.where((w) {
//         return w.values.any(
//               (v) => v != null && v.toString().toLowerCase().contains(q),
//         );
//       }).toList();
//     });
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
//   // ── Build ────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key:             _scaffoldKey,
//       backgroundColor: _bg,
//       appBar: AppBar(
//         title: const Text(
//           'Wagers Detail',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 18,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         backgroundColor: _teal,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.menu, color: Colors.white),
//             onPressed: () => _scaffoldKey.currentState?.openDrawer(),
//           ),
//         ],
//       ),
//       drawer: AppDrawer(),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Header strip ──────────────────────────────────────────────────
//           _HeaderStrip(
//             count:   _filtered.length,
//             loading: _loading,
//           ),
//
//           // ── Search bar ────────────────────────────────────────────────────
//           if (!_loading && _error.isEmpty)
//             _SearchBar(controller: _searchCtrl),
//
//           // ── Offline banner ────────────────────────────────────────────────
//           if (!_loading && _error.isEmpty && _isOffline)
//             const _OfflineBanner(),
//
//           // ── Body ──────────────────────────────────────────────────────────
//           Expanded(
//             child: _loading
//                 ? const _LoadingView()
//                 : _error.isNotEmpty
//                 ? _ErrorView(message: _error, onRetry: _fetchWagers)
//                 : _filtered.isEmpty
//                 ? const _EmptyView()
//                 : RefreshIndicator(
//               color:    _teal,
//               onRefresh: _fetchWagers,
//               child: ListView.builder(
//                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//                 itemCount: _filtered.length,
//                 itemBuilder: (_, i) => _WagerCard(
//                   wager:   _filtered[i],
//                   index:   i,
//                   valFn:   _val,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Header Strip
// // ─────────────────────────────────────────────────────────────────────────────
// class _HeaderStrip extends StatelessWidget {
//   final int  count;
//   final bool loading;
//   const _HeaderStrip({required this.count, required this.loading});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width:   double.infinity,
//       padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
//       decoration: const BoxDecoration(
//         color: Color(0xFF0C6B64),
//         borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
//               const SizedBox(width: 8),
//               const Text(
//                 'Wagers Detail',
//                 style: TextStyle(
//                   color:      Colors.white,
//                   fontSize:   18,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//           Text(
//             loading ? 'Fetching records…' : '$count registered wager(s)',
//             style: const TextStyle(
//               color:    Color(0xFFB2DDD9),
//               fontSize: 13,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Search Bar
// // ─────────────────────────────────────────────────────────────────────────────
// class _SearchBar extends StatelessWidget {
//   final TextEditingController controller;
//   const _SearchBar({required this.controller});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
//       child: TextField(
//         controller:  controller,
//         style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
//         decoration: InputDecoration(
//           hintText:       'Search wagers…',
//           hintStyle:      const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
//           prefixIcon:     const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
//           suffixIcon: ValueListenableBuilder(
//             valueListenable: controller,
//             builder: (_, v, __) => v.text.isNotEmpty
//                 ? IconButton(
//               icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
//               onPressed: () => controller.clear(),
//             )
//                 : const SizedBox.shrink(),
//           ),
//           filled:      true,
//           fillColor:   Colors.white,
//           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide:   BorderSide.none,
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide:   const BorderSide(color: Color(0xFFE5E7EB)),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide:   const BorderSide(color: Color(0xFF0C6B64), width: 1.5),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Offline Banner — shown when data is from the last-saved cache, not live
// // ─────────────────────────────────────────────────────────────────────────────
// class _OfflineBanner extends StatelessWidget {
//   const _OfflineBanner();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//       decoration: BoxDecoration(
//         color:        const Color(0xFFFFFBEB),
//         borderRadius: BorderRadius.circular(10),
//         border:       Border.all(color: const Color(0xFFFDE68A)),
//       ),
//       child: Row(
//         children: const [
//           Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFB45309)),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               'No internet — showing last saved data',
//               style: TextStyle(
//                 fontSize:   12.5,
//                 color:      Color(0xFFB45309),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Wager Card
// // ─────────────────────────────────────────────────────────────────────────────
// class _WagerCard extends StatelessWidget {
//   final Map<String, dynamic>              wager;
//   final int                               index;
//   final String Function(Map<String, dynamic>, List<String>) valFn;
//
//   const _WagerCard({
//     required this.wager,
//     required this.index,
//     required this.valFn,
//   });
//
//   static const _teal      = Color(0xFF0C6B64);
//   static const _tealLight = Color(0xFFE0F5F3);
//   static const _textDark  = Color(0xFF1F2937);
//   static const _textMuted = Color(0xFF6B7280);
//
//   @override
//   Widget build(BuildContext context) {
//     // ── Exact column names from WAGERS_DETAIL view ───────────────────────────
//     final name        = valFn(wager, ['wager_name']);
//     final wagerId     = valFn(wager, ['wager_id']);
//     final department  = valFn(wager, ['dep_name', 'dep_id']);
//     final fatherName  = valFn(wager, ['father_name']);
//     final cnic        = valFn(wager, ['cnic_no']);
//     final contact     = valFn(wager, ['contact_no']);
//     final email       = valFn(wager, ['email']);
//     final gender      = valFn(wager, ['gender']);
//     final dob         = valFn(wager, ['dob']);
//     final salary      = valFn(wager, ['basic_salary']);
//     final entryTime   = valFn(wager, ['entry_time']);
//     final endTime     = valFn(wager, ['end_time']);
//     final status      = valFn(wager, ['status']);
//     // kept for avatar/badge reuse
//     final empNo       = wagerId;
//     final designation = department;
//     final joinDate    = dob;
//
//     // Status badge color
//     final isActive = status.toLowerCase() == 'active' ||
//         status == '1' || status.toLowerCase() == 'true';
//     final statusColor  = isActive ? const Color(0xFF059669) : const Color(0xFFD97706);
//     final statusBg     = isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
//     final statusLabel  = status == '—' ? 'Unknown' : (isActive ? 'Active' : 'Inactive');
//
//     // Avatar initials
//     final nameParts  = name.trim().split(' ');
//     final initials   = nameParts.length >= 2
//         ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
//         : name.isNotEmpty ? name[0].toUpperCase() : '??';
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color:        Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color:        _teal.withOpacity(0.06),
//             blurRadius:   14,
//             spreadRadius: 0,
//             offset:       const Offset(0, 4),
//           ),
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.03),
//             blurRadius: 5,
//             offset:     const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // ── Top row: avatar + name + status ────────────────────────────
//           Padding(
//             padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // Avatar circle
//                 Container(
//                   width:  46,
//                   height: 46,
//                   decoration: const BoxDecoration(
//                     color: _tealLight,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Center(
//                     child: Text(
//                       initials,
//                       style: const TextStyle(
//                         color:      _teal,
//                         fontWeight: FontWeight.w700,
//                         fontSize:   16,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         name,
//                         style: const TextStyle(
//                           fontSize:   15,
//                           fontWeight: FontWeight.w700,
//                           color:      _textDark,
//                           height:     1.2,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         department,
//                         style: const TextStyle(
//                           fontSize:   12,
//                           color:      _textMuted,
//                           fontWeight: FontWeight.w400,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Status badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//                   decoration: BoxDecoration(
//                     color:        statusBg,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     statusLabel,
//                     style: TextStyle(
//                       fontSize:   11,
//                       fontWeight: FontWeight.w600,
//                       color:      statusColor,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // ── Divider ─────────────────────────────────────────────────────
//           const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
//
//           // ── Detail rows ─────────────────────────────────────────────────
//           Padding(
//             padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
//             child: Column(
//               children: [
//                 _DetailRow(icon: Icons.tag_rounded,                   label: 'Wager ID',    value: wagerId),
//                 _DetailRow(icon: Icons.business_outlined,             label: 'Department',  value: department),
//                 _DetailRow(icon: Icons.person_outline_rounded,        label: 'Father Name', value: fatherName),
//                 _DetailRow(icon: Icons.credit_card_outlined,          label: 'CNIC',        value: cnic),
//                 _DetailRow(icon: Icons.phone_outlined,                label: 'Contact',     value: contact),
//                 _DetailRow(icon: Icons.email_outlined,                label: 'Email',       value: email),
//                 _DetailRow(icon: Icons.wc_rounded,                    label: 'Gender',      value: gender),
//                 _DetailRow(icon: Icons.cake_outlined,                 label: 'DOB',         value: dob),
//                 _DetailRow(icon: Icons.payments_outlined,             label: 'Salary',      value: salary == '—' ? '—' : 'PKR $salary'),
//                 _DetailRow(icon: Icons.login_rounded,                 label: 'Entry Time',  value: entryTime),
//                 _DetailRow(icon: Icons.logout_rounded,                label: 'End Time',    value: endTime, isLast: true),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _DetailRow extends StatelessWidget {
//   final IconData icon;
//   final String   label;
//   final String   value;
//   final bool     isLast;
//   const _DetailRow({
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
//           Icon(icon, size: 15, color: const Color(0xFF9CA3AF)),
//           const SizedBox(width: 7),
//           SizedBox(
//             width: 82,
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
//                 fontWeight: FontWeight.w500,
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
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Loading / Error / Empty states
// // ─────────────────────────────────────────────────────────────────────────────
// class _LoadingView extends StatelessWidget {
//   const _LoadingView();
//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           CircularProgressIndicator(
//             color:       Color(0xFF0C6B64),
//             strokeWidth: 2.5,
//           ),
//           SizedBox(height: 14),
//           Text(
//             'Loading wagers…',
//             style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ErrorView extends StatelessWidget {
//   final String message;
//   final VoidCallback onRetry;
//   const _ErrorView({required this.message, required this.onRetry});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
//             const SizedBox(height: 12),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               onPressed: onRetry,
//               icon:  const Icon(Icons.refresh_rounded, size: 18),
//               label: const Text('Retry'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF0C6B64),
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
// class _EmptyView extends StatelessWidget {
//   const _EmptyView();
//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
//           SizedBox(height: 12),
//           Text(
//             'No wagers found',
//             style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
import '../../Repositories/LoginRepositories/login_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// wagers_detail_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class WagersDetailScreen extends StatefulWidget {
  const WagersDetailScreen({super.key});

  @override
  State<WagersDetailScreen> createState() => _WagersDetailScreenState();
}

class _WagersDetailScreenState extends State<WagersDetailScreen> {
  // ── Palette ─────────────────────────────────────────────────────────────────
  static const _bg         = Color(0xFFF4F6FB);
  static const _teal       = Color(0xFF0C6B64);
  static const _tealLight  = Color(0xFFE0F5F3);
  static const _textDark   = Color(0xFF1F2937);
  static const _textMuted  = Color(0xFF6B7280);
  static const _cardWhite  = Colors.white;

  // ── State ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _wagers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool   _loading = true;
  bool   _isOffline = false;
  String _error   = '';
  final  _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchWagers();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  LoginRepository _resolveLoginRepo() {
    try {
      return Get.find<LoginRepository>();
    } catch (_) {
      return LoginRepository();
    }
  }

  // ── API ─────────────────────────────────────────────────────────────────────
  Future<void> _fetchWagers() async {
    setState(() { _loading = true; _error = ''; });

    final loginVM = Get.find<LoginViewModel>();
    final user    = loginVM.currentUser.value;

    final prefs       = await SharedPreferences.getInstance();
    final empId       = user?.emp_id?.toString()
        ?? prefs.get('emp_id')?.toString()
        ?? prefs.getString('userId')
        ?? '';
    final companyCode = user?.company_code?.toString()
        ?? prefs.getString('company_code')
        ?? prefs.getString('companyCode')
        ?? '';

    final loginRepo = _resolveLoginRepo();
    final cacheKey   = loginRepo.wagerCacheKey(empId, companyCode);

    final uri = Uri.parse(
      'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
    ).replace(queryParameters: {
      'emp_id':       empId,
      'company_code': companyCode,
    });

    debugPrint('╔══ WAGER FETCH START ══════════════════════════');
    debugPrint('║ URL         : $uri');
    debugPrint('║ emp_id      : $empId');
    debugPrint('║ company_code: $companyCode');

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);

      final response = await ioClient.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('║ STATUS : ${response.statusCode}');
      debugPrint('║ HEADERS: ${response.headers}');
      debugPrint('║ BODY   : ${response.body}');
      debugPrint('╚═══════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Decoded keys: ${decoded.keys}');

        final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
        debugPrint('✅ Item count: ${items.length}');
        if (items.isNotEmpty) debugPrint('✅ First item: ${items[0]}');

        await prefs.setString(cacheKey, jsonEncode(items));

        setState(() {
          _wagers    = items.map((e) => Map<String, dynamic>.from(e)).toList();
          _filtered  = List.from(_wagers);
          _loading   = false;
          _isOffline = false;
        });
      } else {
        debugPrint('❌ Non-200 response: ${response.statusCode}');
        debugPrint('❌ Body: ${response.body}');
        await _loadFromCacheOrShowError(
          prefs,
          cacheKey,
          'Error ${response.statusCode}\n\n${response.body}',
        );
      }
    } catch (e, stack) {
      debugPrint('❌ EXCEPTION: $e');
      debugPrint('❌ STACKTRACE:\n$stack');
      await _loadFromCacheOrShowError(prefs, cacheKey, 'Exception:\n$e');
    }
  }

  Future<void> _loadFromCacheOrShowError(
      SharedPreferences prefs,
      String cacheKey,
      String errorMessage,
      ) async {
    final cached = prefs.getString(cacheKey);

    if (cached != null && cached.isNotEmpty) {
      try {
        final items = jsonDecode(cached) as List<dynamic>;
        debugPrint('📦 [WAGERS] Offline — showing $cacheKey (${items.length} item[s])');
        setState(() {
          _wagers    = items.map((e) => Map<String, dynamic>.from(e)).toList();
          _filtered  = List.from(_wagers);
          _loading   = false;
          _isOffline = true;
          _error     = '';
        });
        return;
      } catch (e) {
        debugPrint('⚠️ [WAGERS] Cached data corrupt: $e');
      }
    }

    setState(() {
      _error     = errorMessage;
      _loading   = false;
      _isOffline = false;
    });
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_wagers)
          : _wagers.where((w) {
        return w.values.any(
              (v) => v != null && v.toString().toLowerCase().contains(q),
        );
      }).toList();
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _val(Map<String, dynamic> w, List<String> keys) {
    for (final k in keys) {
      final v = w[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return '—';
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient Header (same as terminate screen) ─────────────────────
          _WagersGradientHeader(
            title:    'Wagers Detail',
            subtitle: '${_filtered.length} registered wager(s)',
            icon:     Icons.bar_chart_rounded,
            loading:  _loading,
            rightIconBg: Colors.white.withOpacity(0.2),
          ),

          // ── Search bar ────────────────────────────────────────────────────
          if (!_loading && _error.isEmpty)
            _SearchBar(controller: _searchCtrl),

          // ── Offline banner ────────────────────────────────────────────────
          if (!_loading && _error.isEmpty && _isOffline)
            const _OfflineBanner(),

          // ── Body ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const _LoadingView()
                : _error.isNotEmpty
                ? _ErrorView(message: _error, onRetry: _fetchWagers)
                : _filtered.isEmpty
                ? const _EmptyView()
                : RefreshIndicator(
              color:    _teal,
              onRefresh: _fetchWagers,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _WagerCard(
                  wager:   _filtered[i],
                  index:   i,
                  valFn:   _val,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient Header — same style as terminate screen
// ─────────────────────────────────────────────────────────────────────────────
class _WagersGradientHeader extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final IconData icon;
  final bool     loading;
  final Color    rightIconBg;

  const _WagersGradientHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.loading = false,
    this.rightIconBg = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    Text(loading ? 'Fetching records…' : subtitle,
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
        controller:  controller,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText:       'Search wagers…',
          hintStyle:      const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon:     const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
              onPressed: () => controller.clear(),
            )
                : const SizedBox.shrink(),
          ),
          filled:      true,
          fillColor:   Colors.white,
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
// Offline Banner
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: const [
          Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet — showing last saved data',
              style: TextStyle(
                fontSize:   12.5,
                color:      Color(0xFFB45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wager Card
// ─────────────────────────────────────────────────────────────────────────────
class _WagerCard extends StatelessWidget {
  final Map<String, dynamic>              wager;
  final int                               index;
  final String Function(Map<String, dynamic>, List<String>) valFn;

  const _WagerCard({
    required this.wager,
    required this.index,
    required this.valFn,
  });

  static const _teal      = Color(0xFF0C6B64);
  static const _tealLight = Color(0xFFE0F5F3);
  static const _textDark  = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final name        = valFn(wager, ['wager_name']);
    final wagerId     = valFn(wager, ['wager_id']);
    final department  = valFn(wager, ['dep_name', 'dep_id']);
    final fatherName  = valFn(wager, ['father_name']);
    final cnic        = valFn(wager, ['cnic_no']);
    final contact     = valFn(wager, ['contact_no']);
    final email       = valFn(wager, ['email']);
    final gender      = valFn(wager, ['gender']);
    final dob         = valFn(wager, ['dob']);
    final salary      = valFn(wager, ['basic_salary']);
    final entryTime   = valFn(wager, ['entry_time']);
    final endTime     = valFn(wager, ['end_time']);
    final status      = valFn(wager, ['status']);

    final isActive = status.toLowerCase() == 'active' ||
        status == '1' || status.toLowerCase() == 'true';
    final statusColor  = isActive ? const Color(0xFF059669) : const Color(0xFFD97706);
    final statusBg     = isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final statusLabel  = status == '—' ? 'Unknown' : (isActive ? 'Active' : 'Inactive');

    final nameParts  = name.trim().split(' ');
    final initials   = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : '??';

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
                        name,
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      _textDark,
                          height:     1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        department,
                        style: const TextStyle(
                          fontSize:   12,
                          color:      _textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color:        statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: [
                _DetailRow(icon: Icons.tag_rounded,                   label: 'Wager ID',    value: wagerId),
                _DetailRow(icon: Icons.business_outlined,             label: 'Department',  value: department),
                _DetailRow(icon: Icons.person_outline_rounded,        label: 'Father Name', value: fatherName),
                _DetailRow(icon: Icons.credit_card_outlined,          label: 'CNIC',        value: cnic),
                _DetailRow(icon: Icons.phone_outlined,                label: 'Contact',     value: contact),
                _DetailRow(icon: Icons.email_outlined,                label: 'Email',       value: email),
                _DetailRow(icon: Icons.wc_rounded,                    label: 'Gender',      value: gender),
                _DetailRow(icon: Icons.cake_outlined,                 label: 'DOB',         value: dob),
                _DetailRow(icon: Icons.payments_outlined,             label: 'Salary',      value: salary == '—' ? '—' : 'PKR $salary'),
                _DetailRow(icon: Icons.login_rounded,                 label: 'Entry Time',  value: entryTime),
                _DetailRow(icon: Icons.logout_rounded,                label: 'End Time',    value: endTime, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
// Loading / Error / Empty states
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
            color:       Color(0xFF0C6B64),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 14),
          Text(
            'Loading wagers…',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C6B64),
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
          Text(
            'No wagers found',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ],
      ),
    );
  }
}