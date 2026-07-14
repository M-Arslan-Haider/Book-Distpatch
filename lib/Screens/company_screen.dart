// import 'package:GPS_Workforce_Monitor/Screens/policy_screen.dart';
// import 'package:flutter/material.dart';
// import 'HomeScreenComponents/app_bottom_navbar.dart';
// import '../company_analytics/company_analytics_screen.dart';
//
// import 'company_help_screen.dart';
// import 'news_screen.dart';
//
//
//
//
// // ═══════════════════════════════════════════════════════════════════════════
// // company_screen.dart
// //
// // Shown when the "Company" tab is tapped on the bottom nav bar.
// // Tabs: News / Policy / Help / Analytics — News/Policy/Help share the same
// // searchable + filterable card-list UI, Analytics shows summary stat tiles.
// //
// // NOTE: News and Policy are now loaded live from the Oracle ORDS APP_NOTIFICATIONS API
// // (see news_screen.dart / policy_service.dart), filtered by MSG_TYPE and START_DATE/END_DATE.
// // _helpItems and _statTiles are still DUMMY/PLACEHOLDER data —
// // replace them with real API data later the same way; the UI and filtering
// // logic will keep working as-is.
// // ═══════════════════════════════════════════════════════════════════════════
//
// enum _CompanyTab { news, policy, help, analytics }
//
// enum _FilterType { all, unread }
//
// class _Tag {
//   final String label;
//   final Color bg;
//   final Color textColor;
//   const _Tag(this.label, this.bg, this.textColor);
// }
//
// class _CompanyItem {
//   final IconData icon;
//   final String title;
//   final String dateTime;
//   final String description;
//   final List<_Tag> tags;
//   final bool isUnread;
//
//   const _CompanyItem({
//     required this.icon,
//     required this.title,
//     required this.dateTime,
//     required this.description,
//     required this.tags,
//     this.isUnread = false,
//   });
//
//
// }
//
// class CompanyScreen extends StatefulWidget {
//   final int currentIndex;
//   final int chatBadgeCount;
//   final ValueChanged<int> onNavTap;
//
//   const CompanyScreen({
//     super.key,
//     required this.currentIndex,
//     required this.onNavTap,
//     this.chatBadgeCount = 0,
//   });
//
//   @override
//   State<CompanyScreen> createState() => _CompanyScreenState();
// }
//
// class _CompanyScreenState extends State<CompanyScreen> {
//   // ── Design tokens ──────────────────────────────────────────────────────
//   static const _bgCream     = Color(0xFFFCF3E7);
//   static const _borderColor = Color(0xFFEAE0CF);
//   static const _teal        = Color(0xFF14B8A6);
//   static const _tealDark    = Color(0xFF0F766E);
//   static const _tealLight   = Color(0xFFD9F5EE);
//   static const _textDark    = Color(0xFF1F2A37);
//   static const _textGray    = Color(0xFF6B7280);
//
//   static const _highBg   = Color(0xFFFCE3E1);
//   static const _highText = Color(0xFFDC4C46);
//   static const _medBg    = Color(0xFFFFF1D6);
//   static const _medText  = Color(0xFFB45309);
//   static const _lowBg    = Color(0xFFE5E7EB);
//   static const _lowText  = Color(0xFF374151);
//   static const _purpleBg = Color(0xFFEDE6FF);
//   static const _purpleTx = Color(0xFF6D28D9);
//   static const _pinkBg   = Color(0xFFFFE4ED);
//   static const _pinkTx   = Color(0xFFBE185D);
//   static const _blueBg   = Color(0xFFDCEBFF);
//   static const _blueTx   = Color(0xFF1E40AF);
//   static const _orangeBg = Color(0xFFFFE6D2);
//   static const _orangeTx = Color(0xFFC2410C);
//
//   _CompanyTab _selectedTab  = _CompanyTab.news;
//   _FilterType _activeFilter = _FilterType.all;
//   String      _searchQuery  = '';
//   bool        _isRefreshing = false;
//
//   // ── Read-state tracking ─────────────────────────────────────────────────
//   // Titles of items the user has tapped (i.e. marked as read).
//   final Set<String> _readTitles = {};
//
//   final TextEditingController _searchController = TextEditingController();
//
//   // ── News — loaded from the Oracle ORDS APP_NOTIFICATIONS API ────────────
//   // (see news_service.dart). Items whose START_DATE/END_DATE window does not
//   // include today are filtered out automatically inside NewsService.fetchNews().
//   List<_CompanyItem> _newsItems = [];
//   bool _newsLoading = true;
//   String? _newsError;
//
//   // ── Policy — loaded from the Oracle ORDS APP_NOTIFICATIONS API ──────────
//   // (see policy_service.dart). Rows with MSG_TYPE = 'policy' that fall within
//   // their START_DATE/END_DATE window are shown here.
//   List<_CompanyItem> _policyItems = [];
//   bool _policyLoading = true;
//   String? _policyError;
//
//   // ── Dummy data — Help ────────────────────────────────────────────────
//   final List<_CompanyItem> _helpItems = const [
//     _CompanyItem(
//       icon: Icons.help_rounded,
//       title: 'How to Mark Attendance',
//       dateTime: '2026-01-10 12:00',
//       description:
//       'Step-by-step guide to checking in and out using the GPS attendance feature.',
//       tags: [_Tag('GUIDE', _tealLight, _tealDark), _Tag('Attendance', _blueBg, _blueTx)],
//       isUnread: true,
//     ),
//     _CompanyItem(
//       icon: Icons.help_rounded,
//       title: 'Applying for Leave',
//       dateTime: '2026-01-08 09:30',
//       description: 'Learn how to submit a leave request and track its approval status.',
//       tags: [_Tag('GUIDE', _tealLight, _tealDark), _Tag('HR', _tealLight, _tealDark)],
//       isUnread: false,
//     ),
//     _CompanyItem(
//       icon: Icons.help_rounded,
//       title: 'Contact IT Support',
//       dateTime: '2026-01-05 16:45',
//       description: 'Facing an app issue? Here is how to reach the IT support team directly.',
//       tags: [_Tag('SUPPORT', _orangeBg, _orangeTx), _Tag('IT', _lowBg, _lowText)],
//       isUnread: false,
//     ),
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadNews();
//     _loadPolicy();
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   List<_CompanyItem> get _baseItems {
//     switch (_selectedTab) {
//       case _CompanyTab.news:
//         return _newsItems;
//       case _CompanyTab.policy:
//         return _policyItems;
//       case _CompanyTab.help:
//         return _helpItems;
//       case _CompanyTab.analytics:
//         return const [];
//     }
//   }
//
//   /// An item is effectively unread when it was originally unread AND hasn't
//   /// been tapped by the user yet.
//   bool _isEffectivelyUnread(_CompanyItem item) =>
//       item.isUnread && !_readTitles.contains(item.title);
//
//   List<_CompanyItem> get _currentItems {
//     var list = _baseItems;
//     if (_activeFilter == _FilterType.unread) {
//       list = list.where((i) => _isEffectivelyUnread(i)).toList();
//     }
//     if (_searchQuery.trim().isNotEmpty) {
//       final q = _searchQuery.trim().toLowerCase();
//       list = list
//           .where((i) =>
//       i.title.toLowerCase().contains(q) ||
//           i.description.toLowerCase().contains(q))
//           .toList();
//     }
//     return list;
//   }
//
//   void _handleRefresh() async {
//     if (_isRefreshing) return;
//     setState(() => _isRefreshing = true);
//     if (_selectedTab == _CompanyTab.news) {
//       await _loadNews();
//     } else if (_selectedTab == _CompanyTab.policy) {
//       await _loadPolicy();
//     } else {
//       // Help still uses placeholder data — unchanged.
//       await Future.delayed(const Duration(milliseconds: 700));
//     }
//     if (mounted) setState(() => _isRefreshing = false);
//   }
//
//   // ── Fetch News from Oracle ORDS (APP_NOTIFICATIONS) ─────────────────────
//   Future<void> _loadNews() async {
//     setState(() {
//       _newsLoading = true;
//       _newsError = null;
//     });
//     try {
//       final companyCode = await NewsService.getStoredCompanyCode();
//       if (companyCode == null || companyCode.isEmpty) {
//         throw Exception('company_code not found in SharedPreferences');
//       }
//       final fetched = await NewsService.fetchNews(companyCode);
//       if (!mounted) return;
//       setState(() {
//         _newsItems = fetched.map(_toCompanyItem).toList();
//         _newsLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _newsError = 'Could not load news. Pull down to retry.';
//         _newsLoading = false;
//       });
//     }
//   }
//
//   _CompanyItem _toCompanyItem(NewsItem n) {
//     return _CompanyItem(
//       icon: Icons.campaign_rounded,
//       title: n.title,
//       dateTime: _formatNewsDate(n.startDate),
//       // MESSAGE is the main notification body; falls back to DESCRIPTION
//       // if MESSAGE happens to be empty for a row.
//       description: n.message.isNotEmpty ? n.message : n.description,
//       // APP_NOTIFICATIONS has no priority/category column in the current
//       // query, so there's nothing to populate the HIGH/HR-style badges
//       // with yet — left empty for now.
//       tags: const [],
//       // IS_READ isn't part of the current SELECT, so every fetched item is
//       // treated as unread until read-tracking is wired up.
//       isUnread: true,
//     );
//   }
//
//   // ── Fetch Policy from Oracle ORDS (APP_NOTIFICATIONS, MSG_TYPE='policy') ──
//   Future<void> _loadPolicy() async {
//     setState(() {
//       _policyLoading = true;
//       _policyError = null;
//     });
//     try {
//       final companyCode = await PolicyService.getStoredCompanyCode();
//       if (companyCode == null || companyCode.isEmpty) {
//         throw Exception('company_code not found in SharedPreferences');
//       }
//       final fetched = await PolicyService.fetchPolicy(companyCode);
//       if (!mounted) return;
//       setState(() {
//         _policyItems = fetched.map(_toPolicyItem).toList();
//         _policyLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _policyError = 'Could not load policies. Pull down to retry.';
//         _policyLoading = false;
//       });
//     }
//   }
//
//   _CompanyItem _toPolicyItem(NewsItem n) {
//     return _CompanyItem(
//       icon: Icons.shield_rounded,
//       title: n.title,
//       dateTime: _formatNewsDate(n.startDate),
//       description: n.message.isNotEmpty ? n.message : n.description,
//       tags: const [],
//       isUnread: true,
//     );
//   }
//
//   String _formatNewsDate(DateTime? d) {
//     if (d == null) return '';
//     const months = [
//       'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
//       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
//     ];
//     return '${d.day} ${months[d.month - 1]} ${d.year}';
//   }
//
//   void _onTabSelected(_CompanyTab tab) {
//     setState(() {
//       _selectedTab = tab;
//       _activeFilter = _FilterType.all;
//       _searchController.clear();
//       _searchQuery = '';
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _bgCream,
//       body: SafeArea(
//         bottom: false,
//         child: Column(
//           children: [
//             _buildHeader(),
//             _buildSegmentedControl(),
//             if (_selectedTab != _CompanyTab.analytics &&
//                 _selectedTab != _CompanyTab.help)
//               _buildUnreadAndControls()
//             else
//               const SizedBox(height: 16),
//             Expanded(
//               child: _selectedTab == _CompanyTab.analytics
//                   ? const  CompanyAnalyticsTab()
//                   : _selectedTab == _CompanyTab.help
//                   ? const CompanyHelpTab()
//                   : _buildList(),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: AppBottomNavBar(
//         currentIndex: widget.currentIndex,
//         chatBadgeCount: widget.chatBadgeCount,
//         onTap: widget.onNavTap,
//       ),
//     );
//   }
//
//   // ── Header ───────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return const Padding(
//       padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
//       child: Align(
//         alignment: Alignment.centerLeft,
//         child: Text(
//           'Company',
//           style: TextStyle(
//             fontSize: 26,
//             fontWeight: FontWeight.w800,
//             color: _textDark,
//             letterSpacing: -0.3,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Segmented control (News / Policy / Help / Analytics) ───────────────
//   Widget _buildSegmentedControl() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: Container(
//         padding: const EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(18),
//           border: Border.all(color: _borderColor),
//         ),
//         child: Row(
//           children: [
//             Expanded(child: _segmentButton(_CompanyTab.news, 'News', Icons.campaign_rounded)),
//             Expanded(child: _segmentButton(_CompanyTab.policy, 'Policy', Icons.shield_outlined)),
//             Expanded(child: _segmentButton(_CompanyTab.help, 'Help', Icons.help_rounded, isHelp: true)),
//             Expanded(child: _segmentButton(_CompanyTab.analytics, 'Analytics', Icons.bar_chart_rounded)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _segmentButton(_CompanyTab tab, String label, IconData icon, {bool isHelp = false}) {
//     final isActive = _selectedTab == tab;
//     return GestureDetector(
//       onTap: () => _onTabSelected(tab),
//       behavior: HitTestBehavior.opaque,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 220),
//         curve: Curves.easeOut,
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         decoration: BoxDecoration(
//           color: isActive ? _teal : Colors.transparent,
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: isActive
//               ? [BoxShadow(color: _teal.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 3))]
//               : [],
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             isHelp
//                 ? Container(
//               width: 18,
//               height: 18,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: isActive ? Colors.white : _textDark,
//               ),
//               child: Icon(
//                 Icons.question_mark_rounded,
//                 size: 11,
//                 color: isActive ? _teal : Colors.white,
//               ),
//             )
//                 : Icon(icon, size: 18, color: isActive ? Colors.white : _textDark),
//             const SizedBox(width: 6),
//             Flexible(
//               child: Text(
//                 label,
//                 overflow: TextOverflow.ellipsis,
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w700,
//                   color: isActive ? Colors.white : _textDark,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── "X unread" + search bar + refresh + filter chips ────────────────────
//   Widget _buildUnreadAndControls() {
//     final unreadCount = _baseItems.where((i) => _isEffectivelyUnread(i)).length;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
//           child: Text(
//             '$unreadCount unread',
//             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _teal),
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   height: 46,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(14),
//                     border: Border.all(color: _borderColor),
//                   ),
//                   child: TextField(
//                     controller: _searchController,
//                     onChanged: (v) => setState(() => _searchQuery = v),
//                     style: const TextStyle(fontSize: 14, color: _textDark),
//                     decoration: const InputDecoration(
//                       hintText: 'Search...',
//                       hintStyle: TextStyle(color: _textGray),
//                       prefixIcon: Icon(Icons.search_rounded, color: _textGray, size: 22),
//                       border: InputBorder.none,
//                       isCollapsed: true,
//                       contentPadding: EdgeInsets.symmetric(vertical: 14),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               GestureDetector(
//                 onTap: _handleRefresh,
//                 child: Container(
//                   width: 46,
//                   height: 46,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(14),
//                     border: Border.all(color: _borderColor),
//                   ),
//                   alignment: Alignment.center,
//                   child: _isRefreshing
//                       ? const SizedBox(
//                     width: 18,
//                     height: 18,
//                     child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
//                   )
//                       : const Icon(Icons.refresh_rounded, color: _textDark, size: 22),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),
//         SizedBox(
//           height: 38,
//           child: ListView(
//             scrollDirection: Axis.horizontal,
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             children: [
//               _filterChip('All', _FilterType.all),
//               const SizedBox(width: 8),
//               _filterChip('Unread', _FilterType.unread),
//             ],
//           ),
//         ),
//         const SizedBox(height: 14),
//       ],
//     );
//   }
//
//   Widget _filterChip(String label, _FilterType type) {
//     final isActive = _activeFilter == type;
//     return GestureDetector(
//       onTap: () => setState(() => _activeFilter = type),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
//         decoration: BoxDecoration(
//           color: isActive ? _teal : Colors.white,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: isActive ? _teal : _borderColor),
//         ),
//         alignment: Alignment.center,
//         child: Text(
//           label,
//           style: TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             color: isActive ? Colors.white : _textDark,
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── List of cards (News / Policy / Help) ────────────────────────────────
//   Widget _buildList() {
//     if (_selectedTab == _CompanyTab.news && _newsLoading) {
//       return const Center(
//         child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
//       );
//     }
//     if (_selectedTab == _CompanyTab.news && _newsError != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.cloud_off_rounded, size: 46, color: _textGray.withOpacity(0.5)),
//             const SizedBox(height: 10),
//             Text(_newsError!, style: const TextStyle(color: _textGray, fontSize: 14)),
//           ],
//         ),
//       );
//     }
//     if (_selectedTab == _CompanyTab.policy && _policyLoading) {
//       return const Center(
//         child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
//       );
//     }
//     if (_selectedTab == _CompanyTab.policy && _policyError != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.cloud_off_rounded, size: 46, color: _textGray.withOpacity(0.5)),
//             const SizedBox(height: 10),
//             Text(_policyError!, style: const TextStyle(color: _textGray, fontSize: 14)),
//           ],
//         ),
//       );
//     }
//     final items = _currentItems;
//     if (items.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.inbox_outlined, size: 46, color: _textGray.withOpacity(0.5)),
//             const SizedBox(height: 10),
//             const Text('Nothing here yet', style: TextStyle(color: _textGray, fontSize: 14)),
//           ],
//         ),
//       );
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
//       itemCount: items.length,
//       itemBuilder: (context, index) {
//         final item = items[index];
//         return GestureDetector(
//           onTap: () {
//             if (_isEffectivelyUnread(item)) {
//               setState(() => _readTitles.add(item.title));
//             }
//           },
//           child: _buildCard(item),
//         );
//       },
//     );
//   }
//
//   Widget _buildCard(_CompanyItem item) {
//     final unread = _isEffectivelyUnread(item);
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _borderColor),
//         boxShadow: [
//           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: IntrinsicHeight(
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Container(width: 4, color: unread ? _teal : Colors.transparent),
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Container(
//                         width: 42,
//                         height: 42,
//                         decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(12)),
//                         child: Icon(item.icon, color: _tealDark, size: 20),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Expanded(
//                                   child: Text(
//                                     item.title,
//                                     style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
//                                   ),
//                                 ),
//                                 if (unread)
//                                   Container(
//                                     width: 8,
//                                     height: 8,
//                                     margin: const EdgeInsets.only(left: 8, top: 5),
//                                     decoration: const BoxDecoration(shape: BoxShape.circle, color: _teal),
//                                   ),
//                               ],
//                             ),
//                             const SizedBox(height: 4),
//                             Text(item.dateTime, style: const TextStyle(fontSize: 12, color: _textGray)),
//                             const SizedBox(height: 10),
//                             Text(
//                               item.description,
//                               style: const TextStyle(fontSize: 13.5, color: _textGray, height: 1.4),
//                             ),
//                             const SizedBox(height: 12),
//                             Wrap(
//                               spacing: 8,
//                               runSpacing: 8,
//                               children: item.tags
//                                   .map((t) => Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//                                 decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8)),
//                                 child: Text(
//                                   t.label,
//                                   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.textColor),
//                                 ),
//                               ))
//                                   .toList(),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
// }

import 'package:book_dispatch/Screens/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import '../company_analytics/company_analytics_screen.dart';

import 'company_help_screen.dart';
import 'news_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// company_screen.dart
//
// Shown when the "Company" tab is tapped on the bottom nav bar.
// Tabs: News / Policy / Help / Analytics — News/Policy/Help share the same
// searchable + filterable card-list UI, Analytics shows summary stat tiles.
//
// NOTE: News and Policy are now loaded live from the Oracle ORDS APP_NOTIFICATIONS API
// (see news_screen.dart / policy_service.dart), filtered by MSG_TYPE and START_DATE/END_DATE.
// _helpItems and _statTiles are still DUMMY/PLACEHOLDER data —
// replace them with real API data later the same way; the UI and filtering
// logic will keep working as-is.
// ═══════════════════════════════════════════════════════════════════════════

enum _CompanyTab { news, policy, help, analytics }

enum _FilterType { all, unread }

class _Tag {
  final String label;
  final Color bg;
  final Color textColor;
  const _Tag(this.label, this.bg, this.textColor);
}

class _CompanyItem {
  final IconData icon;
  final String title;
  final String dateTime;
  final String description;
  final List<_Tag> tags;
  final bool isUnread;

  const _CompanyItem({
    required this.icon,
    required this.title,
    required this.dateTime,
    required this.description,
    required this.tags,
    this.isUnread = false,
  });
}

class CompanyScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const CompanyScreen({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    this.chatBadgeCount = 0,
  });

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Design tokens ──────────────────────────────────────────────────────
  static const _bgCream     = Color(0xFFFCF3E7);
  static const _borderColor = Color(0xFFEAE0CF);
  static const _teal        = Color(0xFF14B8A6);
  static const _tealDark    = Color(0xFF0F766E);
  static const _tealLight   = Color(0xFFD9F5EE);
  static const _textDark    = Color(0xFF1F2A37);
  static const _textGray    = Color(0xFF6B7280);

  static const _highBg   = Color(0xFFFCE3E1);
  static const _highText = Color(0xFFDC4C46);
  static const _medBg    = Color(0xFFFFF1D6);
  static const _medText  = Color(0xFFB45309);
  static const _lowBg    = Color(0xFFE5E7EB);
  static const _lowText  = Color(0xFF374151);
  static const _purpleBg = Color(0xFFEDE6FF);
  static const _purpleTx = Color(0xFF6D28D9);
  static const _pinkBg   = Color(0xFFFFE4ED);
  static const _pinkTx   = Color(0xFFBE185D);
  static const _blueBg   = Color(0xFFDCEBFF);
  static const _blueTx   = Color(0xFF1E40AF);
  static const _orangeBg = Color(0xFFFFE6D2);
  static const _orangeTx = Color(0xFFC2410C);

  _CompanyTab _selectedTab  = _CompanyTab.news;
  _FilterType _activeFilter = _FilterType.all;
  String      _searchQuery  = '';
  bool        _isRefreshing = false;

  // ── Read-state tracking ─────────────────────────────────────────────────
  // Titles of items the user has tapped (i.e. marked as read).
  final Set<String> _readTitles = {};

  final TextEditingController _searchController = TextEditingController();

  // ── User info ────────────────────────────────────────────────────────────
  String _empName = 'Employee';

  // ── News — loaded from the Oracle ORDS APP_NOTIFICATIONS API ────────────
  // (see news_service.dart). Items whose START_DATE/END_DATE window does not
  // include today are filtered out automatically inside NewsService.fetchNews().
  List<_CompanyItem> _newsItems = [];
  bool _newsLoading = true;
  String? _newsError;

  // ── Policy — loaded from the Oracle ORDS APP_NOTIFICATIONS API ──────────
  // (see policy_service.dart). Rows with MSG_TYPE = 'policy' that fall within
  // their START_DATE/END_DATE window are shown here.
  List<_CompanyItem> _policyItems = [];
  bool _policyLoading = true;
  String? _policyError;

  // ── Dummy data — Help ────────────────────────────────────────────────
  final List<_CompanyItem> _helpItems = const [
    _CompanyItem(
      icon: Icons.help_rounded,
      title: 'How to Mark Attendance',
      dateTime: '2026-01-10 12:00',
      description:
      'Step-by-step guide to checking in and out using the GPS attendance feature.',
      tags: [_Tag('GUIDE', _tealLight, _tealDark), _Tag('Attendance', _blueBg, _blueTx)],
      isUnread: true,
    ),
    _CompanyItem(
      icon: Icons.help_rounded,
      title: 'Applying for Leave',
      dateTime: '2026-01-08 09:30',
      description: 'Learn how to submit a leave request and track its approval status.',
      tags: [_Tag('GUIDE', _tealLight, _tealDark), _Tag('HR', _tealLight, _tealDark)],
      isUnread: false,
    ),
    _CompanyItem(
      icon: Icons.help_rounded,
      title: 'Contact IT Support',
      dateTime: '2026-01-05 16:45',
      description: 'Facing an app issue? Here is how to reach the IT support team directly.',
      tags: [_Tag('SUPPORT', _orangeBg, _orangeTx), _Tag('IT', _lowBg, _lowText)],
      isUnread: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadNews();
    _loadPolicy();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empName = prefs.getString('userName') ?? 'Employee';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CompanyItem> get _baseItems {
    switch (_selectedTab) {
      case _CompanyTab.news:
        return _newsItems;
      case _CompanyTab.policy:
        return _policyItems;
      case _CompanyTab.help:
        return _helpItems;
      case _CompanyTab.analytics:
        return const [];
    }
  }

  /// An item is effectively unread when it was originally unread AND hasn't
  /// been tapped by the user yet.
  bool _isEffectivelyUnread(_CompanyItem item) =>
      item.isUnread && !_readTitles.contains(item.title);

  List<_CompanyItem> get _currentItems {
    var list = _baseItems;
    if (_activeFilter == _FilterType.unread) {
      list = list.where((i) => _isEffectivelyUnread(i)).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((i) =>
      i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    if (_selectedTab == _CompanyTab.news) {
      await _loadNews();
    } else if (_selectedTab == _CompanyTab.policy) {
      await _loadPolicy();
    } else {
      // Help still uses placeholder data — unchanged.
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  // ── Fetch News from Oracle ORDS (APP_NOTIFICATIONS) ─────────────────────
  Future<void> _loadNews() async {
    setState(() {
      _newsLoading = true;
      _newsError = null;
    });
    try {
      final companyCode = await NewsService.getStoredCompanyCode();
      if (companyCode == null || companyCode.isEmpty) {
        throw Exception('company_code not found in SharedPreferences');
      }
      final fetched = await NewsService.fetchNews(companyCode);
      if (!mounted) return;
      setState(() {
        _newsItems = fetched.map(_toCompanyItem).toList();
        _newsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newsError = 'Could not load news. Pull down to retry.';
        _newsLoading = false;
      });
    }
  }

  _CompanyItem _toCompanyItem(NewsItem n) {
    return _CompanyItem(
      icon: Icons.campaign_rounded,
      title: n.title,
      dateTime: _formatNewsDate(n.startDate),
      // MESSAGE is the main notification body; falls back to DESCRIPTION
      // if MESSAGE happens to be empty for a row.
      description: n.message.isNotEmpty ? n.message : n.description,
      // APP_NOTIFICATIONS has no priority/category column in the current
      // query, so there's nothing to populate the HIGH/HR-style badges
      // with yet — left empty for now.
      tags: const [],
      // IS_READ isn't part of the current SELECT, so every fetched item is
      // treated as unread until read-tracking is wired up.
      isUnread: true,
    );
  }

  // ── Fetch Policy from Oracle ORDS (APP_NOTIFICATIONS, MSG_TYPE='policy') ──
  Future<void> _loadPolicy() async {
    setState(() {
      _policyLoading = true;
      _policyError = null;
    });
    try {
      final companyCode = await PolicyService.getStoredCompanyCode();
      if (companyCode == null || companyCode.isEmpty) {
        throw Exception('company_code not found in SharedPreferences');
      }
      final fetched = await PolicyService.fetchPolicy(companyCode);
      if (!mounted) return;
      setState(() {
        _policyItems = fetched.map(_toPolicyItem).toList();
        _policyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _policyError = 'Could not load policies. Pull down to retry.';
        _policyLoading = false;
      });
    }
  }

  _CompanyItem _toPolicyItem(NewsItem n) {
    return _CompanyItem(
      icon: Icons.shield_rounded,
      title: n.title,
      dateTime: _formatNewsDate(n.startDate),
      description: n.message.isNotEmpty ? n.message : n.description,
      tags: const [],
      isUnread: true,
    );
  }

  String _formatNewsDate(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _onTabSelected(_CompanyTab tab) {
    setState(() {
      _selectedTab = tab;
      _activeFilter = _FilterType.all;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate user initials
    String userInitials = '?';
    if (_empName.trim().isNotEmpty) {
      final parts = _empName.trim().split(' ');
      if (parts.length >= 2) {
        userInitials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        userInitials = _empName[0].toUpperCase();
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgCream,
      appBar: Navbar(
        userName: _empName,
        userInitials: userInitials,
        scaffoldKey: _scaffoldKey,
        // lastSync: 'Just now', // Optional: pass if you have a sync timestamp
      ),
      drawer: AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSegmentedControl(),
            if (_selectedTab != _CompanyTab.analytics &&
                _selectedTab != _CompanyTab.help)
              _buildUnreadAndControls()
            else
              const SizedBox(height: 16),
            Expanded(
              child: _selectedTab == _CompanyTab.analytics
                  ? const CompanyAnalyticsTab()
                  : _selectedTab == _CompanyTab.help
                  ? const CompanyHelpTab()
                  : _buildList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap: widget.onNavTap,
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Company',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _textDark,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // ── Segmented control (News / Policy / Help / Analytics) ───────────────
  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Expanded(child: _segmentButton(_CompanyTab.news, 'News', Icons.campaign_rounded)),
            Expanded(child: _segmentButton(_CompanyTab.policy, 'Policy', Icons.shield_outlined)),
            Expanded(child: _segmentButton(_CompanyTab.help, 'Help', Icons.help_rounded, isHelp: true)),
            Expanded(child: _segmentButton(_CompanyTab.analytics, 'Analytics', Icons.bar_chart_rounded)),
          ],
        ),
      ),
    );
  }

  Widget _segmentButton(_CompanyTab tab, String label, IconData icon, {bool isHelp = false}) {
    final isActive = _selectedTab == tab;
    return GestureDetector(
      onTap: () => _onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [BoxShadow(color: _teal.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isHelp
                ? Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : _textDark,
              ),
              child: Icon(
                Icons.question_mark_rounded,
                size: 11,
                color: isActive ? _teal : Colors.white,
              ),
            )
                : Icon(icon, size: 18, color: isActive ? Colors.white : _textDark),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : _textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── "X unread" + search bar + refresh + filter chips ────────────────────
  Widget _buildUnreadAndControls() {
    final unreadCount = _baseItems.where((i) => _isEffectivelyUnread(i)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text(
            '$unreadCount unread',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _teal),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 14, color: _textDark),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: _textGray),
                      prefixIcon: Icon(Icons.search_rounded, color: _textGray, size: 22),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _handleRefresh,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderColor),
                  ),
                  alignment: Alignment.center,
                  child: _isRefreshing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
                  )
                      : const Icon(Icons.refresh_rounded, color: _textDark, size: 22),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('All', _FilterType.all),
              const SizedBox(width: 8),
              _filterChip('Unread', _FilterType.unread),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _filterChip(String label, _FilterType type) {
    final isActive = _activeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? _teal : _borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : _textDark,
          ),
        ),
      ),
    );
  }

  // ── List of cards (News / Policy / Help) ────────────────────────────────
  Widget _buildList() {
    if (_selectedTab == _CompanyTab.news && _newsLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
      );
    }
    if (_selectedTab == _CompanyTab.news && _newsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 46, color: _textGray.withOpacity(0.5)),
            const SizedBox(height: 10),
            Text(_newsError!, style: const TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }
    if (_selectedTab == _CompanyTab.policy && _policyLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
      );
    }
    if (_selectedTab == _CompanyTab.policy && _policyError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 46, color: _textGray.withOpacity(0.5)),
            const SizedBox(height: 10),
            Text(_policyError!, style: const TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }
    final items = _currentItems;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 46, color: _textGray.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text('Nothing here yet', style: TextStyle(color: _textGray, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            if (_isEffectivelyUnread(item)) {
              setState(() => _readTitles.add(item.title));
            }
          },
          child: _buildCard(item),
        );
      },
    );
  }

  Widget _buildCard(_CompanyItem item) {
    final unread = _isEffectivelyUnread(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: unread ? _teal : Colors.transparent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: _tealLight, borderRadius: BorderRadius.circular(12)),
                        child: Icon(item.icon, color: _tealDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
                                  ),
                                ),
                                if (unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8, top: 5),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _teal),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(item.dateTime, style: const TextStyle(fontSize: 12, color: _textGray)),
                            const SizedBox(height: 10),
                            Text(
                              item.description,
                              style: const TextStyle(fontSize: 13.5, color: _textGray, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: item.tags
                                  .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  t.label,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.textColor),
                                ),
                              ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
