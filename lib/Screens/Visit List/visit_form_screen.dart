
import 'package:book_dispatch/Screens/Visit%20List/settings_view_model.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_constants.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_model.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../AppColors.dart';
import 'customer_model.dart';
import 'customer_view_model.dart';
import 'followup_view_model.dart';

class VisitFormScreen extends StatefulWidget {
  final VisitModel? editing;
  const VisitFormScreen({super.key, this.editing});

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final VisitViewModel vm =
  Get.isRegistered<VisitViewModel>() ? Get.find<VisitViewModel>() : Get.put(VisitViewModel());
  final CustomerViewModel customerVm =
  Get.isRegistered<CustomerViewModel>() ? Get.find<CustomerViewModel>() : Get.put(CustomerViewModel());
  late final FollowupViewModel fuVm =
  Get.isRegistered<FollowupViewModel>() ? Get.find<FollowupViewModel>() : Get.put(FollowupViewModel());

  late final SettingsViewModel settingsVm =
  Get.isRegistered<SettingsViewModel>() ? Get.find<SettingsViewModel>() : Get.put(SettingsViewModel());

  // ✅ draft nullable rakhein taake build se pehle check kar sakein
  VisitModel? draft;
  bool get isNew => widget.editing == null;

  // Controllers
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _cnic = TextEditingController();
  final _address = TextEditingController();
  final _location = TextEditingController();
  final _propSize = TextEditingController();
  final _budgetFrom = TextEditingController();
  final _budgetTo = TextEditingController();
  final _outcome = TextEditingController();
  final _remarks = TextEditingController();

  // Selected customer
  CustomerModel? _selectedCustomer;
  String _selectedCustomerId = '';

  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();
  DateTime? _fuDate;
  TimeOfDay? _fuTime;

  String visitType = '';
  String project = '';
  String propType = '';
  String timeline = '';
  String response = '';
  String interest = '';
  String nextAction = '';

  Map<String, dynamic>? gpsResult;
  String? photoBase64;
  String? photoFileName;
  bool isSaving = false;

  final Map<String, String?> _errors = {};

  bool _isInitialized = false; // ✅ Flag to track initialization

  @override
  void initState() {
    super.initState();
    _initDraft();
  }

