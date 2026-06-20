// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/leave_view_model.dart';
//
// class LeaveScreen extends StatelessWidget {
//   LeaveScreen({super.key});
//
//   final LeaveViewModel vm = Get.put(LeaveViewModel());
//
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: Column(
//         children: [
//           _buildHeader(),
//           Expanded(
//             child: SingleChildScrollView(
//               physics: const BouncingScrollPhysics(),
//               padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Employee Information
//                   _sectionHeader('Employee Information', Icons.person_outline_rounded, AppColors.cyan),
//                   const SizedBox(height: 10),
//                   _card([
//                     _readOnlyField('EMPLOYEE NAME', vm.empName, Icons.person_rounded, AppColors.skyBlue),
//                     _cardDivider(),
//                     _readOnlyField('EMPLOYEE ID', vm.empId, Icons.badge_rounded, AppColors.skyBlue),
//                   ]),
//
//                   const SizedBox(height: 24),
//
//                   // Leave Type
//                   _sectionHeader('Leave Type', Icons.event_note_outlined, AppColors.skyBlueDk),
//                   const SizedBox(height: 10),
//                   _card([_buildLeaveTypeDropdown()]),
//
//                   const SizedBox(height: 24),
//
//                   // Leave Duration
//                   _sectionHeader('Leave Duration', Icons.access_time_rounded, AppColors.warning),
//                   const SizedBox(height: 10),
//                   _card([
//                     _buildDateField(
//                       label: 'START DATE',
//                       icon: Icons.calendar_today_rounded,
//                       iconColor: AppColors.warning,
//                       dateObs: vm.startDate,
//                       onTap: () => _selectDate(context, isStart: true),
//                     ),
//                     _cardDivider(),
//                     _buildDateField(
//                       label: 'END DATE',
//                       icon: Icons.event_rounded,
//                       iconColor: AppColors.warning,
//                       dateObs: vm.endDate,
//                       onTap: () => _selectDate(context, isStart: false),
//                     ),
//                     Obx(() {
//                       final days = vm.totalDays.value;
//                       if (days <= 0) return const SizedBox.shrink();
//                       return Padding(
//                         padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
//                           decoration: BoxDecoration(
//                             color: AppColors.greenTeal.withOpacity(0.12),
//                             borderRadius: BorderRadius.circular(12),
//                             border: Border.all(color: AppColors.greenTeal.withOpacity(0.3)),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.schedule_rounded, size: 16, color: AppColors.greenTeal),
//                               const SizedBox(width: 8),
//                               Text(
//                                 '$days ${days == 1 ? 'day' : 'days'} selected',
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w600,
//                                   color: AppColors.greenTeal,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }),
//                   ]),
//
//                   const SizedBox(height: 24),
//
//                   // ── Half Day ─────────────────────────────────────────────
//                   _sectionHeader('Half Day Option', Icons.timelapse_rounded, AppColors.greenTeal),
//                   const SizedBox(height: 10),
//                   // Wrap the whole card in Obx so it rebuilds when isHalfDay changes
//                   Obx(() {
//                     final children = <Widget>[_buildHalfDayDropdown()];
//
//                     // ── NEW: show time pickers only when half day = Yes ────
//                     if (vm.isHalfDay.value) {
//                       children.addAll([
//                         _cardDivider(),
//                         _buildTimeField(
//                           context: context,
//                           label: 'START TIME',
//                           icon: Icons.access_time_rounded,
//                           iconColor: AppColors.greenTeal,
//                           timeObs: vm.halfDayStartTime,
//                           onTap: () => _selectTime(context, isStart: true),
//                         ),
//                         _cardDivider(),
//                         _buildTimeField(
//                           context: context,
//                           label: 'END TIME',
//                           icon: Icons.timelapse_rounded,
//                           iconColor: AppColors.greenTeal,
//                           timeObs: vm.halfDayEndTime,
//                           onTap: () => _selectTime(context, isStart: false),
//                         ),
//                       ]);
//                     }
//
//                     return _card(children);
//                   }),
//
//                   const SizedBox(height: 24),
//
//                   // Reason
//                   _sectionHeader('Reason for Leave', Icons.notes_rounded, AppColors.error),
//                   const SizedBox(height: 10),
//                   _card([_buildReasonField()]),
//
//                   const SizedBox(height: 24),
//
//                   // Attachment
//                   _sectionHeader('Attachment (Optional)', Icons.attach_file_rounded, AppColors.skyBlueDk),
//                   const SizedBox(height: 6),
//                   Text(
//                     'Medical certificate or any supporting document',
//                     style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.85)),
//                   ),
//                   const SizedBox(height: 14),
//                   Obx(() => vm.attachmentBytes.value != null
//                       ? _buildAttachmentPreview()
//                       : _buildAttachmentPicker()),
//
//                   const SizedBox(height: 40),
//
//                   // Submit Button
//                   _buildSubmitButton(),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ====================== HEADER ======================
//   Widget _buildHeader() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
//         boxShadow: [
//           BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
//         ],
//       ),
//       child: Stack(
//         children: [
//           Positioned(top: -40, right: -30, child: _decorCircle(160, 0.08)),
//           Positioned(bottom: -40, left: -20, child: _decorCircle(110, 0.06)),
//           SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 44,
//                       height: 44,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.18),
//                         borderRadius: BorderRadius.circular(14),
//                         border: Border.all(color: Colors.white.withOpacity(0.25)),
//                       ),
//                       child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
//                     ),
//                   ),
//                   const SizedBox(width: 16),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Leave Application',
//                           style: TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.w800,
//                             color: Colors.white,
//                             letterSpacing: 0.3,
//                           ),
//                         ),
//                         Obx(() => Text(
//                           vm.selectedLeaveType.value.isEmpty
//                               ? 'Apply for leave'
//                               : vm.selectedLeaveType.value,
//                           style: TextStyle(
//                             fontSize: 13.5,
//                             color: Colors.white.withOpacity(0.75),
//                           ),
//                         )),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ====================== SHARED HELPERS ======================
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(
//       children: [
//         Container(width: 5, height: 22, decoration: BoxDecoration(color: AppColors.greenTeal, borderRadius: BorderRadius.circular(3))),
//         const SizedBox(width: 10),
//         Container(
//           padding: const EdgeInsets.all(7),
//           decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
//           child: Icon(icon, size: 17, color: color),
//         ),
//         const SizedBox(width: 12),
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 15,
//             fontWeight: FontWeight.w700,
//             color: AppColors.textPrimary,
//             letterSpacing: 0.2,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _card(List<Widget> children) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
//       ),
//       child: Column(children: children),
//     );
//   }
//
//   Widget _cardDivider() => const Divider(height: 1, thickness: 1, color: AppColors.divider);
//
//   Widget _readOnlyField(String label, RxString valueObs, IconData icon, Color iconColor) {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8)),
//           const SizedBox(height: 4),
//           Row(
//             children: [
//               Icon(icon, size: 16, color: iconColor),
//               const SizedBox(width: 8),
//               Text(
//                 valueObs.value.isEmpty ? '—' : valueObs.value,
//                 style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//         ],
//       ),
//     ));
//   }
//
//   // ====================== DATE PICKER ======================
//   Future<void> _selectDate(BuildContext context, {required bool isStart}) async {
//     final now = DateTime.now();
//     final initial = isStart ? vm.startDate.value ?? now : vm.endDate.value ?? vm.startDate.value ?? now;
//     final firstDate = isStart ? now : (vm.startDate.value ?? now);
//
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: firstDate,
//       lastDate: DateTime(now.year + 2),
//       builder: (context, child) => Theme(
//         data: Theme.of(context).copyWith(
//           colorScheme: ColorScheme.light(
//             primary: AppColors.primary,
//             onPrimary: Colors.white,
//             surface: Colors.white,
//             onSurface: AppColors.textPrimary,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//
//     if (picked != null) {
//       if (isStart) vm.setStartDate(picked);
//       else vm.setEndDate(picked);
//     }
//   }
//
//   Widget _buildDateField({
//     required String label,
//     required IconData icon,
//     required Color iconColor,
//     required Rx<DateTime?> dateObs,
//     required VoidCallback onTap,
//   }) {
//     return Obx(() {
//       final date = dateObs.value;
//       return InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8)),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Icon(icon, size: 16, color: date != null ? iconColor : AppColors.textSecondary),
//                   const SizedBox(width: 8),
//                   Text(
//                     date != null ? DateFormat('EEEE, dd MMM yyyy').format(date) : 'Select date',
//                     style: TextStyle(
//                       fontSize: 14.5,
//                       fontWeight: FontWeight.w600,
//                       color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
//                     ),
//                   ),
//                   const Spacer(),
//                   const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );
//     });
//   }
//
//   // ── NEW: Time Picker ────────────────────────────────────────────────────────
//
//   /// Shows a native time picker; result is passed to the ViewModel.
//   Future<void> _selectTime(BuildContext context, {required bool isStart}) async {
//     final initial = isStart
//         ? (vm.halfDayStartTime.value ?? TimeOfDay.now())
//         : (vm.halfDayEndTime.value   ?? TimeOfDay.now());
//
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: initial,
//       builder: (context, child) => Theme(
//         data: Theme.of(context).copyWith(
//           colorScheme: ColorScheme.light(
//             primary: AppColors.primary,
//             onPrimary: Colors.white,
//             surface: Colors.white,
//             onSurface: AppColors.textPrimary,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//
//     if (picked != null) {
//       if (isStart) vm.setHalfDayStartTime(picked);
//       else         vm.setHalfDayEndTime(picked);
//     }
//   }
//
//   /// Formats TimeOfDay for display: "9:00 AM"
//   String _formatTimeDisplay(TimeOfDay t) {
//     final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
//     final m = t.minute.toString().padLeft(2, '0');
//     final p = t.period == DayPeriod.am ? 'AM' : 'PM';
//     return '$h:$m $p';
//   }
//
//   /// Time field widget — same look & feel as _buildDateField.
//   Widget _buildTimeField({
//     required BuildContext context,
//     required String label,
//     required IconData icon,
//     required Color iconColor,
//     required Rx<TimeOfDay?> timeObs,
//     required VoidCallback onTap,
//   }) {
//     return Obx(() {
//       final time = timeObs.value;
//       return InkWell(
//         onTap: onTap,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: const TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textSecondary,
//                   letterSpacing: 0.8,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Icon(icon, size: 16, color: time != null ? iconColor : AppColors.textSecondary),
//                   const SizedBox(width: 8),
//                   Text(
//                     time != null ? _formatTimeDisplay(time) : 'Select time',
//                     style: TextStyle(
//                       fontSize: 14.5,
//                       fontWeight: FontWeight.w600,
//                       color: time != null ? AppColors.textPrimary : AppColors.textSecondary,
//                     ),
//                   ),
//                   const Spacer(),
//                   const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );
//     });
//   }
//
//   // ====================== DROPDOWNS ======================
//   Widget _buildLeaveTypeDropdown() {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: DropdownButtonFormField<String>(
//         value: vm.selectedLeaveType.value.isEmpty ? null : vm.selectedLeaveType.value,
//         hint: const Text('Select leave type', style: TextStyle(color: AppColors.textSecondary)),
//         dropdownColor: Colors.white,
//         icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
//         decoration: const InputDecoration(border: InputBorder.none),
//         style: const TextStyle(
//           fontSize: 14.5,
//           fontWeight: FontWeight.w600,
//           color: AppColors.textPrimary,
//         ),
//         items: vm.leaveTypes
//             .map((type) => DropdownMenuItem(
//           value: type,
//           child: Text(
//             type,
//             style: const TextStyle(color: AppColors.textPrimary),
//           ),
//         ))
//             .toList(),
//         onChanged: (val) => vm.selectedLeaveType.value = val ?? '',
//       ),
//     ));
//   }
//
//   Widget _buildHalfDayDropdown() {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: DropdownButtonFormField<String>(
//         value: vm.halfDayDisplay.value.isEmpty ? null : vm.halfDayDisplay.value,
//         hint: const Text('Is this a half day?', style: TextStyle(color: AppColors.textSecondary)),
//         dropdownColor: Colors.white,
//         icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
//         decoration: const InputDecoration(border: InputBorder.none),
//         style: const TextStyle(
//           fontSize: 14.5,
//           fontWeight: FontWeight.w600,
//           color: AppColors.textPrimary,
//         ),
//         items: const ['No', 'Yes']
//             .map((e) => DropdownMenuItem(
//           value: e,
//           child: Text(
//             e,
//             style: const TextStyle(color: AppColors.textPrimary),
//           ),
//         ))
//             .toList(),
//         onChanged: (val) => vm.toggleHalfDay(val == 'Yes'),
//       ),
//     ));
//   }
//
//   Widget _buildReasonField() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: TextFormField(
//         maxLines: 5,
//         onChanged: (v) => vm.reason.value = v,
//         style: const TextStyle(fontSize: 14.5, height: 1.5),
//         decoration: InputDecoration(
//           hintText: 'Write reason for your leave...',
//           hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: AppColors.divider),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(14),
//             borderSide: BorderSide(color: AppColors.cyan, width: 1.8),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ====================== ATTACHMENT ======================
//   Widget _buildAttachmentPicker() {
//     return _card([
//       Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Expanded(child: _attachButton(Icons.camera_alt_rounded, 'Camera', AppColors.cyan, () => vm.pickImage(ImageSource.camera))),
//             const SizedBox(width: 12),
//             Expanded(child: _attachButton(Icons.photo_library_rounded, 'Gallery', AppColors.skyBlueDk, () => vm.pickImage(ImageSource.gallery))),
//           ],
//         ),
//       ),
//     ]);
//   }
//
//   Widget _attachButton(IconData icon, String label, Color color, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 18),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: color.withOpacity(0.25)),
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 48,
//               height: 48,
//               decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
//               child: Icon(icon, color: color, size: 24),
//             ),
//             const SizedBox(height: 10),
//             Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAttachmentPreview() {
//     return _card([
//       ClipRRect(
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
//         child: Obx(() => Image.memory(
//           vm.attachmentBytes.value!,
//           height: 190,
//           width: double.infinity,
//           fit: BoxFit.cover,
//         )),
//       ),
//       Padding(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: AppColors.success.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Obx(() => Text(
//                 vm.attachmentFileName.value,
//                 style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
//                 overflow: TextOverflow.ellipsis,
//               )),
//             ),
//             GestureDetector(
//               onTap: vm.removeAttachment,
//               child: Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: AppColors.error.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ]);
//   }
//
//   // ====================== SUBMIT BUTTON ======================
//   Widget _buildSubmitButton() {
//     return Obx(() {
//       final enabled = vm.canSubmit;
//       final isLoading = vm.isLoading.value;
//
//       return GestureDetector(
//         onTap: enabled && !isLoading ? vm.submitLeave : null,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 200),
//           height: 58,
//           decoration: BoxDecoration(
//             gradient: enabled
//                 ? const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan])
//                 : null,
//             color: enabled ? null : AppColors.divider,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: enabled
//                 ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))]
//                 : null,
//           ),
//           child: Center(
//             child: isLoading
//                 ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
//                 : Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.send_rounded, color: enabled ? Colors.white : AppColors.textSecondary, size: 20),
//                 const SizedBox(width: 10),
//                 Text(
//                   'Submit Leave Application',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: enabled ? Colors.white : AppColors.textSecondary,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     });
//   }
//
//   Widget _decorCircle(double size, double opacity) => Container(
//     width: size,
//     height: size,
//     decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
//   );
// }

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../ViewModels/leave_view_model.dart';

class LeaveScreen extends StatelessWidget {
  /// True jab yeh screen "Half Day" card se khuli ho, false jab "Leaves" card se khuli ho.
  final bool isHalfDayMode;

  LeaveScreen({super.key, this.isHalfDayMode = false}) {
    // Screen open hote hi default value set kar do:
    // Leaves card  -> Half Day = No
    // Half Day card -> Half Day = Yes
    vm.toggleHalfDay(isHalfDayMode);
  }

  final LeaveViewModel vm = Get.put(LeaveViewModel());

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
                  // Employee Information
                  _sectionHeader('Employee Information', Icons.person_outline_rounded, AppColors.cyan),
                  const SizedBox(height: 10),
                  _card([
                    _readOnlyField('EMPLOYEE NAME', vm.empName, Icons.person_rounded, AppColors.skyBlue),
                    _cardDivider(),
                    _readOnlyField('EMPLOYEE ID', vm.empId, Icons.badge_rounded, AppColors.skyBlue),
                  ]),

                  const SizedBox(height: 24),

                  // Leave Type
                  _sectionHeader('Leave Type', Icons.event_note_outlined, AppColors.skyBlueDk),
                  const SizedBox(height: 10),
                  _card([_buildLeaveTypeDropdown()]),

                  const SizedBox(height: 24),

                  // Leave Duration
                  _sectionHeader('Leave Duration', Icons.access_time_rounded, AppColors.warning),
                  const SizedBox(height: 10),
                  _card([
                    _buildDateField(
                      label: 'START DATE',
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppColors.warning,
                      dateObs: vm.startDate,
                      onTap: () => _selectDate(context, isStart: true),
                    ),
                    _cardDivider(),
                    _buildDateField(
                      label: 'END DATE',
                      icon: Icons.event_rounded,
                      iconColor: AppColors.warning,
                      dateObs: vm.endDate,
                      // Half Day mode mein end date manually select nahi hoti,
                      // yeh start date se auto fill hoti hai (neeche _selectDate mein).
                      onTap: isHalfDayMode ? null : () => _selectDate(context, isStart: false),
                    ),
                    Obx(() {
                      final days = vm.totalDays.value;
                      if (days <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: AppColors.greenTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.greenTeal.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: AppColors.greenTeal),
                              const SizedBox(width: 8),
                              Text(
                                '$days ${days == 1 ? 'day' : 'days'} selected',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.greenTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ]),

                  const SizedBox(height: 24),

                  // ── Half Day ─────────────────────────────────────────────
                  // Yeh poora section sirf "Half Day" flow mein dikhega.
                  // "Leaves" flow mein yeh hide rahega (user ko nazar nahi ayega)
                  // kyunke uska Half Day = No already constructor mein set ho chuka hai.
                  if (isHalfDayMode) ...[
                    _sectionHeader('Half Day Option', Icons.timelapse_rounded, AppColors.greenTeal),
                    const SizedBox(height: 10),
                    _card([
                      _buildTimeField(
                        context: context,
                        label: 'START TIME',
                        icon: Icons.access_time_rounded,
                        iconColor: AppColors.greenTeal,
                        timeObs: vm.halfDayStartTime,
                        onTap: () => _selectTime(context, isStart: true),
                      ),
                      _cardDivider(),
                      _buildTimeField(
                        context: context,
                        label: 'END TIME',
                        icon: Icons.timelapse_rounded,
                        iconColor: AppColors.greenTeal,
                        timeObs: vm.halfDayEndTime,
                        onTap: () => _selectTime(context, isStart: false),
                      ),
                    ]),

                    const SizedBox(height: 24),
                  ],

                  // Reason
                  _sectionHeader('Reason for Leave', Icons.notes_rounded, AppColors.error),
                  const SizedBox(height: 10),
                  _card([_buildReasonField()]),

                  const SizedBox(height: 24),

                  // Attachment
                  _sectionHeader('Attachment (Optional)', Icons.attach_file_rounded, AppColors.skyBlueDk),
                  const SizedBox(height: 6),
                  Text(
                    'Medical certificate or any supporting document',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 14),
                  Obx(() => vm.attachmentBytes.value != null
                      ? _buildAttachmentPreview()
                      : _buildAttachmentPicker()),

                  const SizedBox(height: 40),

                  // Submit Button
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
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
                    onTap: () => Get.back(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leave Application',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Obx(() => Text(
                          vm.selectedLeaveType.value.isEmpty
                              ? 'Apply for leave'
                              : vm.selectedLeaveType.value,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        )),
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

  // ====================== SHARED HELPERS ======================
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(width: 5, height: 22, decoration: BoxDecoration(color: AppColors.greenTeal, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _cardDivider() => const Divider(height: 1, thickness: 1, color: AppColors.divider);

  Widget _readOnlyField(String label, RxString valueObs, IconData icon, Color iconColor) {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                valueObs.value.isEmpty ? '—' : valueObs.value,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  // ====================== DATE PICKER ======================
  Future<void> _selectDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? vm.startDate.value ?? now : vm.endDate.value ?? vm.startDate.value ?? now;
    final firstDate = isStart ? now : (vm.startDate.value ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      if (isStart) {
        vm.setStartDate(picked);

        // Half Day mein leave hamesha ek hi din ki hoti hai, is liye
        // start date select hote hi end date bhi automatically wohi set ho jati hai.
        if (isHalfDayMode) {
          vm.setEndDate(picked);
        }
      } else {
        vm.setEndDate(picked);
      }
    }
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Rx<DateTime?> dateObs,
    VoidCallback? onTap,
  }) {
    return Obx(() {
      final date = dateObs.value;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 16, color: date != null ? iconColor : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    date != null ? DateFormat('EEEE, dd MMM yyyy').format(date) : 'Select date',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── NEW: Time Picker ────────────────────────────────────────────────────────

  /// Shows a native time picker; result is passed to the ViewModel.
  Future<void> _selectTime(BuildContext context, {required bool isStart}) async {
    final initial = isStart
        ? (vm.halfDayStartTime.value ?? TimeOfDay.now())
        : (vm.halfDayEndTime.value   ?? TimeOfDay.now());

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      if (isStart) vm.setHalfDayStartTime(picked);
      else         vm.setHalfDayEndTime(picked);
    }
  }

  /// Formats TimeOfDay for display: "9:00 AM"
  String _formatTimeDisplay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  /// Time field widget — same look & feel as _buildDateField.
  Widget _buildTimeField({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Rx<TimeOfDay?> timeObs,
    required VoidCallback onTap,
  }) {
    return Obx(() {
      final time = timeObs.value;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 16, color: time != null ? iconColor : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    time != null ? _formatTimeDisplay(time) : 'Select time',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: time != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  // ====================== DROPDOWNS ======================
  Widget _buildLeaveTypeDropdown() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: vm.selectedLeaveType.value.isEmpty ? null : vm.selectedLeaveType.value,
        hint: const Text('Select leave type', style: TextStyle(color: AppColors.textSecondary)),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        decoration: const InputDecoration(border: InputBorder.none),
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        items: vm.leaveTypes
            .map((type) => DropdownMenuItem(
          value: type,
          child: Text(
            type,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ))
            .toList(),
        onChanged: (val) => vm.selectedLeaveType.value = val ?? '',
      ),
    ));
  }

  Widget _buildReasonField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        maxLines: 5,
        onChanged: (v) => vm.reason.value = v,
        style: const TextStyle(fontSize: 14.5, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Write reason for your leave...',
          hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.cyan, width: 1.8),
          ),
        ),
      ),
    );
  }

  // ====================== ATTACHMENT ======================
  Widget _buildAttachmentPicker() {
    return _card([
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _attachButton(Icons.camera_alt_rounded, 'Camera', AppColors.cyan, () => vm.pickImage(ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _attachButton(Icons.photo_library_rounded, 'Gallery', AppColors.skyBlueDk, () => vm.pickImage(ImageSource.gallery))),
          ],
        ),
      ),
    ]);
  }

  Widget _attachButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    return _card([
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        child: Obx(() => Image.memory(
          vm.attachmentBytes.value!,
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        )),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => Text(
                vm.attachmentFileName.value,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              )),
            ),
            GestureDetector(
              onTap: vm.removeAttachment,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ====================== SUBMIT BUTTON ======================
  Widget _buildSubmitButton() {
    return Obx(() {
      final enabled = vm.canSubmit;
      final isLoading = vm.isLoading.value;

      return GestureDetector(
        onTap: enabled && !isLoading ? vm.submitLeave : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan])
                : null,
            color: enabled ? null : AppColors.divider,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_rounded, color: enabled ? Colors.white : AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Submit Leave Application',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _decorCircle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
  );
}