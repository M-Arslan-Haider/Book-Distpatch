// ════════════════════════════════════════════════════════════════════════════
//  lib/Screens/salary_slip_screen.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../AppColors.dart';
import '../Models/salary_slip_model.dart';
import '../ViewModels/salary_slip_view_model.dart';

// ── Document colour palette — brand gradient theme ───────────────────────────
const _kDocBg      = Color(0xFFEAF8F8);   // light cyan-tinted background
const _kDocRow1    = Color(0xFFD6F0F0);   // alternate row — soft cyan tint
const _kDocDivider = Color(0xFF9FD8D8);   // divider — muted cyan

// Semantic aliases that map to AppColors brand tokens
// (keeps all widget references working without touching widget code)
const _kDocBlue   = AppColors.primary;    // deep navy — headings, values
const _kDocAccent = AppColors.cyan;       // cyan — labels, lines

// ════════════════════════════════════════════════════════════════════════════
//  LIST SCREEN
// ════════════════════════════════════════════════════════════════════════════
class SalarySlipScreen extends StatelessWidget {
  const SalarySlipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(SalarySlipViewModel());

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _SalaryHeader(vm: vm),
          _ColumnLabels(),
          Expanded(
            child: Obx(() {
              if (vm.isLoading.value) return _LoadingView();
              if (vm.errorMessage.value.isNotEmpty) {
                return _ErrorView(
                  message: vm.errorMessage.value,
                  onRetry: vm.fetchSalarySlips,
                );
              }
              if (vm.slips.isEmpty) {
                return _EmptyView(onRefresh: vm.fetchSalarySlips);
              }
              return RefreshIndicator(
                color: AppColors.cyan,
                onRefresh: vm.fetchSalarySlips,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  itemCount: vm.slips.length,
                  itemBuilder: (ctx, i) =>
                      _SlipRow(slip: vm.slips[i], index: i),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════════════════════
class _SalaryHeader extends StatelessWidget {
  final SalarySlipViewModel vm;
  const _SalaryHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -40,
              right: -20,
              child: _circle(160, AppColors.greenTeal, 0.15)),
          Positioned(
              bottom: -30,
              left: -10,
              child: _circle(100, Colors.white, 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.20)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Salary Slips',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                )),
                            Text('Monthly payroll records',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                )),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: vm.fetchSalarySlips,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.20)),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Obx(() {
                    if (vm.slips.isEmpty) return const SizedBox.shrink();
                    final total = vm.slips.fold<double>(
                        0, (sum, s) => sum + s.netPayableAmount);
                    return Row(
                      children: [
                        _statChip(Icons.receipt_long_rounded,
                            '${vm.slips.length}', 'Payslips'),
                        const SizedBox(width: 10),
                        Flexible(
                          child: _statChip(
                              Icons.account_balance_wallet_rounded,
                              'PKR ${_fmt(total)}',
                              'Total Net Payable'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  COLUMN LABELS — Month | Monthly Salary | Net Payable | Salary Paid
// ═══════════════════════════════════════════════════════════════════════════
class _ColumnLabels extends StatelessWidget {
  const _ColumnLabels();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.cyan.withOpacity(0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('MONTH',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text('SALARY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text('NET PAY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text('SAL. PAID',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                )),
          ),
          const SizedBox(width: 62),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SLIP ROW — Month | Monthly Salary | Net Payable | Salary Paid
// ═══════════════════════════════════════════════════════════════════════════
class _SlipRow extends StatelessWidget {
  final SalarySlip slip;
  final int index;
  const _SlipRow({required this.slip, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cyan.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // ── MONTH BADGE + LABEL ───────────────────────────────────────
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _parseMonthShort(slip.month),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _parseMonthFull(slip.month),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _parseYear(slip.month),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _divider(),

            // ── MONTHLY SALARY ────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _amountCol(
                label: 'SALARY',
                value: _fmt(slip.monthlySalary),
                color: AppColors.skyBlueDk,
                align: CrossAxisAlignment.center,
              ),
            ),

            _divider(),

            // ── NET PAYABLE ───────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _amountCol(
                label: 'NET PAY',
                value: _fmt(slip.netPayableAmount),
                color: AppColors.primary,
                align: CrossAxisAlignment.center,
                bold: true,
              ),
            ),

            _divider(),

            // ── TOTAL SALARY PAID ─────────────────────────────────────────
            Expanded(
              flex: 3,
              child: _amountCol(
                label: 'SAL. PAID',
                value: _fmt(slip.totalSalaryPaid),
                color: slip.totalSalaryPaid > 0
                    ? const Color(0xFF1B8A4C)
                    : const Color(0xFFD32F2F),
                align: CrossAxisAlignment.end,
                bold: true,
              ),
            ),

            const SizedBox(width: 8),

            // ── VIEW BUTTON ───────────────────────────────────────────────
            GestureDetector(
              onTap: () => Get.to(
                    () => SalarySlipDetailScreen(slip: slip),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 300),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 34,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: AppColors.cyan.withOpacity(0.22),
  );

  Widget _amountCol({
    required String label,
    required String value,
    required Color color,
    required CrossAxisAlignment align,
    bool bold = false,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _parseMonthShort(String m) {
    try {
      if (m.contains('-')) {
        final parts = m.split('-');
        const months = ['', 'JAN','FEB','MAR','APR','MAY','JUN',
          'JUL','AUG','SEP','OCT','NOV','DEC'];
        if (parts[0].length == 4) {
          final idx = int.tryParse(parts[1]) ?? 0;
          if (idx >= 1 && idx <= 12) return months[idx];
        }
      }
    } catch (_) {}
    return m.length > 3 ? m.substring(0, 3).toUpperCase() : m.toUpperCase();
  }

  String _parseMonthFull(String m) {
    try {
      if (m.contains('-')) {
        final parts = m.split('-');
        const months = ['', 'January','February','March','April','May','June',
          'July','August','September','October','November','December'];
        if (parts[0].length == 4) {
          final idx = int.tryParse(parts[1]) ?? 0;
          if (idx >= 1 && idx <= 12) return months[idx];
        }
      }
    } catch (_) {}
    return m;
  }

  String _parseYear(String m) {
    try {
      if (m.contains('-')) {
        final parts = m.split('-');
        if (parts[0].length == 4) return parts[0];
        if (parts.length >= 2 && parts[1].length == 4) return parts[1];
      }
    } catch (_) {}
    return '';
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  FULL-SCREEN SALARY SLIP DETAIL
// ════════════════════════════════════════════════════════════════════════════
class SalarySlipDetailScreen extends StatefulWidget {
  final SalarySlip slip;
  const SalarySlipDetailScreen({super.key, required this.slip});

  @override
  State<SalarySlipDetailScreen> createState() => _SalarySlipDetailScreenState();
}

class _SalarySlipDetailScreenState extends State<SalarySlipDetailScreen> {
  bool _pdfGenerating = false;

  // ── PDF Generation ────────────────────────────────────────────────────────
  Future<void> _generateAndSharePdf() async {
    setState(() => _pdfGenerating = true);
    try {
      final slip = widget.slip;
      final pdf = pw.Document();

      // ── Colours ─────────────────────────────────────────────────────────
      final navyColor   = PdfColor.fromHex('#1A3A6B');
      final cyanColor   = PdfColor.fromHex('#06B6D4');
      final rowTint     = PdfColor.fromHex('#D6F0F0');
      final rowWhite    = PdfColor.fromHex('#F0FBFB');
      final greyText    = PdfColor.fromHex('#6B7280');
      final greenColor  = PdfColor.fromHex('#1B8A4C');
      final redColor    = PdfColor.fromHex('#D32F2F');

      // ── Helper formatters ────────────────────────────────────────────────
      String fmtD(double v) {
        if (v >= 1000) {
          final s = v.toStringAsFixed(0);
          final buf = StringBuffer();
          int cnt = 0;
          for (int i = s.length - 1; i >= 0; i--) {
            if (cnt > 0 && cnt % 3 == 0) buf.write(',');
            buf.write(s[i]);
            cnt++;
          }
          return buf.toString().split('').reversed.join('');
        }
        return v.toStringAsFixed(2);
      }

      // ── Table row builder ─────────────────────────────────────────────────
      pw.TableRow tableRow(String label, String value, int index,
          {bool boldValue = false, PdfColor? valueColor}) {
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: index.isEven ? rowTint : rowWhite),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(label,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: greyText,
                    fontWeight: pw.FontWeight.normal,
                  )),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: valueColor ?? navyColor,
                    fontWeight: boldValue
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  )),
            ),
          ],
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // ── TITLE ──────────────────────────────────────────────────
                pw.Row(
                  children: [
                    pw.Expanded(child: pw.Divider(color: cyanColor, thickness: 1)),
                    pw.SizedBox(width: 10),
                    pw.Text('SALARY SLIP',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: navyColor,
                          letterSpacing: 3,
                        )),
                    pw.SizedBox(width: 10),
                    pw.Expanded(child: pw.Divider(color: cyanColor, thickness: 1)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(color: navyColor, thickness: 2.5),
                pw.Divider(color: cyanColor, thickness: 0.5),
                pw.SizedBox(height: 10),

                // ── EMPLOYEE INFO ──────────────────────────────────────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoRow('Employee Code', slip.employeeCode, navyColor, cyanColor),
                          _pdfInfoRow('Employee Name', slip.employeeName, navyColor, cyanColor),
                          _pdfInfoRow('Designation', slip.designation, navyColor, cyanColor),
                          _pdfInfoRow('Department', slip.depName, navyColor, cyanColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfInfoRow('ID', 'SL-${slip.id}', navyColor, cyanColor),
                          _pdfInfoRow('Month', slip.month, navyColor, cyanColor),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: cyanColor, thickness: 0.8),
                pw.SizedBox(height: 10),

                // ── EARNINGS / DEDUCTIONS ──────────────────────────────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // EARNINGS
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(
                            color: navyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 7),
                            alignment: pw.Alignment.center,
                            child: pw.Text('EARNINGS',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.5,
                                )),
                          ),
                          pw.Table(
                            children: [
                              tableRow('Monthly Salary', fmtD(slip.monthlySalary), 0, boldValue: true),
                              tableRow('Gross Days', slip.grossDays.toStringAsFixed(0), 1),
                              tableRow('Gross Salary', fmtD(slip.grossSalary), 2, boldValue: true),
                              tableRow('OT Hours', slip.otHours.toStringAsFixed(0), 3),
                              tableRow('Allowance', fmtD(slip.allowance), 4, boldValue: true),
                              tableRow('Total Increment', fmtD(slip.totalIncrement), 5, boldValue: true),
                              tableRow('Arrear Amount', fmtD(slip.arearAmount), 6, boldValue: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    // DEDUCTIONS
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(
                            color: navyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 7),
                            alignment: pw.Alignment.center,
                            child: pw.Text('DEDUCTIONS',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.5,
                                )),
                          ),
                          pw.Table(
                            children: [

                              tableRow('Late/Short Hrs', fmtD(slip.lateShortHrs), 1, boldValue: true),
                              tableRow('EOBI', fmtD(slip.eobi), 2, boldValue: true),
                              tableRow('Monthly Tax', fmtD(slip.monthlyTax), 3, boldValue: true),
                              tableRow('Deduction Amt', fmtD(slip.deductionAmount), 4, boldValue: true),
                              tableRow('Temp. Adv. Amt', fmtD(slip.tempAdvAmount), 5, boldValue: true),
                              tableRow('Long Term Amt', fmtD(slip.longTermAmount), 6, boldValue: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                // ── NET SUMMARY BAR ────────────────────────────────────────
                pw.Container(
                  color: navyColor,
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      _pdfSummaryCell('Net Salary', fmtD(slip.netSalary)),
                      _pdfDividerCell(),
                      _pdfSummaryCell('Net Payable', fmtD(slip.netPayableAmount)),
                      _pdfDividerCell(),
                      _pdfSummaryCell('Salary Paid', fmtD(slip.totalSalaryPaid)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // ── BOTTOM DETAIL TABLE ────────────────────────────────────
                pw.Table(
                  border: pw.TableBorder.all(color: cyanColor, width: 0.5),
                  children: [
                    tableRow('Basic Salary', fmtD(slip.basicSalary), 0, boldValue: true),
                    tableRow('Total Increment', fmtD(slip.totalIncrement), 1, boldValue: true),
                    tableRow('Temp. Adv. Amount', fmtD(slip.tempAdvAmount), 2, boldValue: true),
                    tableRow('Long Term Amount', fmtD(slip.longTermAmount), 3, boldValue: true),
                    tableRow('Total Salary Paid', fmtD(slip.totalSalaryPaid), 4,
                        boldValue: true,
                        valueColor: slip.totalSalaryPaid > 0 ? greenColor : redColor),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // ── Save to temp and share ────────────────────────────────────────────
      final dir = await getTemporaryDirectory();
      final fileName =
          'Salary_Slip_${slip.employeeCode}_${slip.month.replaceAll('/', '-')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Salary Slip - ${slip.employeeName} (${slip.month})',
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not generate PDF: $e',
        backgroundColor: Colors.red.shade50,
        colorText: Colors.red.shade800,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  // PDF helper: info row
  static pw.Widget _pdfInfoRow(
      String label, String value, PdfColor navyColor, PdfColor cyanColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 8,
                color: cyanColor,
                fontWeight: pw.FontWeight.normal,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: navyColor,
                fontWeight: pw.FontWeight.bold,
              )),
          pw.Divider(color: PdfColor.fromHex('#9FD8D8'), thickness: 0.4),
        ],
      ),
    );
  }

  // PDF helper: summary cell
  static pw.Widget _pdfSummaryCell(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.normal,
            )),
        pw.SizedBox(height: 3),
        pw.Text(value,
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
            )),
      ],
    );
  }

  // PDF helper: vertical divider for summary bar
  static pw.Widget _pdfDividerCell() {
    return pw.Container(
      width: 1,
      height: 32,
      color: PdfColors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _kDocBg,
      body: Column(
        children: [
          _DetailHeader(
            slip: widget.slip,
            onDownloadPdf: _generateAndSharePdf,
            pdfGenerating: _pdfGenerating,
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
              child: _SalaryDocument(slip: widget.slip),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail screen gradient header ────────────────────────────────────────────
class _DetailHeader extends StatelessWidget {
  final SalarySlip slip;
  final VoidCallback onDownloadPdf;
  final bool pdfGenerating;
  const _DetailHeader({
    required this.slip,
    required this.onDownloadPdf,
    required this.pdfGenerating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -30, right: -10, child: _circle(130, AppColors.greenTeal, 0.13)),
          Positioned(
              bottom: -20, left: -10, child: _circle(80, Colors.white, 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back | Title | PDF button | ID badge ──────────────
                  Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.20)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Salary Slip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                )),
                            Text('Payroll document',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                )),
                          ],
                        ),
                      ),
                      // ── PDF Download button ──────────────────────────
                      GestureDetector(
                        onTap: pdfGenerating ? null : onDownloadPdf,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.20)),
                          ),
                          child: pdfGenerating
                              ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Slip ID badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.20)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('SL-${slip.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                )),
                            Text(slip.month,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.70),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Quick summary chips
                  Row(
                    children: [
                      Flexible(
                        child: _chip(Icons.person_rounded, slip.employeeName),
                      ),
                      const SizedBox(width: 8),
                      _chip(Icons.account_balance_wallet_rounded,
                          'PKR ${_fmt(slip.netPayableAmount)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _circle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SALARY SLIP DOCUMENT CARD
// ════════════════════════════════════════════════════════════════════════════
class _SalaryDocument extends StatelessWidget {
  final SalarySlip slip;
  const _SalaryDocument({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kDocBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDocAccent.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleSection(slip: slip),
          _EmployeeInfoSection(slip: slip),
          _EarningsDeductionsTable(slip: slip),
          _NetSummaryBar(slip: slip),
          _BottomDetailTable(slip: slip),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── 1. TITLE ─────────────────────────────────────────────────────────────────
class _TitleSection extends StatelessWidget {
  final SalarySlip slip;
  const _TitleSection({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left decorative line
              Expanded(child: Container(height: 1.5, color: _kDocAccent)),
              const SizedBox(width: 12),
              // SALARY SLIP title
              const Text(
                'SALARY SLIP',
                style: TextStyle(
                  color: _kDocBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 12),
              // Right decorative line
              Expanded(child: Container(height: 1.5, color: _kDocAccent)),
              const SizedBox(width: 12),
              // Company Logo placeholder
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.business_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Company',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(height: 1, color: AppColors.cyan.withOpacity(0.30)),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ── 2. EMPLOYEE INFO ──────────────────────────────────────────────────────────
class _EmployeeInfoSection extends StatelessWidget {
  final SalarySlip slip;
  const _EmployeeInfoSection({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left info column — takes 60% width
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Employee Code:', value: slip.employeeCode),
                      const _RowDivider(),
                      _InfoRow(label: 'Employee Name:', value: slip.employeeName),
                      const _RowDivider(),
                      _InfoRow(label: 'Designation:', value: slip.designation),
                      const _RowDivider(),
                      _InfoRow(label: 'Department:', value: slip.depName),
                    ],
                  ),
                ),
                // Vertical separator — auto height via IntrinsicHeight
                Container(
                  width: 1,
                  color: _kDocAccent.withOpacity(0.40),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                // Right info column — takes 40% width
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'ID:', value: 'SL-${slip.id}'),
                      const _RowDivider(),
                      _InfoRow(label: 'Month:', value: slip.month),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _kDocAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12,
              color: _kDocBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: _kDocAccent.withOpacity(0.30));
}

// ── 3. EARNINGS / DEDUCTIONS TABLE ───────────────────────────────────────────
class _EarningsDeductionsTable extends StatelessWidget {
  final SalarySlip slip;
  const _EarningsDeductionsTable({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EARNINGS column
          Expanded(
            child: _TableBlock(
              title: 'EARNINGS',
              rows: [
                _TR('Monthly Salary:', _fmtV(slip.monthlySalary), bold: true),
                _TR('Gross Days:', slip.grossDays.toStringAsFixed(0)),
                _TR('Gross Salary:', _fmtV(slip.grossSalary), bold: true),
                _TR('OT Hours:', slip.otHours.toStringAsFixed(0)),
                _TR('Allowance:', _fmtV(slip.allowance), bold: true),
                _TR('Total Increment:', _fmtV(slip.totalIncrement), bold: true),
                _TR('Arrear Amount:', _fmtV(slip.arearAmount), bold: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // DEDUCTIONS column
          Expanded(
            child: _TableBlock(
              title: 'DEDUCTIONS',
              rows: [

                _TR('Late/Short Hrs:', _fmtV(slip.lateShortHrs), bold: true),
                _TR('EOBI:', _fmtV(slip.eobi), bold: true),
                _TR('Monthly Tax:', _fmtV(slip.monthlyTax), bold: true),
                _TR('Deduction Amt:', _fmtV(slip.deductionAmount), bold: true),
                _TR('Temp. Adv. Amt:', _fmtV(slip.tempAdvAmount), bold: true),
                _TR('Long Term Amt:', _fmtV(slip.longTermAmount), bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple row model
class _TR {
  final String label;
  final String value;
  final bool bold;
  const _TR(this.label, this.value, {this.bold = false});
}

class _TableBlock extends StatelessWidget {
  final String title;
  final List<_TR> rows;
  const _TableBlock({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.cyan,
                  AppColors.greenTeal,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // ── Rows ──
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Container(
              color: i.isEven ? _kDocRow1 : const Color(0xFFF0FBFB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  Text(
                    row.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      row.bold ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── 4. NET SUMMARY BAR ────────────────────────────────────────────────────────
class _NetSummaryBar extends StatelessWidget {
  final SalarySlip slip;
  const _NetSummaryBar({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Net Salary',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    _fmtV(slip.netSalary),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Net Payable',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    _fmtV(slip.netPayableAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Salary Paid',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    _fmtV(slip.totalSalaryPaid),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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
}

// ── 5. BOTTOM DETAIL TABLE ────────────────────────────────────────────────────
class _BottomDetailTable extends StatelessWidget {
  final SalarySlip slip;
  const _BottomDetailTable({required this.slip});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _TR('Basic Salary:', _fmtV(slip.basicSalary), bold: true),
      _TR('Total Increment:', _fmtV(slip.totalIncrement), bold: true),
      _TR('Temp. Adv. Amount:', _fmtV(slip.tempAdvAmount), bold: true),
      _TR('Long Term Amount:', _fmtV(slip.longTermAmount), bold: true),
      _TR('Total Salary Paid:', _fmtV(slip.totalSalaryPaid), bold: true),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _kDocAccent.withOpacity(0.35), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            final isLast = i == rows.length - 1;
            return Container(
              decoration: BoxDecoration(
                color: i.isEven ? _kDocRow1 : const Color(0xFFF0FBFB),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(7))
                    : null,
                border: !isLast
                    ? Border(
                    bottom: BorderSide(color: _kDocDivider, width: 0.8))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                  Text(row.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        row.bold ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.primary,
                      )),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  STATE WIDGETS
// ════════════════════════════════════════════════════════════════════════════
class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Loading salary slips…',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                color: Colors.red, size: 34),
          ),
          const SizedBox(height: 14),
          const Text('Could not load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              message,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: AppColors.cyan.withOpacity(0.40), size: 38),
          ),
          const SizedBox(height: 16),
          const Text('No salary slips found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 8),
          Text('Your payroll records will appear here',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text('Refresh',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════════════
String _fmt(double v) {
  if (v >= 1000) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int cnt = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (cnt > 0 && cnt % 3 == 0) buf.write(',');
      buf.write(s[i]);
      cnt++;
    }
    return buf.toString().split('').reversed.join('');
  }
  return v.toStringAsFixed(2);
}

String _fmtV(double v) => _fmt(v);