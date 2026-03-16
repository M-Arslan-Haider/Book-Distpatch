// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../../constants.dart';
// import '../AppColors.dart'; // adjust path as needed
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
//
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   @override
//   void initState() {
//     super.initState();
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
//       begin: const Offset(0, 0.08),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(
//         parent: _animationController, curve: Curves.easeOutCubic));
//
//     _animationController.forward();
//     _loadSavedCredentials();
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
//         Get.snackbar(
//           'Success',
//           'Login successful!',
//           backgroundColor: AppColors.primary,
//           colorText: AppColors.textOnDark,
//         );
//         String route = loginViewModel.getHomeRoute();
//         await Future.delayed(const Duration(milliseconds: 500));
//         Get.offAllNamed(route);
//       } else {
//         Get.snackbar(
//           'Error',
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
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: GestureDetector(
//         onTap: () => FocusScope.of(context).unfocus(),
//         child: Stack(
//           children: [
//             // ── Decorative background blobs ──────────────────────────────
//             Positioned(
//               top: -100,
//               right: -50,
//               child: Transform.rotate(
//                 angle: -0.2,
//                 child: Container(
//                   width: 300,
//                   height: 300,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(80),
//                     gradient: LinearGradient(
//                       colors: [
//                         AppColors.cyan.withOpacity(0.18),
//                         AppColors.cyan.withOpacity(0.04),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Positioned(
//               top: 50,
//               left: -30,
//               child: Container(
//                 width: 130,
//                 height: 130,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: AppColors.skyBlue.withOpacity(0.10),
//                 ),
//               ),
//             ),
//             Positioned(
//               bottom: -60,
//               right: -40,
//               child: Container(
//                 width: 160,
//                 height: 160,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: AppColors.greenTeal.withOpacity(0.08),
//                 ),
//               ),
//             ),
//
//             // ── Main content ─────────────────────────────────────────────
//             SafeArea(
//               child: FadeTransition(
//                 opacity: _fadeAnimation,
//                 child: SlideTransition(
//                   position: _slideAnimation,
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.symmetric(horizontal: 32),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const SizedBox(height: 52),
//
//                         // ── Icon — gradient circle ────────────────────────
//                         Container(
//                           padding: const EdgeInsets.all(28),
//                           decoration: BoxDecoration(
//                             gradient: AppColors.brandGradient,
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                                 color: AppColors.cyan.withOpacity(0.5),
//                                 width: 2.5),
//                             boxShadow: AppColors.cyanGlow,
//                           ),
//                           child: const Icon(
//                             Icons.how_to_reg_rounded,
//                             size: 64,
//                             color: Colors.white,
//                           ),
//                         ),
//
//                         const SizedBox(height: 32),
//
//                         // ── Title ─────────────────────────────────────────
//                         const Text(
//                           'Welcome Back',
//                           style: TextStyle(
//                             fontSize: 26,
//                             fontWeight: FontWeight.w800,
//                             color: AppColors.textPrimary,
//                             letterSpacing: -0.3,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//
//                         const SizedBox(height: 10),
//
//                         // Cyan accent divider
//                         Container(
//                           width: 40,
//                           height: 3,
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [AppColors.cyan, AppColors.greenTeal],
//                             ),
//                             borderRadius: BorderRadius.circular(2),
//                           ),
//                         ),
//
//                         const SizedBox(height: 12),
//
//                         Text(
//                           'Sign in to your account to continue.',
//                           style: TextStyle(
//                             fontSize: 15,
//                             color: AppColors.textSecondary,
//                             height: 1.5,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//
//                         const SizedBox(height: 36),
//
//                         // ── Login Card ────────────────────────────────────
//                         _buildLoginCard(),
//
//                         const SizedBox(height: 24),
//
//                         // ── Footer ────────────────────────────────────────
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(Icons.lock_outline_rounded,
//                                 size: 13,
//                                 color:
//                                 AppColors.textSecondary.withOpacity(0.6)),
//                             const SizedBox(width: 5),
//                             Text(
//                               'Secured & Encrypted Connection',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color:
//                                 AppColors.textSecondary.withOpacity(0.6),
//                               ),
//                             ),
//                           ],
//                         ),
//
//                         const SizedBox(height: 28),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLoginCard() {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: AppColors.divider, width: 1.2),
//         boxShadow: AppColors.cardShadow,
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Card header ───────────────────────────────────────────────
//             Row(
//               children: [
//                 // Cyan left accent bar
//                 Container(
//                   width: 4,
//                   height: 22,
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [AppColors.cyan, AppColors.greenTeal],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: AppColors.iconBgCyan,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: const Icon(Icons.badge_rounded,
//                       color: AppColors.primary, size: 16),
//                 ),
//                 const SizedBox(width: 10),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Employee Login',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: AppColors.textPrimary,
//                       ),
//                     ),
//                     Text(
//                       'Use your credentials to sign in',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: AppColors.textSecondary.withOpacity(0.8),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 18),
//             const Divider(color: AppColors.divider, height: 1),
//             const SizedBox(height: 18),
//
//             // ── Employee ID ───────────────────────────────────────────────
//             const Text(
//               'EMPLOYEE ID',
//               style: TextStyle(
//                 fontSize: 9,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.textSecondary,
//                 letterSpacing: 1.4,
//               ),
//             ),
//             const SizedBox(height: 7),
//             TextFormField(
//               controller: _userIdController,
//               style: const TextStyle(
//                 color: AppColors.textPrimary,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 15,
//               ),
//               decoration: InputDecoration(
//                 hintText: 'Enter your employee ID',
//                 hintStyle: TextStyle(
//                   color: AppColors.textSecondary.withOpacity(0.50),
//                   fontWeight: FontWeight.w400,
//                   fontSize: 14,
//                 ),
//                 filled: true,
//                 fillColor: AppColors.surface,
//                 prefixIcon: Icon(
//                   Icons.person_outline_rounded,
//                   color: AppColors.cyan,
//                   size: 20,
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.divider, width: 1.2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.divider, width: 1.2),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.primary, width: 2),
//                 ),
//                 errorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.error, width: 1.5),
//                 ),
//                 focusedErrorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.error, width: 2),
//                 ),
//                 errorStyle:
//                 const TextStyle(color: AppColors.error, fontSize: 12),
//                 contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 18),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter employee ID';
//                 }
//                 return null;
//               },
//             ),
//
//             const SizedBox(height: 16),
//
//             // ── Password ──────────────────────────────────────────────────
//             const Text(
//               'PASSWORD',
//               style: TextStyle(
//                 fontSize: 9,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.textSecondary,
//                 letterSpacing: 1.4,
//               ),
//             ),
//             const SizedBox(height: 7),
//             TextFormField(
//               controller: _passwordController,
//               obscureText: !isPasswordVisible,
//               style: const TextStyle(
//                 color: AppColors.textPrimary,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 15,
//               ),
//               decoration: InputDecoration(
//                 hintText: 'Enter your password',
//                 hintStyle: TextStyle(
//                   color: AppColors.textSecondary.withOpacity(0.50),
//                   fontWeight: FontWeight.w400,
//                   fontSize: 14,
//                 ),
//                 filled: true,
//                 fillColor: AppColors.surface,
//                 prefixIcon: Icon(
//                   Icons.lock_outline_rounded,
//                   color: AppColors.cyan,
//                   size: 20,
//                 ),
//                 suffixIcon: IconButton(
//                   icon: Icon(
//                     isPasswordVisible
//                         ? Icons.visibility_off_outlined
//                         : Icons.visibility_outlined,
//                     color: AppColors.textSecondary,
//                     size: 20,
//                   ),
//                   onPressed: () =>
//                       setState(() => isPasswordVisible = !isPasswordVisible),
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.divider, width: 1.2),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.divider, width: 1.2),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.primary, width: 2),
//                 ),
//                 errorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.error, width: 1.5),
//                 ),
//                 focusedErrorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide:
//                   const BorderSide(color: AppColors.error, width: 2),
//                 ),
//                 errorStyle:
//                 const TextStyle(color: AppColors.error, fontSize: 12),
//                 contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 18),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Please enter password';
//                 }
//                 return null;
//               },
//             ),
//
//             const SizedBox(height: 16),
//
//             // ── Remember me ───────────────────────────────────────────────
//             Row(
//               children: [
//                 SizedBox(
//                   width: 22,
//                   height: 22,
//                   child: Checkbox(
//                     value: isChecked,
//                     onChanged: (v) =>
//                         setState(() => isChecked = v ?? false),
//                     activeColor: AppColors.primary,
//                     side: const BorderSide(color: AppColors.divider, width: 1.5),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(5),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Text(
//                   'Remember me',
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: AppColors.textSecondary,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 22),
//
//             // ── Sign In Button ────────────────────────────────────────────
//             SizedBox(
//               width: double.infinity,
//               height: 54,
//               child: DecoratedBox(
//                 decoration: BoxDecoration(
//                   gradient: AppColors.brandGradient,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: AppColors.cyanGlow,
//                 ),
//                 child: ElevatedButton(
//                   onPressed: isLoading ? null : _login,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.transparent,
//                     shadowColor: Colors.transparent,
//                     foregroundColor: Colors.white,
//                     disabledBackgroundColor: const Color(0xFFCBD5E1),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: isLoading
//                       ? const SizedBox(
//                     width: 22,
//                     height: 22,
//                     child: CircularProgressIndicator(
//                       color: Colors.white,
//                       strokeWidth: 2.5,
//                     ),
//                   )
//                       : const Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text(
//                         'Sign In',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w700,
//                           letterSpacing: 0.3,
//                         ),
//                       ),
//                       SizedBox(width: 8),
//                       Icon(Icons.arrow_forward_rounded, size: 18),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ViewModels/login_view_model.dart';
import '../../constants.dart';
import '../AppColors.dart'; // adjust path as needed

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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(prefRememberMe) ?? false;
    setState(() => isChecked = rememberMe);
    if (rememberMe) {
      final savedUserId = prefs.getString(prefSavedUserId);
      if (savedUserId != null) _userIdController.text = savedUserId;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
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
          await prefs.setString(
              prefSavedUserId, _userIdController.text.trim());
        }
        Get.snackbar(
          'Success',
          'Login successful!',
          backgroundColor: AppColors.primary,
          colorText: AppColors.textOnDark,
        );
        String route = loginViewModel.getHomeRoute();
        await Future.delayed(const Duration(milliseconds: 500));
        Get.offAllNamed(route);
      } else {
        Get.snackbar(
          'Error',
          loginViewModel.loginError.value,
          backgroundColor: AppColors.error,
          colorText: AppColors.textOnDark,
        );
      }
    } finally {
      setState(() => isLoading = false);
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Decorative background blobs ──────────────────────────────
            Positioned(
              top: -100,
              right: -50,
              child: Transform.rotate(
                angle: -0.2,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cyan.withOpacity(0.18),
                        AppColors.cyan.withOpacity(0.04),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 50,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.skyBlue.withOpacity(0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenTeal.withOpacity(0.08),
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 52),

                        // ── Logo image ───────────────────────────────────
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withOpacity(0.30),
                                blurRadius: 32,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: AppColors.greenTeal.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/images/applogo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Title ─────────────────────────────────────────
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 10),

                        // Cyan accent divider
                        Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.cyan, AppColors.greenTeal],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Sign in to your account to continue.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        // ── Login Card ────────────────────────────────────
                        _buildLoginCard(),

                        const SizedBox(height: 15),

                        // ── Footer ────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 13,
                                color:
                                AppColors.textSecondary.withOpacity(0.6)),
                            const SizedBox(width: 5),
                            Text(
                              'Secured & Encrypted Connection',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                AppColors.textSecondary.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.2),
        boxShadow: AppColors.cardShadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ───────────────────────────────────────────────
            Row(
              children: [
                // Cyan left accent bar
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.greenTeal],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.iconBgCyan,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.badge_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Employee Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Use your credentials to sign in',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 18),

            // ── Employee ID ───────────────────────────────────────────────
            const Text(
              'EMPLOYEE ID',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _userIdController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your employee ID',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.50),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.cyan,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
                ),
                errorStyle:
                const TextStyle(color: AppColors.error, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter employee ID';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Password ──────────────────────────────────────────────────
            const Text(
              'PASSWORD',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: _passwordController,
              obscureText: !isPasswordVisible,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.50),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.cyan,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => isPasswordVisible = !isPasswordVisible),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
                ),
                errorStyle:
                const TextStyle(color: AppColors.error, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Remember me ───────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (v) =>
                        setState(() => isChecked = v ?? false),
                    activeColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.divider, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Remember me',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ── Sign In Button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.cyanGlow,
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}