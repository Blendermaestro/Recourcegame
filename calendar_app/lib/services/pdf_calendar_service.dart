import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../data/vacation_manager.dart';

/// 📄 PDF CALENDAR GENERATION SERVICE
/// Creates professional calendar PDFs with all assignment data
class PDFCalendarService {
  
  /// Generate weekly calendar PDF
  static Future<Uint8List> generateWeeklyPDF({
    required int weekNumber,
    required int year,
    required Map<String, Employee> assignments,
  }) async {
    final pdf = pw.Document();
    
    // Get week dates
    final dates = _getWeekDates(weekNumber, year);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(weekNumber, year, dates),
            pw.SizedBox(height: 20),
            
            // Calendar table
            _buildWeeklyTable(assignments, weekNumber, dates),
            
            // Footer
            pw.Spacer(),
            _buildFooter(),
          ];
        },
      ),
    );
    
    return pdf.save();
  }
  
  /// Generate yearly overview PDF  
  static Future<Uint8List> generateYearlyPDF({
    required int year,
    required Map<String, Employee> assignments,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape for year view
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            _buildYearHeader(year),
            pw.SizedBox(height: 16),
            
            // Yearly grid
            _buildYearlyGrid(assignments, year),
            
            // Footer
            pw.Spacer(),
            _buildFooter(),
          ];
        },
      ),
    );
    
    return pdf.save();
  }
  
  /// Download PDF on web or share on mobile
  static Future<void> downloadPDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
  
  // ==================== PRIVATE HELPERS ====================
  
  /// Build PDF header
  static pw.Widget _buildHeader(int weekNumber, int year, List<DateTime> dates) {
    final startDate = dates.first;
    final endDate = dates.last;
    
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ALUSTAVA TYÖVUOROLISTA',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Viikko $weekNumber/$year (${_formatDate(startDate)} - ${_formatDate(endDate)})',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build year header
  static pw.Widget _buildYearHeader(int year) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Center(
        child: pw.Text(
          'VUOSIKATSAUS $year',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Build weekly calendar table
  static pw.Widget _buildWeeklyTable(Map<String, Employee> assignments, int weekNumber, List<DateTime> dates) {
    final dayLabels = ['TI', 'KE', 'TO', 'PE', 'LA', 'SU', 'MA'];
    
    // Group assignments by day and shift
    final dayShiftAssignments = <int, List<Employee>>{};
    final nightShiftAssignments = <int, List<Employee>>{};
    
    for (final entry in assignments.entries) {
      final parts = entry.key.split('-');
      if (parts.length == 5) {
        final assignmentWeek = int.tryParse(parts[0]);
        final shiftTitle = parts[1];
        final dayIndex = int.tryParse(parts[2]);
        
        if (assignmentWeek == weekNumber && dayIndex != null) {
          final employee = entry.value;
          
          if (shiftTitle.contains('Päivävuoro')) {
            dayShiftAssignments.putIfAbsent(dayIndex, () => []).add(employee);
          } else if (shiftTitle.contains('Yövuoro')) {
            nightShiftAssignments.putIfAbsent(dayIndex, () => []).add(employee);
          }
        }
      }
    }
    
    return pw.Column(
      children: [
        // Day shift table
        _buildShiftTable('PÄIVÄVUORO (06:00-18:00)', dayLabels, dates, dayShiftAssignments, weekNumber),
        pw.SizedBox(height: 20),
        
        // Night shift table
        _buildShiftTable('YÖVUORO (18:00-06:00)', dayLabels, dates, nightShiftAssignments, weekNumber),
      ],
    );
  }
  
  /// Build single shift table
  static pw.Widget _buildShiftTable(
    String shiftTitle,
    List<String> dayLabels,
    List<DateTime> dates,
    Map<int, List<Employee>> assignments,
    int weekNumber,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          shiftTitle,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 8),
        
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableCell('PÄIVÄ', isHeader: true),
                ...List.generate(7, (index) => _buildTableCell(dayLabels[index], isHeader: true)),
              ],
            ),
            
            // Date row
            pw.TableRow(
              children: [
                _buildTableCell('PVM', isHeader: true),
                ...List.generate(7, (index) => _buildTableCell(_formatDateShort(dates[index]))),
              ],
            ),
            
            // Assignment rows
            ...List.generate(4, (roleIndex) {
              return pw.TableRow(
                children: [
                  _buildTableCell(_getRoleLabel(roleIndex), isHeader: true),
                  ...List.generate(7, (dayIndex) {
                    final dayAssignments = assignments[dayIndex] ?? [];
                    final employee = dayAssignments.length > roleIndex ? dayAssignments[roleIndex] : null;
                    
                    String cellContent = '';
                    PdfColor bgColor = PdfColors.white;
                    
                    if (employee != null) {
                      cellContent = employee.name;
                      bgColor = _getEmployeeCategoryColor(employee.category);
                      
                      // Check for vacation
                      final date = dates[dayIndex];
                      final hasVacation = VacationManager.vacations.any((vacation) => 
                        vacation.isActiveOn(date) && vacation.employeeId == employee.id
                      );
                      
                      if (hasVacation) {
                        cellContent += ' ⛱️';
                        bgColor = PdfColors.red100;
                      }
                    }
                    
                    return _buildTableCell(cellContent, bgColor: bgColor);
                  }),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
  
  /// Build yearly overview grid
  static pw.Widget _buildYearlyGrid(Map<String, Employee> assignments, int year) {
    return pw.Container(
      child: pw.Text(
        'Vuosikatsaus: ${assignments.length} työvuoroa jaksolle $year\n\n'
        'Työntekijäkategoriat:\n'
        '• AB-työntekijät: ${assignments.values.where((e) => e.category == EmployeeCategory.ab).length} vuoroa\n'
        '• CD-työntekijät: ${assignments.values.where((e) => e.category == EmployeeCategory.cd).length} vuoroa\n'
        '• Huolto: ${assignments.values.where((e) => e.category == EmployeeCategory.huolto).length} vuoroa\n'
        '• Sijaiset: ${assignments.values.where((e) => e.category == EmployeeCategory.sijainen).length} vuoroa\n\n'
        'Yhteensä ${assignments.values.map((e) => e.name).toSet().length} eri työntekijää.',
        style: const pw.TextStyle(fontSize: 14),
      ),
    );
  }
  
  /// Build footer
  static pw.Widget _buildFooter() {
    final now = DateTime.now();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Tulostettu: ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Sovi muutoksista vuorosi työnjohtajan kanssa.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }
  
  /// Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? bgColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: bgColor ?? (isHeader ? PdfColors.grey300 : PdfColors.white),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  // ==================== UTILITY METHODS ====================
  
  /// Get week dates
  static List<DateTime> _getWeekDates(int weekNumber, int year) {
    final firstDayOfYear = DateTime(year, 1, 1);
    final firstMonday = firstDayOfYear.add(Duration(days: (8 - firstDayOfYear.weekday) % 7));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }
  
  /// Format date
  static String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
  
  /// Format date short
  static String _formatDateShort(DateTime date) {
    return '${date.day}.${date.month}';
  }
  
  /// Get role label
  static String _getRoleLabel(int index) {
    switch (index) {
      case 0: return 'VV';
      case 1: return 'KV';
      case 2: return 'AP';
      case 3: return 'YL';
      default: return 'R${index + 1}';
    }
  }
  
  /// Get employee category color
  static PdfColor _getEmployeeCategoryColor(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab: return PdfColors.blue100;
      case EmployeeCategory.cd: return PdfColors.green100;
      case EmployeeCategory.huolto: return PdfColors.orange100;
      case EmployeeCategory.sijainen: return PdfColors.purple100;
      case EmployeeCategory.kommentit: return PdfColors.grey100;
    }
  }
} 