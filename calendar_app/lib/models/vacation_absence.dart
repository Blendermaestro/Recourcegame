enum VacationAbsenceType {
  loma, // Vacation
  poissaolo, // Absence
}

class VacationAbsence {
  final String id;
  final String employeeId;
  final VacationAbsenceType type;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason; // For poissaolo (absence) - required, for loma (vacation) - optional
  final String? notes;

  VacationAbsence({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'type': type.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'notes': notes,
    };
  }

  factory VacationAbsence.fromJson(Map<String, dynamic> json) {
    return VacationAbsence(
      id: json['id'],
      employeeId: json['employeeId'],
      type: VacationAbsenceType.values.byName(json['type']),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      reason: json['reason'],
      notes: json['notes'],
    );
  }

  String getDisplayText() {
    final startFormatted = '${startDate.day}.${startDate.month}';
    final endFormatted = '${endDate.day}.${endDate.month}';
    
    switch (type) {
      case VacationAbsenceType.loma:
        return 'Loma $startFormatted-$endFormatted';
      case VacationAbsenceType.poissaolo:
        return 'Poissaolo $startFormatted-$endFormatted';
    }
  }

  bool isActiveOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    
    return dateOnly.isAtSameMomentAs(startOnly) || 
           dateOnly.isAtSameMomentAs(endOnly) ||
           (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
  }
} 