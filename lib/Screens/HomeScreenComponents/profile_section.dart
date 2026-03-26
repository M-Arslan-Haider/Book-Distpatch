
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