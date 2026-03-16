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

  // ── Design tokens (mirrored from EmployeeProfileScreen) ──────────────────
  // Color tokens moved to AppColors
  // see app_colors.dart
  //
  //
  //
  //
  //
  //
  //
  //

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
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

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

      final response = await http
          .get(Uri.parse(companyApiEndpoint))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch company data');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> companies = data['items'] ?? [];

      if (companies.isEmpty) {
        throw Exception('No companies found');
      }

      final company = companies.firstWhere(
            (c) {
          final code = c['company_code']?.toString().toUpperCase() ?? '';
          return code == companyCode;
        },
        orElse: () => null,
      );

      if (company == null) {
        throw Exception('Company code not found');
      }

      final prefs = await SharedPreferences.getInstance();
      String companyName = company['company_name'] ?? 'Unknown';
      String workspaceName = company['workspace_name'] ?? 'production';

      await prefs.setString(prefCompanyCode, companyCode);
      await prefs.setString(prefCompanyName, companyName);
      await prefs.setString(prefWorkspaceName, workspaceName);

      _showSnackBar('Company verified successfully!');
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Get.toNamed('/permissions');
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
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
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ── Decorative blobs using navy/gold palette ──────────────────
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
                        AppColors.cyan.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.03),
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
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.greenTeal.withOpacity(0.10),
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
                  color: AppColors.primary.withOpacity(0.05),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back button ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                  ),

                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),

                              // ── Logo image — GPS Workforce logo ─────────
                              Container(
                                width: 140,
                                height: 140,
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

                              const SizedBox(height: 36),

                              // ── Title ───────────────────────────────────
                              const Text(
                                'GPS Workforce Monitor',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1.25,
                                  letterSpacing: -0.3,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 10),

                              // Gold accent divider — signature profile element
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32, height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Enter your company code to continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 40),

                              // ── Input ────────────────────────────────────
                              Form(
                                key: _formKey,
                                child: TextFormField(
                                  controller: companyCodeController,
                                  textCapitalization:
                                  TextCapitalization.characters,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    letterSpacing: 2.0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Company Code',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary.withOpacity(0.55),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                      fontSize: 15,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      color: AppColors.primary.withOpacity(0.5),
                                      size: 22,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.divider, width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.divider, width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary, width: 2),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.error, width: 1.5),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.error, width: 2),
                                    ),
                                    errorText: errorMessage,
                                    errorStyle: const TextStyle(
                                        color: AppColors.error, fontSize: 12),
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 20),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a company code';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 52),

                              // ── Continue Button — navy with gold shadow ──
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: (isButtonDisabled || isOffline)
                                      ? null
                                      : _validateCompanyCode,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOffline
                                        ? const Color(0xFFCBD5E1)
                                        : AppColors.primary,
                                    foregroundColor: isOffline
                                        ? AppColors.textSecondary
                                        : Colors.white,
                                    disabledBackgroundColor:
                                    const Color(0xFFCBD5E1),
                                    elevation: isOffline ? 0 : 6,
                                    shadowColor: AppColors.cyan.withOpacity(0.40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                      : Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isOffline ? 'Offline' : 'Continue',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      if (!isOffline) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Footer ───────────────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      size: 13,
                                      color: AppColors.textSecondary.withOpacity(0.6)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Secured & Encrypted Connection',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Offline Banner ─────────────────────────────────────────────
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
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
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
      ),
    );
  }
}