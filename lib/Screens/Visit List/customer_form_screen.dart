// lib/Screens/Customers/customer_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../AppColors.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';
import 'customer_model.dart';
import 'customer_view_model.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CustomerViewModel vm =
  Get.isRegistered<CustomerViewModel>() ? Get.find<CustomerViewModel>() : Get.put(CustomerViewModel());
  late CustomerModel draft;

  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _altMobile = TextEditingController();
  final _city = TextEditingController();
  final _remarks = TextEditingController();

  bool isSaving = false;
  final Map<String, String?> _errors = {};

  bool get _isFormValid {
    final mobileOk = RegExp(r'^03\d{9}$').hasMatch(_mobile.text.trim());
    return _name.text.trim().isNotEmpty && mobileOk;
  }

  @override
  void initState() {
    super.initState();
    draft = vm.buildDraft();
    for (final c in [_name, _mobile, _email, _address, _altMobile, _city, _remarks]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _email, _address, _altMobile, _city, _remarks]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Obx(() => Navbar(
          userName: vm.empName.value.isEmpty ? 'Employee' : vm.empName.value,
          userInitials: vm.initials,
          scaffoldKey: _scaffoldKey,
        )),
      ),
      drawer: AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Customer',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Add a new customer to your CRM',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),

                  _sectionHeader('Customer Information', Icons.person_outline_rounded, AppColors.tealLight),
                  const SizedBox(height: 10),
                  _card([
                    _textField('CUSTOMER NAME *', _name, Icons.person_rounded, hint: 'e.g. Muhammad Asif', error: _errors['name']),
                    _cardDivider(),
                    _textField('MOBILE NUMBER *', _mobile, Icons.phone_rounded,
                        hint: '03XXXXXXXXX', keyboard: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                        error: _errors['mobile']),
                    _cardDivider(),
                    _textField('ALTERNATE MOBILE', _altMobile, Icons.phone_rounded,
                        hint: '03XXXXXXXXX', keyboard: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]),
                    _cardDivider(),
                    _textField('EMAIL', _email, Icons.email_rounded,
                        hint: 'name@example.com', keyboard: TextInputType.emailAddress),
                    _cardDivider(),
                    _textField('ADDRESS', _address, Icons.location_on_rounded, hint: 'House / street / area, city'),
                    _cardDivider(),
                    _textField('CITY', _city, Icons.location_city_rounded, hint: 'e.g. Lahore, Karachi'),
                    _cardDivider(),
                    _textField('REMARKS', _remarks, Icons.notes_rounded, hint: 'Any additional notes', maxLines: 3),
                  ]),

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

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    ]);
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
      child: Column(children: children),
    );
  }

  Widget _cardDivider() => Divider(height: 1, thickness: 1, color: AppColors.divider.withOpacity(0.5));

  Widget _textField(String label, TextEditingController controller, IconData icon,
      {String? hint, TextInputType keyboard = TextInputType.text, String? error,
        List<TextInputFormatter>? inputFormatters, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: const UnderlineInputBorder(borderSide: BorderSide.none),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide.none),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
                const SizedBox(width: 4),
                Text(error, style: const TextStyle(fontSize: 10.5, color: AppColors.error, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }

  bool _validate() {
    _errors.clear();
    if (_name.text.trim().isEmpty) _errors['name'] = 'Customer name is required';
    final mobileOk = RegExp(r'^03\d{9}$').hasMatch(_mobile.text.trim());
    if (_mobile.text.trim().isEmpty || !mobileOk) {
      _errors['mobile'] = 'Enter a valid 11-digit mobile number (03XXXXXXXXX)';
    }
    setState(() {});
    return _errors.isEmpty;
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (isSaving || !_isFormValid) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid ? AppColors.tealLight : AppColors.divider,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
        child: isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          Icon(Icons.save_rounded, size: 18, color: Colors.white),
          SizedBox(width: 8),
          Text('Save Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validate()) {
      Get.snackbar('Check the form', 'Some required fields need attention.',
          snackPosition: SnackPosition.TOP, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => isSaving = true);

    draft
      ..name = _name.text.trim()
      ..mobile = _mobile.text.trim()
      ..email = _email.text.trim()
      ..address = _address.text.trim()
      ..altMobile = _altMobile.text.trim()
      ..city = _city.text.trim()
      ..remarks = _remarks.text.trim();  // ✅ Only what user types

    await vm.saveCustomer(draft, isNew: true);

    setState(() => isSaving = false);

    Get.snackbar(
      'Customer saved',
      draft.name,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.tealDark,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    if (mounted) Navigator.pop(context);
  }
}