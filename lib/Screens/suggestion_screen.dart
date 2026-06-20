// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../AppColors.dart';
// import '../Database/db_helper.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════
// // suggestion_screen.dart
// //
// // Suggestion Screen — bottom sheet style, exactly like the screenshot
// // ═══════════════════════════════════════════════════════════════════════════
//
// class SuggestionScreen extends StatefulWidget {
//   const SuggestionScreen({super.key});
//
//   @override
//   State<SuggestionScreen> createState() => _SuggestionScreenState();
// }
//
// class _SuggestionScreenState extends State<SuggestionScreen> {
//   final TextEditingController _suggestionController = TextEditingController();
//   static const int _maxChars = 500;
//
//   // ── Employee Info (loaded from SharedPreferences — same as LeaveViewModel) ─
//   String _empId       = '';
//   String _empName     = '';
//   String _companyCode = '';
//
//   bool _isLoading = false;
//
//   static const _bgColor     = AppColors.surface;
//   static const _cardBg      = AppColors.cardBg;
//   static const _borderColor = AppColors.divider;
//   static const _textDark    = AppColors.textPrimary;
//   static const _textGray    = AppColors.textSecondary;
//   static const _primary     = AppColors.cyan;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadEmployee();
//   }
//
//   @override
//   void dispose() {
//     _suggestionController.dispose();
//     super.dispose();
//   }
//
//   // ── Load employee info exactly like LeaveViewModel._loadEmployee() ─────────
//   Future<void> _loadEmployee() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//
//     final empName = prefs.getString('userName')     ??
//         prefs.getString('user_name')    ??
//         prefs.getString('name')         ??
//         prefs.getString('full_name')    ??
//         prefs.getString('fullName')     ?? '';
//
//     final empId   = prefs.getString('userId')       ??
//         prefs.getString('user_id')      ??
//         prefs.getString('emp_id')       ??
//         prefs.getString('empId')        ??
//         prefs.getString('employee_id')  ??
//         prefs.getString('employeeId')   ?? '';
//
//     final companyCode = DBHelper.getCompanyCode() ?? '';
//
//     if (mounted) {
//       setState(() {
//         _empName     = empName;
//         _empId       = empId;
//         _companyCode = companyCode;
//       });
//     }
//   }
//
//   void _reset() {
//     setState(() {
//       _suggestionController.clear();
//     });
//   }
//
//   // ── Professional snackbar ─────────────────────────────────────────────────
//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//       ..hideCurrentSnackBar()
//       ..showSnackBar(
//         SnackBar(
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
//           backgroundColor: const Color(0xFF1C1C2E),
//           shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(14)),
//           elevation: 10,
//           duration: const Duration(seconds: 3),
//           content: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(7),
//                 decoration: BoxDecoration(
//                   color: Colors.redAccent.withOpacity(0.18),
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.error_outline_rounded,
//                     color: Colors.redAccent, size: 16),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   message,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 13.5,
//                     fontWeight: FontWeight.w500,
//                     height: 1.35,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//   }
//
//   Future<void> _submit() async {
//     if (_suggestionController.text.trim().isEmpty) {
//       _showErrorSnackBar('Please share your suggestion.');
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       final now = DateTime.now();
//       final suggestionDate =
//           '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
//
//       final response = await http.post(
//         Uri.parse(
//             'http://oracle.metaxperts.net/ords/gps_workforce/gpssuggestion/post/'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'emp_id':          _empId,
//           'emp_name':        _empName,
//           'company_code':    _companyCode,
//           'suggestion':      _suggestionController.text.trim(),
//           'suggestion_date': suggestionDate,
//           'status':          'Pending',
//         }),
//       );
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         if (mounted) Navigator.pop(context);
//       } else {
//         _showErrorSnackBar('Failed to submit. Please try again.');
//       }
//     } catch (e) {
//       _showErrorSnackBar('Network error. Please check your connection.');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       body: DraggableScrollableSheet(
//         initialChildSize: 0.92,
//         minChildSize: 0.6,
//         maxChildSize: 0.95,
//         builder: (context, scrollController) {
//           return Container(
//             decoration: const BoxDecoration(
//               color: _bgColor,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//             ),
//             child: Column(
//               children: [
//                 // ── Drag handle ──────────────────────────────────────────
//                 Padding(
//                   padding: const EdgeInsets.only(top: 12, bottom: 4),
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: _borderColor,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                   ),
//                 ),
//
//                 // ── Header ───────────────────────────────────────────────
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
//                   child: Row(
//                     children: [
//                       const Expanded(
//                         child: Text(
//                           'New Suggestion Request',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.w800,
//                             color: _textDark,
//                             letterSpacing: -0.3,
//                           ),
//                         ),
//                       ),
//                       GestureDetector(
//                         onTap: () => Navigator.pop(context),
//                         child: Container(
//                           width: 36,
//                           height: 36,
//                           decoration: BoxDecoration(
//                             color: _cardBg,
//                             shape: BoxShape.circle,
//                             border: Border.all(color: _borderColor),
//                           ),
//                           child: const Icon(Icons.close_rounded,
//                               size: 18, color: _textDark),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // ── Divider ──────────────────────────────────────────────
//                 Divider(height: 1, color: _borderColor),
//
//                 // ── Scrollable body ──────────────────────────────────────
//                 Expanded(
//                   child: SingleChildScrollView(
//                     controller: scrollController,
//                     padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//
//                         // ── Breadcrumb ─────────────────────────────────
//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 10),
//                           decoration: BoxDecoration(
//                             color: _cardBg,
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: _borderColor),
//                           ),
//                           child: Row(
//                             children: [
//                               Text('Requests',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       color: _textGray,
//                                       fontWeight: FontWeight.w500)),
//                               const Padding(
//                                 padding: EdgeInsets.symmetric(horizontal: 6),
//                                 child: Icon(Icons.chevron_right_rounded,
//                                     size: 16, color: AppColors.textSecondary),
//                               ),
//                               Text('Others',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       color: _textGray,
//                                       fontWeight: FontWeight.w500)),
//                               const Padding(
//                                 padding: EdgeInsets.symmetric(horizontal: 6),
//                                 child: Icon(Icons.chevron_right_rounded,
//                                     size: 16, color: AppColors.textSecondary),
//                               ),
//                               const Text('Suggestion',
//                                   style: TextStyle(
//                                       fontSize: 13,
//                                       color: _primary,
//                                       fontWeight: FontWeight.w700)),
//                             ],
//                           ),
//                         ),
//
//                         const SizedBox(height: 20),
//
//                         // ── Suggestion field ───────────────────────────
//                         RichText(
//                           text: const TextSpan(
//                             children: [
//                               TextSpan(
//                                 text: 'Suggestion',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w700,
//                                   color: _textDark,
//                                 ),
//                               ),
//                               TextSpan(
//                                 text: ' *',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.red,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: _cardBg,
//                             borderRadius: BorderRadius.circular(14),
//                             border: Border.all(color: _borderColor),
//                           ),
//                           child: TextField(
//                             controller: _suggestionController,
//                             maxLines: 6,
//                             maxLength: _maxChars,
//                             style: const TextStyle(
//                                 fontSize: 14.5, color: _textDark),
//                             decoration: const InputDecoration(
//                               hintText: 'Share your idea...',
//                               hintStyle: TextStyle(
//                                   color: AppColors.textSecondary,
//                                   fontSize: 14.5),
//                               border: InputBorder.none,
//                               contentPadding: EdgeInsets.all(14),
//                               counterText: '',
//                             ),
//                             onChanged: (_) => setState(() {}),
//                           ),
//                         ),
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: Padding(
//                             padding: const EdgeInsets.only(top: 6),
//                             child: Text(
//                               '${_suggestionController.text.length} / $_maxChars',
//                               style: const TextStyle(
//                                   fontSize: 12, color: _textGray),
//                             ),
//                           ),
//                         ),
//
//                         const SizedBox(height: 30),
//                       ],
//                     ),
//                   ),
//                 ),
//
//                 // ── Bottom buttons ────────────────────────────────────────
//                 Container(
//                   padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
//                   decoration: BoxDecoration(
//                     color: _bgColor,
//                     border: Border(top: BorderSide(color: _borderColor)),
//                   ),
//                   child: Row(
//                     children: [
//                       // Reset button
//                       Expanded(
//                         flex: 4,
//                         child: GestureDetector(
//                           onTap: _reset,
//                           child: Container(
//                             height: 52,
//                             decoration: BoxDecoration(
//                               color: _cardBg,
//                               borderRadius: BorderRadius.circular(14),
//                               border: Border.all(color: _borderColor),
//                             ),
//                             child: const Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.refresh_rounded,
//                                     color: _textDark, size: 18),
//                                 SizedBox(width: 6),
//                                 Text('Reset',
//                                     style: TextStyle(
//                                         fontSize: 15,
//                                         fontWeight: FontWeight.w700,
//                                         color: _textDark)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       // Submit button
//                       Expanded(
//                         flex: 6,
//                         child: GestureDetector(
//                           onTap: _isLoading ? null : _submit,
//                           child: Container(
//                             height: 52,
//                             decoration: BoxDecoration(
//                               color: _primary,
//                               borderRadius: BorderRadius.circular(14),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: _primary.withOpacity(0.3),
//                                   blurRadius: 12,
//                                   offset: const Offset(0, 4),
//                                 ),
//                               ],
//                             ),
//                             child: _isLoading
//                                 ? const Center(
//                               child: SizedBox(
//                                 width: 22,
//                                 height: 22,
//                                 child: CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2.5,
//                                 ),
//                               ),
//                             )
//                                 : const Row(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.send_rounded,
//                                     color: Colors.white, size: 18),
//                                 SizedBox(width: 8),
//                                 Text('Submit',
//                                     style: TextStyle(
//                                         fontSize: 15,
//                                         fontWeight: FontWeight.w700,
//                                         color: Colors.white)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
//

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../AppColors.dart';
import '../Database/db_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// suggestion_screen.dart
//
// Suggestion Screen — Full screen with gradient header
// ═══════════════════════════════════════════════════════════════════════════

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _suggestionController = TextEditingController();
  static const int _maxChars = 500;

  // ── Employee Info ──────────────────────────────────────────────────────
  String _empId       = '';
  String _empName     = '';
  String _companyCode = '';

  bool _isLoading = false;
  bool _submitting = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const _bgColor     = AppColors.surface;
  static const _borderColor = AppColors.divider;
  static const _textDark    = AppColors.textPrimary;
  static const _textGray    = AppColors.textSecondary;
  static const _primary     = AppColors.cyan;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _suggestionController.addListener(() => setState(() {}));
    _loadEmployee();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  // ── Load employee info ──────────────────────────────────────────────────
  Future<void> _loadEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final empName = prefs.getString('userName')     ??
        prefs.getString('user_name')    ??
        prefs.getString('name')         ??
        prefs.getString('full_name')    ??
        prefs.getString('fullName')     ?? '';

    final empId   = prefs.getString('userId')       ??
        prefs.getString('user_id')      ??
        prefs.getString('emp_id')       ??
        prefs.getString('empId')        ??
        prefs.getString('employee_id')  ??
        prefs.getString('employeeId')   ?? '';

    final companyCode = DBHelper.getCompanyCode() ?? '';

    if (mounted) {
      setState(() {
        _empName     = empName;
        _empId       = empId;
        _companyCode = companyCode;
      });
    }
  }

  void _reset() {
    setState(() {
      _suggestionController.clear();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          backgroundColor: const Color(0xFF1C1C2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 10,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _submit() async {
    if (_suggestionController.text.trim().isEmpty) {
      _showErrorSnackBar('Please share your suggestion.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final suggestionDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse(
            'http://oracle.metaxperts.net/ords/gps_workforce/gpssuggestion/post/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emp_id':          _empId,
          'emp_name':        _empName,
          'company_code':    _companyCode,
          'suggestion':      _suggestionController.text.trim(),
          'suggestion_date': suggestionDate,
          'status':          'Pending',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Suggestion submitted successfully!'),
              backgroundColor: _primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showErrorSnackBar('Failed to submit. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Breadcrumb ─────────────────────────────────────
                    _Breadcrumb(),

                    const SizedBox(height: 24),

                    // ── Suggestion field ──────────────────────────────
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Suggestion',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: TextField(
                        controller: _suggestionController,
                        maxLines: 8,
                        maxLength: _maxChars,
                        style: const TextStyle(
                            fontSize: 14.5, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Share your idea...',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14.5),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(14),
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${_suggestionController.text.length} / $_maxChars',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── Bottom buttons ─────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: GestureDetector(
                            onTap: _reset,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _borderColor),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh_rounded,
                                      color: AppColors.textPrimary, size: 18),
                                  SizedBox(width: 6),
                                  Text('Reset',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: GestureDetector(
                            onTap: _submitting ? null : _submit,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _submitting
                                  ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                                  : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Submit',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
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
                          'New Suggestion Request',
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

// ── Breadcrumb ──────────────────────────────────────────────────────────────
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
          _crumb('Others', isActive: false),
          _chevron(),
          _crumb('Suggestion', isActive: true),
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