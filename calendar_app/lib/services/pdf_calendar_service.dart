import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import '../models/employee.dart';
import '../data/vacation_manager.dart';
import 'shared_assignment_data.dart';
import 'shared_data_service.dart';

/// 📄 PDF CALENDAR GENERATION SERVICE
/// Creates professional calendar PDFs with merged cells and real data
class PDFCalendarService {
  
  /// Generate weekly calendar PDF with REAL data and cell merging
  static Future<Uint8List> generateWeeklyPDF({
    required int weekNumber,
    required int year,
    required Map<String, Employee> assignments,
  }) async {
    final pdf = pw.Document();
    
    // Get week dates using the SAME calculation as the app
    final dates = _getWeekDatesLikeApp(weekNumber, year);
    
    // Load all employees for vacation name mapping
    final allEmployees = await SharedDataService.loadEmployees();
    final employeeMap = {for (var emp in allEmployees) emp.id: emp.name};
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16), // Even smaller margins
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(weekNumber, year, dates),
            pw.SizedBox(height: 12),
            
            // Calendar tables with REAL data and merged cells
            _buildRealCalendarTablesWithMerging(assignments, weekNumber, dates, year),
            
            pw.SizedBox(height: 12),
            
            // Vacation section with employee names
            _buildVacationSectionWithNames(dates, employeeMap),
            
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
  
  // ==================== REAL DATA PROCESSING WITH CELL MERGING ====================
  
