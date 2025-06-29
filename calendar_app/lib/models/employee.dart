import 'package:flutter/material.dart';

// Using enums for properties that have a fixed set of options.
// This prevents typos and makes the code more readable.

enum EmployeeType {
  vakityontekija,
  sijainen,
}

enum EmployeeRole {
  tj,       // Työnjohtaja - ALWAYS FIRST!
  varu1,
  varu2,
  varu3,
  varu4,
  pasta1,
  pasta2,
  ict,
  tarvike,
  pora,
  huolto,
  custom,   // Special role for custom professions
}

enum ShiftCycle {
  a,
  b,
  c,
  d,
  abDay, // Works only day shifts on A/B weeks
  cdDay, // Works only day shifts on C/D weeks
  none,  // For substitutes or others without a fixed cycle
}

// Housing locations
enum HousingLocation {
  levijarviA,
  levijarviB,
  etelarakkaA,
  etelarakkaB,
  eiMajoitusta, // No housing needed
}

// Extension for housing location display names
extension HousingLocationExtension on HousingLocation {
  String get displayName {
    switch (this) {
      case HousingLocation.levijarviA:
        return 'LevijärviA';
      case HousingLocation.levijarviB:
        return 'LevijärviB';
      case HousingLocation.etelarakkaA:
        return 'EtelärakkaA';
      case HousingLocation.etelarakkaB:
        return 'EtelärakkaB';
      case HousingLocation.eiMajoitusta:
        return 'Ei majoitusta';
    }
  }
  
  String get shortName {
    switch (this) {
      case HousingLocation.levijarviA:
        return 'LeviA';
      case HousingLocation.levijarviB:
        return 'LeviB';
      case HousingLocation.etelarakkaA:
        return 'RakkaA';
      case HousingLocation.etelarakkaB:
        return 'RakkaB';
      case HousingLocation.eiMajoitusta:
        return 'Ei maj.';
    }
  }
  
  Color get color {
    switch (this) {
      case HousingLocation.levijarviA:
        return Colors.green[700]!;
      case HousingLocation.levijarviB:
        return Colors.green[500]!;
      case HousingLocation.etelarakkaA:
        return Colors.purple[700]!;
      case HousingLocation.etelarakkaB:
        return Colors.purple[500]!;
      case HousingLocation.eiMajoitusta:
        return Colors.grey[600]!;
    }
  }
}

// Housing limits for each location
class HousingLimits {
  int dayLimit;
  int nightLimit;
  
  HousingLimits({this.dayLimit = 4, this.nightLimit = 4});
}

enum EmployeeCategory {
  ab,
  cd,
  huolto,
  sijainen;

  // Add color property to the enum
  Color get color {
    switch (this) {
      case EmployeeCategory.ab:
        return Colors.red[300]!; // Light passionate red
      case EmployeeCategory.cd:
        return Colors.blue[300]!; // Light passionate blue
      case EmployeeCategory.huolto:
        return Colors.yellow[400]!; // Light passionate yellow
      case EmployeeCategory.sijainen:
        return Colors.green[300]!; // Light passionate green
    }
  }
}

class Employee {
  final String id;
  final String name;
  final EmployeeCategory category;
  final EmployeeType type;
  final EmployeeRole role;
  final ShiftCycle shiftCycle;
  final List<DateTimeRange> vacations;

