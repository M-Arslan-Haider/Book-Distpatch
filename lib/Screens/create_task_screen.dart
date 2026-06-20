// // // // import 'package:flutter/material.dart';
// // // // import 'package:flutter/services.dart';
// // // // import 'package:get/get.dart';
// // // // import 'package:shared_preferences/shared_preferences.dart';
// // // // import 'package:intl/intl.dart';
// // // //
// // // // import '../AppColors.dart';
// // // // import '../ViewModels/task_view_model.dart';
// // // //
// // // // class CreateTaskScreen extends StatefulWidget {
// // // //   const CreateTaskScreen({super.key});
// // // //
// // // //   @override
// // // //   State<CreateTaskScreen> createState() => _CreateTaskScreenState();
// // // // }
// // // //
// // // // class _CreateTaskScreenState extends State<CreateTaskScreen>
// // // //     with SingleTickerProviderStateMixin {
// // // //   final TaskViewModel _vm = Get.find<TaskViewModel>();
// // // //
// // // //   // ── Double-tap guard ───────────────────────────────────────────────────────
// // // //   bool _isPosting = false;
// // // //
// // // //   // ── Controllers ────────────────────────────────────────────────────────────
// // // //   final _formKey            = GlobalKey<FormState>();
// // // //   final _empIdCtrl          = TextEditingController();
// // // //   final _empNameCtrl        = TextEditingController();
// // // //   final _taskTitleCtrl      = TextEditingController();
// // // //   final _taskDescCtrl       = TextEditingController();
// // // //   final _commentsCtrl       = TextEditingController();
// // // //
// // // //   // ── Dropdown values ─────────────────────────────────────────────────────────
// // // //   String _status   = 'Pending';
// // // //   String _priority = 'Medium';
// // // //
// // // //   final List<String> _statusOptions   = ['Pending', 'In Progress', 'Completed'];
// // // //   final List<String> _priorityOptions = ['Low', 'Medium', 'High'];
// // // //
// // // //   // ── Date ───────────────────────────────────────────────────────────────────
// // // //   DateTime? _dueDate;
// // // //   String get _dueDateStr =>
// // // //       _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();
// // // //
// // // //   // ── Animation ──────────────────────────────────────────────────────────────
// // // //   late AnimationController _fadeCtrl;
// // // //   late Animation<double>    _fadeAnim;
// // // //
// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //     _fadeCtrl = AnimationController(
// // // //         vsync: this, duration: const Duration(milliseconds: 450));
// // // //     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// // // //     _fadeCtrl.forward();
// // // //     _loadEmployeeData();          // ← auto-fill from SharedPreferences
// // // //   }
// // // //
// // // //   // Auto-fill emp_id and emp_name from SharedPreferences
// // // //   Future<void> _loadEmployeeData() async {
// // // //     final prefs = await SharedPreferences.getInstance();
// // // //     final empId   = prefs.getString('userId')   ?? '';
// // // //     final empName = prefs.getString('userName') ?? '';
// // // //     if (mounted) {
// // // //       setState(() {
// // // //         _empIdCtrl.text   = empId;
// // // //         _empNameCtrl.text = empName;
// // // //       });
// // // //     }
// // // //   }
// // // //
// // // //   @override
// // // //   void dispose() {
// // // //     _empIdCtrl.dispose();
// // // //     _empNameCtrl.dispose();
// // // //     _taskTitleCtrl.dispose();
// // // //     _taskDescCtrl.dispose();
// // // //     _commentsCtrl.dispose();
// // // //     _fadeCtrl.dispose();
// // // //     super.dispose();
// // // //   }
// // // //
// // // //   // ── Date picker ────────────────────────────────────────────────────────────
// // // //   Future<void> _pickDate() async {
// // // //     final picked = await showDatePicker(
// // // //       context:     context,
// // // //       initialDate: DateTime.now().add(const Duration(days: 1)),
// // // //       firstDate:   DateTime.now(),
// // // //       lastDate:    DateTime.now().add(const Duration(days: 365)),
// // // //       builder: (ctx, child) {
// // // //         return Theme(
// // // //           data: Theme.of(ctx).copyWith(
// // // //             colorScheme: const ColorScheme.light(
// // // //               primary:   AppColors.cyan,
// // // //               onPrimary: Colors.white,
// // // //               surface:   Colors.white,
// // // //               onSurface: AppColors.textPrimary,
// // // //             ),
// // // //             dialogBackgroundColor: Colors.white,
// // // //           ),
// // // //           child: child!,
// // // //         );
// // // //       },
// // // //     );
// // // //     if (picked != null) setState(() => _dueDate = picked);
// // // //   }
// // // //
// // // //   // ── Submit ─────────────────────────────────────────────────────────────────
// // // //   Future<void> _submit() async {
// // // //     if (!_formKey.currentState!.validate()) return;
// // // //     if (_dueDate == null) {
// // // //       Get.showSnackbar(const GetSnackBar(
// // // //         message:         'Please select a due date.',
// // // //         duration:        Duration(seconds: 2),
// // // //         backgroundColor: AppColors.warning,
// // // //         borderRadius:    10,
// // // //         margin:          EdgeInsets.all(12),
// // // //         icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
// // // //       ));
// // // //       return;
// // // //     }
// // // //
// // // //     // Guard against double tap
// // // //     if (_isPosting) return;
// // // //     _isPosting = true;
// // // //
// // // //     final success = await _vm.createTask(
// // // //       empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
// // // //       empName:         _empNameCtrl.text.trim(),
// // // //       taskTitle:       _taskTitleCtrl.text.trim(),
// // // //       taskDescription: _taskDescCtrl.text.trim(),
// // // //       status:          _status,
// // // //       priority:        _priority,
// // // //       dueDate:         _dueDateStr,
// // // //       comments:        _commentsCtrl.text.trim(),
// // // //     );
// // // //
// // // //     _isPosting = false;
// // // //
// // // //     if (success) {
// // // //       // Go back FIRST, then show snackbar — prevents snackbar being
// // // //       // destroyed with the screen
// // // //       Get.back();
// // // //       await Future.delayed(const Duration(milliseconds: 300));
// // // //       Get.showSnackbar(const GetSnackBar(
// // // //         message:         'Task created successfully!',
// // // //         duration:        Duration(seconds: 3),
// // // //         backgroundColor: AppColors.greenTeal,
// // // //         borderRadius:    10,
// // // //         margin:          EdgeInsets.all(12),
// // // //         icon:            Icon(Icons.check_circle_outline_rounded,
// // // //             color: Colors.white),
// // // //       ));
// // // //     } else {
// // // //       Get.showSnackbar(GetSnackBar(
// // // //         message:         _vm.errorMessage.value.isNotEmpty
// // // //             ? _vm.errorMessage.value
// // // //             : 'Something went wrong.',
// // // //         duration:        const Duration(seconds: 3),
// // // //         backgroundColor: const Color(0xFFEF4444),
// // // //         borderRadius:    10,
// // // //         margin:          const EdgeInsets.all(12),
// // // //         icon:            const Icon(Icons.error_outline_rounded,
// // // //             color: Colors.white),
// // // //       ));
// // // //     }
// // // //   }
// // // //
// // // //   // ──────────────────────────────────────────────────────────────────────────
// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// // // //       statusBarColor:          Colors.transparent,
// // // //       statusBarIconBrightness: Brightness.light,
// // // //     ));
// // // //
// // // //     return Scaffold(
// // // //       backgroundColor: AppColors.surface,
// // // //       body: FadeTransition(
// // // //         opacity: _fadeAnim,
// // // //         child: Column(
// // // //           children: [
// // // //             _buildHeader(),
// // // //             Expanded(
// // // //               child: SingleChildScrollView(
// // // //                 physics: const BouncingScrollPhysics(),
// // // //                 padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
// // // //                 child: Form(
// // // //                   key: _formKey,
// // // //                   child: Column(
// // // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // // //                     children: [
// // // //                       // ── Section: Employee Info ──────────────────────────
// // // //                       _sectionHeader('Employee Info',
// // // //                           Icons.person_rounded, AppColors.skyBlueDk),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       _buildTextField(
// // // //                         controller:  _empIdCtrl,
// // // //                         label:       'Employee ID',
// // // //                         hint:        'Loading...',
// // // //                         icon:        Icons.badge_rounded,
// // // //                         iconColor:   AppColors.skyBlueDk,
// // // //                         readOnly:    true,       // auto-filled from SharedPreferences
// // // //                         validator:   (v) =>
// // // //                         (v == null || v.trim().isEmpty)
// // // //                             ? 'Employee ID not found' : null,
// // // //                         keyboardType: TextInputType.number,
// // // //                       ),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       _buildTextField(
// // // //                         controller: _empNameCtrl,
// // // //                         label:      'Employee Name',
// // // //                         hint:       'Loading...',
// // // //                         icon:       Icons.person_outline_rounded,
// // // //                         iconColor:  AppColors.skyBlueDk,
// // // //                         readOnly:   true,        // auto-filled from SharedPreferences
// // // //                         validator:  (v) =>
// // // //                         (v == null || v.trim().isEmpty)
// // // //                             ? 'Employee name not found' : null,
// // // //                       ),
// // // //
// // // //                       const SizedBox(height: 24),
// // // //
// // // //                       // ── Section: Task Details ───────────────────────────
// // // //                       _sectionHeader('Task Details',
// // // //                           Icons.task_alt_rounded, AppColors.cyan),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       _buildTextField(
// // // //                         controller: _taskTitleCtrl,
// // // //                         label:      'Task Title',
// // // //                         hint:       'Enter task title',
// // // //                         icon:       Icons.title_rounded,
// // // //                         iconColor:  AppColors.cyan,
// // // //                         validator:  (v) =>
// // // //                         (v == null || v.trim().isEmpty)
// // // //                             ? 'Task title is required' : null,
// // // //                       ),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       _buildTextField(
// // // //                         controller: _taskDescCtrl,
// // // //                         label:      'Task Description',
// // // //                         hint:       'Describe the task in detail...',
// // // //                         icon:       Icons.description_rounded,
// // // //                         iconColor:  AppColors.cyan,
// // // //                         maxLines:   4,
// // // //                         validator:  (v) =>
// // // //                         (v == null || v.trim().isEmpty)
// // // //                             ? 'Description is required' : null,
// // // //                       ),
// // // //
// // // //                       const SizedBox(height: 24),
// // // //
// // // //                       // ── Section: Status & Priority ──────────────────────
// // // //                       _sectionHeader('Status & Priority',
// // // //                           Icons.tune_rounded, AppColors.greenTeal),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       Row(
// // // //                         children: [
// // // //                           Expanded(
// // // //                             child: _buildDropdown(
// // // //                               label:    'Status',
// // // //                               value:    _status,
// // // //                               items:    _statusOptions,
// // // //                               icon:     Icons.circle_rounded,
// // // //                               color:    _statusColor(_status),
// // // //                               onChanged: (v) => setState(() => _status = v!),
// // // //                             ),
// // // //                           ),
// // // //                           const SizedBox(width: 14),
// // // //                           Expanded(
// // // //                             child: _buildDropdown(
// // // //                               label:    'Priority',
// // // //                               value:    _priority,
// // // //                               items:    _priorityOptions,
// // // //                               icon:     Icons.flag_rounded,
// // // //                               color:    _priorityColor(_priority),
// // // //                               onChanged: (v) => setState(() => _priority = v!),
// // // //                             ),
// // // //                           ),
// // // //                         ],
// // // //                       ),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       // ── Due date picker ───────────────────────────────────
// // // //                       _buildDatePicker(),
// // // //
// // // //                       const SizedBox(height: 24),
// // // //
// // // //                       // ── Section: Comments ───────────────────────────────
// // // //                       _sectionHeader('Comments',
// // // //                           Icons.comment_rounded, AppColors.cyanBright),
// // // //                       const SizedBox(height: 14),
// // // //
// // // //                       _buildTextField(
// // // //                         controller: _commentsCtrl,
// // // //                         label:      'Comments (Optional)',
// // // //                         hint:       'Add any notes or remarks...',
// // // //                         icon:       Icons.sticky_note_2_outlined,
// // // //                         iconColor:  AppColors.cyanBright,
// // // //                         maxLines:   3,
// // // //                       ),
// // // //
// // // //                       const SizedBox(height: 32),
// // // //
// // // //                       // ── Submit button ─────────────────────────────────────
// // // //                       _buildSubmitButton(),
// // // //                     ],
// // // //                   ),
// // // //                 ),
// // // //               ),
// // // //             ),
// // // //           ],
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   // ── Header ─────────────────────────────────────────────────────────────────
// // // //   Widget _buildHeader() {
// // // //     return Container(
// // // //       decoration: const BoxDecoration(
// // // //         gradient: LinearGradient(
// // // //           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
// // // //           begin:  Alignment.topLeft,
// // // //           end:    Alignment.bottomRight,
// // // //         ),
// // // //         borderRadius: BorderRadius.only(
// // // //           bottomLeft:  Radius.circular(36),
// // // //           bottomRight: Radius.circular(36),
// // // //         ),
// // // //       ),
// // // //       child: Stack(
// // // //         children: [
// // // //           Positioned(top: -50, right: -30,
// // // //               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
// // // //           Positioned(bottom: -40, left: -20,
// // // //               child: _decorCircle(130, Colors.white, 0.10)),
// // // //           SafeArea(
// // // //             child: Padding(
// // // //               padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
// // // //               child: Row(
// // // //                 children: [
// // // //                   GestureDetector(
// // // //                     onTap: () => Get.back(),
// // // //                     child: Container(
// // // //                       width: 42, height: 42,
// // // //                       decoration: BoxDecoration(
// // // //                         color:        Colors.white.withOpacity(0.12),
// // // //                         borderRadius: BorderRadius.circular(10),
// // // //                         border:       Border.all(color: Colors.white.withOpacity(0.18)),
// // // //                       ),
// // // //                       child: const Icon(Icons.arrow_back_ios_new_rounded,
// // // //                           color: Colors.white, size: 18),
// // // //                     ),
// // // //                   ),
// // // //                   const SizedBox(width: 14),
// // // //                   const Expanded(
// // // //                     child: Column(
// // // //                       crossAxisAlignment: CrossAxisAlignment.start,
// // // //                       children: [
// // // //                         Text('Create Task',
// // // //                             style: TextStyle(
// // // //                               color:      Colors.white,
// // // //                               fontSize:   18,
// // // //                               fontWeight: FontWeight.w800,
// // // //                               letterSpacing: 0.2,
// // // //                             )),
// // // //                         Text('Assign a new task to an employee',
// // // //                             style: TextStyle(
// // // //                               color:      Color(0xAAFFFFFF),
// // // //                               fontSize:   11,
// // // //                               fontWeight: FontWeight.w400,
// // // //                             )),
// // // //                       ],
// // // //                     ),
// // // //                   ),
// // // //                   Container(
// // // //                     width: 42, height: 42,
// // // //                     decoration: BoxDecoration(
// // // //                       color:        Colors.white.withOpacity(0.12),
// // // //                       borderRadius: BorderRadius.circular(10),
// // // //                       border:       Border.all(color: Colors.white.withOpacity(0.18)),
// // // //                     ),
// // // //                     child: const Icon(Icons.add_task_rounded,
// // // //                         color: Colors.white, size: 22),
// // // //                   ),
// // // //                 ],
// // // //               ),
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   // ── Text field ─────────────────────────────────────────────────────────────
// // // //   Widget _buildTextField({
// // // //     required TextEditingController controller,
// // // //     required String                label,
// // // //     required String                hint,
// // // //     required IconData              icon,
// // // //     required Color                 iconColor,
// // // //     int                            maxLines  = 1,
// // // //     bool                           readOnly  = false,
// // // //     String? Function(String?)?     validator,
// // // //     TextInputType                  keyboardType = TextInputType.text,
// // // //   }) {
// // // //     return Container(
// // // //       decoration: BoxDecoration(
// // // //         color:        AppColors.cardBg,
// // // //         borderRadius: BorderRadius.circular(14),
// // // //         border:       Border.all(color: AppColors.divider),
// // // //         boxShadow: [
// // // //           BoxShadow(
// // // //             color:      Colors.black.withOpacity(0.03),
// // // //             blurRadius: 8,
// // // //             offset:     const Offset(0, 3),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //       child: TextFormField(
// // // //         controller:   controller,
// // // //         maxLines:     maxLines,
// // // //         readOnly:     readOnly,
// // // //         keyboardType: keyboardType,
// // // //         validator:    validator,
// // // //         style: const TextStyle(
// // // //           color:      AppColors.textPrimary,
// // // //           fontSize:   13,
// // // //           fontWeight: FontWeight.w500,
// // // //         ),
// // // //         decoration: InputDecoration(
// // // //           labelText: label,
// // // //           hintText:  hint,
// // // //           labelStyle: TextStyle(
// // // //             color:    iconColor,
// // // //             fontSize: 12,
// // // //             fontWeight: FontWeight.w600,
// // // //           ),
// // // //           hintStyle: TextStyle(
// // // //             color:    AppColors.textSecondary,
// // // //             fontSize: 12,
// // // //           ),
// // // //           prefixIcon: Icon(icon, color: iconColor, size: 20),
// // // //           suffixIcon: readOnly
// // // //               ? Icon(Icons.lock_outline_rounded,
// // // //               color: AppColors.textSecondary.withOpacity(0.4), size: 16)
// // // //               : null,
// // // //           filled:      readOnly,
// // // //           fillColor:   readOnly
// // // //               ? AppColors.surface.withOpacity(0.6)
// // // //               : Colors.transparent,
// // // //           border:         InputBorder.none,
// // // //           contentPadding: const EdgeInsets.symmetric(
// // // //               horizontal: 16, vertical: 14),
// // // //           errorStyle: const TextStyle(fontSize: 10),
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   // ── Dropdown ────────────────────────────────────────────────────────────────
// // // //   Widget _buildDropdown({
// // // //     required String         label,
// // // //     required String         value,
// // // //     required List<String>   items,
// // // //     required IconData       icon,
// // // //     required Color          color,
// // // //     required void Function(String?) onChanged,
// // // //   }) {
// // // //     return Container(
// // // //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
// // // //       decoration: BoxDecoration(
// // // //         color:        AppColors.cardBg,
// // // //         borderRadius: BorderRadius.circular(14),
// // // //         border:       Border.all(color: AppColors.divider),
// // // //         boxShadow: [
// // // //           BoxShadow(
// // // //             color:      Colors.black.withOpacity(0.03),
// // // //             blurRadius: 8,
// // // //             offset:     const Offset(0, 3),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //       child: Column(
// // // //         crossAxisAlignment: CrossAxisAlignment.start,
// // // //         children: [
// // // //           Padding(
// // // //             padding: const EdgeInsets.only(top: 8, left: 4),
// // // //             child: Text(
// // // //               label,
// // // //               style: TextStyle(
// // // //                 color:      color,
// // // //                 fontSize:   10,
// // // //                 fontWeight: FontWeight.w600,
// // // //               ),
// // // //             ),
// // // //           ),
// // // //           DropdownButtonHideUnderline(
// // // //             child: DropdownButton<String>(
// // // //               value:         value,
// // // //               isExpanded:    true,
// // // //               icon:          Icon(Icons.keyboard_arrow_down_rounded,
// // // //                   color: color, size: 18),
// // // //               style: const TextStyle(
// // // //                 color:      AppColors.textPrimary,
// // // //                 fontSize:   13,
// // // //                 fontWeight: FontWeight.w600,
// // // //               ),
// // // //               onChanged:     onChanged,
// // // //               items: items.map((item) {
// // // //                 return DropdownMenuItem(
// // // //                   value: item,
// // // //                   child: Row(
// // // //                     children: [
// // // //                       Icon(icon, size: 13,
// // // //                           color: item == value ? color : AppColors.textSecondary),
// // // //                       const SizedBox(width: 6),
// // // //                       Text(item),
// // // //                     ],
// // // //                   ),
// // // //                 );
// // // //               }).toList(),
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   // ── Date picker tile ────────────────────────────────────────────────────────
// // // //   Widget _buildDatePicker() {
// // // //     return GestureDetector(
// // // //       onTap: _pickDate,
// // // //       child: Container(
// // // //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// // // //         decoration: BoxDecoration(
// // // //           color:        AppColors.cardBg,
// // // //           borderRadius: BorderRadius.circular(14),
// // // //           border:       Border.all(
// // // //             color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
// // // //           ),
// // // //           boxShadow: [
// // // //             BoxShadow(
// // // //               color:      Colors.black.withOpacity(0.03),
// // // //               blurRadius: 8,
// // // //               offset:     const Offset(0, 3),
// // // //             ),
// // // //           ],
// // // //         ),
// // // //         child: Row(
// // // //           children: [
// // // //             Icon(Icons.calendar_month_rounded,
// // // //                 color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
// // // //                 size: 20),
// // // //             const SizedBox(width: 12),
// // // //             Expanded(
// // // //               child: Column(
// // // //                 crossAxisAlignment: CrossAxisAlignment.start,
// // // //                 children: [
// // // //                   Text(
// // // //                     'Due Date',
// // // //                     style: TextStyle(
// // // //                       color:      _dueDate != null
// // // //                           ? AppColors.greenTeal
// // // //                           : AppColors.textSecondary,
// // // //                       fontSize:   10,
// // // //                       fontWeight: FontWeight.w600,
// // // //                     ),
// // // //                   ),
// // // //                   const SizedBox(height: 2),
// // // //                   Text(
// // // //                     _dueDate == null
// // // //                         ? 'Tap to select due date'
// // // //                         : DateFormat('dd MMM yyyy').format(_dueDate!),
// // // //                     style: TextStyle(
// // // //                       color:      _dueDate == null
// // // //                           ? AppColors.textSecondary
// // // //                           : AppColors.textPrimary,
// // // //                       fontSize:   13,
// // // //                       fontWeight: FontWeight.w600,
// // // //                     ),
// // // //                   ),
// // // //                 ],
// // // //               ),
// // // //             ),
// // // //             Icon(Icons.arrow_forward_ios_rounded,
// // // //                 color: AppColors.textSecondary, size: 14),
// // // //           ],
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   // ── Submit button ───────────────────────────────────────────────────────────
// // // //   Widget _buildSubmitButton() {
// // // //     return Obx(() => GestureDetector(
// // // //       onTap: _vm.isSubmitting.value ? null : _submit,
// // // //       child: Container(
// // // //         width:  double.infinity,
// // // //         height: 54,
// // // //         decoration: BoxDecoration(
// // // //           gradient: _vm.isSubmitting.value
// // // //               ? LinearGradient(colors: [
// // // //             AppColors.cyan.withOpacity(0.5),
// // // //             AppColors.greenTeal.withOpacity(0.5),
// // // //           ])
// // // //               : const LinearGradient(
// // // //             colors: [AppColors.cyan, AppColors.greenTeal],
// // // //             begin:  Alignment.centerLeft,
// // // //             end:    Alignment.centerRight,
// // // //           ),
// // // //           borderRadius: BorderRadius.circular(16),
// // // //           boxShadow: [
// // // //             BoxShadow(
// // // //               color:      AppColors.cyan.withOpacity(0.35),
// // // //               blurRadius: 14,
// // // //               offset:     const Offset(0, 5),
// // // //             ),
// // // //           ],
// // // //         ),
// // // //         child: Center(
// // // //           child: _vm.isSubmitting.value
// // // //               ? const Row(
// // // //             mainAxisAlignment: MainAxisAlignment.center,
// // // //             children: [
// // // //               SizedBox(
// // // //                 width: 18, height: 18,
// // // //                 child: CircularProgressIndicator(
// // // //                     color: Colors.white, strokeWidth: 2),
// // // //               ),
// // // //               SizedBox(width: 12),
// // // //               Text('Submitting...',
// // // //                   style: TextStyle(
// // // //                     color:      Colors.white,
// // // //                     fontSize:   15,
// // // //                     fontWeight: FontWeight.w700,
// // // //                   )),
// // // //             ],
// // // //           )
// // // //               : const Row(
// // // //             mainAxisAlignment: MainAxisAlignment.center,
// // // //             children: [
// // // //               Icon(Icons.cloud_upload_rounded,
// // // //                   color: Colors.white, size: 20),
// // // //               SizedBox(width: 10),
// // // //               Text('Submit Task',
// // // //                   style: TextStyle(
// // // //                     color:      Colors.white,
// // // //                     fontSize:   15,
// // // //                     fontWeight: FontWeight.w700,
// // // //                     letterSpacing: 0.3,
// // // //                   )),
// // // //             ],
// // // //           ),
// // // //         ),
// // // //       ),
// // // //     ));
// // // //   }
// // // //
// // // //   // ── Helpers ─────────────────────────────────────────────────────────────────
// // // //   Widget _sectionHeader(String title, IconData icon, Color color) {
// // // //     return Row(children: [
// // // //       Container(
// // // //           width: 4, height: 20,
// // // //           decoration: BoxDecoration(
// // // //               gradient:     AppColors.brandGradient,
// // // //               borderRadius: BorderRadius.circular(2))),
// // // //       const SizedBox(width: 8),
// // // //       Container(
// // // //         width: 28, height: 28,
// // // //         decoration: BoxDecoration(
// // // //             color:        color.withOpacity(0.10),
// // // //             borderRadius: BorderRadius.circular(8)),
// // // //         child: Icon(icon, size: 15, color: color),
// // // //       ),
// // // //       const SizedBox(width: 8),
// // // //       Text(title,
// // // //           style: const TextStyle(
// // // //               color:      AppColors.primary,
// // // //               fontSize:   13,
// // // //               fontWeight: FontWeight.w700,
// // // //               letterSpacing: 0.3)),
// // // //     ]);
// // // //   }
// // // //
// // // //   Widget _decorCircle(double size, Color color, double opacity) => Container(
// // // //     width: size, height: size,
// // // //     decoration: BoxDecoration(
// // // //       shape: BoxShape.circle,
// // // //       color: color.withOpacity(opacity),
// // // //     ),
// // // //   );
// // // //
// // // //   Color _statusColor(String s) {
// // // //     switch (s.toLowerCase()) {
// // // //       case 'completed':  return AppColors.greenTeal;
// // // //       case 'in progress': return AppColors.cyan;
// // // //       default:           return AppColors.warning;
// // // //     }
// // // //   }
// // // //
// // // //   Color _priorityColor(String p) {
// // // //     switch (p.toLowerCase()) {
// // // //       case 'high':   return const Color(0xFFEF4444);
// // // //       case 'medium': return AppColors.warning;
// // // //       default:       return AppColors.greenTeal;
// // // //     }
// // // //   }
// // // // }
// // //
// // //
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:get/get.dart';
// // // import 'package:shared_preferences/shared_preferences.dart';
// // // import 'package:intl/intl.dart';
// // //
// // // import '../AppColors.dart';
// // // import '../ViewModels/task_view_model.dart';
// // //
// // // class CreateTaskScreen extends StatefulWidget {
// // //   const CreateTaskScreen({super.key});
// // //
// // //   @override
// // //   State<CreateTaskScreen> createState() => _CreateTaskScreenState();
// // // }
// // //
// // // class _CreateTaskScreenState extends State<CreateTaskScreen>
// // //     with SingleTickerProviderStateMixin {
// // //   final TaskViewModel _vm = Get.find<TaskViewModel>();
// // //
// // //   // ── Double-tap guard ───────────────────────────────────────────────────────
// // //   bool _isPosting = false;
// // //
// // //   // ── Controllers ────────────────────────────────────────────────────────────
// // //   final _formKey            = GlobalKey<FormState>();
// // //   final _empIdCtrl          = TextEditingController();
// // //   final _empNameCtrl        = TextEditingController();
// // //   final _taskTitleCtrl      = TextEditingController();
// // //   final _taskDescCtrl       = TextEditingController();
// // //   final _commentsCtrl       = TextEditingController();
// // //
// // //   // ── Dropdown values ─────────────────────────────────────────────────────────
// // //   String _status   = 'Pending';
// // //   String _priority = 'Medium';
// // //   String _taskType = 'SELF'; // ✅ NEW — matches previous default in TaskViewModel.createTask()
// // //
// // //   final List<String> _statusOptions   = ['Pending', 'In Progress', 'Completed'];
// // //   final List<String> _priorityOptions = ['low', 'medium', 'high'];
// // //   final List<String> _taskTypeOptions = ['SELF', 'ok', 'OFFICE', 'OTHER']; // ✅ NEW
// // //
// // //   // ── Date ───────────────────────────────────────────────────────────────────
// // //   DateTime? _dueDate;
// // //   String get _dueDateStr =>
// // //       _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();
// // //
// // //   // ── Animation ──────────────────────────────────────────────────────────────
// // //   late AnimationController _fadeCtrl;
// // //   late Animation<double>    _fadeAnim;
// // //
// // //   // ── Initialization flag ────────────────────────────────────────────────────
// // //   bool _isInitialized = false;
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _initializeAnimation();
// // //     _loadEmployeeData();
// // //   }
// // //
// // //   void _initializeAnimation() {
// // //     if (!_isInitialized) {
// // //       _fadeCtrl = AnimationController(
// // //           vsync: this, duration: const Duration(milliseconds: 450));
// // //       _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// // //       _fadeCtrl.forward();
// // //       _isInitialized = true;
// // //     }
// // //   }
// // //
// // //   Future<void> _loadEmployeeData() async {
// // //     final prefs = await SharedPreferences.getInstance();
// // //     final empId   = prefs.getString('userId')   ?? '';
// // //     final empName = prefs.getString('userName') ?? '';
// // //     if (mounted) {
// // //       setState(() {
// // //         _empIdCtrl.text   = empId;
// // //         _empNameCtrl.text = empName;
// // //       });
// // //     }
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     _empIdCtrl.dispose();
// // //     _empNameCtrl.dispose();
// // //     _taskTitleCtrl.dispose();
// // //     _taskDescCtrl.dispose();
// // //     _commentsCtrl.dispose();
// // //     _fadeCtrl.dispose();
// // //     super.dispose();
// // //   }
// // //
// // //   // ── Responsive helpers ─────────────────────────────────────────────────────
// // //   double get _screenWidth => MediaQuery.of(context).size.width;
// // //   double get _screenHeight => MediaQuery.of(context).size.height;
// // //   bool get _isMobile => _screenWidth < 600;
// // //   bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
// // //   bool get _isDesktop => _screenWidth >= 900;
// // //
// // //   double _responsivePadding() {
// // //     if (_isMobile) return 16;
// // //     if (_isTablet) return 20;
// // //     return 24;
// // //   }
// // //
// // //   double _responsiveSpacing() {
// // //     if (_isMobile) return 14;
// // //     if (_isTablet) return 16;
// // //     return 18;
// // //   }
// // //
// // //   double _responsiveFontSize(double mobileSize) {
// // //     if (_isMobile) return mobileSize;
// // //     if (_isTablet) return mobileSize + 1;
// // //     return mobileSize + 2;
// // //   }
// // //
// // //   // ── Date picker ────────────────────────────────────────────────────────────
// // //   Future<void> _pickDate() async {
// // //     final picked = await showDatePicker(
// // //       context:     context,
// // //       initialDate: DateTime.now().add(const Duration(days: 1)),
// // //       firstDate:   DateTime.now(),
// // //       lastDate:    DateTime.now().add(const Duration(days: 365)),
// // //       builder: (ctx, child) {
// // //         return Theme(
// // //           data: Theme.of(ctx).copyWith(
// // //             colorScheme: const ColorScheme.light(
// // //               primary:   AppColors.cyan,
// // //               onPrimary: Colors.white,
// // //               surface:   Colors.white,
// // //               onSurface: AppColors.textPrimary,
// // //             ),
// // //             dialogBackgroundColor: Colors.white,
// // //           ),
// // //           child: child!,
// // //         );
// // //       },
// // //     );
// // //     if (picked != null) setState(() => _dueDate = picked);
// // //   }
// // //
// // //   // ── Submit ─────────────────────────────────────────────────────────────────
// // //   Future<void> _submit() async {
// // //     if (!_formKey.currentState!.validate()) return;
// // //     if (_dueDate == null) {
// // //       Get.showSnackbar(const GetSnackBar(
// // //         message:         'Please select a due date.',
// // //         duration:        Duration(seconds: 2),
// // //         backgroundColor: AppColors.warning,
// // //         borderRadius:    10,
// // //         margin:          EdgeInsets.all(12),
// // //         icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
// // //       ));
// // //       return;
// // //     }
// // //
// // //     if (_isPosting) return;
// // //     _isPosting = true;
// // //
// // //     final success = await _vm.createTask(
// // //       empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
// // //       empName:         _empNameCtrl.text.trim(),
// // //       taskTitle:       _taskTitleCtrl.text.trim(),
// // //       taskDescription: _taskDescCtrl.text.trim(),
// // //       status:          _status,
// // //       priority:        _priority,
// // //       dueDate:         _dueDateStr,
// // //       comments:        _commentsCtrl.text.trim(),
// // //       taskType:        _taskType, // ✅ NEW — sends the dropdown-selected type
// // //     );
// // //
// // //     _isPosting = false;
// // //
// // //     if (success) {
// // //       Get.back();
// // //       await Future.delayed(const Duration(milliseconds: 300));
// // //       Get.showSnackbar(const GetSnackBar(
// // //         message:         'Task created successfully!',
// // //         duration:        Duration(seconds: 3),
// // //         backgroundColor: AppColors.greenTeal,
// // //         borderRadius:    10,
// // //         margin:          EdgeInsets.all(12),
// // //         icon:            Icon(Icons.check_circle_outline_rounded,
// // //             color: Colors.white),
// // //       ));
// // //     } else {
// // //       Get.showSnackbar(GetSnackBar(
// // //         message:         _vm.errorMessage.value.isNotEmpty
// // //             ? _vm.errorMessage.value
// // //             : 'Something went wrong.',
// // //         duration:        const Duration(seconds: 3),
// // //         backgroundColor: const Color(0xFFEF4444),
// // //         borderRadius:    10,
// // //         margin:          const EdgeInsets.all(12),
// // //         icon:            const Icon(Icons.error_outline_rounded,
// // //             color: Colors.white),
// // //       ));
// // //     }
// // //   }
// // //
// // //   // ──────────────────────────────────────────────────────────────────────────
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     // Ensure animation is initialized before build
// // //     _initializeAnimation();
// // //
// // //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// // //       statusBarColor:          Colors.transparent,
// // //       statusBarIconBrightness: Brightness.light,
// // //     ));
// // //
// // //     return Scaffold(
// // //       backgroundColor: AppColors.surface,
// // //       body: FadeTransition(
// // //         opacity: _fadeAnim,
// // //         child: Column(
// // //           children: [
// // //             _buildHeader(),
// // //             Expanded(
// // //               child: SingleChildScrollView(
// // //                 physics: const BouncingScrollPhysics(),
// // //                 padding: EdgeInsets.fromLTRB(
// // //                   _responsivePadding(),
// // //                   _responsiveSpacing() + 10,
// // //                   _responsivePadding(),
// // //                   _responsiveSpacing() + 26,
// // //                 ),
// // //                 child: _isDesktop
// // //                     ? _buildDesktopLayout()
// // //                     : _buildMobileTabletLayout(),
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Desktop Layout (2-column) ──────────────────────────────────────────────
// // //   Widget _buildDesktopLayout() {
// // //     return Row(
// // //       crossAxisAlignment: CrossAxisAlignment.start,
// // //       children: [
// // //         Expanded(
// // //           child: _buildFormColumn(isLeftColumn: true),
// // //         ),
// // //         SizedBox(width: _responsiveSpacing() * 2),
// // //         Expanded(
// // //           child: _buildFormColumn(isLeftColumn: false),
// // //         ),
// // //       ],
// // //     );
// // //   }
// // //
// // //   // ── Mobile/Tablet Layout (single column) ───────────────────────────────────
// // //   Widget _buildMobileTabletLayout() {
// // //     return Form(
// // //       key: _formKey,
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           _sectionHeader('Employee Info',
// // //               Icons.person_rounded, AppColors.skyBlueDk),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller:  _empIdCtrl,
// // //             label:       'Employee ID',
// // //             hint:        'Loading...',
// // //             icon:        Icons.badge_rounded,
// // //             iconColor:   AppColors.skyBlueDk,
// // //             readOnly:    true,
// // //             validator:   (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Employee ID not found' : null,
// // //             keyboardType: TextInputType.number,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _empNameCtrl,
// // //             label:      'Employee Name',
// // //             hint:       'Loading...',
// // //             icon:       Icons.person_outline_rounded,
// // //             iconColor:  AppColors.skyBlueDk,
// // //             readOnly:   true,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Employee name not found' : null,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing() * 1.5),
// // //           _sectionHeader('Task Details',
// // //               Icons.task_alt_rounded, AppColors.cyan),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _taskTitleCtrl,
// // //             label:      'Task Title',
// // //             hint:       'Enter task title',
// // //             icon:       Icons.title_rounded,
// // //             iconColor:  AppColors.cyan,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Task title is required' : null,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _taskDescCtrl,
// // //             label:      'Task Description',
// // //             hint:       'Describe the task in detail...',
// // //             icon:       Icons.description_rounded,
// // //             iconColor:  AppColors.cyan,
// // //             maxLines:   _isMobile ? 3 : 4,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Description is required' : null,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing() * 1.5),
// // //           _sectionHeader('Status & Priority',
// // //               Icons.tune_rounded, AppColors.greenTeal),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildStatusPriorityRow(),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildDatePicker(),
// // //           SizedBox(height: _responsiveSpacing() * 1.5),
// // //           _sectionHeader('Comments',
// // //               Icons.comment_rounded, AppColors.cyanBright),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _commentsCtrl,
// // //             label:      'Comments (Optional)',
// // //             hint:       'Add any notes or remarks...',
// // //             icon:       Icons.sticky_note_2_outlined,
// // //             iconColor:  AppColors.cyanBright,
// // //             maxLines:   _isMobile ? 2 : 3,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing() * 2),
// // //           _buildSubmitButton(),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Desktop form column ────────────────────────────────────────────────────
// // //   Widget _buildFormColumn({required bool isLeftColumn}) {
// // //     return Form(
// // //       key: _formKey,
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: isLeftColumn
// // //             ? [
// // //           _sectionHeader('Employee Info',
// // //               Icons.person_rounded, AppColors.skyBlueDk),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller:  _empIdCtrl,
// // //             label:       'Employee ID',
// // //             hint:        'Loading...',
// // //             icon:        Icons.badge_rounded,
// // //             iconColor:   AppColors.skyBlueDk,
// // //             readOnly:    true,
// // //             validator:   (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Employee ID not found' : null,
// // //             keyboardType: TextInputType.number,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _empNameCtrl,
// // //             label:      'Employee Name',
// // //             hint:       'Loading...',
// // //             icon:       Icons.person_outline_rounded,
// // //             iconColor:  AppColors.skyBlueDk,
// // //             readOnly:   true,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Employee name not found' : null,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing() * 1.5),
// // //           _sectionHeader('Task Details',
// // //               Icons.task_alt_rounded, AppColors.cyan),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _taskTitleCtrl,
// // //             label:      'Task Title',
// // //             hint:       'Enter task title',
// // //             icon:       Icons.title_rounded,
// // //             iconColor:  AppColors.cyan,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Task title is required' : null,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _taskDescCtrl,
// // //             label:      'Task Description',
// // //             hint:       'Describe the task in detail...',
// // //             icon:       Icons.description_rounded,
// // //             iconColor:  AppColors.cyan,
// // //             maxLines:   4,
// // //             validator:  (v) =>
// // //             (v == null || v.trim().isEmpty)
// // //                 ? 'Description is required' : null,
// // //           ),
// // //         ]
// // //             : [
// // //           _sectionHeader('Status & Priority',
// // //               Icons.tune_rounded, AppColors.greenTeal),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildStatusPriorityColumn(),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildDatePicker(),
// // //           SizedBox(height: _responsiveSpacing() * 1.5),
// // //           _sectionHeader('Comments',
// // //               Icons.comment_rounded, AppColors.cyanBright),
// // //           SizedBox(height: _responsiveSpacing()),
// // //           _buildTextField(
// // //             controller: _commentsCtrl,
// // //             label:      'Comments (Optional)',
// // //             hint:       'Add any notes or remarks...',
// // //             icon:       Icons.sticky_note_2_outlined,
// // //             iconColor:  AppColors.cyanBright,
// // //             maxLines:   3,
// // //           ),
// // //           SizedBox(height: _responsiveSpacing() * 2),
// // //           _buildSubmitButton(),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Status & Priority Row (mobile/tablet) ──────────────────────────────────
// // //   Widget _buildStatusPriorityRow() {
// // //     return Column(
// // //       children: [
// // //         Row(
// // //           children: [
// // //             Expanded(
// // //               child: _buildDropdown(
// // //                 label:    'Status',
// // //                 value:    _status,
// // //                 items:    _statusOptions,
// // //                 icon:     Icons.circle_rounded,
// // //                 color:    _statusColor(_status),
// // //                 onChanged: (v) => setState(() => _status = v!),
// // //               ),
// // //             ),
// // //             SizedBox(width: _responsiveSpacing()),
// // //             Expanded(
// // //               child: _buildDropdown(
// // //                 label:    'Priority',
// // //                 value:    _priority,
// // //                 items:    _priorityOptions,
// // //                 icon:     Icons.flag_rounded,
// // //                 color:    _priorityColor(_priority),
// // //                 onChanged: (v) => setState(() => _priority = v!),
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //         SizedBox(height: _responsiveSpacing()),
// // //         // ✅ NEW — Task Type dropdown
// // //         _buildDropdown(
// // //           label:    'Task Type',
// // //           value:    _taskType,
// // //           items:    _taskTypeOptions,
// // //           icon:     Icons.category_rounded,
// // //           color:    AppColors.primary,
// // //           onChanged: (v) => setState(() => _taskType = v!),
// // //         ),
// // //       ],
// // //     );
// // //   }
// // //
// // //   // ── Status & Priority Column (desktop) ─────────────────────────────────────
// // //   Widget _buildStatusPriorityColumn() {
// // //     return Column(
// // //       children: [
// // //         _buildDropdown(
// // //           label:    'Status',
// // //           value:    _status,
// // //           items:    _statusOptions,
// // //           icon:     Icons.circle_rounded,
// // //           color:    _statusColor(_status),
// // //           onChanged: (v) => setState(() => _status = v!),
// // //         ),
// // //         SizedBox(height: _responsiveSpacing()),
// // //         _buildDropdown(
// // //           label:    'Priority',
// // //           value:    _priority,
// // //           items:    _priorityOptions,
// // //           icon:     Icons.flag_rounded,
// // //           color:    _priorityColor(_priority),
// // //           onChanged: (v) => setState(() => _priority = v!),
// // //         ),
// // //         SizedBox(height: _responsiveSpacing()),
// // //         // ✅ NEW — Task Type dropdown
// // //         _buildDropdown(
// // //           label:    'Task Type',
// // //           value:    _taskType,
// // //           items:    _taskTypeOptions,
// // //           icon:     Icons.category_rounded,
// // //           color:    AppColors.primary,
// // //           onChanged: (v) => setState(() => _taskType = v!),
// // //         ),
// // //       ],
// // //     );
// // //   }
// // //
// // //   // ── Header ─────────────────────────────────────────────────────────────────
// // //   Widget _buildHeader() {
// // //     return Container(
// // //       decoration: const BoxDecoration(
// // //         gradient: LinearGradient(
// // //           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
// // //           begin:  Alignment.topLeft,
// // //           end:    Alignment.bottomRight,
// // //         ),
// // //         borderRadius: BorderRadius.only(
// // //           bottomLeft:  Radius.circular(36),
// // //           bottomRight: Radius.circular(36),
// // //         ),
// // //       ),
// // //       child: Stack(
// // //         children: [
// // //           Positioned(top: -50, right: -30,
// // //               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
// // //           Positioned(bottom: -40, left: -20,
// // //               child: _decorCircle(130, Colors.white, 0.10)),
// // //           SafeArea(
// // //             child: Padding(
// // //               padding: EdgeInsets.fromLTRB(
// // //                 _responsivePadding(),
// // //                 12,
// // //                 _responsivePadding(),
// // //                 _responsiveSpacing() + 4,
// // //               ),
// // //               child: Row(
// // //                 children: [
// // //                   GestureDetector(
// // //                     onTap: () => Get.back(),
// // //                     child: Container(
// // //                       width: 42, height: 42,
// // //                       decoration: BoxDecoration(
// // //                         color:        Colors.white.withOpacity(0.12),
// // //                         borderRadius: BorderRadius.circular(10),
// // //                         border:       Border.all(color: Colors.white.withOpacity(0.18)),
// // //                       ),
// // //                       child: const Icon(Icons.arrow_back_ios_new_rounded,
// // //                           color: Colors.white, size: 18),
// // //                     ),
// // //                   ),
// // //                   SizedBox(width: _responsiveSpacing()),
// // //                   Expanded(
// // //                     child: Column(
// // //                       crossAxisAlignment: CrossAxisAlignment.start,
// // //                       children: [
// // //                         Text('Create Task',
// // //                             style: TextStyle(
// // //                               color:      Colors.white,
// // //                               fontSize:   _responsiveFontSize(18),
// // //                               fontWeight: FontWeight.w800,
// // //                               letterSpacing: 0.2,
// // //                             )),
// // //                         Text('Assign a new task to an employee',
// // //                             style: TextStyle(
// // //                               color:      const Color(0xAAFFFFFF),
// // //                               fontSize:   _responsiveFontSize(11),
// // //                               fontWeight: FontWeight.w400,
// // //                             )),
// // //                       ],
// // //                     ),
// // //                   ),
// // //                   Container(
// // //                     width: 42, height: 42,
// // //                     decoration: BoxDecoration(
// // //                       color:        Colors.white.withOpacity(0.12),
// // //                       borderRadius: BorderRadius.circular(10),
// // //                       border:       Border.all(color: Colors.white.withOpacity(0.18)),
// // //                     ),
// // //                     child: const Icon(Icons.add_task_rounded,
// // //                         color: Colors.white, size: 22),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Text field ─────────────────────────────────────────────────────────────
// // //   Widget _buildTextField({
// // //     required TextEditingController controller,
// // //     required String                label,
// // //     required String                hint,
// // //     required IconData              icon,
// // //     required Color                 iconColor,
// // //     int                            maxLines  = 1,
// // //     bool                           readOnly  = false,
// // //     String? Function(String?)?     validator,
// // //     TextInputType                  keyboardType = TextInputType.text,
// // //   }) {
// // //     return Container(
// // //       decoration: BoxDecoration(
// // //         color:        AppColors.cardBg,
// // //         borderRadius: BorderRadius.circular(14),
// // //         border:       Border.all(color: AppColors.divider),
// // //         boxShadow: [
// // //           BoxShadow(
// // //             color:      Colors.black.withOpacity(0.03),
// // //             blurRadius: 8,
// // //             offset:     const Offset(0, 3),
// // //           ),
// // //         ],
// // //       ),
// // //       child: TextFormField(
// // //         controller:   controller,
// // //         maxLines:     maxLines,
// // //         readOnly:     readOnly,
// // //         keyboardType: keyboardType,
// // //         validator:    validator,
// // //         style: TextStyle(
// // //           color:      AppColors.textPrimary,
// // //           fontSize:   _responsiveFontSize(13),
// // //           fontWeight: FontWeight.w500,
// // //         ),
// // //         decoration: InputDecoration(
// // //           labelText: label,
// // //           hintText:  hint,
// // //           labelStyle: TextStyle(
// // //             color:    iconColor,
// // //             fontSize: _responsiveFontSize(12),
// // //             fontWeight: FontWeight.w600,
// // //           ),
// // //           hintStyle: TextStyle(
// // //             color:    AppColors.textSecondary,
// // //             fontSize: _responsiveFontSize(12),
// // //           ),
// // //           prefixIcon: Icon(icon, color: iconColor, size: 20),
// // //           suffixIcon: readOnly
// // //               ? Icon(Icons.lock_outline_rounded,
// // //               color: AppColors.textSecondary.withOpacity(0.4), size: 16)
// // //               : null,
// // //           filled:      readOnly,
// // //           fillColor:   readOnly
// // //               ? AppColors.surface.withOpacity(0.6)
// // //               : Colors.transparent,
// // //           border:         InputBorder.none,
// // //           contentPadding: EdgeInsets.symmetric(
// // //               horizontal: _responsivePadding(), vertical: _responsiveSpacing()),
// // //           errorStyle: TextStyle(fontSize: _responsiveFontSize(10)),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Dropdown ────────────────────────────────────────────────────────────────
// // //   Widget _buildDropdown({
// // //     required String         label,
// // //     required String         value,
// // //     required List<String>   items,
// // //     required IconData       icon,
// // //     required Color          color,
// // //     required void Function(String?) onChanged,
// // //   }) {
// // //     return Container(
// // //       padding: EdgeInsets.symmetric(
// // //           horizontal: _responsivePadding() * 0.75, vertical: 4),
// // //       decoration: BoxDecoration(
// // //         color:        AppColors.cardBg,
// // //         borderRadius: BorderRadius.circular(14),
// // //         border:       Border.all(color: AppColors.divider),
// // //         boxShadow: [
// // //           BoxShadow(
// // //             color:      Colors.black.withOpacity(0.03),
// // //             blurRadius: 8,
// // //             offset:     const Offset(0, 3),
// // //           ),
// // //         ],
// // //       ),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //           Padding(
// // //             padding: const EdgeInsets.only(top: 8, left: 4),
// // //             child: Text(
// // //               label,
// // //               style: TextStyle(
// // //                 color:      color,
// // //                 fontSize:   _responsiveFontSize(10),
// // //                 fontWeight: FontWeight.w600,
// // //               ),
// // //             ),
// // //           ),
// // //           DropdownButtonHideUnderline(
// // //             child: DropdownButton<String>(
// // //               value:         value,
// // //               isExpanded:    true,
// // //               icon:          Icon(Icons.keyboard_arrow_down_rounded,
// // //                   color: color, size: 18),
// // //               style: TextStyle(
// // //                 color:      AppColors.textPrimary,
// // //                 fontSize:   _responsiveFontSize(13),
// // //                 fontWeight: FontWeight.w600,
// // //               ),
// // //               onChanged:     onChanged,
// // //               items: items.map((item) {
// // //                 return DropdownMenuItem(
// // //                   value: item,
// // //                   child: Row(
// // //                     children: [
// // //                       Icon(icon, size: 13,
// // //                           color: item == value ? color : AppColors.textSecondary),
// // //                       const SizedBox(width: 6),
// // //                       Text(item),
// // //                     ],
// // //                   ),
// // //                 );
// // //               }).toList(),
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Date picker tile ────────────────────────────────────────────────────────
// // //   Widget _buildDatePicker() {
// // //     return GestureDetector(
// // //       onTap: _pickDate,
// // //       child: Container(
// // //         padding: EdgeInsets.symmetric(
// // //             horizontal: _responsivePadding(),
// // //             vertical: _responsiveSpacing()),
// // //         decoration: BoxDecoration(
// // //           color:        AppColors.cardBg,
// // //           borderRadius: BorderRadius.circular(14),
// // //           border:       Border.all(
// // //             color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
// // //           ),
// // //           boxShadow: [
// // //             BoxShadow(
// // //               color:      Colors.black.withOpacity(0.03),
// // //               blurRadius: 8,
// // //               offset:     const Offset(0, 3),
// // //             ),
// // //           ],
// // //         ),
// // //         child: Row(
// // //           children: [
// // //             Icon(Icons.calendar_month_rounded,
// // //                 color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
// // //                 size: 20),
// // //             SizedBox(width: _responsiveSpacing()),
// // //             Expanded(
// // //               child: Column(
// // //                 crossAxisAlignment: CrossAxisAlignment.start,
// // //                 children: [
// // //                   Text(
// // //                     'Due Date',
// // //                     style: TextStyle(
// // //                       color:      _dueDate != null
// // //                           ? AppColors.greenTeal
// // //                           : AppColors.textSecondary,
// // //                       fontSize:   _responsiveFontSize(10),
// // //                       fontWeight: FontWeight.w600,
// // //                     ),
// // //                   ),
// // //                   const SizedBox(height: 2),
// // //                   Text(
// // //                     _dueDate == null
// // //                         ? 'Tap to select due date'
// // //                         : DateFormat('dd MMM yyyy').format(_dueDate!),
// // //                     style: TextStyle(
// // //                       color:      _dueDate == null
// // //                           ? AppColors.textSecondary
// // //                           : AppColors.textPrimary,
// // //                       fontSize:   _responsiveFontSize(13),
// // //                       fontWeight: FontWeight.w600,
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //             Icon(Icons.arrow_forward_ios_rounded,
// // //                 color: AppColors.textSecondary, size: 14),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── Submit button ───────────────────────────────────────────────────────────
// // //   Widget _buildSubmitButton() {
// // //     return Obx(() => GestureDetector(
// // //       onTap: _vm.isSubmitting.value ? null : _submit,
// // //       child: Container(
// // //         width:  double.infinity,
// // //         height: _isMobile ? 48 : 54,
// // //         decoration: BoxDecoration(
// // //           gradient: _vm.isSubmitting.value
// // //               ? LinearGradient(colors: [
// // //             AppColors.cyan.withOpacity(0.5),
// // //             AppColors.greenTeal.withOpacity(0.5),
// // //           ])
// // //               : const LinearGradient(
// // //             colors: [AppColors.cyan, AppColors.greenTeal],
// // //             begin:  Alignment.centerLeft,
// // //             end:    Alignment.centerRight,
// // //           ),
// // //           borderRadius: BorderRadius.circular(16),
// // //           boxShadow: [
// // //             BoxShadow(
// // //               color:      AppColors.cyan.withOpacity(0.35),
// // //               blurRadius: 14,
// // //               offset:     const Offset(0, 5),
// // //             ),
// // //           ],
// // //         ),
// // //         child: Center(
// // //           child: _vm.isSubmitting.value
// // //               ? Row(
// // //             mainAxisAlignment: MainAxisAlignment.center,
// // //             children: [
// // //               const SizedBox(
// // //                 width: 18, height: 18,
// // //                 child: CircularProgressIndicator(
// // //                     color: Colors.white, strokeWidth: 2),
// // //               ),
// // //               SizedBox(width: _responsiveSpacing()),
// // //               Text('Submitting...',
// // //                   style: TextStyle(
// // //                     color:      Colors.white,
// // //                     fontSize:   _responsiveFontSize(15),
// // //                     fontWeight: FontWeight.w700,
// // //                   )),
// // //             ],
// // //           )
// // //               : Row(
// // //             mainAxisAlignment: MainAxisAlignment.center,
// // //             children: [
// // //               const Icon(Icons.cloud_upload_rounded,
// // //                   color: Colors.white, size: 20),
// // //               SizedBox(width: _responsiveSpacing()),
// // //               Text('Submit Task',
// // //                   style: TextStyle(
// // //                     color:      Colors.white,
// // //                     fontSize:   _responsiveFontSize(15),
// // //                     fontWeight: FontWeight.w700,
// // //                     letterSpacing: 0.3,
// // //                   )),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     ));
// // //   }
// // //
// // //   // ── Helpers ─────────────────────────────────────────────────────────────────
// // //   Widget _sectionHeader(String title, IconData icon, Color color) {
// // //     return Row(children: [
// // //       Container(
// // //           width: 4, height: 20,
// // //           decoration: BoxDecoration(
// // //               gradient:     AppColors.brandGradient,
// // //               borderRadius: BorderRadius.circular(2))),
// // //       SizedBox(width: _responsiveSpacing() * 0.5),
// // //       Container(
// // //         width: 28, height: 28,
// // //         decoration: BoxDecoration(
// // //             color:        color.withOpacity(0.10),
// // //             borderRadius: BorderRadius.circular(8)),
// // //         child: Icon(icon, size: 15, color: color),
// // //       ),
// // //       SizedBox(width: _responsiveSpacing() * 0.5),
// // //       Expanded(
// // //         child: Text(title,
// // //             style: TextStyle(
// // //                 color:      AppColors.primary,
// // //                 fontSize:   _responsiveFontSize(13),
// // //                 fontWeight: FontWeight.w700,
// // //                 letterSpacing: 0.3)),
// // //       ),
// // //     ]);
// // //   }
// // //
// // //   Widget _decorCircle(double size, Color color, double opacity) => Container(
// // //     width: size, height: size,
// // //     decoration: BoxDecoration(
// // //       shape: BoxShape.circle,
// // //       color: color.withOpacity(opacity),
// // //     ),
// // //   );
// // //
// // //   Color _statusColor(String s) {
// // //     switch (s.toLowerCase()) {
// // //       case 'completed':  return AppColors.greenTeal;
// // //       case 'in progress': return AppColors.cyan;
// // //       default:           return AppColors.warning;
// // //     }
// // //   }
// // //
// // //   Color _priorityColor(String p) {
// // //     switch (p.toLowerCase()) {
// // //       case 'high':   return const Color(0xFFEF4444);
// // //       case 'medium': return AppColors.warning;
// // //       default:       return AppColors.greenTeal;
// // //     }
// // //   }
// // // }
// // //
// //
// //
// //
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:intl/intl.dart';
// //
// // import '../AppColors.dart';
// // import '../ViewModels/task_view_model.dart';
// //
// // class CreateTaskScreen extends StatefulWidget {
// //   const CreateTaskScreen({super.key});
// //
// //   @override
// //   State<CreateTaskScreen> createState() => _CreateTaskScreenState();
// // }
// //
// // class _CreateTaskScreenState extends State<CreateTaskScreen>
// //     with SingleTickerProviderStateMixin {
// //   final TaskViewModel _vm = Get.find<TaskViewModel>();
// //
// //   // ── Double-tap guard ───────────────────────────────────────────────────────
// //   bool _isPosting = false;
// //
// //   // ── Controllers ────────────────────────────────────────────────────────────
// //   final _formKey            = GlobalKey<FormState>();
// //   final _empIdCtrl          = TextEditingController();
// //   final _empNameCtrl        = TextEditingController();
// //   final _taskTitleCtrl      = TextEditingController();
// //   final _taskDescCtrl       = TextEditingController();
// //   final _commentsCtrl       = TextEditingController();
// //
// //   // ── Dropdown values ─────────────────────────────────────────────────────────
// //   String _status   = 'Pending';
// //   String _priority = 'medium';
// //   String _taskType = 'SELF'; // ✅ NEW — matches previous default in TaskViewModel.createTask()
// //
// //   final List<String> _statusOptions   = ['Pending', 'In Progress', 'Completed'];
// //   final List<String> _priorityOptions = ['low', 'medium', 'high'];
// //   final List<String> _taskTypeOptions = ['SELF', 'ok', 'OFFICE', 'OTHER']; // ✅ NEW
// //
// //   // ── Date ───────────────────────────────────────────────────────────────────
// //   DateTime? _dueDate;
// //   String get _dueDateStr =>
// //       _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();
// //
// //   // ── Animation ──────────────────────────────────────────────────────────────
// //   late AnimationController _fadeCtrl;
// //   late Animation<double>    _fadeAnim;
// //
// //   // ── Initialization flag ────────────────────────────────────────────────────
// //   bool _isInitialized = false;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _initializeAnimation();
// //     _loadEmployeeData();
// //   }
// //
// //   void _initializeAnimation() {
// //     if (!_isInitialized) {
// //       _fadeCtrl = AnimationController(
// //           vsync: this, duration: const Duration(milliseconds: 450));
// //       _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// //       _fadeCtrl.forward();
// //       _isInitialized = true;
// //     }
// //   }
// //
// //   Future<void> _loadEmployeeData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final empId   = prefs.getString('userId')   ?? '';
// //     final empName = prefs.getString('userName') ?? '';
// //     if (mounted) {
// //       setState(() {
// //         _empIdCtrl.text   = empId;
// //         _empNameCtrl.text = empName;
// //       });
// //     }
// //   }
// //
// //   @override
// //   void dispose() {
// //     _empIdCtrl.dispose();
// //     _empNameCtrl.dispose();
// //     _taskTitleCtrl.dispose();
// //     _taskDescCtrl.dispose();
// //     _commentsCtrl.dispose();
// //     _fadeCtrl.dispose();
// //     super.dispose();
// //   }
// //
// //   // ── Responsive helpers ─────────────────────────────────────────────────────
// //   double get _screenWidth => MediaQuery.of(context).size.width;
// //   double get _screenHeight => MediaQuery.of(context).size.height;
// //   bool get _isMobile => _screenWidth < 600;
// //   bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
// //   bool get _isDesktop => _screenWidth >= 900;
// //
// //   double _responsivePadding() {
// //     if (_isMobile) return 16;
// //     if (_isTablet) return 20;
// //     return 24;
// //   }
// //
// //   double _responsiveSpacing() {
// //     if (_isMobile) return 14;
// //     if (_isTablet) return 16;
// //     return 18;
// //   }
// //
// //   double _responsiveFontSize(double mobileSize) {
// //     if (_isMobile) return mobileSize;
// //     if (_isTablet) return mobileSize + 1;
// //     return mobileSize + 2;
// //   }
// //
// //   // ── Date picker ────────────────────────────────────────────────────────────
// //   Future<void> _pickDate() async {
// //     final picked = await showDatePicker(
// //       context:     context,
// //       initialDate: DateTime.now().add(const Duration(days: 1)),
// //       firstDate:   DateTime.now(),
// //       lastDate:    DateTime.now().add(const Duration(days: 365)),
// //       builder: (ctx, child) {
// //         return Theme(
// //           data: Theme.of(ctx).copyWith(
// //             colorScheme: const ColorScheme.light(
// //               primary:   AppColors.cyan,
// //               onPrimary: Colors.white,
// //               surface:   Colors.white,
// //               onSurface: AppColors.textPrimary,
// //             ),
// //             dialogBackgroundColor: Colors.white,
// //           ),
// //           child: child!,
// //         );
// //       },
// //     );
// //     if (picked != null) setState(() => _dueDate = picked);
// //   }
// //
// //   // ── Submit ─────────────────────────────────────────────────────────────────
// //   Future<void> _submit() async {
// //     if (!_formKey.currentState!.validate()) return;
// //     if (_dueDate == null) {
// //       Get.showSnackbar(const GetSnackBar(
// //         message:         'Please select a due date.',
// //         duration:        Duration(seconds: 2),
// //         backgroundColor: AppColors.warning,
// //         borderRadius:    10,
// //         margin:          EdgeInsets.all(12),
// //         icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
// //       ));
// //       return;
// //     }
// //
// //     if (_isPosting) return;
// //     _isPosting = true;
// //
// //     final success = await _vm.createTask(
// //       empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
// //       empName:         _empNameCtrl.text.trim(),
// //       taskTitle:       _taskTitleCtrl.text.trim(),
// //       taskDescription: _taskDescCtrl.text.trim(),
// //       status:          _status,
// //       priority:        _priority,
// //       dueDate:         _dueDateStr,
// //       comments:        _commentsCtrl.text.trim(),
// //       taskType:        _taskType, // ✅ NEW — sends the dropdown-selected type
// //     );
// //
// //     _isPosting = false;
// //
// //     if (success) {
// //       Get.back();
// //       await Future.delayed(const Duration(milliseconds: 300));
// //       Get.showSnackbar(const GetSnackBar(
// //         message:         'Task created successfully!',
// //         duration:        Duration(seconds: 3),
// //         backgroundColor: AppColors.greenTeal,
// //         borderRadius:    10,
// //         margin:          EdgeInsets.all(12),
// //         icon:            Icon(Icons.check_circle_outline_rounded,
// //             color: Colors.white),
// //       ));
// //     } else {
// //       Get.showSnackbar(GetSnackBar(
// //         message:         _vm.errorMessage.value.isNotEmpty
// //             ? _vm.errorMessage.value
// //             : 'Something went wrong.',
// //         duration:        const Duration(seconds: 3),
// //         backgroundColor: const Color(0xFFEF4444),
// //         borderRadius:    10,
// //         margin:          const EdgeInsets.all(12),
// //         icon:            const Icon(Icons.error_outline_rounded,
// //             color: Colors.white),
// //       ));
// //     }
// //   }
// //
// //   // ──────────────────────────────────────────────────────────────────────────
// //   @override
// //   Widget build(BuildContext context) {
// //     // Ensure animation is initialized before build
// //     _initializeAnimation();
// //
// //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// //       statusBarColor:          Colors.transparent,
// //       statusBarIconBrightness: Brightness.light,
// //     ));
// //
// //     return Scaffold(
// //       backgroundColor: AppColors.surface,
// //       body: FadeTransition(
// //         opacity: _fadeAnim,
// //         child: Column(
// //           children: [
// //             _buildHeader(),
// //             Expanded(
// //               child: SingleChildScrollView(
// //                 physics: const BouncingScrollPhysics(),
// //                 padding: EdgeInsets.fromLTRB(
// //                   _responsivePadding(),
// //                   _responsiveSpacing() + 10,
// //                   _responsivePadding(),
// //                   _responsiveSpacing() + 26,
// //                 ),
// //                 child: _isDesktop
// //                     ? _buildDesktopLayout()
// //                     : _buildMobileTabletLayout(),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── Desktop Layout (2-column) ──────────────────────────────────────────────
// //   Widget _buildDesktopLayout() {
// //     return Row(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         Expanded(
// //           child: _buildFormColumn(isLeftColumn: true),
// //         ),
// //         SizedBox(width: _responsiveSpacing() * 2),
// //         Expanded(
// //           child: _buildFormColumn(isLeftColumn: false),
// //         ),
// //       ],
// //     );
// //   }
// //
// //   // ── Mobile/Tablet Layout (single column) ───────────────────────────────────
// //   Widget _buildMobileTabletLayout() {
// //     return Form(
// //       key: _formKey,
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           _sectionHeader('Employee Info',
// //               Icons.person_rounded, AppColors.skyBlueDk),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller:  _empIdCtrl,
// //             label:       'Employee ID',
// //             hint:        'Loading...',
// //             icon:        Icons.badge_rounded,
// //             iconColor:   AppColors.skyBlueDk,
// //             readOnly:    true,
// //             validator:   (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Employee ID not found' : null,
// //             keyboardType: TextInputType.number,
// //           ),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _empNameCtrl,
// //             label:      'Employee Name',
// //             hint:       'Loading...',
// //             icon:       Icons.person_outline_rounded,
// //             iconColor:  AppColors.skyBlueDk,
// //             readOnly:   true,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Employee name not found' : null,
// //           ),
// //           SizedBox(height: _responsiveSpacing() * 1.5),
// //           _sectionHeader('Task Details',
// //               Icons.task_alt_rounded, AppColors.cyan),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _taskTitleCtrl,
// //             label:      'Task Title',
// //             hint:       'Enter task title',
// //             icon:       Icons.title_rounded,
// //             iconColor:  AppColors.cyan,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Task title is required' : null,
// //           ),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _taskDescCtrl,
// //             label:      'Task Description',
// //             hint:       'Describe the task in detail...',
// //             icon:       Icons.description_rounded,
// //             iconColor:  AppColors.cyan,
// //             maxLines:   _isMobile ? 3 : 4,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Description is required' : null,
// //           ),
// //           SizedBox(height: _responsiveSpacing() * 1.5),
// //           _sectionHeader('Status & Priority',
// //               Icons.tune_rounded, AppColors.greenTeal),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildStatusPriorityRow(),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildDatePicker(),
// //           SizedBox(height: _responsiveSpacing() * 1.5),
// //           _sectionHeader('Comments',
// //               Icons.comment_rounded, AppColors.cyanBright),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _commentsCtrl,
// //             label:      'Comments (Optional)',
// //             hint:       'Add any notes or remarks...',
// //             icon:       Icons.sticky_note_2_outlined,
// //             iconColor:  AppColors.cyanBright,
// //             maxLines:   _isMobile ? 2 : 3,
// //           ),
// //           SizedBox(height: _responsiveSpacing() * 2),
// //           _buildSubmitButton(),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Desktop form column ────────────────────────────────────────────────────
// //   Widget _buildFormColumn({required bool isLeftColumn}) {
// //     return Form(
// //       key: _formKey,
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: isLeftColumn
// //             ? [
// //           _sectionHeader('Employee Info',
// //               Icons.person_rounded, AppColors.skyBlueDk),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller:  _empIdCtrl,
// //             label:       'Employee ID',
// //             hint:        'Loading...',
// //             icon:        Icons.badge_rounded,
// //             iconColor:   AppColors.skyBlueDk,
// //             readOnly:    true,
// //             validator:   (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Employee ID not found' : null,
// //             keyboardType: TextInputType.number,
// //           ),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _empNameCtrl,
// //             label:      'Employee Name',
// //             hint:       'Loading...',
// //             icon:       Icons.person_outline_rounded,
// //             iconColor:  AppColors.skyBlueDk,
// //             readOnly:   true,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Employee name not found' : null,
// //           ),
// //           SizedBox(height: _responsiveSpacing() * 1.5),
// //           _sectionHeader('Task Details',
// //               Icons.task_alt_rounded, AppColors.cyan),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _taskTitleCtrl,
// //             label:      'Task Title',
// //             hint:       'Enter task title',
// //             icon:       Icons.title_rounded,
// //             iconColor:  AppColors.cyan,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Task title is required' : null,
// //           ),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _taskDescCtrl,
// //             label:      'Task Description',
// //             hint:       'Describe the task in detail...',
// //             icon:       Icons.description_rounded,
// //             iconColor:  AppColors.cyan,
// //             maxLines:   4,
// //             validator:  (v) =>
// //             (v == null || v.trim().isEmpty)
// //                 ? 'Description is required' : null,
// //           ),
// //         ]
// //             : [
// //           _sectionHeader('Status & Priority',
// //               Icons.tune_rounded, AppColors.greenTeal),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildStatusPriorityColumn(),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildDatePicker(),
// //           SizedBox(height: _responsiveSpacing() * 1.5),
// //           _sectionHeader('Comments',
// //               Icons.comment_rounded, AppColors.cyanBright),
// //           SizedBox(height: _responsiveSpacing()),
// //           _buildTextField(
// //             controller: _commentsCtrl,
// //             label:      'Comments (Optional)',
// //             hint:       'Add any notes or remarks...',
// //             icon:       Icons.sticky_note_2_outlined,
// //             iconColor:  AppColors.cyanBright,
// //             maxLines:   3,
// //           ),
// //           SizedBox(height: _responsiveSpacing() * 2),
// //           _buildSubmitButton(),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Status & Priority Row (mobile/tablet) ──────────────────────────────────
// //   Widget _buildStatusPriorityRow() {
// //     return Column(
// //       children: [
// //         Row(
// //           children: [
// //             Expanded(
// //               child: _buildDropdown(
// //                 label:    'Status',
// //                 value:    _status,
// //                 items:    _statusOptions,
// //                 icon:     Icons.circle_rounded,
// //                 color:    _statusColor(_status),
// //                 onChanged: (v) => setState(() => _status = v!),
// //               ),
// //             ),
// //             SizedBox(width: _responsiveSpacing()),
// //             Expanded(
// //               child: _buildDropdown(
// //                 label:    'Priority',
// //                 value:    _priority,
// //                 items:    _priorityOptions,
// //                 icon:     Icons.flag_rounded,
// //                 color:    _priorityColor(_priority),
// //                 onChanged: (v) => setState(() => _priority = v!),
// //               ),
// //             ),
// //           ],
// //         ),
// //         SizedBox(height: _responsiveSpacing()),
// //         // ✅ NEW — Task Type dropdown
// //         _buildDropdown(
// //           label:    'Task Type',
// //           value:    _taskType,
// //           items:    _taskTypeOptions,
// //           icon:     Icons.category_rounded,
// //           color:    AppColors.primary,
// //           onChanged: (v) => setState(() => _taskType = v!),
// //         ),
// //       ],
// //     );
// //   }
// //
// //   // ── Status & Priority Column (desktop) ─────────────────────────────────────
// //   Widget _buildStatusPriorityColumn() {
// //     return Column(
// //       children: [
// //         _buildDropdown(
// //           label:    'Status',
// //           value:    _status,
// //           items:    _statusOptions,
// //           icon:     Icons.circle_rounded,
// //           color:    _statusColor(_status),
// //           onChanged: (v) => setState(() => _status = v!),
// //         ),
// //         SizedBox(height: _responsiveSpacing()),
// //         _buildDropdown(
// //           label:    'Priority',
// //           value:    _priority,
// //           items:    _priorityOptions,
// //           icon:     Icons.flag_rounded,
// //           color:    _priorityColor(_priority),
// //           onChanged: (v) => setState(() => _priority = v!),
// //         ),
// //         SizedBox(height: _responsiveSpacing()),
// //         // ✅ NEW — Task Type dropdown
// //         _buildDropdown(
// //           label:    'Task Type',
// //           value:    _taskType,
// //           items:    _taskTypeOptions,
// //           icon:     Icons.category_rounded,
// //           color:    AppColors.primary,
// //           onChanged: (v) => setState(() => _taskType = v!),
// //         ),
// //       ],
// //     );
// //   }
// //
// //   // ── Header ─────────────────────────────────────────────────────────────────
// //   Widget _buildHeader() {
// //     return Container(
// //       decoration: const BoxDecoration(
// //         gradient: LinearGradient(
// //           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
// //           begin:  Alignment.topLeft,
// //           end:    Alignment.bottomRight,
// //         ),
// //         borderRadius: BorderRadius.only(
// //           bottomLeft:  Radius.circular(36),
// //           bottomRight: Radius.circular(36),
// //         ),
// //       ),
// //       child: Stack(
// //         children: [
// //           Positioned(top: -50, right: -30,
// //               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
// //           Positioned(bottom: -40, left: -20,
// //               child: _decorCircle(130, Colors.white, 0.10)),
// //           SafeArea(
// //             child: Padding(
// //               padding: EdgeInsets.fromLTRB(
// //                 _responsivePadding(),
// //                 12,
// //                 _responsivePadding(),
// //                 _responsiveSpacing() + 4,
// //               ),
// //               child: Row(
// //                 children: [
// //                   GestureDetector(
// //                     onTap: () => Get.back(),
// //                     child: Container(
// //                       width: 42, height: 42,
// //                       decoration: BoxDecoration(
// //                         color:        Colors.white.withOpacity(0.12),
// //                         borderRadius: BorderRadius.circular(10),
// //                         border:       Border.all(color: Colors.white.withOpacity(0.18)),
// //                       ),
// //                       child: const Icon(Icons.arrow_back_ios_new_rounded,
// //                           color: Colors.white, size: 18),
// //                     ),
// //                   ),
// //                   SizedBox(width: _responsiveSpacing()),
// //                   Expanded(
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         Text('Create Task',
// //                             style: TextStyle(
// //                               color:      Colors.white,
// //                               fontSize:   _responsiveFontSize(18),
// //                               fontWeight: FontWeight.w800,
// //                               letterSpacing: 0.2,
// //                             )),
// //                         Text('Assign a new task to an employee',
// //                             style: TextStyle(
// //                               color:      const Color(0xAAFFFFFF),
// //                               fontSize:   _responsiveFontSize(11),
// //                               fontWeight: FontWeight.w400,
// //                             )),
// //                       ],
// //                     ),
// //                   ),
// //                   Container(
// //                     width: 42, height: 42,
// //                     decoration: BoxDecoration(
// //                       color:        Colors.white.withOpacity(0.12),
// //                       borderRadius: BorderRadius.circular(10),
// //                       border:       Border.all(color: Colors.white.withOpacity(0.18)),
// //                     ),
// //                     child: const Icon(Icons.add_task_rounded,
// //                         color: Colors.white, size: 22),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Text field ─────────────────────────────────────────────────────────────
// //   Widget _buildTextField({
// //     required TextEditingController controller,
// //     required String                label,
// //     required String                hint,
// //     required IconData              icon,
// //     required Color                 iconColor,
// //     int                            maxLines  = 1,
// //     bool                           readOnly  = false,
// //     String? Function(String?)?     validator,
// //     TextInputType                  keyboardType = TextInputType.text,
// //   }) {
// //     return Container(
// //       decoration: BoxDecoration(
// //         color:        AppColors.cardBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border:       Border.all(color: AppColors.divider),
// //         boxShadow: [
// //           BoxShadow(
// //             color:      Colors.black.withOpacity(0.03),
// //             blurRadius: 8,
// //             offset:     const Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       child: TextFormField(
// //         controller:   controller,
// //         maxLines:     maxLines,
// //         readOnly:     readOnly,
// //         keyboardType: keyboardType,
// //         validator:    validator,
// //         style: TextStyle(
// //           color:      AppColors.textPrimary,
// //           fontSize:   _responsiveFontSize(13),
// //           fontWeight: FontWeight.w500,
// //         ),
// //         decoration: InputDecoration(
// //           labelText: label,
// //           hintText:  hint,
// //           labelStyle: TextStyle(
// //             color:    iconColor,
// //             fontSize: _responsiveFontSize(12),
// //             fontWeight: FontWeight.w600,
// //           ),
// //           hintStyle: TextStyle(
// //             color:    AppColors.textSecondary,
// //             fontSize: _responsiveFontSize(12),
// //           ),
// //           prefixIcon: Icon(icon, color: iconColor, size: 20),
// //           suffixIcon: readOnly
// //               ? Icon(Icons.lock_outline_rounded,
// //               color: AppColors.textSecondary.withOpacity(0.4), size: 16)
// //               : null,
// //           filled:      readOnly,
// //           fillColor:   readOnly
// //               ? AppColors.surface.withOpacity(0.6)
// //               : Colors.transparent,
// //           border:         InputBorder.none,
// //           contentPadding: EdgeInsets.symmetric(
// //               horizontal: _responsivePadding(), vertical: _responsiveSpacing()),
// //           errorStyle: TextStyle(fontSize: _responsiveFontSize(10)),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── Dropdown ────────────────────────────────────────────────────────────────
// //   Widget _buildDropdown({
// //     required String         label,
// //     required String         value,
// //     required List<String>   items,
// //     required IconData       icon,
// //     required Color          color,
// //     required void Function(String?) onChanged,
// //   }) {
// //     return Container(
// //       padding: EdgeInsets.symmetric(
// //           horizontal: _responsivePadding() * 0.75, vertical: 4),
// //       decoration: BoxDecoration(
// //         color:        AppColors.cardBg,
// //         borderRadius: BorderRadius.circular(14),
// //         border:       Border.all(color: AppColors.divider),
// //         boxShadow: [
// //           BoxShadow(
// //             color:      Colors.black.withOpacity(0.03),
// //             blurRadius: 8,
// //             offset:     const Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.only(top: 8, left: 4),
// //             child: Text(
// //               label,
// //               style: TextStyle(
// //                 color:      color,
// //                 fontSize:   _responsiveFontSize(10),
// //                 fontWeight: FontWeight.w600,
// //               ),
// //             ),
// //           ),
// //           DropdownButtonHideUnderline(
// //             child: DropdownButton<String>(
// //               value:         value,
// //               isExpanded:    true,
// //               icon:          Icon(Icons.keyboard_arrow_down_rounded,
// //                   color: color, size: 18),
// //               style: TextStyle(
// //                 color:      AppColors.textPrimary,
// //                 fontSize:   _responsiveFontSize(13),
// //                 fontWeight: FontWeight.w600,
// //               ),
// //               onChanged:     onChanged,
// //               items: items.map((item) {
// //                 return DropdownMenuItem(
// //                   value: item,
// //                   child: Row(
// //                     children: [
// //                       Icon(icon, size: 13,
// //                           color: item == value ? color : AppColors.textSecondary),
// //                       const SizedBox(width: 6),
// //                       Text(item),
// //                     ],
// //                   ),
// //                 );
// //               }).toList(),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ── Date picker tile ────────────────────────────────────────────────────────
// //   Widget _buildDatePicker() {
// //     return GestureDetector(
// //       onTap: _pickDate,
// //       child: Container(
// //         padding: EdgeInsets.symmetric(
// //             horizontal: _responsivePadding(),
// //             vertical: _responsiveSpacing()),
// //         decoration: BoxDecoration(
// //           color:        AppColors.cardBg,
// //           borderRadius: BorderRadius.circular(14),
// //           border:       Border.all(
// //             color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
// //           ),
// //           boxShadow: [
// //             BoxShadow(
// //               color:      Colors.black.withOpacity(0.03),
// //               blurRadius: 8,
// //               offset:     const Offset(0, 3),
// //             ),
// //           ],
// //         ),
// //         child: Row(
// //           children: [
// //             Icon(Icons.calendar_month_rounded,
// //                 color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
// //                 size: 20),
// //             SizedBox(width: _responsiveSpacing()),
// //             Expanded(
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Text(
// //                     'Due Date',
// //                     style: TextStyle(
// //                       color:      _dueDate != null
// //                           ? AppColors.greenTeal
// //                           : AppColors.textSecondary,
// //                       fontSize:   _responsiveFontSize(10),
// //                       fontWeight: FontWeight.w600,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 2),
// //                   Text(
// //                     _dueDate == null
// //                         ? 'Tap to select due date'
// //                         : DateFormat('dd MMM yyyy').format(_dueDate!),
// //                     style: TextStyle(
// //                       color:      _dueDate == null
// //                           ? AppColors.textSecondary
// //                           : AppColors.textPrimary,
// //                       fontSize:   _responsiveFontSize(13),
// //                       fontWeight: FontWeight.w600,
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //             Icon(Icons.arrow_forward_ios_rounded,
// //                 color: AppColors.textSecondary, size: 14),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── Submit button ───────────────────────────────────────────────────────────
// //   Widget _buildSubmitButton() {
// //     return Obx(() => GestureDetector(
// //       onTap: _vm.isSubmitting.value ? null : _submit,
// //       child: Container(
// //         width:  double.infinity,
// //         height: _isMobile ? 48 : 54,
// //         decoration: BoxDecoration(
// //           gradient: _vm.isSubmitting.value
// //               ? LinearGradient(colors: [
// //             AppColors.cyan.withOpacity(0.5),
// //             AppColors.greenTeal.withOpacity(0.5),
// //           ])
// //               : const LinearGradient(
// //             colors: [AppColors.cyan, AppColors.greenTeal],
// //             begin:  Alignment.centerLeft,
// //             end:    Alignment.centerRight,
// //           ),
// //           borderRadius: BorderRadius.circular(16),
// //           boxShadow: [
// //             BoxShadow(
// //               color:      AppColors.cyan.withOpacity(0.35),
// //               blurRadius: 14,
// //               offset:     const Offset(0, 5),
// //             ),
// //           ],
// //         ),
// //         child: Center(
// //           child: _vm.isSubmitting.value
// //               ? Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               const SizedBox(
// //                 width: 18, height: 18,
// //                 child: CircularProgressIndicator(
// //                     color: Colors.white, strokeWidth: 2),
// //               ),
// //               SizedBox(width: _responsiveSpacing()),
// //               Text('Submitting...',
// //                   style: TextStyle(
// //                     color:      Colors.white,
// //                     fontSize:   _responsiveFontSize(15),
// //                     fontWeight: FontWeight.w700,
// //                   )),
// //             ],
// //           )
// //               : Row(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               const Icon(Icons.cloud_upload_rounded,
// //                   color: Colors.white, size: 20),
// //               SizedBox(width: _responsiveSpacing()),
// //               Text('Submit Task',
// //                   style: TextStyle(
// //                     color:      Colors.white,
// //                     fontSize:   _responsiveFontSize(15),
// //                     fontWeight: FontWeight.w700,
// //                     letterSpacing: 0.3,
// //                   )),
// //             ],
// //           ),
// //         ),
// //       ),
// //     ));
// //   }
// //
// //   // ── Helpers ─────────────────────────────────────────────────────────────────
// //   Widget _sectionHeader(String title, IconData icon, Color color) {
// //     return Row(children: [
// //       Container(
// //           width: 4, height: 20,
// //           decoration: BoxDecoration(
// //               gradient:     AppColors.brandGradient,
// //               borderRadius: BorderRadius.circular(2))),
// //       SizedBox(width: _responsiveSpacing() * 0.5),
// //       Container(
// //         width: 28, height: 28,
// //         decoration: BoxDecoration(
// //             color:        color.withOpacity(0.10),
// //             borderRadius: BorderRadius.circular(8)),
// //         child: Icon(icon, size: 15, color: color),
// //       ),
// //       SizedBox(width: _responsiveSpacing() * 0.5),
// //       Expanded(
// //         child: Text(title,
// //             style: TextStyle(
// //                 color:      AppColors.primary,
// //                 fontSize:   _responsiveFontSize(13),
// //                 fontWeight: FontWeight.w700,
// //                 letterSpacing: 0.3)),
// //       ),
// //     ]);
// //   }
// //
// //   Widget _decorCircle(double size, Color color, double opacity) => Container(
// //     width: size, height: size,
// //     decoration: BoxDecoration(
// //       shape: BoxShape.circle,
// //       color: color.withOpacity(opacity),
// //     ),
// //   );
// //
// //   Color _statusColor(String s) {
// //     switch (s.toLowerCase()) {
// //       case 'completed':  return AppColors.greenTeal;
// //       case 'in progress': return AppColors.cyan;
// //       default:           return AppColors.warning;
// //     }
// //   }
// //
// //   Color _priorityColor(String p) {
// //     switch (p.toLowerCase()) {
// //       case 'high':   return const Color(0xFFEF4444);
// //       case 'medium': return AppColors.warning;
// //       default:       return AppColors.greenTeal;
// //     }
// //   }
// // }
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/task_view_model.dart';
//
// class CreateTaskScreen extends StatefulWidget {
//   const CreateTaskScreen({super.key});
//
//   @override
//   State<CreateTaskScreen> createState() => _CreateTaskScreenState();
// }
//
// class _CreateTaskScreenState extends State<CreateTaskScreen>
//     with SingleTickerProviderStateMixin {
//   final TaskViewModel _vm = Get.find<TaskViewModel>();
//
//   // ── Double-tap guard ───────────────────────────────────────────────────────
//   bool _isPosting = false;
//
//   // ── Controllers ────────────────────────────────────────────────────────────
//   final _formKey            = GlobalKey<FormState>();
//   final _empIdCtrl          = TextEditingController();
//   final _empNameCtrl        = TextEditingController();
//   final _taskTitleCtrl      = TextEditingController();
//   final _taskDescCtrl       = TextEditingController();
//   final _commentsCtrl       = TextEditingController();
//
//   // ── Dropdown values ─────────────────────────────────────────────────────────
//   String _status   = 'Open';
//   String _priority = 'medium';
//   String _taskType = 'SELF'; // ✅ NEW — matches previous default in TaskViewModel.createTask()
//
//   final List<String> _statusOptions   = ['Open', 'In Progress', 'Done', 'Cancel'];
//   final List<String> _priorityOptions = ['low', 'medium', 'high'];
//   final List<String> _taskTypeOptions = ['SELF', 'ok', 'OFFICE', 'OTHER']; // ✅ NEW
//
//   // ── Date ───────────────────────────────────────────────────────────────────
//   DateTime? _dueDate;
//   String get _dueDateStr =>
//       _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();
//
//   // ── Animation ──────────────────────────────────────────────────────────────
//   late AnimationController _fadeCtrl;
//   late Animation<double>    _fadeAnim;
//
//   // ── Initialization flag ────────────────────────────────────────────────────
//   bool _isInitialized = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimation();
//     _loadEmployeeData();
//   }
//
//   void _initializeAnimation() {
//     if (!_isInitialized) {
//       _fadeCtrl = AnimationController(
//           vsync: this, duration: const Duration(milliseconds: 450));
//       _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//       _fadeCtrl.forward();
//       _isInitialized = true;
//     }
//   }
//
//   Future<void> _loadEmployeeData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final empId   = prefs.getString('userId')   ?? '';
//     final empName = prefs.getString('userName') ?? '';
//     if (mounted) {
//       setState(() {
//         _empIdCtrl.text   = empId;
//         _empNameCtrl.text = empName;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _empIdCtrl.dispose();
//     _empNameCtrl.dispose();
//     _taskTitleCtrl.dispose();
//     _taskDescCtrl.dispose();
//     _commentsCtrl.dispose();
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── Responsive helpers ─────────────────────────────────────────────────────
//   double get _screenWidth => MediaQuery.of(context).size.width;
//   double get _screenHeight => MediaQuery.of(context).size.height;
//   bool get _isMobile => _screenWidth < 600;
//   bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
//   bool get _isDesktop => _screenWidth >= 900;
//
//   double _responsivePadding() {
//     if (_isMobile) return 16;
//     if (_isTablet) return 20;
//     return 24;
//   }
//
//   double _responsiveSpacing() {
//     if (_isMobile) return 14;
//     if (_isTablet) return 16;
//     return 18;
//   }
//
//   double _responsiveFontSize(double mobileSize) {
//     if (_isMobile) return mobileSize;
//     if (_isTablet) return mobileSize + 1;
//     return mobileSize + 2;
//   }
//
//   // ── Date picker ────────────────────────────────────────────────────────────
//   Future<void> _pickDate() async {
//     final picked = await showDatePicker(
//       context:     context,
//       initialDate: DateTime.now().add(const Duration(days: 1)),
//       firstDate:   DateTime.now(),
//       lastDate:    DateTime.now().add(const Duration(days: 365)),
//       builder: (ctx, child) {
//         return Theme(
//           data: Theme.of(ctx).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary:   AppColors.cyan,
//               onPrimary: Colors.white,
//               surface:   Colors.white,
//               onSurface: AppColors.textPrimary,
//             ),
//             dialogBackgroundColor: Colors.white,
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null) setState(() => _dueDate = picked);
//   }
//
//   // ── Submit ─────────────────────────────────────────────────────────────────
//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_dueDate == null) {
//       Get.showSnackbar(const GetSnackBar(
//         message:         'Please select a due date.',
//         duration:        Duration(seconds: 2),
//         backgroundColor: AppColors.warning,
//         borderRadius:    10,
//         margin:          EdgeInsets.all(12),
//         icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
//       ));
//       return;
//     }
//
//     if (_isPosting) return;
//     _isPosting = true;
//
//     final success = await _vm.createTask(
//       empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
//       empName:         _empNameCtrl.text.trim(),
//       taskTitle:       _taskTitleCtrl.text.trim(),
//       taskDescription: _taskDescCtrl.text.trim(),
//       status:          _status,
//       priority:        _priority,
//       dueDate:         _dueDateStr,
//       comments:        _commentsCtrl.text.trim(),
//       taskType:        _taskType, // ✅ NEW — sends the dropdown-selected type
//     );
//
//     _isPosting = false;
//
//     if (success) {
//       Get.back();
//       await Future.delayed(const Duration(milliseconds: 300));
//       Get.showSnackbar(const GetSnackBar(
//         message:         'Task created successfully!',
//         duration:        Duration(seconds: 3),
//         backgroundColor: AppColors.greenTeal,
//         borderRadius:    10,
//         margin:          EdgeInsets.all(12),
//         icon:            Icon(Icons.check_circle_outline_rounded,
//             color: Colors.white),
//       ));
//     } else {
//       Get.showSnackbar(GetSnackBar(
//         message:         _vm.errorMessage.value.isNotEmpty
//             ? _vm.errorMessage.value
//             : 'Something went wrong.',
//         duration:        const Duration(seconds: 3),
//         backgroundColor: const Color(0xFFEF4444),
//         borderRadius:    10,
//         margin:          const EdgeInsets.all(12),
//         icon:            const Icon(Icons.error_outline_rounded,
//             color: Colors.white),
//       ));
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     // Ensure animation is initialized before build
//     _initializeAnimation();
//
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor:          Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 padding: EdgeInsets.fromLTRB(
//                   _responsivePadding(),
//                   _responsiveSpacing() + 10,
//                   _responsivePadding(),
//                   _responsiveSpacing() + 26,
//                 ),
//                 child: _isDesktop
//                     ? _buildDesktopLayout()
//                     : _buildMobileTabletLayout(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Desktop Layout (2-column) ──────────────────────────────────────────────
//   Widget _buildDesktopLayout() {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//           child: _buildFormColumn(isLeftColumn: true),
//         ),
//         SizedBox(width: _responsiveSpacing() * 2),
//         Expanded(
//           child: _buildFormColumn(isLeftColumn: false),
//         ),
//       ],
//     );
//   }
//
//   // ── Mobile/Tablet Layout (single column) ───────────────────────────────────
//   Widget _buildMobileTabletLayout() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _sectionHeader('Employee Info',
//               Icons.person_rounded, AppColors.skyBlueDk),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller:  _empIdCtrl,
//             label:       'Employee ID',
//             hint:        'Loading...',
//             icon:        Icons.badge_rounded,
//             iconColor:   AppColors.skyBlueDk,
//             readOnly:    true,
//             validator:   (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Employee ID not found' : null,
//             keyboardType: TextInputType.number,
//           ),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _empNameCtrl,
//             label:      'Employee Name',
//             hint:       'Loading...',
//             icon:       Icons.person_outline_rounded,
//             iconColor:  AppColors.skyBlueDk,
//             readOnly:   true,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Employee name not found' : null,
//           ),
//           SizedBox(height: _responsiveSpacing() * 1.5),
//           _sectionHeader('Task Details',
//               Icons.task_alt_rounded, AppColors.cyan),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _taskTitleCtrl,
//             label:      'Task Title',
//             hint:       'Enter task title',
//             icon:       Icons.title_rounded,
//             iconColor:  AppColors.cyan,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Task title is required' : null,
//           ),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _taskDescCtrl,
//             label:      'Task Description',
//             hint:       'Describe the task in detail...',
//             icon:       Icons.description_rounded,
//             iconColor:  AppColors.cyan,
//             maxLines:   _isMobile ? 3 : 4,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Description is required' : null,
//           ),
//           SizedBox(height: _responsiveSpacing() * 1.5),
//           _sectionHeader('Status & Priority',
//               Icons.tune_rounded, AppColors.greenTeal),
//           SizedBox(height: _responsiveSpacing()),
//           _buildStatusPriorityRow(),
//           SizedBox(height: _responsiveSpacing()),
//           _buildDatePicker(),
//           SizedBox(height: _responsiveSpacing() * 1.5),
//           _sectionHeader('Comments',
//               Icons.comment_rounded, AppColors.cyanBright),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _commentsCtrl,
//             label:      'Comments (Optional)',
//             hint:       'Add any notes or remarks...',
//             icon:       Icons.sticky_note_2_outlined,
//             iconColor:  AppColors.cyanBright,
//             maxLines:   _isMobile ? 2 : 3,
//           ),
//           SizedBox(height: _responsiveSpacing() * 2),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }
//
//   // ── Desktop form column ────────────────────────────────────────────────────
//   Widget _buildFormColumn({required bool isLeftColumn}) {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: isLeftColumn
//             ? [
//           _sectionHeader('Employee Info',
//               Icons.person_rounded, AppColors.skyBlueDk),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller:  _empIdCtrl,
//             label:       'Employee ID',
//             hint:        'Loading...',
//             icon:        Icons.badge_rounded,
//             iconColor:   AppColors.skyBlueDk,
//             readOnly:    true,
//             validator:   (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Employee ID not found' : null,
//             keyboardType: TextInputType.number,
//           ),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _empNameCtrl,
//             label:      'Employee Name',
//             hint:       'Loading...',
//             icon:       Icons.person_outline_rounded,
//             iconColor:  AppColors.skyBlueDk,
//             readOnly:   true,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Employee name not found' : null,
//           ),
//           SizedBox(height: _responsiveSpacing() * 1.5),
//           _sectionHeader('Task Details',
//               Icons.task_alt_rounded, AppColors.cyan),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _taskTitleCtrl,
//             label:      'Task Title',
//             hint:       'Enter task title',
//             icon:       Icons.title_rounded,
//             iconColor:  AppColors.cyan,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Task title is required' : null,
//           ),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _taskDescCtrl,
//             label:      'Task Description',
//             hint:       'Describe the task in detail...',
//             icon:       Icons.description_rounded,
//             iconColor:  AppColors.cyan,
//             maxLines:   4,
//             validator:  (v) =>
//             (v == null || v.trim().isEmpty)
//                 ? 'Description is required' : null,
//           ),
//         ]
//             : [
//           _sectionHeader('Status & Priority',
//               Icons.tune_rounded, AppColors.greenTeal),
//           SizedBox(height: _responsiveSpacing()),
//           _buildStatusPriorityColumn(),
//           SizedBox(height: _responsiveSpacing()),
//           _buildDatePicker(),
//           SizedBox(height: _responsiveSpacing() * 1.5),
//           _sectionHeader('Comments',
//               Icons.comment_rounded, AppColors.cyanBright),
//           SizedBox(height: _responsiveSpacing()),
//           _buildTextField(
//             controller: _commentsCtrl,
//             label:      'Comments (Optional)',
//             hint:       'Add any notes or remarks...',
//             icon:       Icons.sticky_note_2_outlined,
//             iconColor:  AppColors.cyanBright,
//             maxLines:   3,
//           ),
//           SizedBox(height: _responsiveSpacing() * 2),
//           _buildSubmitButton(),
//         ],
//       ),
//     );
//   }
//
//   // ── Status & Priority Row (mobile/tablet) ──────────────────────────────────
//   Widget _buildStatusPriorityRow() {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: _buildDropdown(
//                 label:    'Status',
//                 value:    _status,
//                 items:    _statusOptions,
//                 icon:     Icons.circle_rounded,
//                 color:    _statusColor(_status),
//                 onChanged: (v) => setState(() => _status = v!),
//               ),
//             ),
//             SizedBox(width: _responsiveSpacing()),
//             Expanded(
//               child: _buildDropdown(
//                 label:    'Priority',
//                 value:    _priority,
//                 items:    _priorityOptions,
//                 icon:     Icons.flag_rounded,
//                 color:    _priorityColor(_priority),
//                 onChanged: (v) => setState(() => _priority = v!),
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: _responsiveSpacing()),
//         // ✅ NEW — Task Type dropdown
//         _buildDropdown(
//           label:    'Task Type',
//           value:    _taskType,
//           items:    _taskTypeOptions,
//           icon:     Icons.category_rounded,
//           color:    AppColors.primary,
//           onChanged: (v) => setState(() => _taskType = v!),
//         ),
//       ],
//     );
//   }
//
//   // ── Status & Priority Column (desktop) ─────────────────────────────────────
//   Widget _buildStatusPriorityColumn() {
//     return Column(
//       children: [
//         _buildDropdown(
//           label:    'Status',
//           value:    _status,
//           items:    _statusOptions,
//           icon:     Icons.circle_rounded,
//           color:    _statusColor(_status),
//           onChanged: (v) => setState(() => _status = v!),
//         ),
//         SizedBox(height: _responsiveSpacing()),
//         _buildDropdown(
//           label:    'Priority',
//           value:    _priority,
//           items:    _priorityOptions,
//           icon:     Icons.flag_rounded,
//           color:    _priorityColor(_priority),
//           onChanged: (v) => setState(() => _priority = v!),
//         ),
//         SizedBox(height: _responsiveSpacing()),
//         // ✅ NEW — Task Type dropdown
//         _buildDropdown(
//           label:    'Task Type',
//           value:    _taskType,
//           items:    _taskTypeOptions,
//           icon:     Icons.category_rounded,
//           color:    AppColors.primary,
//           onChanged: (v) => setState(() => _taskType = v!),
//         ),
//       ],
//     );
//   }
//
//   // ── Header ─────────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
//           begin:  Alignment.topLeft,
//           end:    Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft:  Radius.circular(36),
//           bottomRight: Radius.circular(36),
//         ),
//       ),
//       child: Stack(
//         children: [
//           Positioned(top: -50, right: -30,
//               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
//           Positioned(bottom: -40, left: -20,
//               child: _decorCircle(130, Colors.white, 0.10)),
//           SafeArea(
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(
//                 _responsivePadding(),
//                 12,
//                 _responsivePadding(),
//                 _responsiveSpacing() + 4,
//               ),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(10),
//                         border:       Border.all(color: Colors.white.withOpacity(0.18)),
//                       ),
//                       child: const Icon(Icons.arrow_back_ios_new_rounded,
//                           color: Colors.white, size: 18),
//                     ),
//                   ),
//                   SizedBox(width: _responsiveSpacing()),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Create Task',
//                             style: TextStyle(
//                               color:      Colors.white,
//                               fontSize:   _responsiveFontSize(18),
//                               fontWeight: FontWeight.w800,
//                               letterSpacing: 0.2,
//                             )),
//                         Text('Assign a new task to an employee',
//                             style: TextStyle(
//                               color:      const Color(0xAAFFFFFF),
//                               fontSize:   _responsiveFontSize(11),
//                               fontWeight: FontWeight.w400,
//                             )),
//                       ],
//                     ),
//                   ),
//                   Container(
//                     width: 42, height: 42,
//                     decoration: BoxDecoration(
//                       color:        Colors.white.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(10),
//                       border:       Border.all(color: Colors.white.withOpacity(0.18)),
//                     ),
//                     child: const Icon(Icons.add_task_rounded,
//                         color: Colors.white, size: 22),
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
//   // ── Text field ─────────────────────────────────────────────────────────────
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String                label,
//     required String                hint,
//     required IconData              icon,
//     required Color                 iconColor,
//     int                            maxLines  = 1,
//     bool                           readOnly  = false,
//     String? Function(String?)?     validator,
//     TextInputType                  keyboardType = TextInputType.text,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color:        AppColors.cardBg,
//         borderRadius: BorderRadius.circular(14),
//         border:       Border.all(color: AppColors.divider),
//         boxShadow: [
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.03),
//             blurRadius: 8,
//             offset:     const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: TextFormField(
//         controller:   controller,
//         maxLines:     maxLines,
//         readOnly:     readOnly,
//         keyboardType: keyboardType,
//         validator:    validator,
//         style: TextStyle(
//           color:      AppColors.textPrimary,
//           fontSize:   _responsiveFontSize(13),
//           fontWeight: FontWeight.w500,
//         ),
//         decoration: InputDecoration(
//           labelText: label,
//           hintText:  hint,
//           labelStyle: TextStyle(
//             color:    iconColor,
//             fontSize: _responsiveFontSize(12),
//             fontWeight: FontWeight.w600,
//           ),
//           hintStyle: TextStyle(
//             color:    AppColors.textSecondary,
//             fontSize: _responsiveFontSize(12),
//           ),
//           prefixIcon: Icon(icon, color: iconColor, size: 20),
//           suffixIcon: readOnly
//               ? Icon(Icons.lock_outline_rounded,
//               color: AppColors.textSecondary.withOpacity(0.4), size: 16)
//               : null,
//           filled:      readOnly,
//           fillColor:   readOnly
//               ? AppColors.surface.withOpacity(0.6)
//               : Colors.transparent,
//           border:         InputBorder.none,
//           contentPadding: EdgeInsets.symmetric(
//               horizontal: _responsivePadding(), vertical: _responsiveSpacing()),
//           errorStyle: TextStyle(fontSize: _responsiveFontSize(10)),
//         ),
//       ),
//     );
//   }
//
//   // ── Dropdown ────────────────────────────────────────────────────────────────
//   Widget _buildDropdown({
//     required String         label,
//     required String         value,
//     required List<String>   items,
//     required IconData       icon,
//     required Color          color,
//     required void Function(String?) onChanged,
//   }) {
//     return Container(
//       padding: EdgeInsets.symmetric(
//           horizontal: _responsivePadding() * 0.75, vertical: 4),
//       decoration: BoxDecoration(
//         color:        AppColors.cardBg,
//         borderRadius: BorderRadius.circular(14),
//         border:       Border.all(color: AppColors.divider),
//         boxShadow: [
//           BoxShadow(
//             color:      Colors.black.withOpacity(0.03),
//             blurRadius: 8,
//             offset:     const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(top: 8, left: 4),
//             child: Text(
//               label,
//               style: TextStyle(
//                 color:      color,
//                 fontSize:   _responsiveFontSize(10),
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           DropdownButtonHideUnderline(
//             child: DropdownButton<String>(
//               value:         value,
//               isExpanded:    true,
//               icon:          Icon(Icons.keyboard_arrow_down_rounded,
//                   color: color, size: 18),
//               style: TextStyle(
//                 color:      AppColors.textPrimary,
//                 fontSize:   _responsiveFontSize(13),
//                 fontWeight: FontWeight.w600,
//               ),
//               onChanged:     onChanged,
//               items: items.map((item) {
//                 return DropdownMenuItem(
//                   value: item,
//                   child: Row(
//                     children: [
//                       Icon(icon, size: 13,
//                           color: item == value ? color : AppColors.textSecondary),
//                       const SizedBox(width: 6),
//                       Text(item),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Date picker tile ────────────────────────────────────────────────────────
//   Widget _buildDatePicker() {
//     return GestureDetector(
//       onTap: _pickDate,
//       child: Container(
//         padding: EdgeInsets.symmetric(
//             horizontal: _responsivePadding(),
//             vertical: _responsiveSpacing()),
//         decoration: BoxDecoration(
//           color:        AppColors.cardBg,
//           borderRadius: BorderRadius.circular(14),
//           border:       Border.all(
//             color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color:      Colors.black.withOpacity(0.03),
//               blurRadius: 8,
//               offset:     const Offset(0, 3),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(Icons.calendar_month_rounded,
//                 color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
//                 size: 20),
//             SizedBox(width: _responsiveSpacing()),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Due Date',
//                     style: TextStyle(
//                       color:      _dueDate != null
//                           ? AppColors.greenTeal
//                           : AppColors.textSecondary,
//                       fontSize:   _responsiveFontSize(10),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     _dueDate == null
//                         ? 'Tap to select due date'
//                         : DateFormat('dd MMM yyyy').format(_dueDate!),
//                     style: TextStyle(
//                       color:      _dueDate == null
//                           ? AppColors.textSecondary
//                           : AppColors.textPrimary,
//                       fontSize:   _responsiveFontSize(13),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(Icons.arrow_forward_ios_rounded,
//                 color: AppColors.textSecondary, size: 14),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Submit button ───────────────────────────────────────────────────────────
//   Widget _buildSubmitButton() {
//     return Obx(() => GestureDetector(
//       onTap: _vm.isSubmitting.value ? null : _submit,
//       child: Container(
//         width:  double.infinity,
//         height: _isMobile ? 48 : 54,
//         decoration: BoxDecoration(
//           gradient: _vm.isSubmitting.value
//               ? LinearGradient(colors: [
//             AppColors.cyan.withOpacity(0.5),
//             AppColors.greenTeal.withOpacity(0.5),
//           ])
//               : const LinearGradient(
//             colors: [AppColors.cyan, AppColors.greenTeal],
//             begin:  Alignment.centerLeft,
//             end:    Alignment.centerRight,
//           ),
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color:      AppColors.cyan.withOpacity(0.35),
//               blurRadius: 14,
//               offset:     const Offset(0, 5),
//             ),
//           ],
//         ),
//         child: Center(
//           child: _vm.isSubmitting.value
//               ? Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const SizedBox(
//                 width: 18, height: 18,
//                 child: CircularProgressIndicator(
//                     color: Colors.white, strokeWidth: 2),
//               ),
//               SizedBox(width: _responsiveSpacing()),
//               Text('Submitting...',
//                   style: TextStyle(
//                     color:      Colors.white,
//                     fontSize:   _responsiveFontSize(15),
//                     fontWeight: FontWeight.w700,
//                   )),
//             ],
//           )
//               : Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.cloud_upload_rounded,
//                   color: Colors.white, size: 20),
//               SizedBox(width: _responsiveSpacing()),
//               Text('Submit Task',
//                   style: TextStyle(
//                     color:      Colors.white,
//                     fontSize:   _responsiveFontSize(15),
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 0.3,
//                   )),
//             ],
//           ),
//         ),
//       ),
//     ));
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────────────
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               gradient:     AppColors.brandGradient,
//               borderRadius: BorderRadius.circular(2))),
//       SizedBox(width: _responsiveSpacing() * 0.5),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color:        color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       SizedBox(width: _responsiveSpacing() * 0.5),
//       Expanded(
//         child: Text(title,
//             style: TextStyle(
//                 color:      AppColors.primary,
//                 fontSize:   _responsiveFontSize(13),
//                 fontWeight: FontWeight.w700,
//                 letterSpacing: 0.3)),
//       ),
//     ]);
//   }
//
//   Widget _decorCircle(double size, Color color, double opacity) => Container(
//     width: size, height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: color.withOpacity(opacity),
//     ),
//   );
//
//   Color _statusColor(String s) {
//     switch (s.toLowerCase()) {
//       case 'done':        return AppColors.greenTeal;
//       case 'in progress': return AppColors.cyan;
//       case 'cancel':      return AppColors.error;
//       default:            return AppColors.warning; // open
//     }
//   }
//
//   Color _priorityColor(String p) {
//     switch (p.toLowerCase()) {
//       case 'high':   return const Color(0xFFEF4444);
//       case 'medium': return AppColors.warning;
//       default:       return AppColors.greenTeal;
//     }
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../ViewModels/task_view_model.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen>
    with SingleTickerProviderStateMixin {
  final TaskViewModel _vm = Get.find<TaskViewModel>();

  // ── Double-tap guard ───────────────────────────────────────────────────────
  bool _isPosting = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey            = GlobalKey<FormState>();
  final _empIdCtrl          = TextEditingController();
  final _empNameCtrl        = TextEditingController();
  final _taskTitleCtrl      = TextEditingController();
  final _taskDescCtrl       = TextEditingController();
  final _commentsCtrl       = TextEditingController();

  // ── Dropdown values ─────────────────────────────────────────────────────────
  // ✅ Status: Open, In Progress, Completed, Cancel
  String _status   = 'Open';
  String _priority = 'medium';
  String _taskType = 'SELF';

  final List<String> _statusOptions   = ['Open', 'In Progress', 'Completed', 'Cancel'];
  final List<String> _priorityOptions = ['low', 'medium', 'high'];
  final List<String> _taskTypeOptions = ['SELF', 'ok', 'OFFICE', 'OTHER'];

  // ── Date ───────────────────────────────────────────────────────────────────
  DateTime? _dueDate;
  String get _dueDateStr =>
      _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;

  // ── Initialization flag ────────────────────────────────────────────────────
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadEmployeeData();
  }

  void _initializeAnimation() {
    if (!_isInitialized) {
      _fadeCtrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450));
      _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
      _fadeCtrl.forward();
      _isInitialized = true;
    }
  }

  Future<void> _loadEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final empId   = prefs.getString('userId')   ?? '';
    final empName = prefs.getString('userName') ?? '';
    if (mounted) {
      setState(() {
        _empIdCtrl.text   = empId;
        _empNameCtrl.text = empName;
      });
    }
  }

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _empNameCtrl.dispose();
    _taskTitleCtrl.dispose();
    _taskDescCtrl.dispose();
    _commentsCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Responsive helpers ─────────────────────────────────────────────────────
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;
  bool get _isMobile => _screenWidth < 600;
  bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
  bool get _isDesktop => _screenWidth >= 900;

  double _responsivePadding() {
    if (_isMobile) return 16;
    if (_isTablet) return 20;
    return 24;
  }

  double _responsiveSpacing() {
    if (_isMobile) return 14;
    if (_isTablet) return 16;
    return 18;
  }

  double _responsiveFontSize(double mobileSize) {
    if (_isMobile) return mobileSize;
    if (_isTablet) return mobileSize + 1;
    return mobileSize + 2;
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary:   AppColors.cyan,
              onPrimary: Colors.white,
              surface:   Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      Get.showSnackbar(const GetSnackBar(
        message:         'Please select a due date.',
        duration:        Duration(seconds: 2),
        backgroundColor: AppColors.warning,
        borderRadius:    10,
        margin:          EdgeInsets.all(12),
        icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
      ));
      return;
    }

    if (_isPosting) return;
    _isPosting = true;

    // ✅ Status is already in correct format (Open, In Progress, Completed, Cancel)
    // ✅ Backend expects: Open, In Progress, Done, Cancel
    // So 'Completed' needs to be converted to 'Done' for backend
    String backendStatus = _status;
    if (_status == 'Completed') {
      backendStatus = 'Done';
    }

    debugPrint('📝 [Create] UI Status: $_status → Backend Status: $backendStatus');

    final success = await _vm.createTask(
      empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
      empName:         _empNameCtrl.text.trim(),
      taskTitle:       _taskTitleCtrl.text.trim(),
      taskDescription: _taskDescCtrl.text.trim(),
      status:          backendStatus,  // Open, In Progress, Done, Cancel
      priority:        _priority,
      dueDate:         _dueDateStr,
      comments:        _commentsCtrl.text.trim(),
      taskType:        _taskType,
    );

    _isPosting = false;

    if (success) {
      Get.back();
      await Future.delayed(const Duration(milliseconds: 300));
      Get.showSnackbar(const GetSnackBar(
        message:         'Task created successfully!',
        duration:        Duration(seconds: 3),
        backgroundColor: AppColors.greenTeal,
        borderRadius:    10,
        margin:          EdgeInsets.all(12),
        icon:            Icon(Icons.check_circle_outline_rounded,
            color: Colors.white),
      ));
    } else {
      Get.showSnackbar(GetSnackBar(
        message:         _vm.errorMessage.value.isNotEmpty
            ? _vm.errorMessage.value
            : 'Something went wrong.',
        duration:        const Duration(seconds: 3),
        backgroundColor: const Color(0xFFEF4444),
        borderRadius:    10,
        margin:          const EdgeInsets.all(12),
        icon:            const Icon(Icons.error_outline_rounded,
            color: Colors.white),
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _initializeAnimation();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  _responsivePadding(),
                  _responsiveSpacing() + 10,
                  _responsivePadding(),
                  _responsiveSpacing() + 26,
                ),
                child: _isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileTabletLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Layout (2-column) ──────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildFormColumn(isLeftColumn: true),
        ),
        SizedBox(width: _responsiveSpacing() * 2),
        Expanded(
          child: _buildFormColumn(isLeftColumn: false),
        ),
      ],
    );
  }

  // ── Mobile/Tablet Layout (single column) ───────────────────────────────────
  Widget _buildMobileTabletLayout() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Employee Info',
              Icons.person_rounded, AppColors.skyBlueDk),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller:  _empIdCtrl,
            label:       'Employee ID',
            hint:        'Loading...',
            icon:        Icons.badge_rounded,
            iconColor:   AppColors.skyBlueDk,
            readOnly:    true,
            validator:   (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee ID not found' : null,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _empNameCtrl,
            label:      'Employee Name',
            hint:       'Loading...',
            icon:       Icons.person_outline_rounded,
            iconColor:  AppColors.skyBlueDk,
            readOnly:   true,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee name not found' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Task Details',
              Icons.task_alt_rounded, AppColors.cyan),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskTitleCtrl,
            label:      'Task Title',
            hint:       'Enter task title',
            icon:       Icons.title_rounded,
            iconColor:  AppColors.cyan,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Task title is required' : null,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskDescCtrl,
            label:      'Task Description',
            hint:       'Describe the task in detail...',
            icon:       Icons.description_rounded,
            iconColor:  AppColors.cyan,
            maxLines:   _isMobile ? 3 : 4,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Description is required' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Status & Priority',
              Icons.tune_rounded, AppColors.greenTeal),
          SizedBox(height: _responsiveSpacing()),
          _buildStatusPriorityRow(),
          SizedBox(height: _responsiveSpacing()),
          _buildDatePicker(),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Comments',
              Icons.comment_rounded, AppColors.cyanBright),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _commentsCtrl,
            label:      'Comments (Optional)',
            hint:       'Add any notes or remarks...',
            icon:       Icons.sticky_note_2_outlined,
            iconColor:  AppColors.cyanBright,
            maxLines:   _isMobile ? 2 : 3,
          ),
          SizedBox(height: _responsiveSpacing() * 2),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ── Desktop form column ────────────────────────────────────────────────────
  Widget _buildFormColumn({required bool isLeftColumn}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isLeftColumn
            ? [
          _sectionHeader('Employee Info',
              Icons.person_rounded, AppColors.skyBlueDk),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller:  _empIdCtrl,
            label:       'Employee ID',
            hint:        'Loading...',
            icon:        Icons.badge_rounded,
            iconColor:   AppColors.skyBlueDk,
            readOnly:    true,
            validator:   (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee ID not found' : null,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _empNameCtrl,
            label:      'Employee Name',
            hint:       'Loading...',
            icon:       Icons.person_outline_rounded,
            iconColor:  AppColors.skyBlueDk,
            readOnly:   true,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee name not found' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Task Details',
              Icons.task_alt_rounded, AppColors.cyan),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskTitleCtrl,
            label:      'Task Title',
            hint:       'Enter task title',
            icon:       Icons.title_rounded,
            iconColor:  AppColors.cyan,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Task title is required' : null,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskDescCtrl,
            label:      'Task Description',
            hint:       'Describe the task in detail...',
            icon:       Icons.description_rounded,
            iconColor:  AppColors.cyan,
            maxLines:   4,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Description is required' : null,
          ),
        ]
            : [
          _sectionHeader('Status & Priority',
              Icons.tune_rounded, AppColors.greenTeal),
          SizedBox(height: _responsiveSpacing()),
          _buildStatusPriorityColumn(),
          SizedBox(height: _responsiveSpacing()),
          _buildDatePicker(),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Comments',
              Icons.comment_rounded, AppColors.cyanBright),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _commentsCtrl,
            label:      'Comments (Optional)',
            hint:       'Add any notes or remarks...',
            icon:       Icons.sticky_note_2_outlined,
            iconColor:  AppColors.cyanBright,
            maxLines:   3,
          ),
          SizedBox(height: _responsiveSpacing() * 2),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ── Status & Priority Row (mobile/tablet) ──────────────────────────────────
  Widget _buildStatusPriorityRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label:    'Status',
                value:    _status,
                items:    _statusOptions,
                icon:     Icons.circle_rounded,
                color:    _statusColor(_status),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
            SizedBox(width: _responsiveSpacing()),
            Expanded(
              child: _buildDropdown(
                label:    'Priority',
                value:    _priority,
                items:    _priorityOptions,
                icon:     Icons.flag_rounded,
                color:    _priorityColor(_priority),
                onChanged: (v) => setState(() => _priority = v!),
              ),
            ),
          ],
        ),
        SizedBox(height: _responsiveSpacing()),
        _buildDropdown(
          label:    'Task Type',
          value:    _taskType,
          items:    _taskTypeOptions,
          icon:     Icons.category_rounded,
          color:    AppColors.primary,
          onChanged: (v) => setState(() => _taskType = v!),
        ),
      ],
    );
  }

  // ── Status & Priority Column (desktop) ─────────────────────────────────────
  Widget _buildStatusPriorityColumn() {
    return Column(
      children: [
        _buildDropdown(
          label:    'Status',
          value:    _status,
          items:    _statusOptions,
          icon:     Icons.circle_rounded,
          color:    _statusColor(_status),
          onChanged: (v) => setState(() => _status = v!),
        ),
        SizedBox(height: _responsiveSpacing()),
        _buildDropdown(
          label:    'Priority',
          value:    _priority,
          items:    _priorityOptions,
          icon:     Icons.flag_rounded,
          color:    _priorityColor(_priority),
          onChanged: (v) => setState(() => _priority = v!),
        ),
        SizedBox(height: _responsiveSpacing()),
        _buildDropdown(
          label:    'Task Type',
          value:    _taskType,
          items:    _taskTypeOptions,
          icon:     Icons.category_rounded,
          color:    AppColors.primary,
          onChanged: (v) => setState(() => _taskType = v!),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30,
              child: _decorCircle(180, AppColors.greenTeal, 0.12)),
          Positioned(bottom: -40, left: -20,
              child: _decorCircle(130, Colors.white, 0.10)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _responsivePadding(),
                12,
                _responsivePadding(),
                _responsiveSpacing() + 4,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  SizedBox(width: _responsiveSpacing()),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Task',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   _responsiveFontSize(18),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            )),
                        Text('Assign a new task to an employee',
                            style: TextStyle(
                              color:      const Color(0xAAFFFFFF),
                              fontSize:   _responsiveFontSize(11),
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.add_task_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text field ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    required Color                 iconColor,
    int                            maxLines  = 1,
    bool                           readOnly  = false,
    String? Function(String?)?     validator,
    TextInputType                  keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller:   controller,
        maxLines:     maxLines,
        readOnly:     readOnly,
        keyboardType: keyboardType,
        validator:    validator,
        style: TextStyle(
          color:      AppColors.textPrimary,
          fontSize:   _responsiveFontSize(13),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          labelStyle: TextStyle(
            color:    iconColor,
            fontSize: _responsiveFontSize(12),
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color:    AppColors.textSecondary,
            fontSize: _responsiveFontSize(12),
          ),
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          suffixIcon: readOnly
              ? Icon(Icons.lock_outline_rounded,
              color: AppColors.textSecondary.withOpacity(0.4), size: 16)
              : null,
          filled:      readOnly,
          fillColor:   readOnly
              ? AppColors.surface.withOpacity(0.6)
              : Colors.transparent,
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: _responsivePadding(), vertical: _responsiveSpacing()),
          errorStyle: TextStyle(fontSize: _responsiveFontSize(10)),
        ),
      ),
    );
  }

  // ── Dropdown ────────────────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String         label,
    required String         value,
    required List<String>   items,
    required IconData       icon,
    required Color          color,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: _responsivePadding() * 0.75, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   _responsiveFontSize(10),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:         value,
              isExpanded:    true,
              icon:          Icon(Icons.keyboard_arrow_down_rounded,
                  color: color, size: 18),
              style: TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   _responsiveFontSize(13),
                fontWeight: FontWeight.w600,
              ),
              onChanged:     onChanged,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 13,
                          color: item == value ? color : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(item),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date picker tile ────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: _responsivePadding(),
            vertical: _responsiveSpacing()),
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
                size: 20),
            SizedBox(width: _responsiveSpacing()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(
                      color:      _dueDate != null
                          ? AppColors.greenTeal
                          : AppColors.textSecondary,
                      fontSize:   _responsiveFontSize(10),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dueDate == null
                        ? 'Tap to select due date'
                        : DateFormat('dd MMM yyyy').format(_dueDate!),
                    style: TextStyle(
                      color:      _dueDate == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize:   _responsiveFontSize(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Submit button ───────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Obx(() => GestureDetector(
      onTap: _vm.isSubmitting.value ? null : _submit,
      child: Container(
        width:  double.infinity,
        height: _isMobile ? 48 : 54,
        decoration: BoxDecoration(
          gradient: _vm.isSubmitting.value
              ? LinearGradient(colors: [
            AppColors.cyan.withOpacity(0.5),
            AppColors.greenTeal.withOpacity(0.5),
          ])
              : const LinearGradient(
            colors: [AppColors.cyan, AppColors.greenTeal],
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      AppColors.cyan.withOpacity(0.35),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _vm.isSubmitting.value
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: _responsiveSpacing()),
              Text('Submitting...',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   _responsiveFontSize(15),
                    fontWeight: FontWeight.w700,
                  )),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: _responsiveSpacing()),
              Text('Submit Task',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   _responsiveFontSize(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient:     AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2))),
      SizedBox(width: _responsiveSpacing() * 0.5),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      SizedBox(width: _responsiveSpacing() * 0.5),
      Expanded(
        child: Text(title,
            style: TextStyle(
                color:      AppColors.primary,
                fontSize:   _responsiveFontSize(13),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    ]);
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  // ✅ Status colors for UI display
  Color _statusColor(String s) {
    switch (s) {
      case 'Open':        return AppColors.warning;
      case 'In Progress': return AppColors.cyan;
      case 'Completed':   return AppColors.greenTeal;
      case 'Cancel':      return AppColors.error;
      default:            return AppColors.warning;
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFEF4444);
      case 'medium': return AppColors.warning;
      default:       return AppColors.greenTeal;
    }
  }
}