// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../../Database/util.dart';
// //
// // // Navigate simply:  Get.to(() => const EmployeeProfileScreen());
// //
// // class EmployeeProfileScreen extends StatefulWidget {
// //   final String? empId;
// //   const EmployeeProfileScreen({Key? key, this.empId}) : super(key: key);
// //
// //   @override
// //   State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
// // }
// //
// // class _EmployeeProfileScreenState extends State<EmployeeProfileScreen>
// //     with SingleTickerProviderStateMixin {
// //
// //   // ── Design tokens ──────────────────────────────────────────────────────────
// //   static const Color _navy      = Color(0xFF1A2B6D);
// //   static const Color _gold      = Color(0xFFC9A84C);
// //   static const Color _goldLight = Color(0xFFF5EDD6);
// //   static const Color _surface   = Color(0xFFF4F6FB);
// //   static const Color _green     = Color(0xFF22C55E);
// //   static const Color _red       = Color(0xFFEF4444);
// //   static const Color _textMain  = Color(0xFF111827);
// //   static const Color _textMuted = Color(0xFF6B7280);
// //   static const Color _divider   = Color(0xFFE8EAF0);
// //   static const Color _cBlue     = Color(0xFF4060FF);
// //   static const Color _cPurple   = Color(0xFF7C3AED);
// //   static const Color _cTeal     = Color(0xFF059669);
// //   static const Color _cAmber    = Color(0xFFF59E0B);
// //   static const Color _cRed      = Color(0xFFDC2626);
// //   // ───────────────────────────────────────────────────────────────────────────
// //
// //   Map<String, dynamic>? employee;
// //   bool isLoading = true;
// //   String errorMessage = '';
// //   String _resolvedId = '';
// //
// //   late AnimationController _animController;
// //   late Animation<double> _fadeAnim;
// //   late Animation<Offset> _slideAnim;
// //
// //   static const String _baseUrl =
// //       'http://oracle.metaxperts.net/ords/production/empinfo/get';
// //
// //   static const List<String> _possibleIdKeys = [
// //     'emp_id', 'user_id', 'userId', 'employee_id', 'employeeId',
// //     'id', 'ID', 'EMP_ID', 'USER_ID', 'prefUserId',
// //   ];
// //
// //   // ── Lifecycle ──────────────────────────────────────────────────────────────
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _animController = AnimationController(
// //         vsync: this, duration: const Duration(milliseconds: 650));
// //     _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
// //     _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
// //         .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
// //     _initAndFetch();
// //   }
// //
// //   @override
// //   void dispose() {
// //     _animController.dispose();
// //     super.dispose();
// //   }
// //
// //   // ── Resolve emp_id ─────────────────────────────────────────────────────────
// //
// //   Future<String> _resolveEmpId() async {
// //     if (widget.empId != null && widget.empId!.trim().isNotEmpty) {
// //       return widget.empId!.trim();
// //     }
// //     await loadEmployeeData();
// //     if (emp_id.trim().isNotEmpty) return emp_id.trim();
// //
// //     final prefs = await SharedPreferences.getInstance();
// //     for (final key in _possibleIdKeys) {
// //       final val = prefs.get(key)?.toString().trim() ?? '';
// //       if (val.isNotEmpty) return val;
// //     }
// //     for (final key in prefs.getKeys()) {
// //       final val = prefs.get(key)?.toString().trim() ?? '';
// //       if (val.isNotEmpty && int.tryParse(val) != null) return val;
// //     }
// //     return '';
// //   }
// //
// //   Future<void> _initAndFetch() async {
// //     _resolvedId = await _resolveEmpId();
// //     await _fetchEmployee();
// //   }
// //
// //   // ── API ────────────────────────────────────────────────────────────────────
// //
// //   Future<void> _fetchEmployee() async {
// //     setState(() { isLoading = true; errorMessage = ''; employee = null; });
// //     _animController.reset();
// //     try {
// //       if (_resolvedId.isEmpty) {
// //         throw Exception(
// //             'Could not find Employee ID.\nPlease log out and log in again.');
// //       }
// //       final uri = Uri.parse(_baseUrl)
// //           .replace(queryParameters: {'emp_id': _resolvedId});
// //
// //       final response = await http
// //           .get(uri, headers: {'Accept': 'application/json'})
// //           .timeout(const Duration(seconds: 15));
// //
// //       if (response.statusCode == 200) {
// //         final dynamic raw = json.decode(response.body);
// //         Map<String, dynamic>? parsed;
// //
// //         if (raw is Map<String, dynamic>) {
// //           if (raw.containsKey('items') && raw['items'] is List) {
// //             final list = raw['items'] as List;
// //             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
// //           } else if (raw.containsKey('data') && raw['data'] is List) {
// //             final list = raw['data'] as List;
// //             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
// //           } else {
// //             parsed = raw;
// //           }
// //         } else if (raw is List && raw.isNotEmpty) {
// //           parsed = Map<String, dynamic>.from(raw.first);
// //         }
// //
// //         setState(() { employee = parsed; isLoading = false; });
// //         _animController.forward();
// //       } else {
// //         throw Exception('Server error: HTTP ${response.statusCode}');
// //       }
// //     } catch (e) {
// //       setState(() {
// //         errorMessage = e.toString().replaceFirst('Exception: ', '');
// //         isLoading = false;
// //       });
// //     }
// //   }
// //
// //   // ── Field helpers ──────────────────────────────────────────────────────────
// //
// //   String _v(List<String> keys) {
// //     if (employee == null) return '—';
// //     for (final k in keys) {
// //       final v = employee![k];
// //       if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
// //     }
// //     return '—';
// //   }
// //
// //   // Personal
// //   String get _empId      => _v(['EMP_ID',    'emp_id',    'employee_id']);
// //   String get _empName    => _v(['EMP_NAME',  'emp_name',  'name', 'full_name']);
// //   String get _fatherName => _v(['FATHER_NAME','father_name']);
// //   String get _cnic       => _v(['CNIC_NO',   'cnic_no',   'cnic']);
// //   String get _contact    => _v(['CONTACT_NO','contact_no','phone','mobile']);
// //   String get _email      => _v(['EMAIL',     'email']);
// //   String get _address    => _v(['ADDRESS',   'address']);
// //   String get _gender     => _v(['GENDER',    'gender']);
// //   String get _marital    => _v(['MARITAL_STATUS','marital_status']);
// //   String get _dob        => _v(['DOB',       'dob','date_of_birth']);
// //   String get _education  => _v(['EDUCATION', 'education']);
// //   String get _image      => _v(['IMAGE',     'image','photo']);
// //
// //   // Job Information
// //   String get _dept       => _v(['DEP_NAME',  'dep_name',  'department']);
// //   String get _subDept    => _v(['SUB_DEP_NAME','sub_dep_name','sub_department']);
// //   String get _job        => _v(['JOB',       'job','designation','job_title']);
// //   String get _jobGrade   => _v(['JOB_GRADE', 'job_grade', 'grade']);
// //   String get _hiringDate => _v(['HIRING_DATE','hiring_date','join_date']);
// //   String get _termDate   => _v(['TERMINATION_DATE','termination_date']);
// //   String get _active     => _v(['ACTIVE',    'active',    'status']);
// //
// //   // Salary
// //   String get _basicSalary => _v(['BASIC_SALARY','basic_salary','salary']);
// //
// //   // Attendance
// //   String get _entryTime  => _v(['ENTRY_TIME','entry_time']);
// //   String get _endTime    => _v(['END_TIME',  'end_time']);
// //
// //   // Policy
// //   String get _otDate     => _v(['OVERTIME_EFFECTIVE_DATE','overtime_effective_date','ot_effective_date']);
// //   String get _lateDate   => _v(['LATEHOURS_EFFECTIVE_DATE','latehours_effective_date','late_hours_effective_date']);
// //   String get _overtime   => _v(['OVER_TIME', 'over_time', 'overtime']);
// //   String get _absentDed  => _v(['ABSENT_DEDUCTION','absent_deduction']);
// //   String get _lateDed    => _v(['LATE_DEDUCTION','late_deduction']);
// //   String get _earlyArr   => _v(['EARLY_ARRIVAL','early_arrival']);
// //   String get _wht        => _v(['WHT',       'wht','wht_applied']);
// //   String get _eobi       => _v(['EOBI_DEDUCTION','eobi_deduction']);
// //   String get _medical    => _v(['MEDICAL_ALLOWNACE','medical_allowance','medical_allownace']);
// //
// //   bool get _isActive {
// //     final s = _active.toLowerCase();
// //     return s == 'y' || s == 'yes' || s == '1' || s == 'active';
// //   }
// //
// //   // ── Build ──────────────────────────────────────────────────────────────────
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: _surface,
// //       body: CustomScrollView(
// //         physics: const BouncingScrollPhysics(),
// //         slivers: [
// //           _buildAppBar(),
// //           SliverToBoxAdapter(child: _buildContent()),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Sliver App Bar ─────────────────────────────────────────────────────────
// //
// //   Widget _buildAppBar() {
// //     return SliverAppBar(
// //       expandedHeight: 215,
// //       pinned: true,
// //       stretch: true,
// //       backgroundColor: _navy,
// //       leading: IconButton(
// //         icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
// //         onPressed: () => Navigator.pop(context),
// //       ),
// //       actions: [
// //         IconButton(
// //           icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
// //           onPressed: _initAndFetch,
// //         ),
// //         const SizedBox(width: 8),
// //       ],
// //       flexibleSpace: FlexibleSpaceBar(
// //         stretchModes: const [StretchMode.zoomBackground],
// //         background: Stack(fit: StackFit.expand, children: [
// //           Container(
// //             decoration: const BoxDecoration(
// //               gradient: LinearGradient(
// //                 colors: [_navy, Color(0xFF253D8A)],
// //                 begin: Alignment.topLeft,
// //                 end: Alignment.bottomRight,
// //               ),
// //             ),
// //           ),
// //           Positioned(top: -50, right: -30,
// //               child: Container(width: 200, height: 200,
// //                   decoration: BoxDecoration(shape: BoxShape.circle,
// //                       color: Colors.white.withOpacity(0.05)))),
// //           Positioned(bottom: -40, left: -20,
// //               child: Container(width: 140, height: 140,
// //                   decoration: BoxDecoration(shape: BoxShape.circle,
// //                       color: _gold.withOpacity(0.09)))),
// //           Positioned(
// //             bottom: 18, left: 0, right: 0,
// //             child: Column(children: [
// //               _buildAvatar(),
// //               const SizedBox(height: 8),
// //               if (!isLoading && errorMessage.isEmpty) ...[
// //                 Text(_empName,
// //                     style: const TextStyle(
// //                         color: Colors.white, fontSize: 17,
// //                         fontWeight: FontWeight.w700, letterSpacing: 0.3),
// //                     textAlign: TextAlign.center),
// //                 const SizedBox(height: 2),
// //                 Text(_job,
// //                     style: TextStyle(
// //                         color: Colors.white.withOpacity(0.72),
// //                         fontSize: 12, letterSpacing: 0.4)),
// //                 const SizedBox(height: 5),
// //                 Row(mainAxisAlignment: MainAxisAlignment.center, children: [
// //                   const Icon(Icons.mail_outline_rounded,
// //                       size: 11, color: Colors.white54),
// //                   const SizedBox(width: 4),
// //                   Text(_email,
// //                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
// //                   const SizedBox(width: 14),
// //                   const Icon(Icons.badge_outlined,
// //                       size: 11, color: Colors.white54),
// //                   const SizedBox(width: 3),
// //                   Text(_empId,
// //                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
// //                 ]),
// //               ],
// //             ]),
// //           ),
// //         ]),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildAvatar() {
// //     final name = employee != null ? _empName : emp_name;
// //     final initials = name.isNotEmpty && name != '—'
// //         ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
// //         : (_resolvedId.isNotEmpty ? _resolvedId[0] : '?');
// //     final imgUrl = _image != '—' ? _image : null;
// //
// //     return Container(
// //       width: 68, height: 68,
// //       decoration: BoxDecoration(
// //         shape: BoxShape.circle,
// //         color: Colors.white,
// //         border: Border.all(color: _gold, width: 2.5),
// //         boxShadow: [BoxShadow(
// //             color: _navy.withOpacity(0.3), blurRadius: 18, spreadRadius: 1)],
// //       ),
// //       child: ClipOval(
// //         child: imgUrl != null
// //             ? Image.network(imgUrl, fit: BoxFit.cover,
// //             errorBuilder: (_, __, ___) => _avatarInitials(initials))
// //             : _avatarInitials(initials),
// //       ),
// //     );
// //   }
// //
// //   Widget _avatarInitials(String initials) => Center(
// //     child: Text(initials,
// //         style: const TextStyle(
// //             color: _cBlue, fontSize: 22,
// //             fontWeight: FontWeight.w800, letterSpacing: 1)),
// //   );
// //
// //   // ── Content states ─────────────────────────────────────────────────────────
// //
// //   Widget _buildContent() {
// //     if (isLoading)               return _stateLoading();
// //     if (errorMessage.isNotEmpty) return _stateError();
// //     if (employee == null)        return _stateEmpty();
// //     return _buildProfile();
// //   }
// //
// //   Widget _stateLoading() => SizedBox(height: 400, child: Center(
// //     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
// //       SizedBox(width: 44, height: 44,
// //           child: CircularProgressIndicator(strokeWidth: 2.5,
// //               valueColor: const AlwaysStoppedAnimation<Color>(_cBlue))),
// //       const SizedBox(height: 18),
// //       const Text('Loading profile...',
// //           style: TextStyle(color: _textMuted, fontSize: 13)),
// //     ]),
// //   ));
// //
// //   Widget _stateError() => SizedBox(height: 400, child: Center(
// //     child: Padding(padding: const EdgeInsets.all(32),
// //       child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
// //         Container(width: 72, height: 72,
// //             decoration: BoxDecoration(shape: BoxShape.circle,
// //                 color: Colors.red.withOpacity(0.08)),
// //             child: const Icon(Icons.error_outline_rounded,
// //                 color: Colors.redAccent, size: 34)),
// //         const SizedBox(height: 20),
// //         const Text('Could not load profile',
// //             style: TextStyle(color: _textMain, fontSize: 17,
// //                 fontWeight: FontWeight.w600)),
// //         const SizedBox(height: 8),
// //         Text(errorMessage, textAlign: TextAlign.center,
// //             style: const TextStyle(color: _textMuted, fontSize: 13)),
// //         const SizedBox(height: 24),
// //         _btn('Try Again', Icons.refresh_rounded, _cBlue, _initAndFetch),
// //       ]),
// //     ),
// //   ));
// //
// //   Widget _stateEmpty() => SizedBox(height: 400, child: Center(
// //     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
// //       Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade300),
// //       const SizedBox(height: 16),
// //       Text('No data found for ID: $_resolvedId',
// //           style: const TextStyle(color: _textMuted, fontSize: 14)),
// //       const SizedBox(height: 16),
// //       _btn('Refresh', Icons.refresh_rounded, _cBlue, _initAndFetch),
// //     ]),
// //   ));
// //
// //   // ── Profile ────────────────────────────────────────────────────────────────
// //
// //   Widget _buildProfile() {
// //     return FadeTransition(
// //       opacity: _fadeAnim,
// //       child: SlideTransition(
// //         position: _slideAnim,
// //         child: Padding(
// //           padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
// //           child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
// //               children: [
// //
// //                 _activeBadge(),
// //                 const SizedBox(height: 18),
// //
// //                 // ── 1  Personal Information ────────────────────────────────────
// //                 _sectionHeader('Personal Information',
// //                     Icons.person_outline_rounded, _cBlue),
// //                 const SizedBox(height: 8),
// //                 _card([
// //                   _pair('FATHER NAME', _fatherName, 'DATE OF BIRTH',  _dob),
// //                   _pair('GENDER',      _gender,     'MARITAL STATUS', _marital),
// //                   _pair('CNIC NO',     _cnic,       'EDUCATION',      _education),
// //                   _pair('CONTACT NO',  _contact,    'ADDRESS',        _address),
// //                 ]),
// //                 const SizedBox(height: 18),
// //
// //                 // ── 2  Job Information ─────────────────────────────────────────
// //                 _sectionHeader('Job Information',
// //                     Icons.work_outline_rounded, _cPurple),
// //                 const SizedBox(height: 8),
// //                 _card([
// //                   _pair('DEPARTMENT',       _dept,     'SUB DEPARTMENT',   _subDept),
// //                   _pair('JOB GRADE',        _jobGrade, 'HIRING DATE',      _hiringDate),
// //                   _full('TERMINATION DATE', _termDate),
// //                   _full('STATUS', _active,
// //                       valueColor: _active == '—' ? _textMuted : (_isActive ? _green : _red)),
// //                 ]),
// //                 const SizedBox(height: 18),
// //
// //                 // ── 3  Salary ──────────────────────────────────────────────────
// //                 _sectionHeader('Salary',
// //                     Icons.payments_outlined, _cTeal),
// //                 const SizedBox(height: 8),
// //                 _card([
// //                   _full('BASIC / STARTING SALARY',
// //                       _basicSalary != '—' ? 'PKR $_basicSalary' : '—'),
// //                 ]),
// //                 const SizedBox(height: 18),
// //
// //                 // ── 4  Attendance Policy ───────────────────────────────────────
// //                 _sectionHeader('Attendance Policy',
// //                     Icons.access_time_rounded, _cAmber),
// //                 const SizedBox(height: 8),
// //                 _card([
// //                   _pair('ENTRY TIME', _entryTime, 'END TIME', _endTime),
// //                 ]),
// //                 const SizedBox(height: 18),
// //
// //                 // ── 5  Policy Details ──────────────────────────────────────────
// //                 _sectionHeader('Policy Details',
// //                     Icons.policy_outlined, _cRed),
// //                 const SizedBox(height: 8),
// //                 _card([
// //                   _pair('OVERTIME',         _overtime,  'OT EFFECTIVE DATE',
// //                       _otDate,        leftYesNo: true),
// //                   _pair('LATE DEDUCTION',   _lateDed,   'LATE HRS EFF. DATE',
// //                       _lateDate,      leftYesNo: true),
// //                   _pair('ABSENT DEDUCTION', _absentDed, 'EARLY ARRIVAL',
// //                       _earlyArr,      leftYesNo: true, rightYesNo: true),
// //                   _pair('WHT',              _wht,       'EOBI DEDUCTION',
// //                       _eobi,          leftYesNo: true, rightYesNo: true),
// //                   _full('MEDICAL ALLOWANCE', _medical,   yesNo: true),
// //                 ]),
// //
// //               ]),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── Active badge ───────────────────────────────────────────────────────────
// //
// //   Widget _activeBadge() {
// //     final has   = _active != '—';
// //     final color = has ? (_isActive ? _green : Colors.orange) : Colors.blueGrey;
// //     final label = has ? (_isActive ? 'ACTIVE' : 'INACTIVE') : 'EMPLOYEE';
// //
// //     return Center(child: Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.09),
// //         borderRadius: BorderRadius.circular(20),
// //         border: Border.all(color: color.withOpacity(0.35)),
// //       ),
// //       child: Row(mainAxisSize: MainAxisSize.min, children: [
// //         Container(width: 7, height: 7,
// //             decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
// //         const SizedBox(width: 8),
// //         Text(label,
// //             style: TextStyle(color: color, fontSize: 11,
// //                 fontWeight: FontWeight.w700, letterSpacing: 1.3)),
// //       ]),
// //     ));
// //   }
// //
// //   // ── Section header ─────────────────────────────────────────────────────────
// //
// //   Widget _sectionHeader(String title, IconData icon, Color color) {
// //     return Row(children: [
// //       Container(
// //           width: 4, height: 20,
// //           decoration: BoxDecoration(
// //               color: _gold, borderRadius: BorderRadius.circular(2))),
// //       const SizedBox(width: 8),
// //       Container(
// //         width: 28, height: 28,
// //         decoration: BoxDecoration(
// //             color: color.withOpacity(0.10),
// //             borderRadius: BorderRadius.circular(8)),
// //         child: Icon(icon, size: 15, color: color),
// //       ),
// //       const SizedBox(width: 8),
// //       Text(title,
// //           style: const TextStyle(color: _navy, fontSize: 13,
// //               fontWeight: FontWeight.w700, letterSpacing: 0.3)),
// //     ]);
// //   }
// //
// //   // ── Card ───────────────────────────────────────────────────────────────────
// //
// //   Widget _card(List<Widget> rows) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(12),
// //         border: Border.all(color: _divider),
// //         boxShadow: [BoxShadow(
// //             color: Colors.black.withOpacity(0.04),
// //             blurRadius: 10, offset: const Offset(0, 3))],
// //       ),
// //       child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
// //           children: rows.asMap().entries.map((e) => Column(
// //             crossAxisAlignment: CrossAxisAlignment.stretch,
// //             children: [
// //               e.value,
// //               if (e.key < rows.length - 1)
// //                 const Divider(height: 1, thickness: 1, color: _divider),
// //             ],
// //           )).toList()),
// //     );
// //   }
// //
// //   // ── Row builders ───────────────────────────────────────────────────────────
// //
// //   Widget _pair(
// //       String lLabel, String lVal,
// //       String rLabel, String rVal, {
// //         bool leftYesNo  = false,
// //         bool rightYesNo = false,
// //       }) {
// //     return IntrinsicHeight(
// //       child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
// //         Expanded(child: _cell(lLabel, lVal, yesNo: leftYesNo)),
// //         const VerticalDivider(width: 1, thickness: 1, color: _divider),
// //         Expanded(child: _cell(rLabel, rVal, yesNo: rightYesNo)),
// //       ]),
// //     );
// //   }
// //
// //   Widget _full(String label, String val,
// //       {bool yesNo = false, Color? valueColor}) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
// //       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// //         Text(label,
// //             style: const TextStyle(fontSize: 9, color: _textMuted,
// //                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
// //         const SizedBox(height: 3),
// //         Text(val,
// //             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
// //                 color: valueColor ?? _color(val, yesNo: yesNo))),
// //       ]),
// //     );
// //   }
// //
// //   Widget _cell(String label, String val, {bool yesNo = false}) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
// //       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
// //         Text(label,
// //             style: const TextStyle(fontSize: 9, color: _textMuted,
// //                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
// //         const SizedBox(height: 3),
// //         Text(val,
// //             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
// //                 color: _color(val, yesNo: yesNo))),
// //       ]),
// //     );
// //   }
// //
// //   Color _color(String val, {bool yesNo = false}) {
// //     if (val == '—') return _textMuted;
// //     if (yesNo) {
// //       final v = val.toLowerCase();
// //       if (v == 'no'  || v == 'n' || v == '0') return _red;
// //       if (v == 'yes' || v == 'y' || v == '1') return _green;
// //     }
// //     return _textMain;
// //   }
// //
// //   // ── Button ─────────────────────────────────────────────────────────────────
// //
// //   Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
// //     return GestureDetector(
// //       onTap: onTap,
// //       child: Container(
// //         padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
// //         decoration: BoxDecoration(
// //             color: color,
// //             borderRadius: BorderRadius.circular(14),
// //             boxShadow: [BoxShadow(
// //                 color: color.withOpacity(0.35),
// //                 blurRadius: 16, offset: const Offset(0, 6))]),
// //         child: Row(mainAxisSize: MainAxisSize.min, children: [
// //           Icon(icon, color: Colors.white, size: 18),
// //           const SizedBox(width: 8),
// //           Text(label, style: const TextStyle(
// //               color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
// //         ]),
// //       ),
// //     );
// //   }
// // }
//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../AppColors.dart';
// import '../../Database/util.dart';
//
//
// // Navigate simply:  Get.to(() => const EmployeeProfileScreen());
//
// class EmployeeProfileScreen extends StatefulWidget {
//   final String? empId;
//   const EmployeeProfileScreen({Key? key, this.empId}) : super(key: key);
//
//   @override
//   State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
// }
//
// class _EmployeeProfileScreenState extends State<EmployeeProfileScreen>
//     with SingleTickerProviderStateMixin {
//
//   // ── Design tokens ──────────────────────────────────────────────────────────
//   // Color tokens moved to AppColors
//   //
//   //
//   //
//   //
//   //
//   //
//   //
//   //
//   //
//   static const Color _cPurple   = Color(0xFF7C3AED);
//   static const Color _cTeal     = Color(0xFF059669);
//   static const Color _cAmber    = Color(0xFFF59E0B);
//   static const Color _cRed      = Color(0xFFDC2626);
//   // ───────────────────────────────────────────────────────────────────────────
//
//   Map<String, dynamic>? employee;
//   bool isLoading = true;
//   String errorMessage = '';
//   String _resolvedId = '';
//
//   late AnimationController _animController;
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideAnim;
//
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/production/empinfo/get';
//
//   static const List<String> _possibleIdKeys = [
//     'emp_id', 'user_id', 'userId', 'employee_id', 'employeeId',
//     'id', 'ID', 'EMP_ID', 'USER_ID', 'prefUserId',
//   ];
//
//   // ── Lifecycle ──────────────────────────────────────────────────────────────
//
//   @override
//   void initState() {
//     super.initState();
//     _animController = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 650));
//     _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
//     _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
//     _initAndFetch();
//   }
//
//   @override
//   void dispose() {
//     _animController.dispose();
//     super.dispose();
//   }
//
//   // ── Resolve emp_id ─────────────────────────────────────────────────────────
//
//   Future<String> _resolveEmpId() async {
//     if (widget.empId != null && widget.empId!.trim().isNotEmpty) {
//       return widget.empId!.trim();
//     }
//     await loadEmployeeData();
//     if (emp_id.trim().isNotEmpty) return emp_id.trim();
//
//     final prefs = await SharedPreferences.getInstance();
//     for (final key in _possibleIdKeys) {
//       final val = prefs.get(key)?.toString().trim() ?? '';
//       if (val.isNotEmpty) return val;
//     }
//     for (final key in prefs.getKeys()) {
//       final val = prefs.get(key)?.toString().trim() ?? '';
//       if (val.isNotEmpty && int.tryParse(val) != null) return val;
//     }
//     return '';
//   }
//
//   Future<void> _initAndFetch() async {
//     _resolvedId = await _resolveEmpId();
//     await _fetchEmployee();
//   }
//
//   // ── API ────────────────────────────────────────────────────────────────────
//
//   Future<void> _fetchEmployee() async {
//     setState(() { isLoading = true; errorMessage = ''; employee = null; });
//     _animController.reset();
//     try {
//       if (_resolvedId.isEmpty) {
//         throw Exception(
//             'Could not find Employee ID.\nPlease log out and log in again.');
//       }
//       final uri = Uri.parse(_baseUrl)
//           .replace(queryParameters: {'emp_id': _resolvedId});
//
//       final response = await http
//           .get(uri, headers: {'Accept': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200) {
//         final dynamic raw = json.decode(response.body);
//         Map<String, dynamic>? parsed;
//
//         if (raw is Map<String, dynamic>) {
//           if (raw.containsKey('items') && raw['items'] is List) {
//             final list = raw['items'] as List;
//             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
//           } else if (raw.containsKey('data') && raw['data'] is List) {
//             final list = raw['data'] as List;
//             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
//           } else {
//             parsed = raw;
//           }
//         } else if (raw is List && raw.isNotEmpty) {
//           parsed = Map<String, dynamic>.from(raw.first);
//         }
//
//         setState(() { employee = parsed; isLoading = false; });
//         _animController.forward();
//       } else {
//         throw Exception('Server error: HTTP ${response.statusCode}');
//       }
//     } catch (e) {
//       setState(() {
//         errorMessage = e.toString().replaceFirst('Exception: ', '');
//         isLoading = false;
//       });
//     }
//   }
//
//   // ── Field helpers ──────────────────────────────────────────────────────────
//
//   String _v(List<String> keys) {
//     if (employee == null) return '—';
//     for (final k in keys) {
//       final v = employee![k];
//       if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
//     }
//     return '—';
//   }
//
//   // Personal
//   String get _empId      => _v(['EMP_ID',    'emp_id',    'employee_id']);
//   String get _empName    => _v(['EMP_NAME',  'emp_name',  'name', 'full_name']);
//   String get _fatherName => _v(['FATHER_NAME','father_name']);
//   String get _cnic       => _v(['CNIC_NO',   'cnic_no',   'cnic']);
//   String get _contact    => _v(['CONTACT_NO','contact_no','phone','mobile']);
//   String get _email      => _v(['EMAIL',     'email']);
//   String get _address    => _v(['ADDRESS',   'address']);
//   String get _gender     => _v(['GENDER',    'gender']);
//   String get _marital    => _v(['MARITAL_STATUS','marital_status']);
//   String get _dob        => _v(['DOB',       'dob','date_of_birth']);
//   String get _education  => _v(['EDUCATION', 'education']);
//   String get _image      => _v(['IMAGE',     'image','photo']);
//
//   // Job Information
//   String get _dept       => _v(['DEP_NAME',  'dep_name',  'department']);
//   String get _subDept    => _v(['SUB_DEP_NAME','sub_dep_name','sub_department']);
//   String get _job        => _v(['JOB',       'job','designation','job_title']);
//   String get _jobGrade   => _v(['JOB_GRADE', 'job_grade', 'grade']);
//   String get _hiringDate => _v(['HIRING_DATE','hiring_date','join_date']);
//   String get _termDate   => _v(['TERMINATION_DATE','termination_date']);
//   String get _active     => _v(['ACTIVE',    'active',    'status']);
//
//   // Salary
//   String get _basicSalary => _v(['BASIC_SALARY','basic_salary','salary']);
//
//   // Attendance
//   String get _entryTime  => _v(['ENTRY_TIME','entry_time']);
//   String get _endTime    => _v(['END_TIME',  'end_time']);
//
//   // Policy
//   String get _otDate     => _v(['OVERTIME_EFFECTIVE_DATE','overtime_effective_date','ot_effective_date']);
//   String get _lateDate   => _v(['LATEHOURS_EFFECTIVE_DATE','latehours_effective_date','late_hours_effective_date']);
//   String get _overtime   => _v(['OVER_TIME', 'over_time', 'overtime']);
//   String get _absentDed  => _v(['ABSENT_DEDUCTION','absent_deduction']);
//   String get _lateDed    => _v(['LATE_DEDUCTION','late_deduction']);
//   String get _earlyArr   => _v(['EARLY_ARRIVAL','early_arrival']);
//   String get _wht        => _v(['WHT',       'wht','wht_applied']);
//   String get _eobi       => _v(['EOBI_DEDUCTION','eobi_deduction']);
//   String get _medical    => _v(['MEDICAL_ALLOWNACE','medical_allowance','medical_allownace']);
//
//   bool get _isActive {
//     final s = _active.toLowerCase();
//     return s == 'y' || s == 'yes' || s == '1' || s == 'active';
//   }
//
//   // ── Build ──────────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: CustomScrollView(
//         physics: const BouncingScrollPhysics(),
//         slivers: [
//           _buildAppBar(),
//           SliverToBoxAdapter(child: _buildContent()),
//         ],
//       ),
//     );
//   }
//
//   // ── Sliver App Bar ─────────────────────────────────────────────────────────
//
//   Widget _buildAppBar() {
//     return SliverAppBar(
//       expandedHeight: 215,
//       pinned: true,
//       stretch: true,
//       backgroundColor: AppColors.primary,
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
//         onPressed: () => Navigator.pop(context),
//       ),
//       actions: [
//         IconButton(
//           icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
//           onPressed: _initAndFetch,
//         ),
//         const SizedBox(width: 8),
//       ],
//       flexibleSpace: FlexibleSpaceBar(
//         stretchModes: const [StretchMode.zoomBackground],
//         background: Stack(fit: StackFit.expand, children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [AppColors.primaryDark, AppColors.primary],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           Positioned(top: -50, right: -30,
//               child: Container(width: 200, height: 200,
//                   decoration: BoxDecoration(shape: BoxShape.circle,
//                       color: Colors.white.withOpacity(0.05)))),
//           Positioned(bottom: -40, left: -20,
//               child: Container(width: 140, height: 140,
//                   decoration: BoxDecoration(shape: BoxShape.circle,
//                       color: AppColors.cyan.withOpacity(0.09)))),
//           Positioned(
//             bottom: 18, left: 0, right: 0,
//             child: Column(children: [
//               _buildAvatar(),
//               const SizedBox(height: 8),
//               if (!isLoading && errorMessage.isEmpty) ...[
//                 Text(_empName,
//                     style: const TextStyle(
//                         color: Colors.white, fontSize: 17,
//                         fontWeight: FontWeight.w700, letterSpacing: 0.3),
//                     textAlign: TextAlign.center),
//                 const SizedBox(height: 2),
//                 Text(_job,
//                     style: TextStyle(
//                         color: Colors.white.withOpacity(0.72),
//                         fontSize: 12, letterSpacing: 0.4)),
//                 const SizedBox(height: 5),
//                 Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                   const Icon(Icons.mail_outline_rounded,
//                       size: 11, color: Colors.white54),
//                   const SizedBox(width: 4),
//                   Text(_email,
//                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
//                   const SizedBox(width: 14),
//                   const Icon(Icons.badge_outlined,
//                       size: 11, color: Colors.white54),
//                   const SizedBox(width: 3),
//                   Text(_empId,
//                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
//                 ]),
//               ],
//             ]),
//           ),
//         ]),
//       ),
//     );
//   }
//
//   Widget _buildAvatar() {
//     final name = employee != null ? _empName : emp_name;
//     final initials = name.isNotEmpty && name != '—'
//         ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
//         : (_resolvedId.isNotEmpty ? _resolvedId[0] : '?');
//     final imgUrl = _image != '—' ? _image : null;
//
//     return Container(
//       width: 68, height: 68,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: Colors.white,
//         border: Border.all(color: AppColors.cyan, width: 2.5),
//         boxShadow: [BoxShadow(
//             color: AppColors.primary.withOpacity(0.3), blurRadius: 18, spreadRadius: 1)],
//       ),
//       child: ClipOval(
//         child: imgUrl != null
//             ? Image.network(imgUrl, fit: BoxFit.cover,
//             errorBuilder: (_, __, ___) => _avatarInitials(initials))
//             : _avatarInitials(initials),
//       ),
//     );
//   }
//
//   Widget _avatarInitials(String initials) => Center(
//     child: Text(initials,
//         style: const TextStyle(
//             color: AppColors.cyan, fontSize: 22,
//             fontWeight: FontWeight.w800, letterSpacing: 1)),
//   );
//
//   // ── Content states ─────────────────────────────────────────────────────────
//
//   Widget _buildContent() {
//     if (isLoading)               return _stateLoading();
//     if (errorMessage.isNotEmpty) return _stateError();
//     if (employee == null)        return _stateEmpty();
//     return _buildProfile();
//   }
//
//   Widget _stateLoading() => SizedBox(height: 400, child: Center(
//     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//       SizedBox(width: 44, height: 44,
//           child: CircularProgressIndicator(strokeWidth: 2.5,
//               valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan))),
//       const SizedBox(height: 18),
//       const Text('Loading profile...',
//           style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
//     ]),
//   ));
//
//   Widget _stateError() => SizedBox(height: 400, child: Center(
//     child: Padding(padding: const EdgeInsets.all(32),
//       child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//         Container(width: 72, height: 72,
//             decoration: BoxDecoration(shape: BoxShape.circle,
//                 color: Colors.red.withOpacity(0.08)),
//             child: const Icon(Icons.error_outline_rounded,
//                 color: Colors.redAccent, size: 34)),
//         const SizedBox(height: 20),
//         const Text('Could not load profile',
//             style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
//                 fontWeight: FontWeight.w600)),
//         const SizedBox(height: 8),
//         Text(errorMessage, textAlign: TextAlign.center,
//             style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
//         const SizedBox(height: 24),
//         _btn('Try Again', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
//       ]),
//     ),
//   ));
//
//   Widget _stateEmpty() => SizedBox(height: 400, child: Center(
//     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//       Icon(Icons.person_search_rounded, size: 64, color: Colors.grey.shade300),
//       const SizedBox(height: 16),
//       Text('No data found for ID: $_resolvedId',
//           style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
//       const SizedBox(height: 16),
//       _btn('Refresh', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
//     ]),
//   ));
//
//   // ── Profile ────────────────────────────────────────────────────────────────
//
//   Widget _buildProfile() {
//     return FadeTransition(
//       opacity: _fadeAnim,
//       child: SlideTransition(
//         position: _slideAnim,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
//           child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//
//                 _activeBadge(),
//                 const SizedBox(height: 18),
//
//                 // ── 1  Personal Information ────────────────────────────────────
//                 _sectionHeader('Personal Information',
//                     Icons.person_outline_rounded, AppColors.cyan),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('FATHER NAME', _fatherName, 'DATE OF BIRTH',  _dob),
//                   _pair('GENDER',      _gender,     'MARITAL STATUS', _marital),
//                   _pair('CNIC NO',     _cnic,       'EDUCATION',      _education),
//                   _pair('CONTACT NO',  _contact,    'ADDRESS',        _address),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 2  Job Information ─────────────────────────────────────────
//                 _sectionHeader('Job Information',
//                     Icons.work_outline_rounded, _cPurple),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('DEPARTMENT',       _dept,     'SUB DEPARTMENT',   _subDept),
//                   _pair('JOB GRADE',        _jobGrade, 'HIRING DATE',      _hiringDate),
//                   _full('TERMINATION DATE', _termDate),
//                   _full('STATUS', _active,
//                       valueColor: _active == '—' ? AppColors.textSecondary : (_isActive ? AppColors.success : AppColors.error)),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 3  Salary ──────────────────────────────────────────────────
//                 _sectionHeader('Salary',
//                     Icons.payments_outlined, _cTeal),
//                 const SizedBox(height: 8),
//                 _card([
//                   _full('BASIC / STARTING SALARY',
//                       _basicSalary != '—' ? 'PKR $_basicSalary' : '—'),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 4  Attendance Policy ───────────────────────────────────────
//                 _sectionHeader('Attendance Policy',
//                     Icons.access_time_rounded, _cAmber),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('ENTRY TIME', _entryTime, 'END TIME', _endTime),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 5  Policy Details ──────────────────────────────────────────
//                 _sectionHeader('Policy Details',
//                     Icons.policy_outlined, _cRed),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('OVERTIME',         _overtime,  'OT EFFECTIVE DATE',
//                       _otDate,        leftYesNo: true),
//                   _pair('LATE DEDUCTION',   _lateDed,   'LATE HRS EFF. DATE',
//                       _lateDate,      leftYesNo: true),
//                   _pair('ABSENT DEDUCTION', _absentDed, 'EARLY ARRIVAL',
//                       _earlyArr,      leftYesNo: true, rightYesNo: true),
//                   _pair('WHT',              _wht,       'EOBI DEDUCTION',
//                       _eobi,          leftYesNo: true, rightYesNo: true),
//                   _full('MEDICAL ALLOWANCE', _medical,   yesNo: true),
//                 ]),
//
//               ]),
//         ),
//       ),
//     );
//   }
//
//   // ── Active badge ───────────────────────────────────────────────────────────
//
//   Widget _activeBadge() {
//     final has   = _active != '—';
//     final color = has ? (_isActive ? AppColors.success : Colors.orange) : Colors.blueGrey;
//     final label = has ? (_isActive ? 'ACTIVE' : 'INACTIVE') : 'EMPLOYEE';
//
//     return Center(child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.09),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withOpacity(0.35)),
//       ),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         Container(width: 7, height: 7,
//             decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
//         const SizedBox(width: 8),
//         Text(label,
//             style: TextStyle(color: color, fontSize: 11,
//                 fontWeight: FontWeight.w700, letterSpacing: 1.3)),
//       ]),
//     ));
//   }
//
//   // ── Section header ─────────────────────────────────────────────────────────
//
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               color: AppColors.cyan, borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color: color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(color: AppColors.primary, fontSize: 13,
//               fontWeight: FontWeight.w700, letterSpacing: 0.3)),
//     ]);
//   }
//
//   // ── Card ───────────────────────────────────────────────────────────────────
//
//   Widget _card(List<Widget> rows) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10, offset: const Offset(0, 3))],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: rows.asMap().entries.map((e) => Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               e.value,
//               if (e.key < rows.length - 1)
//                 const Divider(height: 1, thickness: 1, color: AppColors.divider),
//             ],
//           )).toList()),
//     );
//   }
//
//   // ── Row builders ───────────────────────────────────────────────────────────
//
//   Widget _pair(
//       String lLabel, String lVal,
//       String rLabel, String rVal, {
//         bool leftYesNo  = false,
//         bool rightYesNo = false,
//       }) {
//     return IntrinsicHeight(
//       child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//         Expanded(child: _cell(lLabel, lVal, yesNo: leftYesNo)),
//         const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
//         Expanded(child: _cell(rLabel, rVal, yesNo: rightYesNo)),
//       ]),
//     );
//   }
//
//   Widget _full(String label, String val,
//       {bool yesNo = false, Color? valueColor}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(label,
//             style: const TextStyle(fontSize: 9, color: AppColors.textSecondary,
//                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
//         const SizedBox(height: 3),
//         Text(val,
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
//                 color: valueColor ?? _color(val, yesNo: yesNo))),
//       ]),
//     );
//   }
//
//   Widget _cell(String label, String val, {bool yesNo = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(label,
//             style: const TextStyle(fontSize: 9, color: AppColors.textSecondary,
//                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
//         const SizedBox(height: 3),
//         Text(val,
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
//                 color: _color(val, yesNo: yesNo))),
//       ]),
//     );
//   }
//
//   Color _color(String val, {bool yesNo = false}) {
//     if (val == '—') return AppColors.textSecondary;
//     if (yesNo) {
//       final v = val.toLowerCase();
//       if (v == 'no'  || v == 'n' || v == '0') return AppColors.error;
//       if (v == 'yes' || v == 'y' || v == '1') return AppColors.success;
//     }
//     return AppColors.textPrimary;
//   }
//
//   // ── Button ─────────────────────────────────────────────────────────────────
//
//   Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
//         decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: [BoxShadow(
//                 color: color.withOpacity(0.35),
//                 blurRadius: 16, offset: const Offset(0, 6))]),
//         child: Row(mainAxisSize: MainAxisSize.min, children: [
//           Icon(icon, color: Colors.white, size: 18),
//           const SizedBox(width: 8),
//           Text(label, style: const TextStyle(
//               color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
//         ]),
//       ),
//     );
//   }
// }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../Database/util.dart';
//
// // Navigate simply:  Get.to(() => const EmployeeProfileScreen());
//
// class EmployeeProfileScreen extends StatefulWidget {
//   final String? empId;
//   const EmployeeProfileScreen({Key? key, this.empId}) : super(key: key);
//
//   @override
//   State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
// }
//
// class _EmployeeProfileScreenState extends State<EmployeeProfileScreen>
//     with SingleTickerProviderStateMixin {
//
//   // ── Design tokens ──────────────────────────────────────────────────────────
//   static const Color _navy      = Color(0xFF1A2B6D);
//   static const Color _gold      = Color(0xFFC9A84C);
//   static const Color _goldLight = Color(0xFFF5EDD6);
//   static const Color _surface   = Color(0xFFF4F6FB);
//   static const Color _green     = Color(0xFF22C55E);
//   static const Color _red       = Color(0xFFEF4444);
//   static const Color _textMain  = Color(0xFF111827);
//   static const Color _textMuted = Color(0xFF6B7280);
//   static const Color _divider   = Color(0xFFE8EAF0);
//   static const Color _cBlue     = Color(0xFF4060FF);
//
//
//
//
//   // ───────────────────────────────────────────────────────────────────────────
//
//   Map<String, dynamic>? employee;
//   bool isLoading = true;
//   String errorMessage = '';
//   String _resolvedId = '';
//
//   late AnimationController _animController;
//   late Animation<double> _fadeAnim;
//   late Animation<Offset> _slideAnim;
//
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/production/empinfo/get';
//
//   static const List<String> _possibleIdKeys = [
//     'emp_id', 'user_id', 'userId', 'employee_id', 'employeeId',
//     'id', 'ID', 'EMP_ID', 'USER_ID', 'prefUserId',
//   ];
//
//   // ── Lifecycle ──────────────────────────────────────────────────────────────
//
//   @override
//   void initState() {
//     super.initState();
//     _animController = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 650));
//     _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
//     _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
//         .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
//     _initAndFetch();
//   }
//
//   @override
//   void dispose() {
//     _animController.dispose();
//     super.dispose();
//   }
//
//   // ── Resolve emp_id ─────────────────────────────────────────────────────────
//
//   Future<String> _resolveEmpId() async {
//     if (widget.empId != null && widget.empId!.trim().isNotEmpty) {
//       return widget.empId!.trim();
//     }
//     await loadEmployeeData();
//     if (emp_id.trim().isNotEmpty) return emp_id.trim();
//
//     final prefs = await SharedPreferences.getInstance();
//     for (final key in _possibleIdKeys) {
//       final val = prefs.get(key)?.toString().trim() ?? '';
//       if (val.isNotEmpty) return val;
//     }
//     for (final key in prefs.getKeys()) {
//       final val = prefs.get(key)?.toString().trim() ?? '';
//       if (val.isNotEmpty && int.tryParse(val) != null) return val;
//     }
//     return '';
//   }
//
//   Future<void> _initAndFetch() async {
//     _resolvedId = await _resolveEmpId();
//     await _fetchEmployee();
//   }
//
//   // ── API ────────────────────────────────────────────────────────────────────
//
//   Future<void> _fetchEmployee() async {
//     setState(() { isLoading = true; errorMessage = ''; employee = null; });
//     _animController.reset();
//     try {
//       if (_resolvedId.isEmpty) {
//         throw Exception(
//             'Could not find Employee ID.\nPlease log out and log in again.');
//       }
//       final uri = Uri.parse(_baseUrl)
//           .replace(queryParameters: {'emp_id': _resolvedId});
//
//       final response = await http
//           .get(uri, headers: {'Accept': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200) {
//         final dynamic raw = json.decode(response.body);
//         Map<String, dynamic>? parsed;
//
//         if (raw is Map<String, dynamic>) {
//           if (raw.containsKey('items') && raw['items'] is List) {
//             final list = raw['items'] as List;
//             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
//           } else if (raw.containsKey('data') && raw['data'] is List) {
//             final list = raw['data'] as List;
//             parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
//           } else {
//             parsed = raw;
//           }
//         } else if (raw is List && raw.isNotEmpty) {
//           parsed = Map<String, dynamic>.from(raw.first);
//         }
//
//         setState(() { employee = parsed; isLoading = false; });
//         _animController.forward();
//       } else {
//         throw Exception('Server error: HTTP ${response.statusCode}');
//       }
//     } catch (e) {
//       setState(() {
//         errorMessage = e.toString().replaceFirst('Exception: ', '');
//         isLoading = false;
//       });
//     }
//   }
//
//   // ── Field helpers ──────────────────────────────────────────────────────────
//
//   String _v(List<String> keys) {
//     if (employee == null) return '—';
//     for (final k in keys) {
//       final v = employee![k];
//       if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
//     }
//     return '—';
//   }
//
//   // Personal
//   String get _empId      => _v(['EMP_ID',    'emp_id',    'employee_id']);
//   String get _empName    => _v(['EMP_NAME',  'emp_name',  'name', 'full_name']);
//   String get _fatherName => _v(['FATHER_NAME','father_name']);
//   String get _cnic       => _v(['CNIC_NO',   'cnic_no',   'cnic']);
//   String get _contact    => _v(['CONTACT_NO','contact_no','phone','mobile']);
//   String get _email      => _v(['EMAIL',     'email']);
//   String get _address    => _v(['ADDRESS',   'address']);
//   String get _gender     => _v(['GENDER',    'gender']);
//   String get _marital    => _v(['MARITAL_STATUS','marital_status']);
//   String get _dob        => _v(['DOB',       'dob','date_of_birth']);
//   String get _education  => _v(['EDUCATION', 'education']);
//   String get _image      => _v(['IMAGE',     'image','photo']);
//
//   // Job Information
//   String get _dept       => _v(['DEP_NAME',  'dep_name',  'department']);
//   String get _subDept    => _v(['SUB_DEP_NAME','sub_dep_name','sub_department']);
//   String get _job        => _v(['JOB',       'job','designation','job_title']);
//   String get _jobGrade   => _v(['JOB_GRADE', 'job_grade', 'grade']);
//   String get _hiringDate => _v(['HIRING_DATE','hiring_date','join_date']);
//   String get _termDate   => _v(['TERMINATION_DATE','termination_date']);
//   String get _active     => _v(['ACTIVE',    'active',    'status']);
//
//   // Salary
//   String get _basicSalary => _v(['BASIC_SALARY','basic_salary','salary']);
//
//   // Attendance
//   String get _entryTime  => _v(['ENTRY_TIME','entry_time']);
//   String get _endTime    => _v(['END_TIME',  'end_time']);
//
//   // Policy
//   String get _otDate     => _v(['OVERTIME_EFFECTIVE_DATE','overtime_effective_date','ot_effective_date']);
//   String get _lateDate   => _v(['LATEHOURS_EFFECTIVE_DATE','latehours_effective_date','late_hours_effective_date']);
//   String get _overtime   => _v(['OVER_TIME', 'over_time', 'overtime']);
//   String get _absentDed  => _v(['ABSENT_DEDUCTION','absent_deduction']);
//   String get _lateDed    => _v(['LATE_DEDUCTION','late_deduction']);
//   String get _earlyArr   => _v(['EARLY_ARRIVAL','early_arrival']);
//   String get _wht        => _v(['WHT',       'wht','wht_applied']);
//   String get _eobi       => _v(['EOBI_DEDUCTION','eobi_deduction']);
//   String get _medical    => _v(['MEDICAL_ALLOWNACE','medical_allowance','medical_allownace']);
//
//   bool get _isActive {
//     final s = _active.toLowerCase();
//     return s == 'y' || s == 'yes' || s == '1' || s == 'active';
//   }
//
//   // ── Build ──────────────────────────────────────────────────────────────────
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _surface,
//       body: CustomScrollView(
//         physics: const BouncingScrollPhysics(),
//         slivers: [
//           _buildAppBar(),
//           SliverToBoxAdapter(child: _buildContent()),
//         ],
//       ),
//     );
//   }
//
//   // ── Sliver App Bar ─────────────────────────────────────────────────────────
//
//   Widget _buildAppBar() {
//     return SliverAppBar(
//       expandedHeight: 215,
//       pinned: true,
//       stretch: true,
//       backgroundColor: _navy,
//       leading: IconButton(
//         icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
//         onPressed: () => Navigator.pop(context),
//       ),
//       actions: [
//         IconButton(
//           icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
//           onPressed: _initAndFetch,
//         ),
//         const SizedBox(width: 8),
//       ],
//       flexibleSpace: FlexibleSpaceBar(
//         stretchModes: const [StretchMode.zoomBackground],
//         background: Stack(fit: StackFit.expand, children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [_navy, Color(0xFF253D8A)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           Positioned(top: -50, right: -30,
//               child: Container(width: 200, height: 200,
//                   decoration: BoxDecoration(shape: BoxShape.circle,
//                       color: AppColors.greenTeal.withOpacity(0.12)))),
//           Positioned(bottom: -40, left: -20,
//               child: Container(width: 140, height: 140,
//                   decoration: BoxDecoration(shape: BoxShape.circle,
//                       color: _gold.withOpacity(0.09)))),
//           Positioned(
//             bottom: 18, left: 0, right: 0,
//             child: Column(children: [
//               _buildAvatar(),
//               const SizedBox(height: 8),
//               if (!isLoading && errorMessage.isEmpty) ...[
//                 Text(_empName,
//                     style: const TextStyle(
//                         color: Colors.white, fontSize: 17,
//                         fontWeight: FontWeight.w700, letterSpacing: 0.3),
//                     textAlign: TextAlign.center),
//                 const SizedBox(height: 2),
//                 Text(_job,
//                     style: TextStyle(
//                         color: Colors.white.withOpacity(0.72),
//                         fontSize: 12, letterSpacing: 0.4)),
//                 const SizedBox(height: 5),
//                 Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                   const Icon(Icons.mail_outline_rounded,
//                       size: 11, color: Colors.white54),
//                   const SizedBox(width: 4),
//                   Text(_email,
//                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
//                   const SizedBox(width: 14),
//                   const Icon(Icons.badge_outlined,
//                       size: 11, color: Colors.white54),
//                   const SizedBox(width: 3),
//                   Text(_empId,
//                       style: const TextStyle(color: Colors.white54, fontSize: 10)),
//                 ]),
//               ],
//             ]),
//           ),
//         ]),
//       ),
//     );
//   }
//
//   Widget _buildAvatar() {
//     final name = employee != null ? _empName : emp_name;
//     final initials = name.isNotEmpty && name != '—'
//         ? name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
//         : (_resolvedId.isNotEmpty ? _resolvedId[0] : '?');
//     final imgUrl = _image != '—' ? _image : null;
//
//     return Container(
//       width: 68, height: 68,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: Colors.white,
//         border: Border.all(color: _gold, width: 2.5),
//         boxShadow: [BoxShadow(
//             color: _navy.withOpacity(0.3), blurRadius: 18, spreadRadius: 1)],
//       ),
//       child: ClipOval(
//         child: imgUrl != null
//             ? Image.network(imgUrl, fit: BoxFit.cover,
//             errorBuilder: (_, __, ___) => _avatarInitials(initials))
//             : _avatarInitials(initials),
//       ),
//     );
//   }
//
//   Widget _avatarInitials(String initials) => Center(
//     child: Text(initials,
//         style: const TextStyle(
//             color: _cBlue, fontSize: 22,
//             fontWeight: FontWeight.w800, letterSpacing: 1)),
//   );
//
//   // ── Content states ─────────────────────────────────────────────────────────
//
//   Widget _buildContent() {
//     if (isLoading)               return _stateLoading();
//     if (errorMessage.isNotEmpty) return _stateError();
//     if (employee == null)        return _stateEmpty();
//     return _buildProfile();
//   }
//
//   Widget _stateLoading() => SizedBox(height: 400, child: Center(
//     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//       SizedBox(width: 44, height: 44,
//           child: CircularProgressIndicator(strokeWidth: 2.5,
//               valueColor: const AlwaysStoppedAnimation<Color>(_cBlue))),
//       const SizedBox(height: 18),
//       const Text('Loading profile...',
//           style: TextStyle(color: _textMuted, fontSize: 13)),
//     ]),
//   ));
//
//   Widget _stateError() => SizedBox(height: 400, child: Center(
//     child: Padding(padding: const EdgeInsets.all(32),
//       child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//         Container(width: 72, height: 72,
//             decoration: BoxDecoration(shape: BoxShape.circle,
//                 color: AppColors.error.withOpacity(0.08)),
//             child: const Icon(Icons.error_outline_rounded,
//                 color: AppColors.error, size: 34)),
//         const SizedBox(height: 20),
//         const Text('Could not load profile',
//             style: TextStyle(color: _textMain, fontSize: 17,
//                 fontWeight: FontWeight.w600)),
//         const SizedBox(height: 8),
//         Text(errorMessage, textAlign: TextAlign.center,
//             style: const TextStyle(color: _textMuted, fontSize: 13)),
//         const SizedBox(height: 24),
//         _btn('Try Again', Icons.refresh_rounded, _cBlue, _initAndFetch),
//       ]),
//     ),
//   ));
//
//   Widget _stateEmpty() => SizedBox(height: 400, child: Center(
//     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//       Icon(Icons.person_search_rounded, size: 64, color: AppColors.cyanMid),
//       const SizedBox(height: 16),
//       Text('No data found for ID: $_resolvedId',
//           style: const TextStyle(color: _textMuted, fontSize: 14)),
//       const SizedBox(height: 16),
//       _btn('Refresh', Icons.refresh_rounded, _cBlue, _initAndFetch),
//     ]),
//   ));
//
//   // ── Profile ────────────────────────────────────────────────────────────────
//
//   Widget _buildProfile() {
//     return FadeTransition(
//       opacity: _fadeAnim,
//       child: SlideTransition(
//         position: _slideAnim,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
//           child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//
//                 _activeBadge(),
//                 const SizedBox(height: 18),
//
//                 // ── 1  Personal Information ────────────────────────────────────
//                 _sectionHeader('Personal Information',
//                     Icons.person_outline_rounded, _cBlue),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('FATHER NAME', _fatherName, 'DATE OF BIRTH',  _dob),
//                   _pair('GENDER',      _gender,     'MARITAL STATUS', _marital),
//                   _pair('CNIC NO',     _cnic,       'EDUCATION',      _education),
//                   _pair('CONTACT NO',  _contact,    'ADDRESS',        _address),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 2  Job Information ─────────────────────────────────────────
//                 _sectionHeader('Job Information',
//                     Icons.work_outline_rounded, AppColors.skyBlueDk),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('DEPARTMENT',       _dept,     'SUB DEPARTMENT',   _subDept),
//                   _pair('JOB GRADE',        _jobGrade, 'HIRING DATE',      _hiringDate),
//                   _full('TERMINATION DATE', _termDate),
//                   _full('STATUS', _active,
//                       valueColor: _active == '—' ? _textMuted : (_isActive ? _green : _red)),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 3  Salary ──────────────────────────────────────────────────
//                 _sectionHeader('Salary',
//                     Icons.payments_outlined, AppColors.greenTeal),
//                 const SizedBox(height: 8),
//                 _card([
//                   _full('BASIC / STARTING SALARY',
//                       _basicSalary != '—' ? 'PKR $_basicSalary' : '—'),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 4  Attendance Policy ───────────────────────────────────────
//                 _sectionHeader('Attendance Policy',
//                     Icons.access_time_rounded, AppColors.warning),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('ENTRY TIME', _entryTime, 'END TIME', _endTime),
//                 ]),
//                 const SizedBox(height: 18),
//
//                 // ── 5  Policy Details ──────────────────────────────────────────
//                 _sectionHeader('Policy Details',
//                     Icons.policy_outlined, AppColors.error),
//                 const SizedBox(height: 8),
//                 _card([
//                   _pair('OVERTIME',         _overtime,  'OT EFFECTIVE DATE',
//                       _otDate,        leftYesNo: true),
//                   _pair('LATE DEDUCTION',   _lateDed,   'LATE HRS EFF. DATE',
//                       _lateDate,      leftYesNo: true),
//                   _pair('ABSENT DEDUCTION', _absentDed, 'EARLY ARRIVAL',
//                       _earlyArr,      leftYesNo: true, rightYesNo: true),
//                   _pair('WHT',              _wht,       'EOBI DEDUCTION',
//                       _eobi,          leftYesNo: true, rightYesNo: true),
//                   _full('MEDICAL ALLOWANCE', _medical,   yesNo: true),
//                 ]),
//
//               ]),
//         ),
//       ),
//     );
//   }
//
//   // ── Active badge ───────────────────────────────────────────────────────────
//
//   Widget _activeBadge() {
//     final has   = _active != '—';
//     final color = has ? (_isActive ? _green : AppColors.warning) : AppColors.textSecondary;
//     final label = has ? (_isActive ? 'ACTIVE' : 'INACTIVE') : 'EMPLOYEE';
//
//     return Center(child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.09),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: color.withOpacity(0.35)),
//       ),
//       child: Row(mainAxisSize: MainAxisSize.min, children: [
//         Container(width: 7, height: 7,
//             decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
//         const SizedBox(width: 8),
//         Text(label,
//             style: TextStyle(color: color, fontSize: 11,
//                 fontWeight: FontWeight.w700, letterSpacing: 1.3)),
//       ]),
//     ));
//   }
//
//   // ── Section header ─────────────────────────────────────────────────────────
//
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               color: _gold, borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color: color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(color: _navy, fontSize: 13,
//               fontWeight: FontWeight.w700, letterSpacing: 0.3)),
//     ]);
//   }
//
//   // ── Card ───────────────────────────────────────────────────────────────────
//
//   Widget _card(List<Widget> rows) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _divider),
//         boxShadow: [BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10, offset: const Offset(0, 3))],
//       ),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: rows.asMap().entries.map((e) => Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               e.value,
//               if (e.key < rows.length - 1)
//                 const Divider(height: 1, thickness: 1, color: _divider),
//             ],
//           )).toList()),
//     );
//   }
//
//   // ── Row builders ───────────────────────────────────────────────────────────
//
//   Widget _pair(
//       String lLabel, String lVal,
//       String rLabel, String rVal, {
//         bool leftYesNo  = false,
//         bool rightYesNo = false,
//       }) {
//     return IntrinsicHeight(
//       child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
//         Expanded(child: _cell(lLabel, lVal, yesNo: leftYesNo)),
//         const VerticalDivider(width: 1, thickness: 1, color: _divider),
//         Expanded(child: _cell(rLabel, rVal, yesNo: rightYesNo)),
//       ]),
//     );
//   }
//
//   Widget _full(String label, String val,
//       {bool yesNo = false, Color? valueColor}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(label,
//             style: const TextStyle(fontSize: 9, color: _textMuted,
//                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
//         const SizedBox(height: 3),
//         Text(val,
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
//                 color: valueColor ?? _color(val, yesNo: yesNo))),
//       ]),
//     );
//   }
//
//   Widget _cell(String label, String val, {bool yesNo = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(label,
//             style: const TextStyle(fontSize: 9, color: _textMuted,
//                 fontWeight: FontWeight.w600, letterSpacing: 0.6)),
//         const SizedBox(height: 3),
//         Text(val,
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
//                 color: _color(val, yesNo: yesNo))),
//       ]),
//     );
//   }
//
//   Color _color(String val, {bool yesNo = false}) {
//     if (val == '—') return _textMuted;
//     if (yesNo) {
//       final v = val.toLowerCase();
//       if (v == 'no'  || v == 'n' || v == '0') return _red;
//       if (v == 'yes' || v == 'y' || v == '1') return _green;
//     }
//     return _textMain;
//   }
//
//   // ── Button ─────────────────────────────────────────────────────────────────
//
//   Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
//         decoration: BoxDecoration(
//             color: color,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: [BoxShadow(
//                 color: color.withOpacity(0.35),
//                 blurRadius: 16, offset: const Offset(0, 6))]),
//         child: Row(mainAxisSize: MainAxisSize.min, children: [
//           Icon(icon, color: Colors.white, size: 18),
//           const SizedBox(width: 8),
//           Text(label, style: const TextStyle(
//               color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
//         ]),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../AppColors.dart';
import '../../Database/util.dart';


// Navigate simply:  Get.to(() => const EmployeeProfileScreen());

class EmployeeProfileScreen extends StatefulWidget {
  final String? empId;
  const EmployeeProfileScreen({Key? key, this.empId}) : super(key: key);

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen>
    with SingleTickerProviderStateMixin {

  // ── Design tokens ──────────────────────────────────────────────────────────
  // Color tokens moved to AppColors
  //
  //
  //
  //
  //
  //
  //
  //
  //




  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic>? employee;
  bool isLoading = true;
  String errorMessage = '';
  String _resolvedId = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/production/empinfo/get';

  static const List<String> _possibleIdKeys = [
    'emp_id', 'user_id', 'userId', 'employee_id', 'employeeId',
    'id', 'ID', 'EMP_ID', 'USER_ID', 'prefUserId',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _initAndFetch();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Resolve emp_id ─────────────────────────────────────────────────────────

  Future<String> _resolveEmpId() async {
    if (widget.empId != null && widget.empId!.trim().isNotEmpty) {
      return widget.empId!.trim();
    }
    await loadEmployeeData();
    if (emp_id.trim().isNotEmpty) return emp_id.trim();

    final prefs = await SharedPreferences.getInstance();
    for (final key in _possibleIdKeys) {
      final val = prefs.get(key)?.toString().trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    for (final key in prefs.getKeys()) {
      final val = prefs.get(key)?.toString().trim() ?? '';
      if (val.isNotEmpty && int.tryParse(val) != null) return val;
    }
    return '';
  }

  Future<void> _initAndFetch() async {
    _resolvedId = await _resolveEmpId();
    await _fetchEmployee();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchEmployee() async {
    setState(() { isLoading = true; errorMessage = ''; employee = null; });
    _animController.reset();
    try {
      if (_resolvedId.isEmpty) {
        throw Exception(
            'Could not find Employee ID.\nPlease log out and log in again.');
      }
      final uri = Uri.parse(_baseUrl)
          .replace(queryParameters: {'emp_id': _resolvedId});

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic raw = json.decode(response.body);
        Map<String, dynamic>? parsed;

        if (raw is Map<String, dynamic>) {
          if (raw.containsKey('items') && raw['items'] is List) {
            final list = raw['items'] as List;
            parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
          } else if (raw.containsKey('data') && raw['data'] is List) {
            final list = raw['data'] as List;
            parsed = list.isNotEmpty ? Map<String, dynamic>.from(list.first) : null;
          } else {
            parsed = raw;
          }
        } else if (raw is List && raw.isNotEmpty) {
          parsed = Map<String, dynamic>.from(raw.first);
        }

        setState(() { employee = parsed; isLoading = false; });
        _animController.forward();
      } else {
        throw Exception('Server error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────────

  String _v(List<String> keys) {
    if (employee == null) return '—';
    for (final k in keys) {
      final v = employee![k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '—';
  }

  // Personal
  String get _empId      => _v(['EMP_ID',    'emp_id',    'employee_id']);
  String get _empName    => _v(['EMP_NAME',  'emp_name',  'name', 'full_name']);
  String get _fatherName => _v(['FATHER_NAME','father_name']);
  String get _cnic       => _v(['CNIC_NO',   'cnic_no',   'cnic']);
  String get _contact    => _v(['CONTACT_NO','contact_no','phone','mobile']);
  String get _email      => _v(['EMAIL',     'email']);
  String get _address    => _v(['ADDRESS',   'address']);
  String get _gender     => _v(['GENDER',    'gender']);
  String get _marital    => _v(['MARITAL_STATUS','marital_status']);
  String get _dob        => _v(['DOB',       'dob','date_of_birth']);
  String get _education  => _v(['EDUCATION', 'education']);
  String get _image      => _v(['IMAGE',     'image','photo']);

  // Job Information
  String get _dept       => _v(['DEP_NAME',  'dep_name',  'department']);
  String get _subDept    => _v(['SUB_DEP_NAME','sub_dep_name','sub_department']);
  String get _job        => _v(['JOB',       'job','designation','job_title']);
  String get _jobGrade   => _v(['JOB_GRADE', 'job_grade', 'grade']);
  String get _hiringDate => _v(['HIRING_DATE','hiring_date','join_date']);
  String get _termDate   => _v(['TERMINATION_DATE','termination_date']);
  String get _active     => _v(['ACTIVE',    'active',    'status']);

  // Salary
  String get _basicSalary => _v(['BASIC_SALARY','basic_salary','salary']);

  // Attendance
  String get _entryTime  => _v(['ENTRY_TIME','entry_time']);
  String get _endTime    => _v(['END_TIME',  'end_time']);

  // Policy
  String get _otDate     => _v(['OVERTIME_EFFECTIVE_DATE','overtime_effective_date','ot_effective_date']);
  String get _lateDate   => _v(['LATEHOURS_EFFECTIVE_DATE','latehours_effective_date','late_hours_effective_date']);
  String get _overtime   => _v(['OVER_TIME', 'over_time', 'overtime']);
  String get _absentDed  => _v(['ABSENT_DEDUCTION','absent_deduction']);
  String get _lateDed    => _v(['LATE_DEDUCTION','late_deduction']);
  String get _earlyArr   => _v(['EARLY_ARRIVAL','early_arrival']);
  String get _wht        => _v(['WHT',       'wht','wht_applied']);
  String get _eobi       => _v(['EOBI_DEDUCTION','eobi_deduction']);
  String get _medical    => _v(['MEDICAL_ALLOWNACE','medical_allowance','medical_allownace']);

  bool get _isActive {
    final s = _active.toLowerCase();
    return s == 'y' || s == 'yes' || s == '1' || s == 'active';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildContent()),
        ],
      ),
    );
  }

  // ── Sliver App Bar ─────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 215,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _initAndFetch,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(fit: StackFit.expand, children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(top: -50, right: -30,
              child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: AppColors.greenTeal.withOpacity(0.12)))),
          Positioned(bottom: -40, left: -20,
              child: Container(width: 140, height: 140,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.10)))),
          Positioned(
            bottom: 18, left: 0, right: 0,
            child: Column(children: [
              _buildAvatar(),
              const SizedBox(height: 8),
              if (!isLoading && errorMessage.isEmpty) ...[
                Text(_empName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(_job,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 12, letterSpacing: 0.4)),
                const SizedBox(height: 5),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 11, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(_email,
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(width: 14),
                  const Icon(Icons.badge_outlined,
                      size: 11, color: Colors.white54),
                  const SizedBox(width: 3),
                  Text(_empId,
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    final name = employee != null ? _empName : emp_name;
    final imgUrl = _image != '—' ? _image : null;

    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.cyan.withOpacity(0.40),
              blurRadius: 20, spreadRadius: 2),
          BoxShadow(
              color: AppColors.greenTeal.withOpacity(0.20),
              blurRadius: 10, spreadRadius: 0),
        ],
      ),
      child: ClipOval(
        child: imgUrl != null
            ? Image.network(imgUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarPlaceholder())
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() => Stack(
    fit: StackFit.expand,
    children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.cyanLight, AppColors.cyanMid, AppColors.iconBgGreenTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      Image.asset(
        'assets/images/applogo.png',
        fit: BoxFit.cover,
        color: AppColors.surface.withOpacity(0.0),
        colorBlendMode: BlendMode.dstATop,
      ),
    ],
  );

  // ── Content states ─────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (isLoading)               return _stateLoading();
    if (errorMessage.isNotEmpty) return _stateError();
    if (employee == null)        return _stateEmpty();
    return _buildProfile();
  }

  Widget _stateLoading() => SizedBox(height: 400, child: Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 44, height: 44,
          child: CircularProgressIndicator(strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyanBright))),
      const SizedBox(height: 18),
      const Text('Loading profile...',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    ]),
  ));

  Widget _stateError() => SizedBox(height: 400, child: Center(
    child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.08)),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 34)),
        const SizedBox(height: 20),
        const Text('Could not load profile',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(errorMessage, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),
        _btn('Try Again', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
      ]),
    ),
  ));

  Widget _stateEmpty() => SizedBox(height: 400, child: Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.person_search_rounded, size: 64, color: AppColors.cyanMid),
      const SizedBox(height: 16),
      Text('No data found for ID: $_resolvedId',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 16),
      _btn('Refresh', Icons.refresh_rounded, AppColors.cyan, _initAndFetch),
    ]),
  ));

  // ── Profile ────────────────────────────────────────────────────────────────

  Widget _buildProfile() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                _activeBadge(),
                const SizedBox(height: 18),

                // ── 1  Personal Information ────────────────────────────────────
                _sectionHeader('Personal Information',
                    Icons.person_outline_rounded, AppColors.cyan),
                const SizedBox(height: 8),
                _card([
                  _pair('FATHER NAME', _fatherName, 'DATE OF BIRTH',  _dob),
                  _pair('GENDER',      _gender,     'MARITAL STATUS', _marital),
                  _pair('CNIC NO',     _cnic,       'EDUCATION',      _education),
                  _pair('CONTACT NO',  _contact,    'ADDRESS',        _address),
                ]),
                const SizedBox(height: 18),

                // ── 2  Job Information ─────────────────────────────────────────
                _sectionHeader('Job Information',
                    Icons.work_outline_rounded, AppColors.skyBlueDk),
                const SizedBox(height: 8),
                _card([
                  _pair('DEPARTMENT',       _dept,     'SUB DEPARTMENT',   _subDept),
                  _pair('JOB GRADE',        _jobGrade, 'HIRING DATE',      _hiringDate),
                  _full('TERMINATION DATE', _termDate),
                  _full('STATUS', _active,
                      valueColor: _active == '—' ? AppColors.textSecondary : (_isActive ? AppColors.success : AppColors.error)),
                ]),
                const SizedBox(height: 18),

                // ── 3  Salary ──────────────────────────────────────────────────
                _sectionHeader('Salary',
                    Icons.payments_outlined, AppColors.greenTeal),
                const SizedBox(height: 8),
                _card([
                  _full('BASIC / STARTING SALARY',
                      _basicSalary != '—' ? 'PKR $_basicSalary' : '—'),
                ]),
                const SizedBox(height: 18),

                // ── 4  Attendance Policy ───────────────────────────────────────
                _sectionHeader('Attendance Policy',
                    Icons.access_time_rounded, AppColors.warning),
                const SizedBox(height: 8),
                _card([
                  _pair('ENTRY TIME', _entryTime, 'END TIME', _endTime),
                ]),
                const SizedBox(height: 18),

                // ── 5  Policy Details ──────────────────────────────────────────
                _sectionHeader('Policy Details',
                    Icons.policy_outlined, AppColors.error),
                const SizedBox(height: 8),
                _card([
                  _pair('OVERTIME',         _overtime,  'OT EFFECTIVE DATE',
                      _otDate,        leftYesNo: true),
                  _pair('LATE DEDUCTION',   _lateDed,   'LATE HRS EFF. DATE',
                      _lateDate,      leftYesNo: true),
                  _pair('ABSENT DEDUCTION', _absentDed, 'EARLY ARRIVAL',
                      _earlyArr,      leftYesNo: true, rightYesNo: true),
                  _pair('WHT',              _wht,       'EOBI DEDUCTION',
                      _eobi,          leftYesNo: true, rightYesNo: true),
                  _full('MEDICAL ALLOWANCE', _medical,   yesNo: true),
                ]),

              ]),
        ),
      ),
    );
  }

  // ── Active badge ───────────────────────────────────────────────────────────

  Widget _activeBadge() {
    final has   = _active != '—';
    final color = has ? (_isActive ? AppColors.success : AppColors.warning) : AppColors.textSecondary;
    final label = has ? (_isActive ? 'ACTIVE' : 'INACTIVE') : 'EMPLOYEE';

    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 1.3)),
      ]),
    ));
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.greenTeal], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(color: AppColors.primary, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    ]);
  }

  // ── Card ───────────────────────────────────────────────────────────────────

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.asMap().entries.map((e) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              e.value,
              if (e.key < rows.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.divider),
            ],
          )).toList()),
    );
  }

  // ── Row builders ───────────────────────────────────────────────────────────

  Widget _pair(
      String lLabel, String lVal,
      String rLabel, String rVal, {
        bool leftYesNo  = false,
        bool rightYesNo = false,
      }) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _cell(lLabel, lVal, yesNo: leftYesNo)),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
        Expanded(child: _cell(rLabel, rVal, yesNo: rightYesNo)),
      ]),
    );
  }

  Widget _full(String label, String val,
      {bool yesNo = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary,
                fontWeight: FontWeight.w600, letterSpacing: 0.6)),
        const SizedBox(height: 3),
        Text(val,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: valueColor ?? _color(val, yesNo: yesNo))),
      ]),
    );
  }

  Widget _cell(String label, String val, {bool yesNo = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary,
                fontWeight: FontWeight.w600, letterSpacing: 0.6)),
        const SizedBox(height: 3),
        Text(val,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _color(val, yesNo: yesNo))),
      ]),
    );
  }

  Color _color(String val, {bool yesNo = false}) {
    if (val == '—') return AppColors.textSecondary;
    if (yesNo) {
      final v = val.toLowerCase();
      if (v == 'no'  || v == 'n' || v == '0') return AppColors.error;
      if (v == 'yes' || v == 'y' || v == '1') return AppColors.success;
    }
    return AppColors.textPrimary;
  }

  // ── Button ─────────────────────────────────────────────────────────────────

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
        decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(14),
    boxShadow: AppColors.cyanGlow),
    child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white, size: 18),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
    ),
    )
    );
  }
}