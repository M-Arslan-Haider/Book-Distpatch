

class SalarySlip {
  final String employeeCode;
  final String employeeName;
  final String designation;
  final String depName;
  final double monthlySalary;
  final double absentDaysAmt;
  final double lateShortHrs;
  final double grossDays;
  final double grossSalary;
  final double otHours;
  final double netSalary;
  final double allowance;
  final double totalIncrement;
  final double tempAdvAmount;
  final double longTermAmount;
  final double netPayableAmount;
  final int id;
  final String month;
  final double basicSalary;
  final double deductionAmount;
  final double arearAmount;
  // ── New columns ────────────────────────────────────────────────────────────
  final double eobi;
  final double monthlyTax;
  final double totalSalaryPaid;
  final String companyCode;   // ← ADDED

  SalarySlip({
    required this.employeeCode,
    required this.employeeName,
    required this.designation,
    required this.depName,
    required this.monthlySalary,
    required this.absentDaysAmt,
    required this.lateShortHrs,
    required this.grossDays,
    required this.grossSalary,
    required this.otHours,
    required this.netSalary,
    required this.allowance,
    required this.totalIncrement,
    required this.tempAdvAmount,
    required this.longTermAmount,
    required this.netPayableAmount,
    required this.id,
    required this.month,
    required this.basicSalary,
    required this.deductionAmount,
    required this.arearAmount,
    required this.eobi,
    required this.monthlyTax,
    required this.totalSalaryPaid,
    this.companyCode = '',     // ← ADDED (optional with default)
  });

  factory SalarySlip.fromJson(Map<String, dynamic> json) {
    // Normalize all keys to UPPERCASE — handles both snake_case & UPPER_CASE
    final Map<String, dynamic> j = {
      for (final e in json.entries) e.key.toUpperCase(): e.value,
    };

    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int _i(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return SalarySlip(
      employeeCode:     j['EMPLOYEE_CODE']?.toString()  ?? '',
      employeeName:     j['EMPLOYEE_NAME']?.toString()  ?? '',
      designation:      j['DESIGNATION']?.toString()    ?? '',
      depName:          j['DEP_NAME']?.toString()       ?? '',
      monthlySalary:    _d(j['MONTHLY_SALARY']),
      absentDaysAmt:    _d(j['ABSENT_DAYS_AMT']),
      lateShortHrs:     _d(j['LATE_SHORT_HRS']),
      grossDays:        _d(j['GROSS_DAYS']),
      grossSalary:      _d(j['GROSS_SALARY']),
      otHours:          _d(j['OT_HOURS']),
      netSalary:        _d(j['NET_SALARY']),
      allowance:        _d(j['ALLOWANCE']),
      totalIncrement:   _d(j['TOTAL_INCREMENT']),
      tempAdvAmount:    _d(j['TEMP_ADV_AMOUNT']),
      longTermAmount:   _d(j['LONG_TERM_AMOUNT']),
      netPayableAmount: _d(j['NET_PAYABLE_AMOUNT']),
      id:               _i(j['ID']),
      month:            j['MONTH']?.toString() ?? '',
      basicSalary:      _d(j['BASIC_SALARY']),
      deductionAmount:  _d(j['DEDUCTION_AMOUNT']),
      arearAmount:      _d(j['AREAR_AMOUNT']),
      eobi:             _d(j['EOBI']),
      monthlyTax:       _d(j['MONTHLY_TAX']),
      totalSalaryPaid:  _d(j['TOTAL_SALARY_PAID']),
      companyCode:      j['COMPANY_CODE']?.toString() ?? '',  // ← ADDED
    );
  }
}