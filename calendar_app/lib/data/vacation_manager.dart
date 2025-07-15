import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/vacation_absence.dart';

class VacationManager {
  static final List<VacationAbsence> _vacations = [];
  
  static List<VacationAbsence> get vacations => List.unmodifiable(_vacations);
  
  static Future<void> loadVacations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vacationsJson = prefs.getString('vacations');
      
      if (vacationsJson != null) {
        final List<dynamic> vacationsList = json.decode(vacationsJson);
        _vacations.clear();
        _vacations.addAll(vacationsList.map((v) => VacationAbsence.fromJson(v)).toList());
        print('VacationManager: Loaded ${_vacations.length} vacation/absence records');
      }
    } catch (e) {
      print('VacationManager: Error loading vacations: $e');
    }
  }
  
  static Future<void> saveVacations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vacationsJson = json.encode(_vacations.map((v) => v.toJson()).toList());
      await prefs.setString('vacations', vacationsJson);
      print('VacationManager: Saved ${_vacations.length} vacation/absence records');
    } catch (e) {
      print('VacationManager: Error saving vacations: $e');
    }
  }
  
  static Future<void> addVacation(VacationAbsence vacation) async {
    _vacations.add(vacation);
    await saveVacations();
  }
  
  static Future<void> removeVacation(String vacationId) async {
    _vacations.removeWhere((v) => v.id == vacationId);
    await saveVacations();
  }
  
  static List<VacationAbsence> getEmployeeVacations(String employeeId) {
    return _vacations.where((v) => v.employeeId == employeeId).toList();
  }
  
  static VacationAbsence? getActiveVacation(String employeeId, DateTime date) {
    return _vacations
        .where((v) => v.employeeId == employeeId && v.isActiveOn(date))
        .firstOrNull;
  }
  
  static bool isEmployeeOnVacation(String employeeId, DateTime date) {
    return getActiveVacation(employeeId, date) != null;
  }
  
  static List<VacationAbsence> getCurrentVacations(String employeeId) {
    final now = DateTime.now();
    return _vacations
        .where((v) => v.employeeId == employeeId && 
                      (v.endDate.isAfter(now) || v.endDate.isAtSameMomentAs(now)))
        .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  static Future<void> clearAll() async {
    _vacations.clear();
    await saveVacations();
    print('VacationManager: All vacation data cleared');
  }
} 