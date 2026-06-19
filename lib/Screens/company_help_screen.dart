import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// company_help_tab.dart
//
// Content rendered inside CompanyScreen's body when the "Help" segment is
// selected (see company_screen.dart). Self-contained: info banner, search
// bar, category grid, and a tappable help-topics list.
//
// NOTE: _categories and _topics below are DUMMY/PLACEHOLDER data (same
// convention the old _helpItems list used in company_screen.dart) — replace
// with real API data later; the search/filter UI underneath will keep
// working as-is.
// ═══════════════════════════════════════════════════════════════════════════

class _HelpCategory {
  final String key;
  final IconData icon;
  final String title;
  final String description;

  const _HelpCategory({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _HelpTopic {
  final String categoryKey;
  final String title;
  final String subtitle;
  final List<String> steps;

  const _HelpTopic({
    required this.categoryKey,
    required this.title,
    required this.subtitle,
    required this.steps,
  });
}

class CompanyHelpTab extends StatefulWidget {
  const CompanyHelpTab({super.key});

  @override
  State<CompanyHelpTab> createState() => _CompanyHelpTabState();
}

class _CompanyHelpTabState extends State<CompanyHelpTab> {
  // ── Design tokens — mirrors CompanyScreen's palette for visual consistency ──
  static const _bgCream     = Color(0xFFFCF3E7);
  static const _teal        = Color(0xFF14B8A6);
  static const _tealDark    = Color(0xFF0F766E);
  static const _tealLight   = Color(0xFFD9F5EE);
  static const _borderColor = Color(0xFFEAE0CF);
  static const _textDark    = Color(0xFF1F2A37);
  static const _textGray    = Color(0xFF6B7280);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedCategoryKey;

  // Scroll controller for list view
  final ScrollController _scrollController = ScrollController();
  // Key for the attendance topics section
  final GlobalKey _attendanceSectionKey = GlobalKey();

  // ── Dummy data — Help categories ────────────────────────────────────────
  static const List<_HelpCategory> _categories = [
    _HelpCategory(
      key: 'attendance',
      icon: Icons.event_available_rounded,
      title: 'Attendance',
      description: 'Clock in, clock out and attendance basics.',
    ),
    _HelpCategory(
      key: 'requests',
      icon: Icons.send_rounded,
      title: 'Requests',
      description: 'Leaves, expenses, loans and complaints.',
    ),
    _HelpCategory(
      key: 'tasks',
      icon: Icons.checklist_rounded,
      title: 'Tasks',
      description: 'Working on assigned and self-created tasks.',
    ),
    _HelpCategory(
      key: 'breaks',
      icon: Icons.coffee_rounded,
      title: 'Breaks',
      description: 'Lunch and short break recording.',
    ),
    _HelpCategory(
      key: 'gps',
      icon: Icons.location_on_rounded,
      title: 'GPS & Location',
      description: 'Location services and geo fence.',
    ),
    _HelpCategory(
      key: 'reports',
      icon: Icons.bar_chart_rounded,
      title: 'Reports',
      description: 'Reading analytics and reports.',
    ),
  ];

  // ── Dummy data — Help topics ────────────────────────────────────────────
  static const List<_HelpTopic> _topics = [
    _HelpTopic(
      categoryKey: 'attendance',
      title: 'How to Clock In',
      subtitle: 'Record your start of duty with time and location.',
      steps: [
        'Open Home tab.',
        'Check that GPS Status shows Active.',
        'Tap the Clock In button.',
        'Confirm in the popup.',
        'Wait for the success message.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'attendance',
      title: 'How to Clock Out',
      subtitle: 'End your duty and record total worked time.',
      steps: [
        'Open Home tab.',
        'Check that your shift is currently active.',
        'Tap the Clock Out button.',
        'Confirm in the popup.',
        'Wait for the success message with your total worked time.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'gps',
      title: 'Why GPS verification is required',
      subtitle: 'Confirms you are at the assigned site before clocking in.',
      steps: [
        'Your live location is compared with the saved site coordinates.',
        'A radius around the site (geofence) decides if you are in range.',
        'Clock-in only succeeds when you are inside this radius.',
        'If you are out of range, an Out of Range message appears instead.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'requests',
      title: 'How to Submit a Leave Request',
      subtitle: 'Apply for leave and track its approval status.',
      steps: [
        'Open the Requests tab.',
        'Tap New Request and choose Leave.',
        'Select the leave type and date range.',
        'Add a reason and attach documents if needed.',
        'Submit and track the status from the same screen.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'tasks',
      title: 'Completing an Assigned Task',
      subtitle: 'Mark tasks as done and add completion notes.',
      steps: [
        'Open the Tasks tab.',
        'Select the task you want to work on.',
        'Update its progress as you go.',
        'Add notes if needed.',
        'Tap Mark Complete when finished.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'breaks',
      title: 'Recording a Break',
      subtitle: 'Log lunch and short breaks during your shift.',
      steps: [
        'Open your active shift screen.',
        'Tap Start Break.',
        'Take your break.',
        'Tap Resume when back on duty.',
        'Break duration is saved automatically.',
      ],
    ),
    _HelpTopic(
      categoryKey: 'reports',
      title: 'Viewing Your Reports',
      subtitle: 'Check attendance and performance summaries.',
      steps: [
        'Open the Company tab.',
        'Switch to the Analytics segment.',
        'Review your attendance rate and task stats.',
        'Check the trend arrows for week-over-week changes.',
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_HelpTopic> get _filteredTopics {
    var list = _topics;
    if (_selectedCategoryKey != null) {
      list = list.where((t) => t.categoryKey == _selectedCategoryKey).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((t) =>
      t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  String? get _selectedCategoryTitle {
    if (_selectedCategoryKey == null) return null;
    return _categories
        .firstWhere((c) => c.key == _selectedCategoryKey)
        .title;
  }

  void _onCategoryTap(String key) {
    setState(() {
      _selectedCategoryKey = _selectedCategoryKey == key ? null : key;
    });

    // If attendance category is tapped, scroll to attendance section
    if (key == 'attendance') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _attendanceSectionKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showInfoTip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _tealDark,
        content: Text(
          'Tap a category to filter topics, or search for keywords above.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _openTopic(_HelpTopic topic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: _borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: _bgCream,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.close_rounded,
                            size: 20, color: _textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: _borderColor),
                const SizedBox(height: 16),
                Text(
                  topic.subtitle,
                  style: const TextStyle(fontSize: 15, color: _textGray, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text(
                  'STEP-BY-STEP',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _textGray,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < topic.steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == topic.steps.length - 1 ? 0 : 12,
                    ),
                    child: _buildStepRow(i + 1, topic.steps[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _bgCream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 14.5, color: _textDark, height: 1.3),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = _filteredTopics;
    final activeCategory = _selectedCategoryTitle;

    // Check if attendance topics exist in filtered list
    final hasAttendanceTopics = topics.any((t) => t.categoryKey == 'attendance');

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildInfoBanner(),
        const SizedBox(height: 14),
        _buildSearchBar(),
        const SizedBox(height: 18),
        _buildCategoryGrid(),
        const SizedBox(height: 18),
        if (activeCategory != null) ...[
          _buildActiveFilterChip(activeCategory),
          const SizedBox(height: 14),
        ],
        if (topics.isEmpty)
          _buildEmptyTopics()
        else ...[
          // Attendance section with key for scrolling
          if (hasAttendanceTopics && _selectedCategoryKey == null) ...[
            Container(
              key: _attendanceSectionKey,
              padding: const EdgeInsets.only(bottom: 8),
              child: const Text(
                'Attendance Topics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
          ...topics.map((topic) => _buildTopicCard(topic)),
        ],
      ],
    );
  }

  // ── Active category filter chip ─────────────────────────────────────
  Widget _buildActiveFilterChip(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategoryKey = null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _tealLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing: $title',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _tealDark,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.close_rounded, size: 15, color: _tealDark),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info banner ──────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, size: 18, color: _teal),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Search help topics or pick a category below.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: _textGray,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showInfoTip,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: _tealLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.info_rounded, size: 13, color: _tealDark),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: const TextStyle(fontSize: 14, color: _textDark),
        decoration: const InputDecoration(
          hintText: 'Search help topics...',
          hintStyle: TextStyle(color: _textGray),
          prefixIcon: Icon(Icons.search_rounded, color: _textGray, size: 22),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Category grid ───────────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
    );
  }

  Widget _buildCategoryCard(_HelpCategory category) {
    final isSelected = _selectedCategoryKey == category.key;
    return GestureDetector(
      onTap: () => _onCategoryTap(category.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _teal : _borderColor,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: _teal.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_teal, _tealDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(category.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              category.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800, color: _textDark),
            ),
            const SizedBox(height: 6),
            Text(
              category.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _textGray, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  // ── Topic list ───────────────────────────────────────────────────────
  Widget _buildTopicCard(_HelpTopic topic) {
    return GestureDetector(
      onTap: () => _openTopic(topic),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.subtitle,
                    style: const TextStyle(fontSize: 13, color: _textGray, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _textGray),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTopics() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: _textGray.withOpacity(0.5)),
          const SizedBox(height: 10),
          const Text('No topics found', style: TextStyle(color: _textGray, fontSize: 14)),
        ],
      ),
    );
  }
}