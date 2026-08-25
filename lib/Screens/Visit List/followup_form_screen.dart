


import 'package:book_dispatch/Screens/Visit%20List/visit_constants.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_model.dart';
import 'package:book_dispatch/Screens/Visit%20List/visit_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../AppColors.dart';
import 'followup_model.dart';
import 'followup_view_model.dart';


class FollowupFormScreen extends StatefulWidget {
  final FollowupModel? editing;
  final VisitModel? presetVisit;
  const FollowupFormScreen({super.key, this.editing, this.presetVisit});

  @override
  State<FollowupFormScreen> createState() => _FollowupFormScreenState();
}

class _FollowupFormScreenState extends State<FollowupFormScreen> {
  final FollowupViewModel vm =
  Get.isRegistered<FollowupViewModel>() ? Get.find<FollowupViewModel>() : Get.put(FollowupViewModel());
  late final VisitViewModel visitVm =
  Get.isRegistered<VisitViewModel>() ? Get.find<VisitViewModel>() : Get.put(VisitViewModel());

  late FollowupModel draft;
  bool get isNew => widget.editing == null;

  final _clientSearch = TextEditingController();
  final _customer = TextEditingController();
  final _mobile = TextEditingController();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 11, minute: 0);
  String method = FollowupConstants.methods.first;
  String priority = 'Medium';
  String reminder = '1 Hour Before';
  String? linkedVisitNo;
  VisitModel? linkedVisitInfo;

  bool _showClientResults = false;
  List<VisitModel> _clientHits = [];
  final Map<String, String?> _errors = {};
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    draft = vm.buildDraft(editing: widget.editing, presetVisit: widget.presetVisit);
    _hydrate();
  }

  void _hydrate() {
    _customer.text = draft.customer;
    _mobile.text = draft.mobile;
    _purpose.text = draft.purpose;
    _notes.text = draft.notes;
    method = draft.method.isEmpty ? FollowupConstants.methods.first : draft.method;
    priority = draft.priority.isEmpty ? 'Medium' : draft.priority;
    reminder = draft.reminder.isEmpty ? '1 Hour Before' : draft.reminder;
    linkedVisitNo = draft.visitNo;

    if (draft.date.isNotEmpty) _date = DateTime.tryParse(draft.date) ?? _date;
    if (draft.time.contains(':')) {
      final parts = draft.time.split(':');
      _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 11, minute: int.tryParse(parts[1]) ?? 0);
    }

    if (linkedVisitNo != null && linkedVisitNo!.isNotEmpty) {
      linkedVisitInfo = visitVm.visits.firstWhereOrNull((v) => v.visitNo == linkedVisitNo);
    }
  }

  @override
  void dispose() {
    _clientSearch.dispose();
    _customer.dispose();
    _mobile.dispose();
    _purpose.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNew) ...[
                    _sectionHeader('Select Client from Visits', Icons.search_rounded, AppColors.tealLight),
                    const SizedBox(height: 10),
                    _clientPicker(),
                    const SizedBox(height: 24),
                  ],

                  _sectionHeader('Follow-up Details', Icons.notifications_active_outlined, AppColors.warning),
                  const SizedBox(height: 10),
                  _card([
                    _readOnlyField('FOLLOW-UP NUMBER', draft.fuNo, Icons.numbers_rounded, AppColors.warning),
                    _cardDivider(),
                    _textField('CUSTOMER / LEAD NAME *', _customer, Icons.person_rounded, error: _errors['customer']),
                    _cardDivider(),
                    _textField('MOBILE NUMBER *', _mobile, Icons.phone_rounded, hint: '03XX-XXXXXXX', keyboard: TextInputType.phone, error: _errors['mobile']),
                    _cardDivider(),
                    _readOnlyField('ASSIGNED EMPLOYEE *', draft.empName.isEmpty ? 'Not loaded — please re-login' : draft.empName, Icons.badge_rounded, AppColors.warning),
                    if (linkedVisitInfo != null) ...[
                      _cardDivider(),
                      _readOnlyField('LINKED VISIT', '${linkedVisitInfo!.visitNo} — ${linkedVisitInfo!.customer}', Icons.link_rounded, AppColors.tealDark),
                    ],
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader('Schedule', Icons.event_rounded, AppColors.tealDark),
                  const SizedBox(height: 10),
                  _card([
                    _twoCol(
                      _dateField('DATE *', _date, () => _pickDate()),
                      _timeField('TIME *', _time, () => _pickTime()),
                    ),
                    _cardDivider(),
                    _dropdownField('METHOD *', method, Icons.chat_bubble_rounded, AppColors.tealDark, FollowupConstants.methods, (v) => setState(() => method = v)),
                    _cardDivider(),
                    _twoCol(
                      _dropdownField('PRIORITY', priority, Icons.flag_rounded, AppColors.tealDark, FollowupConstants.priorities, (v) => setState(() => priority = v), compact: true),
                      _dropdownField('REMINDER', reminder, Icons.alarm_rounded, AppColors.tealDark, FollowupConstants.reminders, (v) => setState(() => reminder = v), compact: true),
                    ),
                  ]),

                  const SizedBox(height: 24),
                  _sectionHeader('Notes', Icons.notes_rounded, AppColors.error),
                  const SizedBox(height: 10),
                  _card([
                    _textField('PURPOSE *', _purpose, Icons.flag_circle_rounded, hint: 'e.g. Share payment plan', error: _errors['purpose']),
                    _cardDivider(),
                    _textField('NOTES', _notes, Icons.notes_rounded, maxLines: 3),
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

  // ====================== HEADER ======================
  Widget _buildHeader() {
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
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.25))),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNew ? 'Schedule Follow-up' : 'Edit Follow-up', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(isNew ? 'Never let a customer go cold' : draft.fuNo, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== CLIENT PICKER ======================
  Widget _clientPicker() {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _clientSearch,
            onChanged: (q) => _searchClients(q),
            onTap: () => _searchClients(_clientSearch.text),
            decoration: InputDecoration(
              hintText: 'Search client by name, mobile or visit number…',
              hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textSecondary.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.tealLight, width: 1.5)),
            ),
          ),
          if (_showClientResults) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _clientHits.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No matching client${_clientSearch.text.isNotEmpty ? ' for "${_clientSearch.text}"' : ''}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8))),
              )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: _clientHits.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final v = _clientHits[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.iconBgTeal,
                      child: Text((v.customer.isNotEmpty ? v.customer[0] : '?').toUpperCase(), style: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(v.customer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('${v.mobile} · ${v.visitNo}', style: const TextStyle(fontSize: 11)),
                    onTap: () => _pickClient(v),
                  );
                },
              ),
            ),
          ],
          if (linkedVisitInfo != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.tealSurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.link_rounded, size: 15, color: AppColors.tealDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Linked to visit ${linkedVisitInfo!.visitNo} (${linkedVisitInfo!.project}) — fields auto-filled, still editable.',
                    style: const TextStyle(fontSize: 11, color: AppColors.tealDark, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  void _searchClients(String q) {
    final query = q.toLowerCase().trim();
    final seen = <String>{};
    final hits = visitVm.visits.where((v) {
      if (seen.contains(v.mobile)) return false;
      if (query.isNotEmpty && !('${v.customer} ${v.mobile} ${v.visitNo}').toLowerCase().contains(query)) return false;
      seen.add(v.mobile);
      return true;
    }).take(8).toList();
    setState(() {
      _clientHits = hits;
      _showClientResults = true;
    });
  }

  void _pickClient(VisitModel v) {
    setState(() {
      _clientSearch.text = '${v.customer} — ${v.visitNo}';
      _showClientResults = false;
      _customer.text = v.customer;
      _mobile.text = v.mobile;
      linkedVisitNo = v.visitNo;
      linkedVisitInfo = v;
      if (_purpose.text.isEmpty) _purpose.text = 'Follow-up visit — ${v.project}';
      if (v.visitType == 'Site Visit') method = 'Site Visit';
    });
    Get.snackbar('Client selected', '${v.customer} — details filled from ${v.visitNo}',
        snackPosition: SnackPosition.TOP, backgroundColor: AppColors.tealDark, colorText: Colors.white);
  }

  // ====================== SECTION / CARD HELPERS ======================
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

  Widget _twoCol(Widget a, Widget b) => Row(children: [Expanded(child: a), Expanded(child: b)]);

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
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _textField(String label, TextEditingController controller, IconData icon,
      {String? hint, TextInputType keyboard = TextInputType.text, int maxLines = 1, String? error}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: AppColors.textSecondary.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
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

  Widget _dropdownField(String label, String value, IconData icon, Color color, List<String> options, ValueChanged<String> onSelect, {bool compact = false}) {
    return InkWell(
      onTap: () => _showPicker(label, options, value, onSelect),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 14, compact ? 8 : 12),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(DateFormat('dd MMM, yyyy').format(date), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          const Icon(Icons.access_time_rounded, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary.withOpacity(0.7), letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(time.format(context), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showPicker(String title, List<String> options, String current, ValueChanged<String> onSelect) {
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4))),
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final selected = o == current;
                  return ListTile(
                    title: Text(o, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? AppColors.tealDark : AppColors.textPrimary)),
                    trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.tealDark) : null,
                    onTap: () {
                      onSelect(o);
                      Navigator.pop(context);
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

  // ====================== DATE / TIME PICKERS ======================
  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  // ====================== VALIDATE / SUBMIT ======================
  bool _validate() {
    _errors.clear();
    if (_customer.text.trim().isEmpty) _errors['customer'] = 'Customer name required';
    final mobileOk = RegExp(r'^03\d{2}-?\d{7}$').hasMatch(_mobile.text.trim());
    if (_mobile.text.trim().isEmpty || !mobileOk) _errors['mobile'] = 'Valid mobile required';
    if (_purpose.text.trim().isEmpty) _errors['purpose'] = 'Purpose required';
    setState(() {});
    return _errors.isEmpty;
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
          Text('Save Follow-up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

    // ✅ If linkedVisitInfo exists, use its ID, otherwise leave visitId as null
    // The API will handle null visitId (for standalone follow-ups)

    draft
      ..customer = _customer.text.trim()
      ..mobile = _mobile.text.trim()
      ..empId = draft.empId.isEmpty ? vm.empId.value : draft.empId
      ..empName = draft.empName.isEmpty ? vm.empName.value : draft.empName
      ..visitNo = linkedVisitNo
      ..visitId = linkedVisitInfo?.id ?? draft.visitId  // ✅ Store visit ID if linked
      ..date = DateFormat('yyyy-MM-dd').format(_date)
      ..time = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'
      ..method = method
      ..priority = priority
      ..reminder = reminder
      ..purpose = _purpose.text.trim()
      ..notes = _notes.text.trim();

    await vm.saveFollowup(draft, isNew: isNew);

    setState(() => isSaving = false);

    Get.snackbar(
      isNew ? 'Follow-up scheduled' : 'Follow-up updated',
      draft.posted
          ? '${draft.fuNo} ✅ Synced to server · ${DateFormat('dd MMM').format(_date)}'
          : '${draft.fuNo} ⏳ Saved locally (will sync when online)',
      snackPosition: SnackPosition.TOP,
      backgroundColor: draft.posted ? AppColors.tealDark : AppColors.warning,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );

    if (mounted) Navigator.pop(context);
  }
}