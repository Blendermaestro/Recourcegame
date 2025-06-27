import 'package:flutter/material.dart';
import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmployeeSettingsView extends StatefulWidget {
  const EmployeeSettingsView({super.key});

  @override
  State<EmployeeSettingsView> createState() => _EmployeeSettingsViewState();
}

class _EmployeeSettingsViewState extends State<EmployeeSettingsView> {
  List<Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = prefs.getString('employees');
    
    if (employeesJson != null) {
      final List<dynamic> employeesList = json.decode(employeesJson);
      setState(() {
        _employees = employeesList.map((e) => Employee.fromJson(e)).toList();
      });
      // Update global list
      defaultEmployees.clear();
      defaultEmployees.addAll(_employees);
    } else {
      setState(() {
        _employees = List.from(defaultEmployees);
      });
    }
  }

  Future<void> _saveEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = json.encode(_employees.map((e) => e.toJson()).toList());
    await prefs.setString('employees', employeesJson);
    
    // Update global list
    defaultEmployees.clear();
    defaultEmployees.addAll(_employees);
  }

  void _editEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _EmployeeEditDialog(
          employee: employee,
          onSave: (updatedEmployee) async {
            setState(() {
              final index = _employees.indexWhere((e) => e.id == employee.id);
              if (index != -1) {
                _employees[index] = updatedEmployee;
              }
            });
            await _saveEmployees();
          },
        );
      },
    );
  }

  void _addEmployee() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _EmployeeEditDialog(
          employee: Employee(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: '',
            category: EmployeeCategory.sijainen,
            type: EmployeeType.sijainen,
            role: EmployeeRole.varu1,
            shiftCycle: ShiftCycle.none,
          ),
          onSave: (newEmployee) async {
            setState(() {
              _employees.add(newEmployee);
            });
            await _saveEmployees();
          },
          isNewEmployee: true,
        );
      },
    );
  }

  void _deleteEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Poista työntekijä'),
          content: Text('Haluatko varmasti poistaa työntekijän ${employee.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Peruuta'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _employees.removeWhere((e) => e.id == employee.id);
                });
                await _saveEmployees();
                Navigator.of(context).pop();
              },
              child: const Text('Poista', style: TextStyle(color: Color(0xFF5C6B73))), // Payne's gray
            ),
          ],
        );
      },
    );
  }

  String _getCategoryDisplayName(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab: return 'Vakituiset A/B';
      case EmployeeCategory.cd: return 'Vakituiset C/D';
      case EmployeeCategory.huolto: return 'Huolto';
      case EmployeeCategory.sijainen: return 'Sijaiset';
    }
  }

  Color _getCategoryColor(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
        return const Color(0xFFE0FBFC); // Light cyan
      case EmployeeCategory.cd:
        return const Color(0xFFC2DFE3); // Light blue
      case EmployeeCategory.huolto:
        return const Color(0xFF9DB4C0); // Cadet gray
      case EmployeeCategory.sijainen:
        return const Color(0xFF5C6B73); // Payne's gray
    }
  }

  Color _getTextColorForCategory(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
      case EmployeeCategory.cd:
        return const Color(0xFF253237); // Dark text on light backgrounds
      case EmployeeCategory.huolto:
      case EmployeeCategory.sijainen:
        return Colors.white; // White text on darker backgrounds
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<EmployeeCategory, List<Employee>> groupedEmployees = {};
    for (final category in EmployeeCategory.values) {
      groupedEmployees[category] = _employees.where((e) => e.category == category).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE0FBFC), // Light cyan background
      appBar: AppBar(
        title: const Text('Työntekijät'),
        backgroundColor: const Color(0xFF253237), // Gunmetal
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          ElevatedButton.icon(
            onPressed: _addEmployee,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Lisää', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6B73), // Payne's gray
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ...EmployeeCategory.values.map((category) {
            final employees = groupedEmployees[category] ?? [];
            if (employees.isEmpty) return const SizedBox.shrink();
            
            return Column(
              children: [
                // Compact category header
                Container(
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        _getCategoryDisplayName(category),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTextColorForCategory(category),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${employees.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _getTextColorForCategory(category).withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                // Ultra-compact employee list
                ...employees.map((employee) {
                  return Container(
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF9DB4C0)), // Cadet gray border
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getCategoryColor(category),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: _getTextColorForCategory(category),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            employee.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF253237), // Gunmetal text
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _editEmployee(employee),
                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF9DB4C0)), // Cadet gray
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        IconButton(
                          onPressed: () => _deleteEmployee(employee),
                          icon: const Icon(Icons.delete, size: 16, color: Color(0xFF5C6B73)), // Payne's gray
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _EmployeeEditDialog extends StatefulWidget {
  final Employee employee;
  final Function(Employee) onSave;
  final bool isNewEmployee;

  const _EmployeeEditDialog({
    required this.employee,
    required this.onSave,
    this.isNewEmployee = false,
  });

  @override
  State<_EmployeeEditDialog> createState() => _EmployeeEditDialogState();
}

class _EmployeeEditDialogState extends State<_EmployeeEditDialog> {
  late TextEditingController _nameController;
  late EmployeeCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _selectedCategory = widget.employee.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;

    final updatedEmployee = Employee(
      id: widget.employee.id,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      type: _selectedCategory == EmployeeCategory.sijainen ? EmployeeType.sijainen : EmployeeType.vakityontekija,
      role: EmployeeRole.varu1, // Default role
      shiftCycle: _selectedCategory == EmployeeCategory.sijainen 
          ? ShiftCycle.none 
          : (_selectedCategory == EmployeeCategory.ab ? ShiftCycle.a : ShiftCycle.c),
    );

    widget.onSave(updatedEmployee);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNewEmployee ? 'Lisää työntekijä' : 'Muokkaa työntekijää'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nimi',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<EmployeeCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategoria',
              border: OutlineInputBorder(),
            ),
            items: EmployeeCategory.values.map((category) {
              String categoryName;
              switch (category) {
                case EmployeeCategory.ab: categoryName = 'Vakituiset A/B'; break;
                case EmployeeCategory.cd: categoryName = 'Vakituiset C/D'; break;
                case EmployeeCategory.huolto: categoryName = 'Huolto'; break;
                case EmployeeCategory.sijainen: categoryName = 'Sijaiset'; break;
              }
              return DropdownMenuItem(
                value: category,
                child: Text(categoryName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedCategory = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Peruuta'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Tallenna'),
        ),
      ],
    );
  }
} 