  /// Build calendar tables with proper cell merging
  static pw.Widget _buildRealCalendarTablesWithMerging(Map<String, Employee> assignments, int weekNumber, List<DateTime> dates, int year) {
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
        // Day shift table with proper time ranges
        if (dayShiftAssignments.isNotEmpty) ...[
          _buildShiftTableWithMerging(_getShiftTitle(weekNumber, true), dayShiftAssignments, dates, year),
          pw.SizedBox(height: 12),
        ],
        
        // Night shift table with proper time ranges
        if (nightShiftAssignments.isNotEmpty) ...[
          _buildShiftTableWithMerging(_getShiftTitle(weekNumber, false), nightShiftAssignments, dates, year),
        ],
      ],
    );
  }
  
  /// Get proper shift title with correct times based on week cycle
  static String _getShiftTitle(int weekNumber, bool isDayShift) {
    final cyclePosition = (weekNumber - 1) % 4;
    
    if (isDayShift) {
      // Day shifts: 07:00-19:00 or 07:00-17:00
      switch (cyclePosition) {
        case 0: return 'A / PÄIVÄVUORO (07:00-19:00)'; 
        case 1: return 'C / PÄIVÄVUORO (07:00-17:00)'; 
        case 2: return 'B / PÄIVÄVUORO (07:00-19:00)'; 
        case 3: return 'D / PÄIVÄVUORO (07:00-17:00)'; 
        default: return 'PÄIVÄVUORO (07:00-19:00)';
      }
    } else {
      // Night shifts: 19:00-07:00 or 19:00-05:00
      switch (cyclePosition) {
        case 0: return 'B / YÖVUORO (19:00-07:00)'; 
        case 1: return 'D / YÖVUORO (19:00-05:00)'; 
        case 2: return 'A / YÖVUORO (19:00-07:00)'; 
        case 3: return 'C / YÖVUORO (19:00-05:00)'; 
        default: return 'YÖVUORO (19:00-07:00)';
      }
    }
  }
  
  /// Build shift table with merged cells for consecutive assignments
  static pw.Widget _buildShiftTableWithMerging(
    String shiftTitle,
    Map<String, List<Assignment>> professionAssignments,
    List<DateTime> dates,
    int year,
  ) {
    // Sort professions by EmployeeRole enum order (NOT alphabetical!)
    final orderedProfessions = _getOrderedProfessions(professionAssignments.keys.toList());
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          shiftTitle,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        
        _buildCustomMergedTable(orderedProfessions, professionAssignments, dates, year),
      ],
    );
  }
  
  /// Get professions ordered by EmployeeRole enum order
  static List<String> _getOrderedProfessions(List<String> professions) {
    final roleOrder = [
      'tj', 'varu1', 'varu2', 'varu3', 'varu4', 
      'pasta1', 'pasta2', 'ict', 'tarvike', 'pora', 
      'huolto', 'kommentit', 'custom',
      'slot1', 'slot2', 'slot3', 'slot4', 'slot5',
      'slot6', 'slot7', 'slot8', 'slot9', 'slot10'
    ];
    
    final ordered = <String>[];
    for (final role in roleOrder) {
      if (professions.contains(role)) {
        ordered.add(role);
      }
    }
    
    // Add any remaining professions not in the standard order
    for (final profession in professions) {
      if (!ordered.contains(profession)) {
        ordered.add(profession);
      }
    }
    
    return ordered;
  }
  
  /// Build custom table that simulates cell merging
  static pw.Widget _buildCustomMergedTable(
    List<String> orderedProfessions,
    Map<String, List<Assignment>> professionAssignments,
    List<DateTime> dates,
    int year,
  ) {
    final rows = <pw.TableRow>[];
    
    // Header row with day names
    rows.add(pw.TableRow(
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
    ));
    
    // Date row
    rows.add(pw.TableRow(
      children: [
        _buildTableCell('PVM', isHeader: true),
        ...List.generate(7, (index) => _buildTableCell(_formatDateShort(dates[index]))),
      ],
    ));
    
    // Profession rows with merged cells
    for (final profession in orderedProfessions) {
      final assignments = professionAssignments[profession]!;
      rows.addAll(_buildProfessionRowsWithMerging(profession, assignments, dates, year));
    }
    
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
      children: rows,
    );
  }
  
  /// Build profession rows with merged cells for consecutive assignments
  static List<pw.TableRow> _buildProfessionRowsWithMerging(String profession, List<Assignment> assignments, List<DateTime> dates, int year) {
    // Group assignments by profession row
    final rowAssignments = <int, List<Assignment>>{};
    for (final assignment in assignments) {
      rowAssignments.putIfAbsent(assignment.professionRow, () => []).add(assignment);
    }
    
    final displayName = _getProfessionDisplayName(profession);
    final sortedRows = rowAssignments.keys.toList()..sort();
    
    return sortedRows.map((row) {
      final rowAssignmentsList = rowAssignments[row]!;
      
      return pw.TableRow(
        children: [
          // Profession column
          _buildTableCell(
            sortedRows.indexOf(row) == 0 ? displayName : '$displayName${row + 1}',
            isHeader: true,
          ),
          
          // Day columns with merged cell simulation
          ..._buildMergedDayCells(rowAssignmentsList, dates, year),
        ],
      );
    }).toList();
  }
  
  /// Build day cells with merged cell simulation for consecutive assignments
  static List<pw.Widget> _buildMergedDayCells(List<Assignment> assignments, List<DateTime> dates, int year) {
    final cells = <pw.Widget>[];
    final mergedCells = _calculateMergedCells(assignments, dates, year);
    
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      final mergedCell = mergedCells[dayIndex];
      
      if (mergedCell != null) {
        if (mergedCell.isStart) {
          // First cell of merged group - show content
          cells.add(_buildMergedContentCell(mergedCell.content, mergedCell.bgColor, mergedCell.span));
        } else {
          // Continuation cell - show as merged
          cells.add(_buildMergedContinuationCell(mergedCell.bgColor));
        }
      } else {
        // Empty cell
        cells.add(_buildTableCell(''));
      }
    }
    
    return cells;
  }
  
  /// Calculate merged cells for consecutive assignments
  static Map<int, MergedCellInfo?> _calculateMergedCells(List<Assignment> assignments, List<DateTime> dates, int year) {
    final mergedCells = <int, MergedCellInfo?>{};
    final processedDays = <int>{};
    
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      if (processedDays.contains(dayIndex)) {
        continue;
      }
      
      final dayAssignment = assignments.where((a) => a.dayIndex == dayIndex).firstOrNull;
      
      if (dayAssignment?.employee != null) {
        final employee = dayAssignment!.employee!;
        
        // Find consecutive days with same employee
        int span = 1;
        for (int nextDay = dayIndex + 1; nextDay < 7; nextDay++) {
          final nextAssignment = assignments.where((a) => a.dayIndex == nextDay).firstOrNull;
          if (nextAssignment?.employee?.id == employee.id) {
            span++;
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
        
        String content = employee.name;
        PdfColor bgColor = _getEmployeeCategoryColor(employee.category);
        
        if (hasVacation) {
          content += ' (LOMA)';
          bgColor = PdfColors.red100;
        }
        
        // Create merged cell info
        mergedCells[dayIndex] = MergedCellInfo(
          content: content,
          bgColor: bgColor,
          span: span,
          isStart: true,
        );
        
        // Mark continuation cells
        for (int i = 1; i < span; i++) {
          mergedCells[dayIndex + i] = MergedCellInfo(
            content: content,
            bgColor: bgColor,
            span: span,
            isStart: false,
          );
        }
      } else {
        mergedCells[dayIndex] = null;
      }
      
      processedDays.add(dayIndex);
    }
    
    return mergedCells;
  }
  
  /// Build merged content cell (first cell of a span)
  static pw.Widget _buildMergedContentCell(String content, PdfColor bgColor, int span) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: PdfColors.grey600, width: 0.4),
      ),
      child: pw.Text(
        content,
        style: const pw.TextStyle(fontSize: 6),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  /// Build merged continuation cell (subsequent cells of a span)
  static pw.Widget _buildMergedContinuationCell(PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey600, width: 0.4),
          bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.4),
          right: pw.BorderSide(color: PdfColors.grey600, width: 0.4),
          left: pw.BorderSide.none, // No left border to create merged appearance
        ),
      ),
      child: pw.Text('', style: const pw.TextStyle(fontSize: 6)),
    );
  }
  
  /// Build vacation section with actual employee names
  static pw.Widget _buildVacationSectionWithNames(List<DateTime> dates, Map<String, String> employeeMap) {
    final weekStart = dates.first;
    final weekEnd = dates.last;
    
    // Find vacations that overlap with this week
    final weekVacations = VacationManager.vacations.where((vacation) {
      return vacation.startDate.isBefore(weekEnd.add(const Duration(days: 1))) &&
             vacation.endDate.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).toList();
    
    if (weekVacations.isEmpty) {
      return pw.Container();
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'LOMAT TALLA VIIKOLLA', // No emoji - just text
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 4),
        
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(3),
            border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: weekVacations.map((vacation) {
              final employeeName = employeeMap[vacation.employeeId] ?? 'Tuntematon';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(
                  '• $employeeName: ${vacation.getDisplayText()}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
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
    try {
      final role = EmployeeRole.values.byName(profession);
      return SharedAssignmentData.getRoleDisplayName(role);
    } catch (e) {
      return profession.toUpperCase();
    }
  }
  
  /// Get week dates using the SAME calculation as the app
  static List<DateTime> _getWeekDatesLikeApp(int weekNumber, int year) {
    final jan4 = DateTime(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    
    // Start from Tuesday (weekStart + 1 day) - SAME AS APP!
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }
  
  /// Build PDF header
  static pw.Widget _buildHeader(int weekNumber, int year, List<DateTime> dates) {
    final startDate = dates.first;
    final endDate = dates.last;
    
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue900,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ALUSTAVA TYOVUOROLISTA',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Viikko $weekNumber/$year (${_formatDate(startDate)} - ${_formatDate(endDate)})',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
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
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Tulostettu: ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Sovi muutoksista vuorosi tyonjohtajan kanssa.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }
  
  /// Build table cell with extra thin padding
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, PdfColor? bgColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2), // Extra thin padding
      decoration: pw.BoxDecoration(
        color: bgColor ?? (isHeader ? PdfColors.grey300 : PdfColors.white),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 7 : 6, // Even smaller font
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
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

/// Merged cell information for PDF table simulation
class MergedCellInfo {
  final String content;
  final PdfColor bgColor;
  final int span;
  final bool isStart;
  
  MergedCellInfo({
    required this.content,
    required this.bgColor,
    required this.span,
    required this.isStart,
  });
}

/// Extension to safely get first element or null
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
} 