  Future<void> _initDraft() async {
    // ✅ Build draft first
    draft = await vm.buildDraft(editing: widget.editing);
    _hydrate();

    // ✅ Fetch settings after draft is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      settingsVm.fetchSettings();
    });

    // ✅ Mark as initialized and rebuild
    _isInitialized = true;
    if (mounted) setState(() {});
  }

  void _hydrate() {
    if (draft == null) return;

    if (draft!.customerId.isNotEmpty) {
      _selectedCustomer = customerVm.findById(draft!.customerId);
      _selectedCustomerId = draft!.customerId;
      if (_selectedCustomer != null) {
        _mobile.text = _selectedCustomer!.mobile;
        _email.text = _selectedCustomer!.email;
        _cnic.text = _selectedCustomer!.cnic;
        _address.text = _selectedCustomer!.address;
      }
    } else if (draft!.customer.isNotEmpty) {
      final found = customerVm.customers.firstWhereOrNull(
              (c) => c.name == draft!.customer || c.mobile == draft!.mobile
      );
      if (found != null) {
        _selectedCustomer = found;
        _selectedCustomerId = found.id;
        _mobile.text = found.mobile;
        _email.text = found.email;
        _cnic.text = found.cnic;
        _address.text = found.address;
      }
    }

    _mobile.text = draft!.mobile;
    _email.text = draft!.email;
    _cnic.text = draft!.cnic;
    _address.text = draft!.address;
    _location.text = draft!.location;
    _propSize.text = draft!.propSize;
    _budgetFrom.text = draft!.budgetFrom > 0 ? draft!.budgetFrom.toStringAsFixed(0) : '';
    _budgetTo.text = draft!.budgetTo > 0 ? draft!.budgetTo.toStringAsFixed(0) : '';
    _outcome.text = draft!.outcome;
    _remarks.text = draft!.remarks;

    visitType = draft!.visitType;
    project = draft!.project;
    propType = draft!.propType;
    timeline = draft!.timeline;
    response = draft!.response;
    interest = draft!.interest;
    nextAction = draft!.nextAction;

    if (draft!.date.isNotEmpty) {
      _visitDate = DateTime.tryParse(draft!.date) ?? DateTime.now();
    }
    if (draft!.time.contains(':')) {
      final parts = draft!.time.split(':');
      _visitTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    }
    if (draft!.fuDate.isNotEmpty) _fuDate = DateTime.tryParse(draft!.fuDate);
    if (draft!.fuTime.contains(':')) {
      final parts = draft!.fuTime.split(':');
      _fuTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 11, minute: int.tryParse(parts[1]) ?? 0);
    }

    if (draft!.gpsLat != null) {
      gpsResult = {'lat': draft!.gpsLat, 'lng': draft!.gpsLng, 'acc': draft!.gpsAcc, 'status': draft!.gpsStatus};
    }
    photoBase64 = draft!.photoBase64;
    photoFileName = draft!.photoFileName;
  }

  @override
  void dispose() {
    for (final c in [_mobile, _email, _cnic, _address, _location, _propSize, _budgetFrom, _budgetTo, _outcome, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ✅ Show loading while draft is being initialized
    if (!_isInitialized || draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.tealLight,
              ),
              SizedBox(height: 16),
              Text(
                'Loading visit details...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Obx(() {
                final projects = settingsVm.projects.isNotEmpty
                    ? settingsVm.projects
                    : VisitConstants.projects;

                final propTypes = settingsVm.propTypes.isNotEmpty
                    ? settingsVm.propTypes
                    : VisitConstants.propTypes;

                final visitTypes = settingsVm.visitTypes.isNotEmpty
                    ? settingsVm.visitTypes
                    : VisitConstants.visitTypes;

                final timelines = settingsVm.timelines.isNotEmpty
                    ? settingsVm.timelines
                    : VisitConstants.timelines;

                final interestLevels = settingsVm.interestLevels.isNotEmpty
                    ? settingsVm.interestLevels
                    : VisitConstants.interestLevels;

                final responses = settingsVm.responses.isNotEmpty
                    ? settingsVm.responses
                    : VisitConstants.responses;

                final nextActions = settingsVm.nextActions.isNotEmpty
                    ? settingsVm.nextActions
                    : VisitConstants.nextActions;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Visit Information', Icons.info_outline_rounded, AppColors.tealLight),
                    const SizedBox(height: 10),
                    _card([
                      _readOnlyField('VISIT NUMBER', draft!.visitNo, Icons.numbers_rounded, AppColors.tealLight),
                      _cardDivider(),
                      _dateField('VISIT DATE *', _visitDate, Icons.calendar_today_rounded, AppColors.warning, () => _pickDate()),
                      _cardDivider(),
                      _timeField('VISIT TIME *', _visitTime, Icons.access_time_rounded, AppColors.warning, () => _pickTime()),
                      _cardDivider(),
                      _dropdownField('EMPLOYEE *', draft!.empName.isEmpty ? 'Not loaded' : draft!.empName,
                          Icons.badge_rounded, AppColors.tealLight, null, enabled: false),
                      _cardDivider(),
                      _dropdownField('VISIT TYPE', visitType.isEmpty ? 'Select visit type' : visitType,
                          Icons.route_rounded, AppColors.tealLight,
                          visitTypes, onSelect: (v) => setState(() => visitType = v)),
                    ]),

                    const SizedBox(height: 24),
                    _sectionHeader('Customer Information', Icons.person_outline_rounded, AppColors.tealDark),
                    const SizedBox(height: 10),
                    _card([
                      _customerDropdown(),
                      _cardDivider(),
                      _textField('MOBILE NUMBER *', _mobile, Icons.phone_rounded,
                          hint: '03XXXXXXXXX', keyboard: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                          error: _errors['mobile']),
                      _cardDivider(),
                      _textField('EMAIL (OPTIONAL)', _email, Icons.email_rounded,
                          hint: 'name@example.com', keyboard: TextInputType.emailAddress),
                      _cardDivider(),
                      _textField('CNIC (OPTIONAL)', _cnic, Icons.badge_rounded, hint: '34XXX-XXXXXXX-X'),
                      _cardDivider(),
                      _textField('ADDRESS', _address, Icons.location_on_rounded, hint: 'House / street / area, city'),
                    ]),

                    const SizedBox(height: 24),
                    _sectionHeader('Property Interest', Icons.apartment_rounded, AppColors.greenDotDk),
                    const SizedBox(height: 10),
                    _card([
                      _dropdownField('PROJECT *', project.isEmpty ? 'Select project' : project,
                          Icons.location_city_rounded, AppColors.greenDotDk,
                          projects, onSelect: (v) => setState(() => project = v)),
                      _cardDivider(),
                      _dropdownField('PROPERTY TYPE', propType.isEmpty ? 'Select type' : propType,
                          Icons.home_work_rounded, AppColors.greenDotDk,
                          propTypes, onSelect: (v) => setState(() => propType = v)),
                      _cardDivider(),
                      _textField('PREFERRED LOCATION', _location, Icons.pin_drop_rounded, hint: 'Block / phase / area'),
                      _cardDivider(),
                      _textField('PROPERTY SIZE', _propSize, Icons.square_foot_rounded, hint: 'e.g. 10 Marla'),
                      _cardDivider(),
                      _twoCol(
                        _textField('BUDGET FROM (PKR)', _budgetFrom, Icons.attach_money_rounded,
                            hint: '5000000', keyboard: TextInputType.number, compact: true),
                        _textField('BUDGET TO (PKR)', _budgetTo, Icons.attach_money_rounded,
                            hint: '8000000', keyboard: TextInputType.number, compact: true),
                      ),
                      _cardDivider(),
                      _dropdownField('PURCHASE TIMELINE', timeline.isEmpty ? 'Select timeline' : timeline,
                          Icons.schedule_rounded, AppColors.greenDotDk,
                          timelines, onSelect: (v) => setState(() => timeline = v)),
                    ]),

                    const SizedBox(height: 24),
                    _sectionHeader('GPS Information', Icons.location_searching_rounded, AppColors.tealMid),
                    const SizedBox(height: 10),
                    _gpsCard(),

                    const SizedBox(height: 24),
                    _sectionHeader('Visit Outcome', Icons.flag_circle_rounded, AppColors.error),
                    const SizedBox(height: 10),
                    _card([
                      _twoCol(
                        _dropdownField('RESPONSE', response.isEmpty ? 'Select' : response,
                            Icons.chat_bubble_rounded, AppColors.error,
                            responses, onSelect: (v) => setState(() => response = v), compact: true),
                        _dropdownField('INTEREST *', interest.isEmpty ? 'Select' : interest,
                            Icons.local_fire_department_rounded, AppColors.error,
                            interestLevels, onSelect: (v) => setState(() => interest = v), compact: true),
                      ),
                      _cardDivider(),
                      _dropdownField('NEXT ACTION', nextAction.isEmpty ? 'Select action' : nextAction,
                          Icons.arrow_forward_rounded, AppColors.error,
                          nextActions, onSelect: (v) => setState(() => nextAction = v)),
                      _cardDivider(),
                      _textField('VISIT OUTCOME', _outcome, Icons.summarize_rounded, hint: 'Brief summary of how the visit went'),
                      _cardDivider(),
                      _twoCol(
                        _dateField('NEXT FOLLOW-UP DATE', _fuDate, Icons.event_rounded, AppColors.error,
                                () => _pickFuDate(), compact: true),
                        _timeField('NEXT FOLLOW-UP TIME', _fuTime, Icons.access_time_rounded, AppColors.error,
                                () => _pickFuTime(), compact: true),
                      ),
                      _cardDivider(),
                      _textField('REMARKS', _remarks, Icons.notes_rounded, hint: 'Any notes, objections or preferences shared', maxLines: 3),
                    ]),

                    const SizedBox(height: 24),
                    _sectionHeader('Attachment (Optional)', Icons.attach_file_rounded, AppColors.tealDark),
                    const SizedBox(height: 10),
                    _photoPicker(),

                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer Dropdown ────────────────────────────────────────────────
  Widget _customerDropdown() {
    return Obx(() {
      final customers = customerVm.customers;
      final selectedName = _selectedCustomer?.name ?? 'Select customer';

      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.people_rounded, size: 14, color: AppColors.tealDark),
              const SizedBox(width: 6),
              const Text('SELECT CUSTOMER *',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary, letterSpacing: 0.3)),
              const Spacer(),
              if (_selectedCustomer != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => _clearCustomer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ]),
            const SizedBox(height: 6),
            if (customers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No customers found. Add a customer first.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              InkWell(
                onTap: () => _showCustomerPicker(customers),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: _selectedCustomer != null ? AppColors.tealLight : AppColors.divider),
                    borderRadius: BorderRadius.circular(10),
                    color: _selectedCustomer != null ? AppColors.tealSurface : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedCustomer != null ? FontWeight.w700 : FontWeight.w500,
                            color: _selectedCustomer != null ? AppColors.tealDark : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showCustomerPicker(List<CustomerModel> customers) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Customer',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.5)),
                itemBuilder: (context, i) {
                  final c = customers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.iconBgTeal,
                      child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${c.mobile} · ${c.customerNo ?? ''}'),
                    trailing: _selectedCustomerId == c.id
                        ? const Icon(Icons.check_rounded, color: AppColors.tealDark)
                        : null,
                    onTap: () {
                      _selectCustomer(c);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCustomer(CustomerModel c) {
    setState(() {
      _selectedCustomer = c;
      _selectedCustomerId = c.id;
      _mobile.text = c.mobile;
      _email.text = c.email;
      _cnic.text = c.cnic;
      _address.text = c.address;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _selectedCustomerId = '';
      _mobile.text = '';
      _email.text = '';
      _cnic.text = '';
      _address.text = '';
    });
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    if (draft == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Color(0x331A6E59), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.25))),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'New Customer Visit' : 'Edit Customer Visit',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(isNew ? 'Record a planned or completed visit' : draft!.visitNo,
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section / Card Helpers ──────────────────────────────────────────
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

  Widget _twoCol(Widget a, Widget b) {
    return Row(children: [Expanded(child: a), Expanded(child: b)]);
  }

  Widget _readOnlyField(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _textField(String label, TextEditingController controller, IconData icon,
      {String? hint, TextInputType keyboard = TextInputType.text, int maxLines = 1,
        bool compact = false, String? error, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 8 : 12),
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
            maxLines: maxLines,
            inputFormatters: inputFormatters,
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

  Widget _dropdownField(String label, String value, IconData icon, Color color,
      List<String>? options, {ValueChanged<String>? onSelect, bool enabled = true, bool compact = false}) {
    return InkWell(
      onTap: (!enabled || options == null || options.isEmpty) ? null : () => _showPicker(label, options, value, onSelect!),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 8 : 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          if (enabled && options != null && options.isNotEmpty)
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, IconData icon, Color color, VoidCallback onTap, {bool compact = false}) {
    final text = date == null ? 'Select date' : DateFormat('dd MMM, yyyy').format(date);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 8 : 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? time, IconData icon, Color color, VoidCallback onTap, {bool compact = false}) {
    final text = time == null ? 'Select time' : time.format(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 8 : 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showPicker(String title, List<String> options, String current, ValueChanged<String> onSelect) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final selected = o == current;
                  return ListTile(
                    title: Text(o, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? AppColors.tealDark : AppColors.textPrimary)),
                    trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.tealDark) : null,
                    onTap: () {
                      onSelect(o);
                      Navigator.pop(context);
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── GPS ──────────────────────────────────────────────────────────────
  Widget _gpsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _gpsMetric('Latitude', gpsResult?['lat']?.toString() ?? '—'),
            _gpsMetric('Longitude', gpsResult?['lng']?.toString() ?? '—'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _gpsMetric('Accuracy', gpsResult?['acc'] != null ? '${gpsResult!['acc']} m' : '—'),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VERIFICATION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  _gpsStatusBadge(gpsResult?['status']?.toString() ?? 'Not Captured'),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _captureGps,
              icon: const Icon(Icons.satellite_alt_rounded, size: 18, color: Colors.white),
              label: const Text('Capture GPS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tealLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gpsMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _gpsStatusBadge(String status) {
    Color fg = AppColors.textSecondary, bg = AppColors.surface;
    IconData icon = Icons.satellite_alt_rounded;
    if (status == 'Verified') {
      fg = AppColors.greenDotDk;
      bg = AppColors.greenDotLt;
    } else if (status == 'Outside Location') {
      fg = AppColors.warning;
      bg = const Color(0xFFFFF3E0);
      icon = Icons.location_off_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }

  Future<void> _captureGps() async {
    Get.snackbar('Capturing…', 'Getting your current location.',
        snackPosition: SnackPosition.TOP, backgroundColor: AppColors.tealDark, colorText: Colors.white);
    final result = await vm.captureGps();
    if (result != null) {
      setState(() => gpsResult = result);
      Get.snackbar('GPS captured',
          'Location locked at ${result['lat']}, ${result['lng']} (±${result['acc']}m).',
          snackPosition: SnackPosition.TOP,
          backgroundColor: result['status'] == 'Verified' ? AppColors.greenDotDk : AppColors.warning,
          colorText: Colors.white);
    }
  }

  // ── Photo ─────────────────────────────────────────────────────────────
  Widget _photoPicker() {
    if (photoBase64 != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.greenDotLt, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.greenDotDk.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.greenDotDk),
          const SizedBox(width: 10),
          Expanded(child: Text(photoFileName ?? 'Photo attached',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary))),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
            onPressed: () => setState(() {
              photoBase64 = null;
              photoFileName = null;
            }),
          ),
        ]),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final result = await vm.pickPhoto(ImageSource.camera);
        if (result != null) {
          setState(() {
            photoBase64 = result['base64'];
            photoFileName = result['name'];
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: Column(children: [
          Icon(Icons.camera_alt_rounded, color: AppColors.textSecondary.withOpacity(0.6), size: 26),
          const SizedBox(height: 8),
          Text('Tap to attach site / customer photo',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.8), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Date / Time Pickers ──────────────────────────────────────────────
  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _visitDate,
        firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _visitDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _visitTime);
    if (t != null) setState(() => _visitTime = t);
  }

  Future<void> _pickFuDate() async {
    final d = await showDatePicker(context: context,
        initialDate: _fuDate ?? DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _fuDate = d);
  }

  Future<void> _pickFuTime() async {
    final t = await showTimePicker(context: context, initialTime: _fuTime ?? TimeOfDay.now());
    if (t != null) setState(() => _fuTime = t);
  }

  // ── Validation / Submit ──────────────────────────────────────────────
  bool _validate() {
    _errors.clear();
    if (_selectedCustomer == null && _mobile.text.trim().isEmpty) {
      _errors['mobile'] = 'Select a customer or enter mobile number';
    }
    final mobileOk = RegExp(r'^03\d{9}$').hasMatch(_mobile.text.trim());
    if (_mobile.text.trim().isNotEmpty && !mobileOk) {
      _errors['mobile'] = 'Enter a valid 11-digit mobile number (03XXXXXXXXX)';
    }
    setState(() {});
    return _errors.isEmpty && project.isNotEmpty && interest.isNotEmpty;
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tealLight,
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
          Text('Save Visit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (draft == null) {
      Get.snackbar('Error', 'Visit data not loaded properly.',
          snackPosition: SnackPosition.TOP, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    if (!_validate()) {
      Get.snackbar('Check the form', 'Some required fields need attention.',
          snackPosition: SnackPosition.TOP, backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => isSaving = true);

    final visitDateStr = DateFormat('yyyy-MM-dd').format(_visitDate);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    String? customerId = _selectedCustomerId;
    if (customerId.isEmpty && _mobile.text.trim().isNotEmpty) {
      final existing = customerVm.customers.firstWhereOrNull(
              (c) => c.mobile == _mobile.text.trim()
      );
      if (existing != null) {
        customerId = existing.id;
        _selectedCustomer = existing;
      } else {
        final newCustomer = CustomerModel(
          id: const Uuid().v4(),
          customerNo: 'CUST-${DateTime.now().year}-${(customerVm.customers.length + 1).toString().padLeft(4, '0')}',
          name: _selectedCustomer?.name ?? _mobile.text.trim(),
          mobile: _mobile.text.trim(),
          email: _email.text.trim(),
          cnic: _cnic.text.trim(),
          address: _address.text.trim(),
        );
        await customerVm.saveCustomer(newCustomer, isNew: true);
        customerId = newCustomer.id;
        _selectedCustomer = newCustomer;
      }
    }

    draft!
      ..customerId = customerId ?? ''
      ..customer = _selectedCustomer?.name ?? _mobile.text.trim()
      ..date = visitDateStr
      ..time = '${_visitTime.hour.toString().padLeft(2, '0')}:${_visitTime.minute.toString().padLeft(2, '0')}'
      ..visitType = visitType
      ..status = isNew ? (visitDateStr.compareTo(today) > 0 ? 'Planned' : 'Completed') : draft!.status
      ..mobile = _mobile.text.trim()
      ..email = _email.text.trim()
      ..cnic = _cnic.text.trim()
      ..address = _address.text.trim()
      ..project = project
      ..propType = propType
      ..location = _location.text.trim()
      ..propSize = _propSize.text.trim()
      ..budgetFrom = double.tryParse(_budgetFrom.text.trim()) ?? 0
      ..budgetTo = double.tryParse(_budgetTo.text.trim()) ?? 0
      ..timeline = timeline
      ..response = response
      ..interest = interest
      ..outcome = _outcome.text.trim()
      ..nextAction = nextAction
      ..fuDate = _fuDate == null ? '' : DateFormat('yyyy-MM-dd').format(_fuDate!)
      ..fuTime = _fuTime == null ? '' : '${_fuTime!.hour.toString().padLeft(2, '0')}:${_fuTime!.minute.toString().padLeft(2, '0')}'
      ..remarks = _remarks.text.trim()
      ..photoBase64 = photoBase64
      ..photoFileName = photoFileName
      ..hasSignature = draft!.hasSignature;

    if (gpsResult != null) {
      draft!
        ..gpsStatus = gpsResult!['status']
        ..gpsLat = (gpsResult!['lat'] as num).toDouble()
        ..gpsLng = (gpsResult!['lng'] as num).toDouble()
        ..gpsAcc = (gpsResult!['acc'] as num).toDouble();
    }

    // ✅ Check if this is an existing server visit (posted == true)
    final isExistingServerVisit = draft!.posted && draft!.dbVisitId != null && draft!.dbVisitId!.isNotEmpty;

    bool success = false;

    if (isExistingServerVisit) {
      // ✅ UPDATE existing visit using PUT
      success = await vm.updateVisit(draft!);
      if (success) {
        draft!.posted = true;
        final idx = vm.visits.indexWhere((v) => v.id == draft!.id);
        if (idx != -1) {
          vm.visits[idx] = draft!;
          await vm.persist();
        }
        Get.snackbar(
          'Visit updated',
          '${draft!.visitNo} ✅ Synced to server',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.tealDark,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        // Fallback: save locally
        draft!.posted = false;
        final idx = vm.visits.indexWhere((v) => v.id == draft!.id);
        if (idx != -1) {
          vm.visits[idx] = draft!;
          await vm.persist();
        }
        Get.snackbar(
          'Warning',
          'Visit updated locally but not synced to server.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
      }
    } else {
      // ✅ NEW visit: POST (INSERT)
      await vm.saveVisit(draft!, isNew: isNew);
      success = draft!.posted;
    }

    // ✅ Auto-create follow-up if date is set
    if (draft!.fuDate.isNotEmpty && success) {
      await fuVm.autoCreateFromVisit(draft!);
    }

    setState(() => isSaving = false);

    if (mounted) Navigator.pop(context);
  }
}