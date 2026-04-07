//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../constants.dart';
// import '../AppColors.dart';
// import '../Database/db_helper.dart';
//
// class CodeScreen extends StatefulWidget {
//   const CodeScreen({super.key});
//
//   @override
//   State<CodeScreen> createState() => _CodeScreenState();
// }
//
// class _CodeScreenState extends State<CodeScreen>
//     with SingleTickerProviderStateMixin {
//   late final TextEditingController companyCodeController;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   late Animation<Offset> _slideAnimation;
//
//   final _formKey = GlobalKey<FormState>();
//   bool isLoading = false;
//   bool isButtonDisabled = false;
//   String? errorMessage;
//
//   StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
//   bool isOffline = false;
//
//   @override
//   void initState() {
//     super.initState();
//     companyCodeController = TextEditingController();
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
//     _loadSavedCompanyCode();
//
//     connectivitySubscription =
//         Connectivity().onConnectivityChanged.listen((results) async {
//           final result =
//           results.isNotEmpty ? results.first : ConnectivityResult.none;
//           setState(() => isOffline = result == ConnectivityResult.none);
//         });
//   }
//
//   Future<void> _loadSavedCompanyCode() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedCode = prefs.getString(prefCompanyCode);
//     if (savedCode != null && savedCode.isNotEmpty) {
//       companyCodeController.text = savedCode;
//     }
//   }
//
//   @override
//   void dispose() {
//     companyCodeController.dispose();
//     connectivitySubscription?.cancel();
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   Future<bool> _hasInternet() async {
//     try {
//       final result = await InternetAddress.lookup('google.com')
//           .timeout(const Duration(seconds: 5));
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   void _showSnackBar(String message, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         backgroundColor: isError ? AppColors.error : AppColors.primary,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         margin: const EdgeInsets.all(20),
//       ),
//     );
//   }
//
//   Future<void> _validateCompanyCode() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() {
//       isLoading = true;
//       isButtonDisabled = true;
//       errorMessage = null;
//     });
//
//     if (!await _hasInternet()) {
//       _showSnackBar('No internet connection. Please try again.', isError: true);
//       setState(() {
//         isLoading = false;
//         isButtonDisabled = false;
//       });
//       return;
//     }
//
//     try {
//       final companyCode = companyCodeController.text.trim().toUpperCase();
//
//       if (companyCode.isEmpty) {
//         throw Exception('Please enter a valid company code');
//       }
//
//       // ✅ Use single API with company_code filter
//       final apiUrl = ApiManager.getCompanyApi(companyCode);
//       debugPrint('🔍 Validating company code: $companyCode using API: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(const Duration(seconds: 30));
//
//       if (response.statusCode != 200) {
//         throw Exception('Failed to fetch company data');
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       List<dynamic> companies = data['items'] ?? [];
//
//       // Find company by code
//       final company = companies.firstWhere(
//             (c) {
//           final code = c['company_code']?.toString().toUpperCase() ?? '';
//           return code == companyCode;
//         },
//         orElse: () => null,
//       );
//
//       if (company == null) {
//         throw Exception('Company code not found. Please check and try again.');
//       }
//
//       final prefs = await SharedPreferences.getInstance();
//       String companyName = company['company_name'] ?? 'Unknown';
//       String workspaceName = company['workspace_name'] ?? 'gps_workforce';
//
//       // Store company information
//       await prefs.setString(prefCompanyCode, companyCode);
//       await prefs.setString(prefCompanyName, companyName);
//       await prefs.setString(prefWorkspaceName, workspaceName);
//
//       // ✅ Set company code in DBHelper for database operations
//       DBHelper.setCompanyCode(companyCode);
//
//       // Store API endpoints (all use the same base URL but will include company_code)
//       await prefs.setString('company_api_url', apiUrl);
//       await prefs.setString('login_api_url', ApiManager.getLoginApi(companyCode));
//
//       _showSnackBar('Welcome $companyName! Verified successfully.');
//       await Future.delayed(const Duration(milliseconds: 800));
//
//       if (mounted) {
//         Get.toNamed('/permissions');
//       }
//     } catch (e) {
//       String errorMsg = e.toString().replaceAll('Exception: ', '');
//       setState(() {
//         errorMessage = errorMsg;
//       });
//       _showSnackBar(errorMsg, isError: true);
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//           isButtonDisabled = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [AppColors.cyan, AppColors.greenTeal],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           // ... (rest of your UI remains the same)
//           SafeArea(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: SlideTransition(
//                 position: _slideAnimation,
//                 child: SingleChildScrollView(
//                   physics: const BouncingScrollPhysics(),
//                   child: SizedBox(
//                     height: MediaQuery.of(context).size.height,
//                     child: Column(
//                       children: [
//                         Expanded(
//                           flex: 3,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.stretch,
//                             children: [
//                               Padding(
//                                 padding: const EdgeInsets.only(
//                                     left: 20, right: 20, top: 8),
//                                 child: Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: GestureDetector(
//                                     onTap: () => Get.back(),
//                                     child: Container(
//                                       padding: const EdgeInsets.all(8),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white.withOpacity(0.20),
//                                         borderRadius: BorderRadius.circular(10),
//                                       ),
//                                       child: const Icon(
//                                         Icons.arrow_back_ios_new_rounded,
//                                         color: Colors.white,
//                                         size: 18,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Container(
//                                       width: 84,
//                                       height: 84,
//                                       decoration: BoxDecoration(
//                                         shape: BoxShape.circle,
//                                         color: Colors.white,
//                                         boxShadow: [
//                                           BoxShadow(
//                                             color: Colors.black.withOpacity(0.15),
//                                             blurRadius: 24,
//                                             offset: const Offset(0, 8),
//                                           ),
//                                         ],
//                                       ),
//                                       child: Padding(
//                                         padding: const EdgeInsets.all(10),
//                                         child: Image.asset(
//                                           'assets/images/applogo.png',
//                                           fit: BoxFit.contain,
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 12),
//                                     const Text(
//                                       'GPS Workforce Monitor',
//                                       style: TextStyle(
//                                         fontSize: 25,
//                                         fontWeight: FontWeight.w700,
//                                         color: Colors.white,
//                                         letterSpacing: 0.2,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Text(
//                                       'Enter your company code to continue',
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         color: Colors.white.withOpacity(0.75),
//                                         fontWeight: FontWeight.w400,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           flex: 5,
//                           child: Container(
//                             width: double.infinity,
//                             decoration: const BoxDecoration(
//                               color: Colors.white,
//                               borderRadius:
//                               BorderRadius.vertical(top: Radius.circular(32)),
//                             ),
//                             child: SingleChildScrollView(
//                               padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
//                               child: Form(
//                                 key: _formKey,
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     const Text(
//                                       'Verify Code',
//                                       style: TextStyle(
//                                         fontSize: 22,
//                                         fontWeight: FontWeight.w800,
//                                         color: AppColors.textPrimary,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 6),
//                                     Text(
//                                       'Enter the unique code provided by your company',
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         color: AppColors.textSecondary
//                                             .withOpacity(0.8),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 28),
//                                     _buildLabel('COMPANY CODE'),
//                                     const SizedBox(height: 7),
//                                     TextFormField(
//                                       controller: companyCodeController,
//                                       textCapitalization: TextCapitalization.characters,
//                                       style: const TextStyle(
//                                         color: AppColors.textPrimary,
//                                         fontWeight: FontWeight.w700,
//                                         fontSize: 15,
//                                         letterSpacing: 2.0,
//                                       ),
//                                       decoration: InputDecoration(
//                                         hintText: 'e.g. ACME2024',
//                                         hintStyle: TextStyle(
//                                           color: AppColors.textSecondary.withOpacity(0.45),
//                                           fontWeight: FontWeight.w400,
//                                           letterSpacing: 0.5,
//                                           fontSize: 14,
//                                         ),
//                                         filled: true,
//                                         fillColor: const Color(0xFFF8FAFB),
//                                         prefixIcon: Icon(
//                                           Icons.badge_outlined,
//                                           color: AppColors.cyan,
//                                           size: 20,
//                                         ),
//                                         border: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(12),
//                                           borderSide: const BorderSide(
//                                               color: AppColors.divider,
//                                               width: 1.2),
//                                         ),
//                                         enabledBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(12),
//                                           borderSide: const BorderSide(
//                                               color: AppColors.divider,
//                                               width: 1.2),
//                                         ),
//                                         focusedBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(12),
//                                           borderSide: const BorderSide(
//                                               color: AppColors.cyan, width: 2),
//                                         ),
//                                         errorBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(12),
//                                           borderSide: const BorderSide(
//                                               color: AppColors.error, width: 1.5),
//                                         ),
//                                         focusedErrorBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(12),
//                                           borderSide: const BorderSide(
//                                               color: AppColors.error, width: 2),
//                                         ),
//                                         errorText: errorMessage,
//                                         errorStyle: const TextStyle(
//                                             color: AppColors.error, fontSize: 12),
//                                         contentPadding: const EdgeInsets.symmetric(
//                                             horizontal: 16, vertical: 18),
//                                       ),
//                                       validator: (value) {
//                                         if (value == null || value.isEmpty) {
//                                           return 'Please enter a company code';
//                                         }
//                                         return null;
//                                       },
//                                     ),
//                                     const SizedBox(height: 32),
//                                     SizedBox(
//                                       width: double.infinity,
//                                       height: 54,
//                                       child: DecoratedBox(
//                                         decoration: BoxDecoration(
//                                           gradient: isOffline
//                                               ? null
//                                               : AppColors.brandGradient,
//                                           color: isOffline
//                                               ? const Color(0xFFCBD5E1)
//                                               : null,
//                                           borderRadius: BorderRadius.circular(14),
//                                           boxShadow: isOffline
//                                               ? []
//                                               : [
//                                             BoxShadow(
//                                               color: AppColors.cyan.withOpacity(0.40),
//                                               blurRadius: 18,
//                                               offset: const Offset(0, 6),
//                                             ),
//                                           ],
//                                         ),
//                                         child: ElevatedButton(
//                                           onPressed:
//                                           (isButtonDisabled || isOffline)
//                                               ? null
//                                               : _validateCompanyCode,
//                                           style: ElevatedButton.styleFrom(
//                                             backgroundColor: Colors.transparent,
//                                             shadowColor: Colors.transparent,
//                                             foregroundColor: isOffline
//                                                 ? AppColors.textSecondary
//                                                 : Colors.white,
//                                             disabledBackgroundColor: Colors.transparent,
//                                             shape: RoundedRectangleBorder(
//                                               borderRadius: BorderRadius.circular(14),
//                                             ),
//                                           ),
//                                           child: isLoading
//                                               ? const SizedBox(
//                                             width: 22,
//                                             height: 22,
//                                             child: CircularProgressIndicator(
//                                               color: Colors.white,
//                                               strokeWidth: 2.5,
//                                             ),
//                                           )
//                                               : Row(
//                                             mainAxisAlignment: MainAxisAlignment.center,
//                                             children: [
//                                               Text(
//                                                 isOffline ? 'Offline' : 'Continue',
//                                                 style: const TextStyle(
//                                                   fontSize: 16,
//                                                   fontWeight: FontWeight.w700,
//                                                   letterSpacing: 0.3,
//                                                 ),
//                                               ),
//                                               if (!isOffline) ...[
//                                                 const SizedBox(width: 8),
//                                                 const Icon(
//                                                     Icons.arrow_forward_rounded,
//                                                     size: 18),
//                                               ],
//                                             ],
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 16),
//                                     Row(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Icon(Icons.lock_outline_rounded,
//                                             size: 12,
//                                             color: AppColors.textSecondary
//                                                 .withOpacity(0.5)),
//                                         const SizedBox(width: 5),
//                                         Text(
//                                           'Secured & Encrypted Connection',
//                                           style: TextStyle(
//                                             fontSize: 11,
//                                             color: AppColors.textSecondary
//                                                 .withOpacity(0.5),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           if (isOffline)
//             Positioned(
//               top: 0,
//               left: 0,
//               right: 0,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 9),
//                 color: AppColors.warning,
//                 child: const Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
//                     SizedBox(width: 8),
//                     Text(
//                       'No Internet Connection',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLabel(String text) {
//     return Text(
//       text,
//       style: TextStyle(
//         fontSize: 9,
//         fontWeight: FontWeight.w700,
//         color: AppColors.textSecondary.withOpacity(0.8),
//         letterSpacing: 1.4,
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../AppColors.dart';
import '../Database/db_helper.dart';
import '../Repositories/LoginRepositories/login_repository.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController companyCodeController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool isButtonDisabled = false;
  String? errorMessage;

  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    companyCodeController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
    _loadSavedCompanyCode();

    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
          final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
          setState(() => isOffline = result == ConnectivityResult.none);
        });
  }

  Future<void> _loadSavedCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(prefCompanyCode);
    if (savedCode != null && savedCode.isNotEmpty) {
      companyCodeController.text = savedCode;
    }
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _validateCompanyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      isButtonDisabled = true;
      errorMessage = null;
    });

    if (!await _hasInternet()) {
      _showSnackBar('No internet connection. Please try again.', isError: true);
      setState(() {
        isLoading = false;
        isButtonDisabled = false;
      });
      return;
    }

    try {
      final companyCode = companyCodeController.text.trim().toUpperCase();

      if (companyCode.isEmpty) {
        throw Exception('Please enter a valid company code');
      }

      // ── Step 1: Validate company code against registered companies API ────
      final companyApiUrl = ApiManager.getCompanyApi(companyCode);
      debugPrint('🔍 Validating company: $companyCode | URL: $companyApiUrl');

      final companyResponse = await http
          .get(Uri.parse(companyApiUrl))
          .timeout(const Duration(seconds: 30));

      if (companyResponse.statusCode != 200) {
        throw Exception('Failed to reach company server. Please try again.');
      }

      final Map<String, dynamic> companyData = json.decode(companyResponse.body);
      final List<dynamic> companies = companyData['items'] ?? [];

      // Find matching company by company_code
      final company = companies.firstWhere(
            (c) {
          final code = c['company_code']?.toString().toUpperCase() ?? '';
          return code == companyCode;
        },
        orElse: () => null,
      );

      if (company == null) {
        throw Exception('Company code "$companyCode" not found. Please check and try again.');
      }

      // ── Step 2: Save company info ─────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      final String companyName = company['company_name'] ?? 'Unknown';
      final String workspaceName = company['workspace_name'] ?? 'gps_workforce';

      await prefs.setString(prefCompanyCode, companyCode);
      await prefs.setString(prefCompanyName, companyName);
      await prefs.setString(prefWorkspaceName, workspaceName);
      await prefs.setString('company_api_url', companyApiUrl);
      await prefs.setString('login_api_url', ApiManager.getLoginApi(companyCode));

      DBHelper.setCompanyCode(companyCode);

      debugPrint('✅ Company validated: $companyName ($companyCode)');

      // ── Step 3: Pre-fetch & cache all employees for this company ──────────
      // This is KEY: when user logs in, we check their emp_id against this cache.
      debugPrint('👥 Pre-fetching employees for company: $companyCode');

      final loginRepository = Get.find<LoginRepository>();
      final employeesFetched =
      await loginRepository.fetchAndCacheEmployeesForCompany(companyCode);

      if (employeesFetched) {
        debugPrint('✅ Employees cached successfully for: $companyCode');
      } else {
        // Non-fatal: employees will be fetched live at login time
        debugPrint('⚠️ Employee pre-fetch failed — will retry at login');
      }

      // ── Step 4: Navigate ──────────────────────────────────────────────────
      _showSnackBar('Welcome $companyName! Verified successfully.');
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Get.toNamed('/permissions');
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        errorMessage = errorMsg;
      });
      _showSnackBar(errorMsg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isButtonDisabled = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20, right: 20, top: 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () => Get.back(),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.20),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
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
                                    const SizedBox(height: 12),
                                    const Text(
                                      'GPS Workforce Monitor',
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Enter your company code to continue',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.75),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verify Code',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Enter the unique code provided by your company',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    _buildLabel('COMPANY CODE'),
                                    const SizedBox(height: 7),
                                    TextFormField(
                                      controller: companyCodeController,
                                      textCapitalization:
                                      TextCapitalization.characters,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 2.0,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. ACME2024',
                                        hintStyle: TextStyle(
                                          color: AppColors.textSecondary
                                              .withOpacity(0.45),
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.5,
                                          fontSize: 14,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFB),
                                        prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          color: AppColors.cyan,
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.divider,
                                              width: 1.2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.divider,
                                              width: 1.2),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.cyan, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.error,
                                              width: 1.5),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.error, width: 2),
                                        ),
                                        errorText: errorMessage,
                                        errorStyle: const TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 18),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a company code';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: isOffline
                                              ? null
                                              : AppColors.brandGradient,
                                          color: isOffline
                                              ? const Color(0xFFCBD5E1)
                                              : null,
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          boxShadow: isOffline
                                              ? []
                                              : [
                                            BoxShadow(
                                              color: AppColors.cyan
                                                  .withOpacity(0.40),
                                              blurRadius: 18,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: (isButtonDisabled ||
                                              isOffline)
                                              ? null
                                              : _validateCompanyCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: isOffline
                                                ? AppColors.textSecondary
                                                : Colors.white,
                                            disabledBackgroundColor:
                                            Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                            CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                              : Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                isOffline
                                                    ? 'Offline'
                                                    : 'Continue',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              if (!isOffline) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                    Icons
                                                        .arrow_forward_rounded,
                                                    size: 18),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_outline_rounded,
                                            size: 12,
                                            color: AppColors.textSecondary
                                                .withOpacity(0.5)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Secured & Encrypted Connection',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                color: AppColors.warning,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary.withOpacity(0.8),
        letterSpacing: 1.4,
      ),
    );
  }
}