  Employee({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.role,
    required this.shiftCycle,
    this.vacations = const [],
  });

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'type': type.index,
      'role': role.index,
      'shiftCycle': shiftCycle.index,
      'vacations': vacations.map((v) => {
        'start': v.start.millisecondsSinceEpoch,
        'end': v.end.millisecondsSinceEpoch,
      }).toList(),
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    final List<dynamic> vacationsJson = json['vacations'] ?? [];
    final List<DateTimeRange> vacations = vacationsJson.map((v) => 
      DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(v['start']),
        end: DateTime.fromMillisecondsSinceEpoch(v['end']),
      )
    ).toList();

    return Employee(
      id: json['id'],
      name: json['name'],
      category: EmployeeCategory.values[json['category']],
      type: EmployeeType.values[json['type']],
      role: EmployeeRole.values[json['role']],
      shiftCycle: ShiftCycle.values[json['shiftCycle']],
      vacations: vacations,
    );
  }

  // Supabase serialization (using string enums for database storage)
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'type': type.name,
      'role': role.name,
      'shift_cycle': shiftCycle.name,
    };
  }

  factory Employee.fromSupabase(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      category: EmployeeCategory.values.firstWhere((e) => e.name == json['category']),
      type: EmployeeType.values.firstWhere((e) => e.name == json['type']),
      role: EmployeeRole.values.firstWhere((e) => e.name == json['role']),
      shiftCycle: ShiftCycle.values.firstWhere((e) => e.name == json['shift_cycle']),
      vacations: const [], // Vacations will be handled separately if needed
    );
  }

  // Check if employee is on holiday on a specific date
  bool isOnHoliday(DateTime date) {
    for (final vacation in vacations) {
      if (date.isAfter(vacation.start.subtract(const Duration(days: 1))) &&
          date.isBefore(vacation.end.add(const Duration(days: 1)))) {
        return true;
      }
    }
    return false;
  }

  // Check if employee is on holiday during a week (any day of the week)
  bool isOnHolidayDuringWeek(List<DateTime> weekDates) {
    return weekDates.any((date) => isOnHoliday(date));
  }

  // Get holiday status for a specific day index (0-6)
  bool isOnHolidayOnDayIndex(int dayIndex, List<DateTime> weekDates) {
    if (dayIndex < 0 || dayIndex >= weekDates.length) return false;
    return isOnHoliday(weekDates[dayIndex]);
  }

  // Copy method for updating employee data
  Employee copyWith({
    String? id,
    String? name,
    EmployeeCategory? category,
    EmployeeType? type,
    EmployeeRole? role,
    ShiftCycle? shiftCycle,
    List<DateTimeRange>? vacations,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      role: role ?? this.role,
      shiftCycle: shiftCycle ?? this.shiftCycle,
      vacations: vacations ?? this.vacations,
    );
  }
}

// Custom profession manager class
class CustomProfession {
  final String id;
  final String name;
  final String shortName;
  final bool defaultDayVisible;
  final bool defaultNightVisible;
  final int defaultRows;

  const CustomProfession({
    required this.id,
    required this.name,
    required this.shortName,
    this.defaultDayVisible = true,
    this.defaultNightVisible = true,
    this.defaultRows = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'defaultDayVisible': defaultDayVisible,
      'defaultNightVisible': defaultNightVisible,
      'defaultRows': defaultRows,
    };
  }

  factory CustomProfession.fromJson(Map<String, dynamic> json) {
    return CustomProfession(
      id: json['id'],
      name: json['name'],
      shortName: json['shortName'],
      defaultDayVisible: json['defaultDayVisible'] ?? true,
      defaultNightVisible: json['defaultNightVisible'] ?? true,
      defaultRows: json['defaultRows'] ?? 1,
    );
  }
}

// Custom profession manager
class CustomProfessionManager {
  static final Map<String, CustomProfession> _customProfessions = {};
  
  static List<CustomProfession> get allCustomProfessions => _customProfessions.values.toList();
  
  static void addCustomProfession(CustomProfession profession) {
    _customProfessions[profession.id] = profession;
  }
  
  static void removeCustomProfession(String id) {
    _customProfessions.remove(id);
  }
  
  static CustomProfession? getCustomProfession(String id) {
    return _customProfessions[id];
  }
  
  static bool hasCustomProfession(String id) {
    return _customProfessions.containsKey(id);
  }
  
  static void clearAll() {
    _customProfessions.clear();
  }
  
  static Map<String, dynamic> toJson() {
    return {
      'customProfessions': _customProfessions.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
  
  static void fromJson(Map<String, dynamic> json) {
    _customProfessions.clear();
    if (json['customProfessions'] != null) {
      final Map<String, dynamic> profs = json['customProfessions'];
      for (final entry in profs.entries) {
        _customProfessions[entry.key] = CustomProfession.fromJson(entry.value);
      }
    }
  }
} 