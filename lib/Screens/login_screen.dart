import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Services/biometric_service.dart';
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
  final TextEditingController _userIdController    = TextEditingController();
  final TextEditingController _passwordController  = TextEditingController();
  final LoginViewModel loginViewModel              = Get.find<LoginViewModel>();

  final _formKey = GlobalKey<FormState>();

  bool isChecked           = false;
  bool isPasswordVisible   = false;
  bool isLoading           = false;

  // ── Biometric state ───────────────────────────────────────────────────────
  bool _biometricEnabled    = false;
  bool _isBiometricLoading  = false;

  /// Resolved once in [_loadBiometricState]; drives icon & label.
  BiometricModality _modality = BiometricModality.none;
  // ─────────────────────────────────────────────────────────────────────────

  String companyCode = '';

  late AnimationController _animationController;
  late Animation<double>   _fadeAnimation;
  late Animation<Offset>   _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
    _loadSavedCredentials();
    _loadBiometricState();

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

  // ── Existing helpers ──────────────────────────────────────────────────────

  Future<void> _loadCompanyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyCode = prefs.getString(prefCompanyCode) ?? '';
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs    = await SharedPreferences.getInstance();
    final remember = prefs.getBool(prefRememberMe) ?? false;
    setState(() => isChecked = remember);

    if (remember) {
      final savedUserId = prefs.getString(prefSavedUserId);
      if (savedUserId != null) _userIdController.text = savedUserId;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (companyCode.isEmpty) {
      _showSnackbar(
        title:   'Error',
        message: 'Company not verified. Please go back and enter company code.',
        isError: true,
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

        _showSnackbar(
          title:   'Welcome Back!',
          message: 'Login successful',
          isError: false,
        );

        final route = loginViewModel.getHomeRoute();
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Get.offAllNamed(route);
      } else {
        _showSnackbar(
          title:   'Login Failed',
          message: loginViewModel.loginError.value,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackbar({
    required String title,
    required String message,
    required bool isError,
  }) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    Get.snackbar(
      title,
      message,
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      colorText:       Colors.white,
      snackPosition:   SnackPosition.TOP,
      duration:        const Duration(seconds: 4),
      margin:          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius:    12,
      icon: Icon(
        isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: Colors.white,
        size:  24,
      ),
    );
  }

  // ── Biometric helpers ─────────────────────────────────────────────────────

  /// Reads the persisted biometric flag, detects face vs fingerprint, and
  /// schedules an auto-prompt after the entrance animation finishes.
  Future<void> _loadBiometricState() async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(prefBiometricEnabled) ?? false;

    // Detect face vs fingerprint so we can show the right icon & label
    final modality = await BiometricService.getPrimaryModality();

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _modality         = modality;
      });
    }

    if (enabled) {
      // Wait for the entrance animation before prompting the OS sheet
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) await _loginWithBiometric();
      });
    }
  }

  /// Triggers the biometric prompt (face or fingerprint) and navigates home
  /// on success.
  Future<void> _loginWithBiometric() async {
    if (_isBiometricLoading) return;
    setState(() => _isBiometricLoading = true);

    try {
      final success = await loginViewModel.loginWithBiometric();

      if (success) {
        _showSnackbar(
          title:   'Welcome Back!',
          message: '${loginViewModel.biometricLabel} login successful',
          isError: false,
        );
        final route = loginViewModel.getHomeRoute();
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Get.offAllNamed(route);
      } else if (loginViewModel.loginError.value.isNotEmpty) {
        _showSnackbar(
          title:   'Authentication Failed',
          message: loginViewModel.loginError.value,
          isError: true,
        );
        // If credentials were wiped by the VM, refresh our local flag
        final prefs       = await SharedPreferences.getInstance();
        final stillEnabled = prefs.getBool(prefBiometricEnabled) ?? false;
        if (mounted) setState(() => _biometricEnabled = stillEnabled);
      }
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  // ── Adaptive icon & label helpers ─────────────────────────────────────────

  /// Returns the correct icon for the active biometric modality.
  IconData get _biometricIcon {
    switch (_modality) {
      case BiometricModality.face:
        return Icons.face_unlock_rounded;       // face icon
      case BiometricModality.fingerprint:
      case BiometricModality.none:
        return Icons.fingerprint_rounded;
    }
  }

  /// Returns "Sign In with Face ID" or "Sign In with Fingerprint".
  String get _biometricButtonLabel {
    switch (_modality) {
      case BiometricModality.face:
        return 'Sign In with Face ID';
      case BiometricModality.fingerprint:
      case BiometricModality.none:
        return 'Sign In with Fingerprint';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size          = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 680;
    final isTablet      = size.width > 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.greenTeal],
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
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
              opacity:  _fadeAnimation,
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

  // ── Phone Layout ──────────────────────────────────────────────────────────
  Widget _buildPhoneLayout(bool isSmallScreen) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(32, isSmallScreen ? 20 : 40, 65, 20),
          child: _buildHeader(isSmallScreen),
        ),
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
              padding: EdgeInsets.fromLTRB(28, isSmallScreen ? 24 : 32, 28, 32),
              child: _buildForm(isSmallScreen),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tablet Layout ─────────────────────────────────────────────────────────
  Widget _buildTabletLayout(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: _buildHeader(isSmallScreen),
          ),
        ),
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
                    color:      Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset:     const Offset(0, 10),
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

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.22),
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
                  fontSize:      11,
                  fontWeight:    FontWeight.w700,
                  color:         Colors.white,
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
            fontSize:      isSmallScreen ? 32 : 40,
            fontWeight:    FontWeight.w800,
            color:         Colors.white,
            height:        1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to continue to your dashboard',
          style: TextStyle(
            fontSize: 14.5,
            color:    Colors.white.withOpacity(0.82),
          ),
        ),
      ],
    );
  }

  // ── Main Form ─────────────────────────────────────────────────────────────
  Widget _buildForm(bool isSmallScreen) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign In',
            style: TextStyle(
              fontSize:   isSmallScreen ? 21 : 24,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your credentials to continue',
            style: TextStyle(
              fontSize: 13.5,
              color:    AppColors.textSecondary.withOpacity(0.85),
            ),
          ),

          const SizedBox(height: 32),

          // Employee ID
          _buildLabel('EMPLOYEE ID'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _userIdController,
            hint:       'Enter employee ID',
            icon:       Icons.person_outline_rounded,
            validator:  (v) =>
            (v == null || v.trim().isEmpty) ? 'Employee ID is required' : null,
          ),

          const SizedBox(height: 24),

          // Password
          _buildLabel('PASSWORD'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hint:       'Enter password',
            icon:       Icons.lock_outline_rounded,
            obscure:    !isPasswordVisible,
            suffix: IconButton(
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () =>
                  setState(() => isPasswordVisible = !isPasswordVisible),
            ),
            validator: (v) =>
            (v == null || v.isEmpty) ? 'Password is required' : null,
          ),

          const SizedBox(height: 16),

          // Remember Me
          Row(
            children: [
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value:       isChecked,
                  onChanged:   (val) => setState(() => isChecked = val ?? false),
                  activeColor: AppColors.cyan,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
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
                gradient:     AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.cyan.withOpacity(0.45),
                    blurRadius: 20,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize:      16.5,
                        fontWeight:    FontWeight.w700,
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

          // ── Biometric login button (face or fingerprint) ──────────────────
          if (_biometricEnabled) ...[
            const SizedBox(height: 20),
            _buildBiometricButton(isSmallScreen),
          ],
          // ─────────────────────────────────────────────────────────────────

          const SizedBox(height: 20),

          // Switch Company
          Center(
            child: TextButton(
              onPressed: () => Get.offAllNamed(routeCodeScreen),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.switch_account_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Switch to different company?',
                    style: TextStyle(
                      fontSize:   13,
                      color:      AppColors.textSecondary,
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
                    size: 14,
                    color: AppColors.textSecondary.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  'Secured & Encrypted Connection',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:    AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Biometric button widget ───────────────────────────────────────────────
  //  Automatically shows a face icon for Face ID devices and a fingerprint
  //  icon for everything else — no manual configuration required.

  Widget _buildBiometricButton(bool isSmallScreen) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: TextStyle(
                  fontSize:   12.5,
                  color:      AppColors.textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width:  double.infinity,
          height: isSmallScreen ? 52 : 56,
          child: OutlinedButton(
            onPressed: _isBiometricLoading ? null : _loginWithBiometric,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.cyan, width: 1.8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              foregroundColor: AppColors.cyan,
            ),
            child: _isBiometricLoading
                ? SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: AppColors.cyan, strokeWidth: 2.5),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Adaptive icon: face or fingerprint ────────────────
                Icon(_biometricIcon, size: 26, color: AppColors.cyan),
                const SizedBox(width: 10),
                // ── Adaptive label ────────────────────────────────────
                Text(
                  _biometricButtonLabel,
                  style: TextStyle(
                    fontSize:      15,
                    fontWeight:    FontWeight.w600,
                    color:         AppColors.cyan,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize:      10,
      fontWeight:    FontWeight.w700,
      color:         AppColors.textSecondary.withOpacity(0.85),
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
      controller:  controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
          color:    AppColors.textSecondary.withOpacity(0.5),
          fontSize: 14.5,
        ),
        filled:      true,
        fillColor:   const Color(0xFFF8FAFB),
        prefixIcon:  Icon(icon, color: AppColors.cyan, size: 22),
        suffixIcon:  suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.divider, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.cyan, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: AppColors.error, width: 1.6),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      validator: validator,
    );
  }
}