//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../../constants.dart';
// import '../AppColors.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen>
//     with SingleTickerProviderStateMixin {
//   final TextEditingController _userIdController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final LoginViewModel loginViewModel = Get.find<LoginViewModel>();
//
//   final _formKey = GlobalKey<FormState>();
//   bool isChecked = false;
//   bool isPasswordVisible = false;
//   bool isLoading = false;
//   String companyCode = '';
//   String companyName = '';
//
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadCompanyInfo();
//
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 900),
//     );
//
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
//     );
//
//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, 0.06),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//         parent: _animationController, curve: Curves.easeOutCubic));
//
//     _animationController.forward();
//     _loadSavedCredentials();
//   }
//
//   Future<void> _loadCompanyInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       companyCode = prefs.getString(prefCompanyCode) ?? 'Unknown';
//       companyName = prefs.getString(prefCompanyName) ?? 'Company';
//     });
//   }
//
//   Future<void> _loadSavedCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     final rememberMe = prefs.getBool(prefRememberMe) ?? false;
//     setState(() => isChecked = rememberMe);
//     if (rememberMe) {
//       final savedUserId = prefs.getString(prefSavedUserId);
//       if (savedUserId != null) _userIdController.text = savedUserId;
//     }
//   }
//
//   Future<void> _login() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     if (companyCode == 'Unknown' || companyCode.isEmpty) {
//       Get.snackbar(
//         'Error',
//         'Company not verified. Please restart the app and enter company code.',
//         backgroundColor: AppColors.error,
//         colorText: AppColors.textOnDark,
//         duration: const Duration(seconds: 3),
//       );
//       return;
//     }
//
//     setState(() => isLoading = true);
//
//     try {
//       final success = await loginViewModel.login(
//         _userIdController.text.trim(),
//         _passwordController.text.trim(),
//       );
//
//       if (success) {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setBool(prefRememberMe, isChecked);
//         if (isChecked) {
//           await prefs.setString(
//               prefSavedUserId, _userIdController.text.trim());
//         }
//
//         Get.snackbar(
//           'Success',
//           'Welcome back! Login successful.',
//           backgroundColor: AppColors.primary,
//           colorText: AppColors.textOnDark,
//         );
//
//         String route = loginViewModel.getHomeRoute();
//         await Future.delayed(const Duration(milliseconds: 500));
//         Get.offAllNamed(route);
//       } else {
//         Get.snackbar(
//           'Login Failed',
//           loginViewModel.loginError.value,
//           backgroundColor: AppColors.error,
//           colorText: AppColors.textOnDark,
//         );
//       }
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   @override
//   void dispose() {
//     _userIdController.dispose();
//     _passwordController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isSmall  = size.height < 640;   // iPhone SE, small Android
//     final isTablet = size.width  > 600;   // tablet ya landscape
//
//     final double headerPaddingTop = isSmall ? 10 : 20;
//     final double headerPaddingH   = isTablet ? 48 : 32;
//     final double titleFontSize    = isSmall ? 28 : (isTablet ? 42 : 36);
//     final double cardRadius       = isSmall ? 22 : 32;
//     final double cardPaddingH     = isTablet ? 40 : 28;
//     final double cardPaddingV     = isSmall ? 14 : 24;
//     final double fieldSpacing     = isSmall ? 10 : 18;
//     final double buttonHeight     = isSmall ? 46 : 54;
//
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: Stack(
//         children: [
//           // Gradient background
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [AppColors.cyan, AppColors.greenTeal],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//
//           // Decorative circles
//           Positioned(top: -80, left: -80,
//               child: _circle(260, 0.07)),
//           Positioned(bottom: 60, right: -60,
//               child: _circle(200, 0.06)),
//           if (!isSmall)
//             Positioned(top: 160, right: 30,
//                 child: _circle(60, 0.10)),
//
//           // Content
//           SafeArea(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: SlideTransition(
//                 position: _slideAnimation,
//                 child: isTablet
//                     ? _tabletLayout(
//                   headerPaddingTop: headerPaddingTop,
//                   headerPaddingH: headerPaddingH,
//                   titleFontSize: titleFontSize,
//                   cardRadius: cardRadius,
//                   cardPaddingH: cardPaddingH,
//                   cardPaddingV: cardPaddingV,
//                   fieldSpacing: fieldSpacing,
//                   buttonHeight: buttonHeight,
//                 )
//                     : _phoneLayout(
//                   headerPaddingTop: headerPaddingTop,
//                   headerPaddingH: headerPaddingH,
//                   titleFontSize: titleFontSize,
//                   cardRadius: cardRadius,
//                   cardPaddingH: cardPaddingH,
//                   cardPaddingV: cardPaddingV,
//                   fieldSpacing: fieldSpacing,
//                   buttonHeight: buttonHeight,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Phone layout ────────────────────────────────────────────────────
//   Widget _phoneLayout({
//     required double headerPaddingTop,
//     required double headerPaddingH,
//     required double titleFontSize,
//     required double cardRadius,
//     required double cardPaddingH,
//     required double cardPaddingV,
//     required double fieldSpacing,
//     required double buttonHeight,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: EdgeInsets.fromLTRB(
//               headerPaddingH, headerPaddingTop, headerPaddingH, 16),
//           child: _buildHeader(titleFontSize: titleFontSize),
//         ),
//         Expanded(
//           child: Container(
//             width: double.infinity,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius:
//               BorderRadius.vertical(top: Radius.circular(cardRadius)),
//             ),
//             child: SingleChildScrollView(
//               physics: const ClampingScrollPhysics(),
//               padding: EdgeInsets.fromLTRB(
//                   cardPaddingH, cardPaddingV, cardPaddingH, cardPaddingV),
//               child: _buildForm(
//                   fieldSpacing: fieldSpacing, buttonHeight: buttonHeight),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ── Tablet / landscape layout ───────────────────────────────────────
//   Widget _tabletLayout({
//     required double headerPaddingTop,
//     required double headerPaddingH,
//     required double titleFontSize,
//     required double cardRadius,
//     required double cardPaddingH,
//     required double cardPaddingV,
//     required double fieldSpacing,
//     required double buttonHeight,
//   }) {
//     return Row(
//       children: [
//         // Left branding
//         Expanded(
//           flex: 5,
//           child: Padding(
//             padding: EdgeInsets.fromLTRB(
//                 headerPaddingH, headerPaddingTop, 24, 24),
//             child: _buildHeader(titleFontSize: titleFontSize),
//           ),
//         ),
//         // Right form card
//         Expanded(
//           flex: 6,
//           child: Container(
//             margin: const EdgeInsets.symmetric(vertical: 24),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(cardRadius),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.08),
//                   blurRadius: 24,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: SingleChildScrollView(
//               physics: const ClampingScrollPhysics(),
//               padding: EdgeInsets.fromLTRB(
//                   cardPaddingH, cardPaddingV, cardPaddingH, cardPaddingV),
//               child: _buildForm(
//                   fieldSpacing: fieldSpacing, buttonHeight: buttonHeight),
//             ),
//           ),
//         ),
//         SizedBox(width: headerPaddingH),
//       ],
//     );
//   }
//
//   // ── Header ──────────────────────────────────────────────────────────
//   Widget _buildHeader({required double titleFontSize}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         // Badge
//         Container(
//           padding:
//           const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.20),
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: const Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(Icons.shield_outlined, color: Colors.white, size: 12),
//               SizedBox(width: 5),
//               Text(
//                 'GPS Workforce Monitor',
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w700,
//                   color: Colors.white,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 14),
//         Text(
//           'Welcome\nBack',
//           style: TextStyle(
//             fontSize: titleFontSize,
//             fontWeight: FontWeight.w800,
//             color: Colors.white,
//             height: 1.1,
//             letterSpacing: -0.5,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Sign in to access your dashboard',
//           style: TextStyle(
//             fontSize: 13,
//             color: Colors.white.withOpacity(0.85),
//           ),
//         ),
//         const SizedBox(height: 12),
//       ],
//     );
//   }
//
//   // ── Form ────────────────────────────────────────────────────────────
//   Widget _buildForm({
//     required double fieldSpacing,
//     required double buttonHeight,
//   }) {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Sign In',
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.w800,
//               color: AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             'Enter your credentials for $companyName',
//             style: TextStyle(
//               fontSize: 13,
//               color: AppColors.textSecondary.withOpacity(0.8),
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//
//           SizedBox(height: fieldSpacing + 4),
//
//           // Employee ID
//           _buildLabel('EMPLOYEE ID'),
//           const SizedBox(height: 7),
//           _buildTextField(
//             controller: _userIdController,
//             hint: 'Enter your employee ID',
//             icon: Icons.person_outline_rounded,
//             validator: (v) =>
//             (v == null || v.isEmpty) ? 'Please enter employee ID' : null,
//           ),
//
//           SizedBox(height: fieldSpacing),
//
//           // Password
//           _buildLabel('PASSWORD'),
//           const SizedBox(height: 7),
//           _buildTextField(
//             controller: _passwordController,
//             hint: 'Enter your password',
//             icon: Icons.lock_outline_rounded,
//             obscure: !isPasswordVisible,
//             suffix: IconButton(
//               icon: Icon(
//                 isPasswordVisible
//                     ? Icons.visibility_off_outlined
//                     : Icons.visibility_outlined,
//                 color: AppColors.textSecondary,
//                 size: 20,
//               ),
//               onPressed: () =>
//                   setState(() => isPasswordVisible = !isPasswordVisible),
//             ),
//             validator: (v) =>
//             (v == null || v.isEmpty) ? 'Please enter password' : null,
//           ),
//
//           SizedBox(height: fieldSpacing - 4),
//
//           // Remember me
//           Row(
//             children: [
//               SizedBox(
//                 width: 22,
//                 height: 22,
//                 child: Checkbox(
//                   value: isChecked,
//                   onChanged: (v) =>
//                       setState(() => isChecked = v ?? false),
//                   activeColor: AppColors.primary,
//                   side: BorderSide(
//                       color: AppColors.divider, width: 1.5),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(5)),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Text(
//                 'Remember me',
//                 style: TextStyle(
//                   fontSize: 13,
//                   color: AppColors.textSecondary,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//
//           SizedBox(height: fieldSpacing),
//
//           // Sign In button
//           SizedBox(
//             width: double.infinity,
//             height: buttonHeight,
//             child: DecoratedBox(
//               decoration: BoxDecoration(
//                 gradient: AppColors.brandGradient,
//                 borderRadius: BorderRadius.circular(14),
//                 boxShadow: [
//                   BoxShadow(
//                     color: AppColors.cyan.withOpacity(0.40),
//                     blurRadius: 18,
//                     offset: const Offset(0, 6),
//                   ),
//                 ],
//               ),
//               child: ElevatedButton(
//                 onPressed: isLoading ? null : _login,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.transparent,
//                   shadowColor: Colors.transparent,
//                   foregroundColor: Colors.white,
//                   disabledBackgroundColor: const Color(0xFFCBD5E1),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14)),
//                 ),
//                 child: isLoading
//                     ? const SizedBox(
//                   width: 22,
//                   height: 22,
//                   child: CircularProgressIndicator(
//                       color: Colors.white, strokeWidth: 2.5),
//                 )
//                     : const Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text('Sign In',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.3,
//                         )),
//                     SizedBox(width: 8),
//                     Icon(Icons.arrow_forward_rounded, size: 18),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(height: 10),
//
//           // Switch company
//           TextButton(
//             onPressed: () => Get.offAllNamed(routeCodeScreen),
//             style: TextButton.styleFrom(
//                 padding: EdgeInsets.zero,
//                 minimumSize: const Size(0, 0)),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.switch_account_outlined,
//                     size: 14, color: AppColors.textSecondary),
//                 const SizedBox(width: 5),
//                 Text(
//                   'Switch to different company?',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: AppColors.textSecondary,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 4),
//
//           // Footer
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.lock_outline_rounded,
//                   size: 12,
//                   color: AppColors.textSecondary.withOpacity(0.5)),
//               const SizedBox(width: 5),
//               Text(
//                 'Secured & Encrypted Connection',
//                 style: TextStyle(
//                     fontSize: 11,
//                     color: AppColors.textSecondary.withOpacity(0.5)),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────
//   Widget _circle(double size, double opacity) => Container(
//     width: size,
//     height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: Colors.white.withOpacity(opacity),
//     ),
//   );
//
//   Widget _buildLabel(String text) => Text(
//     text,
//     style: TextStyle(
//       fontSize: 9,
//       fontWeight: FontWeight.w700,
//       color: AppColors.textSecondary.withOpacity(0.8),
//       letterSpacing: 1.4,
//     ),
//   );
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String hint,
//     required IconData icon,
//     bool obscure = false,
//     Widget? suffix,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: obscure,
//       style: const TextStyle(
//         color: AppColors.textPrimary,
//         fontWeight: FontWeight.w600,
//         fontSize: 15,
//       ),
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: TextStyle(
//           color: AppColors.textSecondary.withOpacity(0.45),
//           fontWeight: FontWeight.w400,
//           fontSize: 14,
//         ),
//         filled: true,
//         fillColor: const Color(0xFFF8FAFB),
//         prefixIcon: Icon(icon, color: AppColors.cyan, size: 20),
//         suffixIcon: suffix,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           const BorderSide(color: AppColors.divider, width: 1.2),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           const BorderSide(color: AppColors.divider, width: 1.2),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           const BorderSide(color: AppColors.cyan, width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           const BorderSide(color: AppColors.error, width: 1.5),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           const BorderSide(color: AppColors.error, width: 2),
//         ),
//         errorStyle:
//         const TextStyle(color: AppColors.error, fontSize: 12),
//         contentPadding:
//         const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
//       ),
//       validator: validator,
//     );
//   }
// }

///responsive
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ViewModels/login_view_model.dart';
import '../../constants.dart';
import '../AppColors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LoginViewModel loginViewModel = Get.find<LoginViewModel>();

  final _formKey = GlobalKey<FormState>();

  bool isChecked = false;
  bool isPasswordVisible = false;
  bool isLoading = false;

  String companyCode = '';
  String companyName = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
    _loadSavedCredentials();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyCode = prefs.getString(prefCompanyCode) ?? '';
      companyName = prefs.getString(prefCompanyName) ?? 'Your Company';
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(prefRememberMe) ?? false;
    setState(() => isChecked = rememberMe);

    if (rememberMe) {
      final savedUserId = prefs.getString(prefSavedUserId);
      if (savedUserId != null) {
        _userIdController.text = savedUserId;
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (companyCode.isEmpty) {
      Get.snackbar(
        'Error',
        'Company not verified. Please go back and enter company code.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await loginViewModel.login(
        _userIdController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(prefRememberMe, isChecked);
        if (isChecked) {
          await prefs.setString(prefSavedUserId, _userIdController.text.trim());
        }

        Get.snackbar(
          'Welcome Back!',
          'Login successful',
          backgroundColor: AppColors.primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );

        String route = loginViewModel.getHomeRoute();
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Get.offAllNamed(route);
      } else {
        Get.snackbar(
          'Login Failed',
          loginViewModel.loginError.value,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 680;
    final isTablet = size.width > 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative Circles
          Positioned(top: -100, left: -100, child: _circle(280, 0.08)),
          Positioned(bottom: -70, right: -90, child: _circle(240, 0.07)),
          if (!isSmallScreen)
            Positioned(top: 180, right: 40, child: _circle(55, 0.12)),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: isTablet
                    ? _buildTabletLayout(isSmallScreen)
                    : _buildPhoneLayout(isSmallScreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Phone Layout
  Widget _buildPhoneLayout(bool isSmallScreen) {
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(32, isSmallScreen ? 20 : 40, 65, 20),
          child: _buildHeader(isSmallScreen),
        ),

        // White Form Card
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(isSmallScreen ? 24 : 36),
              ),
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  28, isSmallScreen ? 24 : 32, 28, 32),
              child: _buildForm(isSmallScreen),
            ),
          ),
        ),
      ],
    );
  }

  // Tablet Layout
  Widget _buildTabletLayout(bool isSmallScreen) {
    return Row(
      children: [
        // Left Side - Branding
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: _buildHeader(isSmallScreen),
          ),
        ),

        // Right Side - Login Form
        Expanded(
          flex: 6,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
                child: _buildForm(isSmallScreen),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Header (Welcome Back)
  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: Colors.white, size: 14),
              SizedBox(width: 6),
              Text(
                'GPS Workforce Monitor',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: isSmallScreen ? 32 : 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to continue to your dashboard',
          style: TextStyle(
            fontSize: 14.5,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
      ],
    );
  }

  // Main Form
  Widget _buildForm(bool isSmallScreen) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign In',
            style: TextStyle(
              fontSize: isSmallScreen ? 21 : 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your credentials for $companyName',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary.withOpacity(0.85),
            ),
          ),

          const SizedBox(height: 32),

          // Employee ID
          _buildLabel('EMPLOYEE ID'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _userIdController,
            hint: 'Enter employee ID',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Employee ID is required' : null,
          ),

          const SizedBox(height: 24),

          // Password
          _buildLabel('PASSWORD'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint: 'Enter password',
            icon: Icons.lock_outline_rounded,
            obscure: !isPasswordVisible,
            suffix: IconButton(
              icon: Icon(
                isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
          ),

          const SizedBox(height: 16),

          // Remember Me
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (val) => setState(() => isChecked = val ?? false),
                  activeColor: AppColors.cyan,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  side: BorderSide(color: AppColors.divider, width: 1.6),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Remember me',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 52 : 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Switch Company
          Center(
            child: TextButton(
              onPressed: () => Get.offAllNamed(routeCodeScreen),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.switch_account_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Switch to different company?',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Security Footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.textSecondary.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  'Secured & Encrypted Connection',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _circle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary.withOpacity(0.85),
      letterSpacing: 1.5,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.5),
          fontSize: 14.5,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        prefixIcon: Icon(icon, color: AppColors.cyan, size: 22),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      validator: validator,
    );
  }
}