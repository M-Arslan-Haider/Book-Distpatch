//
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
//   // ── Design tokens (matched to EmployeeProfileScreen) ──────────────────────
//   // Color tokens moved to AppColors
//   //
//   //
//   //
//   //
//   //
//   //
//   //
//   //
//   // ──────────────────────────────────────────────────────────────────────────
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
//               padding: const EdgeInsets.fromLTRB(14, 20, 14, 48),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//
//                   // ── Employee Info ──────────────────────────────────────────
//                   _sectionHeader('Employee Information',
//                       Icons.person_outline_rounded, AppColors.cyan),
//                   const SizedBox(height: 8),
//                   _card([
//                     _readOnlyField(
//                       label: 'EMPLOYEE NAME',
//                       valueObs: vm.empName,
//                       icon: Icons.person_rounded,
//                       iconColor: AppColors.skyBlue,
//                     ),
//                     _cardDivider(),
//                     _readOnlyField(
//                       label: 'EMPLOYEE ID',
//                       valueObs: vm.empId,
//                       icon: Icons.badge_rounded,
//                       iconColor: AppColors.skyBlue,
//                     ),
//                   ]),
//
//                   const SizedBox(height: 18),
//
//                   // ── Leave Type ─────────────────────────────────────────────
//                   _sectionHeader('Leave Type',
//                       Icons.event_note_outlined, AppColors.skyBlueDk),
//                   const SizedBox(height: 8),
//                   _card([
//                     _buildDropdown(
//                       label: 'Select Leave Type',
//                       icon: Icons.event_note_rounded,
//                       iconColor: AppColors.skyBlueDk,
//                       items: vm.leaveTypes,
//                       selectedObs: vm.selectedLeaveType,
//                       onChanged: (val) => vm.selectedLeaveType.value = val ?? '',
//                     ),
//                   ]),
//
//                   const SizedBox(height: 18),
//
//                   // ── Dates ──────────────────────────────────────────────────
//                   _sectionHeader('Leave Duration',
//                       Icons.access_time_rounded, AppColors.warning),
//                   const SizedBox(height: 8),
//                   _card([
//                     _buildDateField(
//                       context: context,
//                       label: 'START DATE',
//                       icon: Icons.calendar_today_rounded,
//                       iconColor: AppColors.warning,
//                       dateObs: vm.startDate,
//                       onTap: () async {
//                         final now = DateTime.now();
//                         final picked = await showDatePicker(
//                           context: context,
//                           initialDate: vm.startDate.value ?? now,
//                           firstDate: now,
//                           lastDate: DateTime(now.year + 2),
//                           builder: _datePickerTheme,
//                         );
//                         if (picked != null) vm.setStartDate(picked);
//                       },
//                     ),
//                     _cardDivider(),
//                     _buildDateField(
//                       context: context,
//                       label: 'END DATE',
//                       icon: Icons.event_rounded,
//                       iconColor: AppColors.warning,
//                       dateObs: vm.endDate,
//                       onTap: () async {
//                         final now = DateTime.now();
//                         final first = vm.startDate.value ?? now;
//                         final picked = await showDatePicker(
//                           context: context,
//                           initialDate: vm.endDate.value ?? first,
//                           firstDate: first,
//                           lastDate: DateTime(now.year + 2),
//                           builder: _datePickerTheme,
//                         );
//                         if (picked != null) vm.setEndDate(picked);
//                       },
//                     ),
//                     // Total days badge
//                     Obx(() {
//                       final days = vm.totalDays.value;
//                       if (days == 0) return const SizedBox.shrink();
//                       return Padding(
//                         padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 8),
//                           decoration: BoxDecoration(
//                             color: AppColors.greenTealLt,
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(color: AppColors.greenTeal.withOpacity(0.4)),
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               const Icon(Icons.schedule_rounded,
//                                   size: 15, color: AppColors.greenTeal),
//                               const SizedBox(width: 6),
//                               Text(
//                                 '$days ${days == 1 ? 'day' : 'days'} selected',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w600,
//                                   color: AppColors.primary,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }),
//                   ]),
//
//                   const SizedBox(height: 18),
//
//                   // ── Half Day ───────────────────────────────────────────────
//                   _sectionHeader('Half Day',
//                       Icons.timelapse_rounded, AppColors.greenTeal),
//                   const SizedBox(height: 8),
//                   _card([
//                     _buildSimpleDropdown(
//                       label: 'Is this a half day?',
//                       icon: Icons.timelapse_rounded,
//                       iconColor: AppColors.greenTeal,
//                       items: const ['No', 'Yes'],
//                       selectedObs: vm.halfDayDisplay,
//                       onChanged: (val) {
//                         vm.toggleHalfDay(val == 'Yes');
//                       },
//                     ),
//                   ]),
//
//                   const SizedBox(height: 18),
//
//                   // ── Reason ─────────────────────────────────────────────────
//                   _sectionHeader('Reason',
//                       Icons.notes_rounded, AppColors.error),
//                   const SizedBox(height: 8),
//                   _card([
//                     Padding(
//                       padding: const EdgeInsets.all(4),
//                       child: TextFormField(
//                         maxLines: 4,
//                         onChanged: (v) => vm.reason.value = v,
//                         style: const TextStyle(
//                             fontSize: 14, color: AppColors.textPrimary, height: 1.5),
//                         decoration: InputDecoration(
//                           hintText: 'Enter reason for leave…',
//                           hintStyle:
//                           const TextStyle(color: AppColors.textSecondary, fontSize: 14),
//                           contentPadding:
//                           const EdgeInsets.fromLTRB(16, 14, 16, 14),
//                           border: InputBorder.none,
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide:
//                             BorderSide(color: AppColors.cyan.withOpacity(0.5)),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ]),
//
//                   const SizedBox(height: 18),
//
//                   // ── Attachment ─────────────────────────────────────────────
//                   _sectionHeader('Attachment',
//                       Icons.attach_file_rounded, AppColors.skyBlueDk),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Optional — medical certificate or supporting doc',
//                     style: TextStyle(
//                         fontSize: 11,
//                         color: AppColors.textSecondary.withOpacity(0.8)),
//                   ),
//                   const SizedBox(height: 12),
//                   Obx(() {
//                     final bytes = vm.attachmentBytes.value;
//                     if (bytes != null) {
//                       return _buildAttachmentPreview(bytes);
//                     }
//                     return _buildAttachmentPicker();
//                   }),
//
//                   const SizedBox(height: 36),
//
//                   // ── Submit ─────────────────────────────────────────────────
//                   _buildSubmitButton(),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ─── HEADER (navy gradient with decorative circles like profile) ──────────
//   Widget _buildHeader() {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
//         boxShadow: [
//           BoxShadow(
//               color: AppColors.primary.withOpacity(0.3),
//               blurRadius: 20,
//               offset: const Offset(0, 6)),
//         ],
//       ),
//       child: Stack(
//         children: [
//           // Decorative circles (matching profile screen style)
//           Positioned(
//             top: -30, right: -20,
//             child: Container(
//               width: 140, height: 140,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.05),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: -30, left: -10,
//             child: Container(
//               width: 100, height: 100,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppColors.cyan.withOpacity(0.09),
//               ),
//             ),
//           ),
//           SafeArea(
//             bottom: false,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 42,
//                       height: 42,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(13),
//                         border: Border.all(
//                             color: Colors.white.withOpacity(0.2)),
//                       ),
//                       child: const Icon(Icons.arrow_back_ios_new,
//                           color: Colors.white, size: 17),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Leave Application',
//                           style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: Colors.white,
//                               letterSpacing: 0.2),
//                         ),
//                         const SizedBox(height: 2),
//                         Obx(() {
//                           final type = vm.selectedLeaveType.value;
//                           return Text(
//                             type.isEmpty ? 'Fill in the form below' : type,
//                             style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.white.withOpacity(0.72)),
//                           );
//                         }),
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
//   // ─── SECTION HEADER (exact match to profile screen) ──────────────────────
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               color: AppColors.greenTeal, borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color: color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(
//               color: AppColors.primary,
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.3)),
//     ]);
//   }
//
//   // ─── CARD (exact match to profile screen) ────────────────────────────────
//   Widget _card(List<Widget> rows) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.04),
//               blurRadius: 10,
//               offset: const Offset(0, 3)),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: rows.asMap().entries.map((e) => Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             e.value,
//             if (e.key < rows.length - 1)
//               const Divider(height: 1, thickness: 1, color: AppColors.divider),
//           ],
//         )).toList(),
//       ),
//     );
//   }
//
//   Widget _cardDivider() =>
//       const Divider(height: 1, thickness: 1, color: AppColors.divider);
//
//   // ─── READ ONLY FIELD ──────────────────────────────────────────────────────
//   Widget _readOnlyField({
//     required String label,
//     required RxString valueObs,
//     required IconData icon,
//     required Color iconColor,
//   }) {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(label,
//             style: const TextStyle(
//                 fontSize: 9,
//                 color: AppColors.textSecondary,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 0.6)),
//         const SizedBox(height: 3),
//         Row(children: [
//           Icon(icon, size: 14, color: iconColor),
//           const SizedBox(width: 6),
//           Text(
//             valueObs.value.isEmpty ? '—' : valueObs.value,
//             style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary),
//           ),
//         ]),
//       ]),
//     ));
//   }
//
//   // ─── DROPDOWN (Leave Types) ───────────────────────────────────────────────
//   Widget _buildDropdown({
//     required String label,
//     required IconData icon,
//     required Color iconColor,
//     required List<String> items,
//     required RxString selectedObs,
//     required ValueChanged<String?> onChanged,
//   }) {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
//       child: DropdownButtonFormField<String>(
//         value: selectedObs.value.isEmpty ? null : selectedObs.value,
//         hint: Text(label,
//             style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
//         icon: const Icon(Icons.keyboard_arrow_down_rounded,
//             color: AppColors.textSecondary),
//         decoration: InputDecoration(
//           border: InputBorder.none,
//           contentPadding:
//           const EdgeInsets.symmetric(vertical: 14),
//           prefixIcon: Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: Icon(icon, color: iconColor, size: 20),
//           ),
//           prefixIconConstraints:
//           const BoxConstraints(minWidth: 48, minHeight: 48),
//         ),
//         style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             color: AppColors.textPrimary),
//         dropdownColor: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         items: items
//             .map((t) => DropdownMenuItem(
//           value: t,
//           child: Text(t,
//               style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textPrimary)),
//         ))
//             .toList(),
//         onChanged: onChanged,
//       ),
//     ));
//   }
//
//   // ─── DROPDOWN (Yes/No) ────────────────────────────────────────────────────
//   Widget _buildSimpleDropdown({
//     required String label,
//     required IconData icon,
//     required Color iconColor,
//     required List<String> items,
//     required RxString selectedObs,
//     required ValueChanged<String?> onChanged,
//   }) {
//     return Obx(() => Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
//       child: DropdownButtonFormField<String>(
//         value: selectedObs.value.isEmpty ? null : selectedObs.value,
//         hint: Text(label,
//             style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
//         icon: const Icon(Icons.keyboard_arrow_down_rounded,
//             color: AppColors.textSecondary),
//         decoration: InputDecoration(
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(vertical: 14),
//           prefixIcon: Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: Icon(icon, color: iconColor, size: 20),
//           ),
//           prefixIconConstraints:
//           const BoxConstraints(minWidth: 48, minHeight: 48),
//         ),
//         style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             color: AppColors.textPrimary),
//         dropdownColor: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         items: items
//             .map((t) => DropdownMenuItem(
//           value: t,
//           child: Text(t,
//               style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textPrimary)),
//         ))
//             .toList(),
//         onChanged: onChanged,
//       ),
//     ));
//   }
//
//   // ─── DATE FIELD ───────────────────────────────────────────────────────────
//   Widget _buildDateField({
//     required BuildContext context,
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
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(label,
//                   style: const TextStyle(
//                       fontSize: 9,
//                       color: AppColors.textSecondary,
//                       fontWeight: FontWeight.w600,
//                       letterSpacing: 0.6)),
//               const SizedBox(height: 3),
//               Row(children: [
//                 Icon(icon,
//                     size: 14,
//                     color: date != null ? iconColor : AppColors.textSecondary),
//                 const SizedBox(width: 6),
//                 Text(
//                   date != null
//                       ? DateFormat('EEEE, dd MMM yyyy').format(date)
//                       : 'Tap to select',
//                   style: TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
//                   ),
//                 ),
//                 const Spacer(),
//                 Icon(Icons.chevron_right_rounded,
//                     color: AppColors.textSecondary.withOpacity(0.5), size: 18),
//               ]),
//             ],
//           ),
//         ),
//       );
//     });
//   }
//
//   // ─── DATE PICKER THEME (uses AppColors.primary/AppColors.cyan palette) ─────────────────────────
//   Widget _datePickerTheme(BuildContext ctx, Widget? child) {
//     return Theme(
//       data: Theme.of(ctx).copyWith(
//         colorScheme: const ColorScheme.light(
//           primary: AppColors.primary,
//           onPrimary: Colors.white,
//           surface: Colors.white,
//           onSurface: AppColors.textPrimary,
//         ),
//         dialogBackgroundColor: Colors.white,
//       ),
//       child: child!,
//     );
//   }
//
//   // ─── ATTACHMENT PICKER ────────────────────────────────────────────────────
//   Widget _buildAttachmentPicker() {
//     return _card([
//       Padding(
//         padding: const EdgeInsets.all(16),
//         child: Row(
//           children: [
//             Expanded(
//               child: _attachBtn(
//                 icon: Icons.camera_alt_rounded,
//                 label: 'Camera',
//                 color: AppColors.cyan,
//                 onTap: () => vm.pickImage(ImageSource.camera),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: _attachBtn(
//                 icon: Icons.photo_library_rounded,
//                 label: 'Gallery',
//                 color: AppColors.skyBlueDk,
//                 onTap: () => vm.pickImage(ImageSource.gallery),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ]);
//   }
//
//   Widget _attachBtn({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.07),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: color.withOpacity(0.2)),
//         ),
//         child: Column(
//           children: [
//             Container(
//               width: 42,
//               height: 42,
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(icon, color: color, size: 22),
//             ),
//             const SizedBox(height: 8),
//             Text(label,
//                 style: TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: color)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ─── ATTACHMENT PREVIEW ───────────────────────────────────────────────────
//   Widget _buildAttachmentPreview(Uint8List bytes) {
//     return _card([
//       ClipRRect(
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
//         child: Image.memory(bytes,
//             height: 180,
//             width: double.infinity,
//             fit: BoxFit.cover),
//       ),
//       Padding(
//         padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
//         child: Row(
//           children: [
//             Container(
//               width: 32,
//               height: 32,
//               decoration: BoxDecoration(
//                 color: AppColors.success.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(Icons.check_rounded,
//                   color: AppColors.success, size: 18),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Obx(() => Text(
//                 vm.attachmentFileName.value,
//                 style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textPrimary),
//                 overflow: TextOverflow.ellipsis,
//               )),
//             ),
//             GestureDetector(
//               onTap: vm.removeAttachment,
//               child: Container(
//                 padding: const EdgeInsets.all(7),
//                 decoration: BoxDecoration(
//                   color: AppColors.error.withOpacity(0.08),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(Icons.delete_outline_rounded,
//                     color: AppColors.error, size: 16),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ]);
//   }
//
//   // ─── SUBMIT BUTTON ────────────────────────────────────────────────────────
//   Widget _buildSubmitButton() {
//     return Obx(() {
//       final enabled = vm.canSubmit;
//       final loading = vm.isLoading.value;
//
//       return GestureDetector(
//         onTap: enabled && !loading ? vm.submitLeave : null,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 250),
//           width: double.infinity,
//           height: 58,
//           decoration: BoxDecoration(
//             gradient: enabled
//                 ? const LinearGradient(
//               colors: [AppColors.primaryDark, AppColors.primary, AppColors.cyan],
//               begin: Alignment.centerLeft,
//               end: Alignment.centerRight,
//             )
//                 : null,
//             color: enabled ? null : AppColors.divider,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: enabled
//                 ? [
//               BoxShadow(
//                   color: AppColors.primary.withOpacity(0.35),
//                   blurRadius: 16,
//                   offset: const Offset(0, 6))
//             ]
//                 : null,
//           ),
//           child: Center(
//             child: loading
//                 ? const SizedBox(
//               width: 24,
//               height: 24,
//               child: CircularProgressIndicator(
//                   color: Colors.white, strokeWidth: 2.5),
//             )
//                 : Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.send_rounded,
//                     color: enabled ? Colors.white : AppColors.textSecondary,
//                     size: 19),
//                 const SizedBox(width: 10),
//                 Text(
//                   'Submit Leave Application',
//                   style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w700,
//                       color: enabled ? Colors.white : AppColors.textSecondary),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     });
//   }
// }

///responsive

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../ViewModels/leave_view_model.dart';

class LeaveScreen extends StatelessWidget {
  LeaveScreen({super.key});

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
                      onTap: () => _selectDate(context, isStart: false),
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

                  // Half Day
                  _sectionHeader('Half Day Option', Icons.timelapse_rounded, AppColors.greenTeal),
                  const SizedBox(height: 10),
                  _card([_buildHalfDayDropdown()]),

                  const SizedBox(height: 24),

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
      if (isStart) vm.setStartDate(picked);
      else vm.setEndDate(picked);
    }
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Rx<DateTime?> dateObs,
    required VoidCallback onTap,
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

  // ====================== DROPDOWNS ======================
  Widget _buildLeaveTypeDropdown() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: vm.selectedLeaveType.value.isEmpty ? null : vm.selectedLeaveType.value,
        hint: const Text('Select leave type', style: TextStyle(color: AppColors.textSecondary)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        decoration: const InputDecoration(border: InputBorder.none),
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        items: vm.leaveTypes
            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (val) => vm.selectedLeaveType.value = val ?? '',
      ),
    ));
  }

  Widget _buildHalfDayDropdown() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        value: vm.halfDayDisplay.value.isEmpty ? null : vm.halfDayDisplay.value,
        hint: const Text('Is this a half day?', style: TextStyle(color: AppColors.textSecondary)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        decoration: const InputDecoration(border: InputBorder.none),
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        items: const ['No', 'Yes']
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (val) => vm.toggleHalfDay(val == 'Yes'),
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