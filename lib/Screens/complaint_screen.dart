import 'package:flutter/material.dart';
import '../AppColors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// complaint_screen.dart
//
// Complaint Screen — bottom sheet style, exactly like the screenshot
// ═══════════════════════════════════════════════════════════════════════════

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final TextEditingController _complaintController = TextEditingController();
  String _selectedPriority = 'Medium';
  static const int _maxChars = 500;

  static const _bgColor     = AppColors.surface;
  static const _cardBg      = AppColors.cardBg;
  static const _borderColor = AppColors.divider;
  static const _textDark    = AppColors.textPrimary;
  static const _textGray    = AppColors.textSecondary;
  static const _primary     = AppColors.cyan;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _complaintController.clear();
      _selectedPriority = 'Medium';
    });
  }

  // ── Professional snackbar ─────────────────────────────────────────────────
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          backgroundColor: const Color(0xFF1C1C2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 10,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _submit() {
    if (_complaintController.text.trim().isEmpty) {
      _showErrorSnackBar('Please describe your complaint.');
      return;
    }
    // TODO: Add your API submit logic here
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'New Complaint Request',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: _textDark),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Divider ──────────────────────────────────────────────
                Divider(height: 1, color: _borderColor),

                // ── Scrollable body ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── Breadcrumb ─────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Row(
                            children: [
                              Text('Requests',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _textGray,
                                      fontWeight: FontWeight.w500)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.chevron_right_rounded,
                                    size: 16, color: AppColors.textSecondary),
                              ),
                              Text('Others',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _textGray,
                                      fontWeight: FontWeight.w500)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.chevron_right_rounded,
                                    size: 16, color: AppColors.textSecondary),
                              ),
                              Text('Complaint',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: _primary,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Complaint field ────────────────────────────
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Complaint',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _textDark,
                                ),
                              ),
                              TextSpan(
                                text: ' *',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _borderColor),
                          ),
                          child: TextField(
                            controller: _complaintController,
                            maxLines: 6,
                            maxLength: _maxChars,
                            style: const TextStyle(
                                fontSize: 14.5, color: _textDark),
                            decoration: const InputDecoration(
                              hintText: 'Describe your complaint in detail...',
                              hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14.5),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${_complaintController.text.length} / $_maxChars',
                              style: const TextStyle(
                                  fontSize: 12, color: _textGray),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── Priority dropdown ──────────────────────────
                        const Text('Priority',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        const SizedBox(height: 8),
                        _DropdownField(
                          value: _selectedPriority,
                          items: _priorities,
                          onChanged: (val) =>
                              setState(() => _selectedPriority = val!),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // ── Bottom buttons ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    border: Border(top: BorderSide(color: _borderColor)),
                  ),
                  child: Row(
                    children: [
                      // Reset button
                      Expanded(
                        flex: 4,
                        child: GestureDetector(
                          onTap: _reset,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _borderColor),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    color: _textDark, size: 18),
                                SizedBox(width: 6),
                                Text('Reset',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Submit button
                      Expanded(
                        flex: 6,
                        child: GestureDetector(
                          onTap: _submit,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Submit',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Dropdown Field  (professional redesign)
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  static const _cardBg      = AppColors.cardBg;
  static const _borderColor = AppColors.divider;
  static const _textDark    = AppColors.textPrimary;
  static const _primary     = AppColors.cyan;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          menuMaxHeight: 240,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary, size: 22),
          onChanged: onChanged,
          // Selected value shown in the field — highlighted in primary color
          selectedItemBuilder: (context) => items
              .map(
                (e) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          )
              .toList(),
          // Menu items — dot indicator + highlight for active
          items: items
              .map(
                (e) => DropdownMenuItem(
              value: e,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e == value ? _primary : _borderColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    e,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: e == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: e == value ? _primary : _textDark,
                    ),
                  ),
                ],
              ),
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}
