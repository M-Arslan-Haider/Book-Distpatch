// //
// // import 'package:flutter/material.dart';
// // import '../../Database/util.dart';
// //
// // class ProfileSection extends StatefulWidget {
// //   const ProfileSection({super.key});
// //
// //   @override
// //   State<ProfileSection> createState() => _ProfileSectionState();
// // }
// //
// // class _ProfileSectionState extends State<ProfileSection> {
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _load();
// //   }
// //
// //   Future<void> _load() async {
// //     await loadEmployeeData();
// //     if (mounted) setState(() {});
// //   }
// //
// //   String _getInitials(String name) {
// //     final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
// //     if (parts.isEmpty) return '?';
// //     if (parts.length == 1) return parts[0][0].toUpperCase();
// //     return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
// //   }
// //   //
// //   // @override
// //   // Widget build(BuildContext context) {
// //   //   final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
// //   //   final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
// //   //   final String id          = emp_id.isNotEmpty ? emp_id : '--';
// //   //   final String initials    = _getInitials(name);
// //   //
// //   //   return Padding(
// //   //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
// //   //     child: Container(
// //   //       padding: const EdgeInsets.all(13),
// //   //       decoration: BoxDecoration(
// //   //         color: Colors.white,
// //   //         borderRadius: BorderRadius.circular(20),
// //   //       ),
// //   //       child: Row(
// //   //         children: [
// //   //           Column(
// //   //             crossAxisAlignment: CrossAxisAlignment.start,
// //   //             children: [
// //   //               const Text(
// //   //                 "GPS Attendance System",
// //   //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //   //               ),
// //   //               const SizedBox(height: 2),
// //   //               Text("ID: $id",
// //   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
// //   //               const SizedBox(height: 2),
// //   //               Text("Name: $name",
// //   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
// //   //               const SizedBox(height: 2),
// //   //               Text("Job: $designation",
// //   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
// //   //             ],
// //   //           ),
// //   //           const Spacer(),
// //   //           CircleAvatar(
// //   //             radius: 40,
// //   //             backgroundColor: const Color(0xFF4354E8),
// //   //             child: ClipOval(
// //   //               child: Image.asset(
// //   //                 'assets/icons/pngicon.png',
// //   //                 width: 80,
// //   //                 height: 80,
// //   //                 fit: BoxFit.cover,
// //   //               ),
// //   //             ),
// //   //           )
// //   //         ],
// //   //       ),
// //   //     ),
// //   //   );
// //   // }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
// //     final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
// //     final String id          = emp_id.isNotEmpty ? emp_id : '--';
// //     final String initials    = _getInitials(name);
// //
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
// //       child: Container(
// //         padding: const EdgeInsets.all(13),
// //         decoration: BoxDecoration(
// //           color: Colors.white,
// //           borderRadius: BorderRadius.circular(20),
// //         ),
// //         child: Row(
// //           children: [
// //             // Wrap with Expanded to constrain width
// //             Expanded(
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   const Text(
// //                     "GPS Workforce Monitor",
// //                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
// //                     overflow: TextOverflow.ellipsis, // Add ellipsis for long text
// //                   ),
// //                   const SizedBox(height: 2),
// //                   Text(
// //                     "ID: $id",
// //                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
// //                     overflow: TextOverflow.ellipsis,
// //                   ),
// //                   const SizedBox(height: 2),
// //                   Text(
// //                     "Name: $name",
// //                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
// //                     overflow: TextOverflow.ellipsis,
// //                   ),
// //                   const SizedBox(height: 2),
// //                   Text(
// //                     "Job: $designation",
// //                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
// //                     overflow: TextOverflow.ellipsis,
// //                   ),
// //                 ],
// //               ),
// //             ),
// //             // Remove Spacer(), use SizedBox for spacing instead
// //             const SizedBox(width: 12),
// //             CircleAvatar(
// //               radius: 40,
// //               backgroundColor: const Color(0xFF4354E8),
// //               child: ClipOval(
// //                 child: Image.asset(
// //                   'assets/icons/download (2)-removebg-preview.jpg',
// //                   width: 80,
// //                   height: 80,
// //                   fit: BoxFit.cover,
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
//
//
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../Database/util.dart';
// import '../../AppColors.dart';
//
// class ProfileSection extends StatefulWidget {
//   const ProfileSection({super.key});
//
//   @override
//   State<ProfileSection> createState() => _ProfileSectionState();
// }
//
// class _ProfileSectionState extends State<ProfileSection> {
//   String _currentDate = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//     _updateDate();
//   }
//
//   void _updateDate() {
//     setState(() {
//       _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
//     });
//   }
//
//   Future<void> _load() async {
//     await loadEmployeeData();
//     if (mounted) setState(() {});
//   }
//
//   String _getGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return 'Good Morning';
//     if (hour < 17) return 'Good Afternoon';
//     return 'Good Evening';
//   }
//
//   String _getGreetingEmoji() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return '👋';
//     if (hour < 17) return '☀️';
//     return '🌙';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final String name = emp_name.isNotEmpty ? emp_name : 'Employee';
//     final String firstName = name.split(' ').first;
//     final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
//     final String id = emp_id.isNotEmpty ? emp_id : '--';
//     final String greeting = _getGreeting();
//     final String emoji = _getGreetingEmoji();
//
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//         border: Border.all(
//           color: AppColors.divider.withOpacity(0.3),
//           width: 1,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Greeting line with emoji
//           Row(
//             children: [
//               Text(
//                 '$greeting, $firstName ',
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: AppColors.textPrimary,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//               Text(
//                 emoji,
//                 style: const TextStyle(fontSize: 15),
//               ),
//             ],
//           ),
//           const SizedBox(height: 4),
//
//           // Full Name
//           Text(
//             name,
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//               color: AppColors.textSecondary,
//               letterSpacing: 0.2,
//             ),
//           ),
//           const SizedBox(height: 10),
//
//           // EMP ID and Designation chips
//           Row(
//             children: [
//               _InfoChip(
//                 icon: Icons.badge_outlined,
//                 label: 'EMP-$id',
//               ),
//               const SizedBox(width: 8),
//               _InfoChip(
//                 icon: Icons.work_outline_rounded,
//                 label: designation,
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//
//           // Date with icon
//           Row(
//             children: [
//               Icon(
//                 Icons.calendar_today_rounded,
//                 size: 13,
//                 color: AppColors.textSecondary.withOpacity(0.6),
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 _currentDate,
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w400,
//                   color: AppColors.textSecondary.withOpacity(0.7),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _InfoChip extends StatelessWidget {
//   final IconData icon;
//   final String label;
//
//   const _InfoChip({
//     required this.icon,
//     required this.label,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0F4FF),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: const Color(0xFFDCE4F5),
//           width: 1,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             size: 13,
//             color: const Color(0xFF5B7ED7),
//           ),
//           const SizedBox(width: 5),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12.5,
//               fontWeight: FontWeight.w500,
//               color: Color(0xFF3A4A6B),
//             ),
//           ),
//         ],
//       ),
//     );
//   }


//
// import 'package:flutter/material.dart';
// import '../../Database/util.dart';
//
// class ProfileSection extends StatefulWidget {
//   const ProfileSection({super.key});
//
//   @override
//   State<ProfileSection> createState() => _ProfileSectionState();
// }
//
// class _ProfileSectionState extends State<ProfileSection> {
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     await loadEmployeeData();
//     if (mounted) setState(() {});
//   }
//
//   String _getInitials(String name) {
//     final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
//     if (parts.isEmpty) return '?';
//     if (parts.length == 1) return parts[0][0].toUpperCase();
//     return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
//   }
//   //
//   // @override
//   // Widget build(BuildContext context) {
//   //   final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
//   //   final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
//   //   final String id          = emp_id.isNotEmpty ? emp_id : '--';
//   //   final String initials    = _getInitials(name);
//   //
//   //   return Padding(
//   //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
//   //     child: Container(
//   //       padding: const EdgeInsets.all(13),
//   //       decoration: BoxDecoration(
//   //         color: Colors.white,
//   //         borderRadius: BorderRadius.circular(20),
//   //       ),
//   //       child: Row(
//   //         children: [
//   //           Column(
//   //             crossAxisAlignment: CrossAxisAlignment.start,
//   //             children: [
//   //               const Text(
//   //                 "GPS Attendance System",
//   //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//   //               ),
//   //               const SizedBox(height: 2),
//   //               Text("ID: $id",
//   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
//   //               const SizedBox(height: 2),
//   //               Text("Name: $name",
//   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
//   //               const SizedBox(height: 2),
//   //               Text("Job: $designation",
//   //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
//   //             ],
//   //           ),
//   //           const Spacer(),
//   //           CircleAvatar(
//   //             radius: 40,
//   //             backgroundColor: const Color(0xFF4354E8),
//   //             child: ClipOval(
//   //               child: Image.asset(
//   //                 'assets/icons/pngicon.png',
//   //                 width: 80,
//   //                 height: 80,
//   //                 fit: BoxFit.cover,
//   //               ),
//   //             ),
//   //           )
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
//     final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
//     final String id          = emp_id.isNotEmpty ? emp_id : '--';
//     final String initials    = _getInitials(name);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
//       child: Container(
//         padding: const EdgeInsets.all(13),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Row(
//           children: [
//             // Wrap with Expanded to constrain width
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "GPS Workforce Monitor",
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     overflow: TextOverflow.ellipsis, // Add ellipsis for long text
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     "ID: $id",
//                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     "Name: $name",
//                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     "Job: $designation",
//                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             // Remove Spacer(), use SizedBox for spacing instead
//             const SizedBox(width: 12),
//             CircleAvatar(
//               radius: 40,
//               backgroundColor: const Color(0xFF4354E8),
//               child: ClipOval(
//                 child: Image.asset(
//                   'assets/icons/download (2)-removebg-preview.jpg',
//                   width: 80,
//                   height: 80,
//                   fit: BoxFit.cover,
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
import 'package:intl/intl.dart';
import '../../Database/util.dart';
import '../../AppColors.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _load();
    _updateDate();
  }

  void _updateDate() {
    setState(() {
      _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    });
  }

  Future<void> _load() async {
    await loadEmployeeData();
    if (mounted) setState(() {});
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '👋';
    if (hour < 17) return '☀️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final String name = emp_name.isNotEmpty ? emp_name : 'Employee';
    final String firstName = name.split(' ').first;
    final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
    final String id = emp_id.isNotEmpty ? emp_id : '--';
    final String greeting = _getGreeting();
    final String emoji = _getGreetingEmoji();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF3DAF93).withOpacity(0.25), // teal accent border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting line with emoji
          Row(
            children: [
              Text(
                '$greeting, $firstName ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                emoji,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Full Name
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),

          // EMP ID and Designation chips
          Row(
            children: [
              _InfoChip(
                icon: Icons.badge_outlined,
                label: 'EMP-$id',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.work_outline_rounded,
                label: designation,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date with icon
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: const Color(0xFF3DAF93).withOpacity(0.70),
              ),
              const SizedBox(width: 6),
              Text(
                _currentDate,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sidebar-matched colour palette ──────────────────────────────────────────
const _kTealLight  = Color(0xFF3DAF93); // navbar _tealLight / sidebar greenTeal
const _kTealDark   = Color(0xFF1A6E59); // navbar _tealDark  / sidebar primary
const _kChipBg     = Color(0xFFE8F7F3); // very light teal surface
const _kChipBorder = Color(0xFFB2DFD4); // soft teal border

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Soft teal background — matches sidebar header gradient family
        color: _kChipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kChipBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: _kTealLight,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kTealDark,
            ),
          ),
        ],
      ),
    );
  }
}