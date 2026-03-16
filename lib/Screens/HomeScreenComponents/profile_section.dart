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
//   // ── Colors ─────────────────────────────
//   static const Color _containerBlue   = Color(0xFF4354E8);
//   static const Color _textBlue        = Color(0xFF1A5CFF);
//   static const Color _lightBlueShade  = Color(0xFFE6EDFF);
//   static const Color _border          = Color(0xFFD0DBEE);
//   static const Color _onlineGreen     = Color(0xFF10B981);
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
//
//   @override
//   Widget build(BuildContext context) {
//     final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
//     final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
//     final String id          = emp_id.isNotEmpty ? emp_id : '--';
//     final String initials    = _getInitials(name);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white, // Background white
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: _border, width: 1.5),
//           boxShadow: [
//             BoxShadow(
//               color: _containerBlue.withOpacity(0.1),
//               blurRadius: 20,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             // ── Left: Info ───────────────────────────
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // App badge
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: _lightBlueShade,
//                       borderRadius: BorderRadius.circular(20),
//                       border: Border.all(color: _containerBlue.withOpacity(0.3)),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           width: 6,
//                           height: 6,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: _containerBlue,
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         const Text(
//                           'GPS Attendance System',
//                           style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: Color(0xFF4354E8),
//                             letterSpacing: 0.3,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   // Name
//                   Text(
//                     name,
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w800,
//                       color: _textBlue,
//                       letterSpacing: -0.3,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 8),
//                   // ID row
//                   Row(
//                     children: [
//                       const Icon(Icons.badge_outlined, size: 14, color: _textBlue),
//                       const SizedBox(width: 4),
//                       Text(
//                         'ID: $id',
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: _textBlue.withOpacity(0.85),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 6),
//                   // Designation row
//                   Row(
//                     children: [
//                       const Icon(Icons.work_outline_rounded, size: 14, color: _textBlue),
//                       const SizedBox(width: 4),
//                       Flexible(
//                         child: Text(
//                           designation,
//                           style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: _textBlue.withOpacity(0.85),
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//
//             const SizedBox(width: 16),
//
//             // ── Right: Avatar ─────────────────────────
//             Container(
//               width: 76,
//               height: 76,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: _containerBlue, // Blue avatar
//                 boxShadow: [
//                   BoxShadow(
//                     color: _containerBlue.withOpacity(0.3),
//                     blurRadius: 12,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Center(
//                 child: Text(
//                   initials,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 26,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: 1,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//

import 'package:flutter/material.dart';
import '../../Database/util.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await loadEmployeeData();
    if (mounted) setState(() {});
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  //
  // @override
  // Widget build(BuildContext context) {
  //   final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
  //   final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
  //   final String id          = emp_id.isNotEmpty ? emp_id : '--';
  //   final String initials    = _getInitials(name);
  //
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
  //     child: Container(
  //       padding: const EdgeInsets.all(13),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(20),
  //       ),
  //       child: Row(
  //         children: [
  //           Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Text(
  //                 "GPS Attendance System",
  //                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //               ),
  //               const SizedBox(height: 2),
  //               Text("ID: $id",
  //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  //               const SizedBox(height: 2),
  //               Text("Name: $name",
  //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  //               const SizedBox(height: 2),
  //               Text("Job: $designation",
  //                   style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
  //             ],
  //           ),
  //           const Spacer(),
  //           CircleAvatar(
  //             radius: 40,
  //             backgroundColor: const Color(0xFF4354E8),
  //             child: ClipOval(
  //               child: Image.asset(
  //                 'assets/icons/pngicon.png',
  //                 width: 80,
  //                 height: 80,
  //                 fit: BoxFit.cover,
  //               ),
  //             ),
  //           )
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final String name        = emp_name.isNotEmpty ? emp_name : 'Employee';
    final String designation = emp_job.isNotEmpty ? emp_job : 'Staff';
    final String id          = emp_id.isNotEmpty ? emp_id : '--';
    final String initials    = _getInitials(name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Wrap with Expanded to constrain width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "GPS Workforce Monitor",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // Add ellipsis for long text
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "ID: $id",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Name: $name",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Job: $designation",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Remove Spacer(), use SizedBox for spacing instead
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF4354E8),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/download (2)-removebg-preview.jpg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}