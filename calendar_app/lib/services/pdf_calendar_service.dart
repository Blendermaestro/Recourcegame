import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../data/vacation_manager.dart';
import 'shared_assignment_data.dart';

/// 📄 PDF CALENDAR GENERATION SERVICE
/// Creates professional calendar PDFs with all assignment data
class PDFCalendarService {
  
  /// Generate weekly calendar PDF with REAL data
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
            
            // Calendar tables with REAL data
            _buildRealCalendarTables(assignments, weekNumber, dates),
            
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
  
  // ==================== REAL DATA PROCESSING ====================
  
  /// Build calendar tables using REAL assignment data
  static pw.Widget _buildRealCalendarTables(Map<String, Employee> assignments, int weekNumber, List<DateTime> dates) {
    // Parse assignments by shift type
    final dayShiftAssignments = <String, List<Assignment>>{};
    final nightShiftAssignments = <String, List<Assignment>>{};
    
    // Process all assignments
    for (final entry in assignments.entries) {
      final assignment = _parseAssignmentKey(entry.key);
      if (assignment != null && assignment.weekNumber == weekNumber) {
        assignment.employee = entry.value;
        
        if (assignment.shiftTitle.toLowerCase().contains('yö')) {
          nightShiftAssignments.putIfAbsent(assignment.profession, () => []).add(assignment);
        } else {
          dayShiftAssignments.putIfAbsent(assignment.profession, () => []).add(assignment);
        }
      }
    }
    
    return pw.Column(
      children: [
        // Day shift table
        if (dayShiftAssignments.isNotEmpty) ...[
          _buildShiftTable('PÄIVÄVUORO (06:00-18:00)', dayShiftAssignments, dates),
          pw.SizedBox(height: 20),
        ],
        
        // Night shift table
        if (nightShiftAssignments.isNotEmpty) ...[
          _buildShiftTable('YÖVUORO (18:00-06:00)', nightShiftAssignments, dates),
        ],
      ],
    );
  }
  
