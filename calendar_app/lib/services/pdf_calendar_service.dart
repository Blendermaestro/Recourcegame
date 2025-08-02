import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added for Color class
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
  
  /// Build custom table with real spanning blocks using positioned containers
  static pw.Widget _buildCustomMergedTable(
    List<String> orderedProfessions,
    Map<String, List<Assignment>> professionAssignments,
    List<DateTime> dates,
    int year,
  ) {
    final cellWidth = 68.0; // Slightly smaller to prevent cropping
    final cellHeight = 15.0; // Compact height
    final professionWidth = 85.0; // Wider for profession names with numbers
    
    return pw.Column(
      children: [
        // Header row with day names
        pw.Container(
          height: cellHeight,
          child: pw.Row(
            children: [
              pw.Container(width: professionWidth, child: _buildHeaderCell('ROOLI')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('TI')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('KE')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('TO')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('PE')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('LA')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('SU')),
              pw.Container(width: cellWidth, child: _buildHeaderCell('MA')),
            ],
          ),
        ),
        
        // Date row
        pw.Container(
          height: cellHeight,
          child: pw.Row(
            children: [
              pw.Container(width: professionWidth, child: _buildHeaderCell('PVM')),
              ...List.generate(7, (index) => 
                pw.Container(width: cellWidth, child: _buildHeaderCell(_formatDateShort(dates[index])))
              ),
            ],
          ),
        ),
        
        // Profession rows with real spanning blocks
        ..._buildRealSpanningRows(orderedProfessions, professionAssignments, dates, year, cellWidth, cellHeight, professionWidth),
      ],
    );
  }
  
  /// Build header cell
  static pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey300,
        border: pw.Border.all(color: PdfColors.grey600, width: 0.3),
      ),
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
  
  /// Build profession rows with real spanning assignment blocks
  static List<pw.Widget> _buildRealSpanningRows(
    List<String> orderedProfessions,
    Map<String, List<Assignment>> professionAssignments,
    List<DateTime> dates,
    int year,
    double cellWidth,
    double cellHeight,
    double professionWidth,
  ) {
    final rows = <pw.Widget>[];
    
    for (final profession in orderedProfessions) {
      final assignments = professionAssignments[profession]!;
      
      // Group assignments by profession row
      final rowAssignments = <int, List<Assignment>>{};
      for (final assignment in assignments) {
        rowAssignments.putIfAbsent(assignment.professionRow, () => []).add(assignment);
      }
      
      final sortedRows = rowAssignments.keys.toList()..sort();
      
      for (int rowIndex = 0; rowIndex < sortedRows.length; rowIndex++) {
        final row = sortedRows[rowIndex];
        final rowAssignmentsList = rowAssignments[row]!;
        
        rows.add(_buildProfessionRowWithSpanning(
          profession,
          rowAssignmentsList,
          dates,
          year,
          cellWidth,
          cellHeight,
          professionWidth,
          row, // Pass the actual row number
        ));
      }
    }
    
    return rows;
  }
  
  /// Build single profession row with real spanning blocks
  static pw.Widget _buildProfessionRowWithSpanning(
    String profession,
    List<Assignment> assignments,
    List<DateTime> dates,
    int year,
    double cellWidth,
    double cellHeight,
    double professionWidth,
    int professionRow,
  ) {
    return pw.Container(
      height: cellHeight,
      child: pw.Stack(
        children: [
          // Background grid
          pw.Row(
            children: [
              pw.Container(
                width: professionWidth,
                height: cellHeight,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  border: pw.Border.all(color: PdfColors.grey600, width: 0.3),
                ),
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(
                  _getProfessionDisplayNameWithNumbers(profession, professionRow), // Keep numbers!
                  style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.left, // LEFT align profession names
                ),
              ),
              ...List.generate(7, (index) => 
                pw.Container(
                  width: cellWidth,
                  height: cellHeight,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.3),
                  ),
                )
              ),
            ],
          ),
          
          // Spanning assignment blocks with proper boundaries
          ..._buildSpanningBlocksWithBoundaries(assignments, dates, year, cellWidth, cellHeight, professionWidth),
        ],
      ),
    );
  }
  
  /// Build real spanning blocks with proper boundaries to prevent cropping
  static List<pw.Widget> _buildSpanningBlocksWithBoundaries(
    List<Assignment> assignments,
    List<DateTime> dates,
    int year,
    double cellWidth,
    double cellHeight,
    double professionWidth,
  ) {
    final blocks = <pw.Widget>[];
    final processedDays = <int>{};
    
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      if (processedDays.contains(dayIndex)) continue;
      
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
        PdfColor bgColor = _getRealAppCategoryColor(employee.category); // Use REAL app colors!
        
        if (hasVacation) {
          content += ' (LOMA)';
          bgColor = PdfColors.red100;
        }
        
        // Create REAL spanning block with proper boundaries
        final blockWidth = (cellWidth * span) - 4; // Leave margin to prevent cropping
        final leftPosition = professionWidth + (dayIndex * cellWidth) + 2; // Small margin
        
        blocks.add(
          pw.Positioned(
            left: leftPosition,
            top: 2, // Small top margin
            child: pw.Container(
              width: blockWidth,
              height: cellHeight - 4, // Leave margin to prevent cropping
              decoration: pw.BoxDecoration(
                color: bgColor,
                border: pw.Border.all(color: PdfColors.grey800, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3), // Proper round corners that fit
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft, // LEFT align names!
                child: pw.Text(
                  content,
                  style: const pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.left, // LEFT align text
                  maxLines: 1,
                ),
              ),
            ),
          ),
        );
        
        processedDays.add(dayIndex);
      }
    }
    
    return blocks;
  }
  
  /// Get profession display name WITH numbers (VARU1, VARU2, PASTA1, PASTA2)
  static String _getProfessionDisplayNameWithNumbers(String profession, int professionRow) {
    try {
      final role = EmployeeRole.values.byName(profession);
      
      // Use the EXACT display name from SharedAssignmentData (includes numbers!)
      final displayName = SharedAssignmentData.getRoleDisplayName(role);
      
      // For roles with multiple rows, show them separately
      if (professionRow > 0) {
        return '$displayName${professionRow + 1}'; // Show VARU1, VARU2, etc.
      }
      
      return displayName;
    } catch (e) {
      return profession.toUpperCase();
    }
  }
  
  /// Get REAL app category colors using SharedAssignmentData
  static PdfColor _getRealAppCategoryColor(EmployeeCategory category) {
    // Get the actual color from SharedAssignmentData
    final flutterColor = SharedAssignmentData.getCategoryColor(category);
    return _convertColorToPdfColor(flutterColor);
  }
  
  /// Convert Flutter Color to PdfColor
  static PdfColor _convertColorToPdfColor(Color flutterColor) {
    return PdfColor(
      flutterColor.red / 255.0,
      flutterColor.green / 255.0,
      flutterColor.blue / 255.0,
    );
  }
  
  /// Build vacation section with proper Finnish characters and no emojis
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
          'LOMAT TÄLLÄ VIIKOLLA', // Fixed Finnish characters
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
                  '- $employeeName: ${vacation.getDisplayText()}', // Simple dash instead of bullet
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
  
  /// Get week dates using the SAME calculation as the app
  static List<DateTime> _getWeekDatesLikeApp(int weekNumber, int year) {
    final jan4 = DateTime(year, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = firstMonday.add(Duration(days: (weekNumber - 1) * 7));
    
    // Start from Tuesday (weekStart + 1 day) - SAME AS APP!
    final tuesdayStart = weekStart.add(const Duration(days: 1));
    return List.generate(7, (index) => tuesdayStart.add(Duration(days: index)));
  }
  
  /// Build PDF header with proper Finnish characters
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
            'ALUSTAVA TYÖVUOROLISTA', // Fixed ö character
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
  
  /// Build footer with proper Finnish characters
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
            'Sovi muutoksista vuorosi työnjohtajan kanssa.', // Fixed ö character
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
          ),
        ],
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