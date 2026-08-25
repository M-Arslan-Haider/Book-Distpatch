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
//           color: const Color(0xFF3DAF93).withOpacity(0.25), // teal accent border
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
//                 color: const Color(0xFF3DAF93).withOpacity(0.70),
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
// // ── Sidebar-matched colour palette ──────────────────────────────────────────
// const _kTealLight  = Color(0xFF3DAF93); // navbar _tealLight / sidebar greenTeal
// const _kTealDark   = Color(0xFF1A6E59); // navbar _tealDark  / sidebar primary
// const _kChipBg     = Color(0xFFE8F7F3); // very light teal surface
// const _kChipBorder = Color(0xFFB2DFD4); // soft teal border
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
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//         // Soft teal background — matches sidebar header gradient family
//         color: _kChipBg,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: _kChipBorder,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(
//             icon,
//             size: 13,
//             color: _kTealLight,
//           ),
//           const SizedBox(width: 5),
//           Text(
//             label,
//             style: const TextStyle(
//               fontSize: 12.5,
//               fontWeight: FontWeight.w600,
//               color: _kTealDark,
//             ),
//           ),
//         ],
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
              Flexible(
                child: Text(
                  '$greeting, $firstName ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
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
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 10),

          // EMP ID and Designation chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.badge_outlined,
                label: 'EMP-$id',
              ),
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
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kTealDark,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}