  /// Build shift table with merged cells for consecutive assignments
  static pw.Widget _buildShiftTable(
    String shiftTitle,
    Map<String, List<Assignment>> professionAssignments,
    List<DateTime> dates,
  ) {
    // Get sorted professions
    final sortedProfessions = professionAssignments.keys.toList()..sort();
    
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
            // Header row with day names
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableCell('ROOLI', isHeader: true),
                _buildTableCell('TI', isHeader: true),
                _buildTableCell('KE', isHeader: true),
                _buildTableCell('TO', isHeader: true),
                _buildTableCell('PE', isHeader: true),
                _buildTableCell('LA', isHeader: true),
                _buildTableCell('SU', isHeader: true),
                _buildTableCell('MA', isHeader: true),
              ],
            ),
            
            // Date row
            pw.TableRow(
              children: [
                _buildTableCell('PVM', isHeader: true),
                ...List.generate(7, (index) => _buildTableCell(_formatDateShort(dates[index]))),
              ],
            ),
            
            // Profession rows with merged cells
            ...sortedProfessions.expand((profession) {
              return _buildProfessionRows(profession, professionAssignments[profession]!, dates);
            }),
          ],
        ),
      ],
    );
  }
  
  /// Build profession rows with cell merging for consecutive assignments
  static List<pw.TableRow> _buildProfessionRows(String profession, List<Assignment> assignments, List<DateTime> dates) {
    // Group assignments by profession row
    final rowAssignments = <int, List<Assignment>>{};
    for (final assignment in assignments) {
      rowAssignments.putIfAbsent(assignment.professionRow, () => []).add(assignment);
    }
    
    // Get display name for profession
    final displayName = _getProfessionDisplayName(profession);
    
    // Sort by profession row
    final sortedRows = rowAssignments.keys.toList()..sort();
    
    return sortedRows.map((row) {
      final rowAssignmentsList = rowAssignments[row]!;
      
      return pw.TableRow(
        children: [
          // Profession column (show full name for first row, abbreviated for subsequent)
          _buildTableCell(
            sortedRows.indexOf(row) == 0 ? displayName : '${displayName}${row + 1}',
            isHeader: true,
          ),
          
          // Day columns with merged cells
          ..._buildMergedDayCells(rowAssignmentsList, dates),
        ],
      );
    }).toList();
  }
  
  /// Build day cells with merging for consecutive assignments
  static List<pw.Widget> _buildMergedDayCells(List<Assignment> assignments, List<DateTime> dates) {
    final cells = <pw.Widget>[];
    final processedDays = <int>{};
    
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      if (processedDays.contains(dayIndex)) {
        continue; // Skip days that are part of merged cells
      }
      
      // Find assignment for this day
      final dayAssignment = assignments.where((a) => a.dayIndex == dayIndex).firstOrNull;
      
      if (dayAssignment?.employee != null) {
        final employee = dayAssignment!.employee!;
        
        // Find consecutive days with same employee
        int consecutiveDays = 1;
        for (int nextDay = dayIndex + 1; nextDay < 7; nextDay++) {
          final nextAssignment = assignments.where((a) => a.dayIndex == nextDay).firstOrNull;
          if (nextAssignment?.employee?.id == employee.id) {
            consecutiveDays++;
            processedDays.add(nextDay);
          } else {
            break;
          }
        }
        
        // Check for vacation
        final date = dates[dayIndex];
        final hasVacation = VacationManager.vacations.any((vacation) => 
          vacation.isActiveOn(date) && vacation.employeeId == employee.id
        );
        
        String cellContent = employee.name;
        PdfColor bgColor = _getEmployeeCategoryColor(employee.category);
        
        if (hasVacation) {
          cellContent += ' ⛱️';
          bgColor = PdfColors.red100;
        }
        
        // Add merged cell
        cells.add(_buildMergedTableCell(cellContent, consecutiveDays, bgColor: bgColor));
        
        // Add empty cells for merged days (PDF tables require all cells)
        for (int i = 1; i < consecutiveDays; i++) {
          // These will be handled by the merged cell above
        }
      } else {
        // Empty cell
        cells.add(_buildTableCell(''));
      }
      
      processedDays.add(dayIndex);
    }
    
    // Ensure we have exactly 7 cells
    while (cells.length < 7) {
      cells.add(_buildTableCell(''));
    }
    
    return cells.take(7).toList();
  }
  
  // ==================== UTILITY METHODS ====================
  
  /// Parse assignment key into structured data
  static Assignment? _parseAssignmentKey(String key) {
    final parts = key.split('-');
    if (parts.length != 5) return null;
    
    try {
      return Assignment(
        weekNumber: int.parse(parts[0]),
        shiftTitle: parts[1],
        dayIndex: int.parse(parts[2]),
        profession: parts[3],
        professionRow: int.parse(parts[4]),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Get profession display name
  static String _getProfessionDisplayName(String profession) {
    // Use SharedAssignmentData to get proper display names
    try {
      final role = EmployeeRole.values.byName(profession);
      return SharedAssignmentData.getRoleDisplayName(role);
    } catch (e) {
      return profession.toUpperCase();
    }
  }
  
  /// Build merged table cell that spans multiple columns
  static pw.Widget _buildMergedTableCell(String text, int colspan, {PdfColor? bgColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: bgColor ?? PdfColors.white,
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
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

/// Assignment data structure
class Assignment {
  final int weekNumber;
  final String shiftTitle;
  final int dayIndex;
  final String profession;
  final int professionRow;
  Employee? employee;
  
  Assignment({
    required this.weekNumber,
    required this.shiftTitle,
    required this.dayIndex,
    required this.profession,
    required this.professionRow,
    this.employee,
  });
}

/// Extension to safely get first element or null
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
} 