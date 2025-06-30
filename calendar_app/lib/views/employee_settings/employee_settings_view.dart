import 'package:flutter/material.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/models/vacation_absence.dart';
import 'package:calendar_app/data/vacation_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmployeeSettingsView extends StatefulWidget {
  const EmployeeSettingsView({super.key});

  @override
  State<EmployeeSettingsView> createState() => _EmployeeSettingsViewState();
}

class _EmployeeSettingsViewState extends State<EmployeeSettingsView> {
  List<Employee> employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = prefs.getString('employees') ?? '[]';
    final List<dynamic> employeesList = json.decode(employeesJson);
    
    setState(() {
      employees = employeesList.map((emp) => Employee.fromJson(emp)).toList();
    });
  }

  Future<void> _saveEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    final employeesJson = json.encode(employees.map((emp) => emp.toJson()).toList());
    await prefs.setString('employees', employeesJson);
  }

  void _addEmployee() {
    _showEmployeeDialog(null);
  }

  void _editEmployee(Employee employee) {
    _showEmployeeDialog(employee);
  }

  void _showEmployeeDialog(Employee? employee) {
    final nameController = TextEditingController(text: employee?.name ?? '');
    EmployeeCategory selectedCategory = employee?.category ?? EmployeeCategory.sijainen;
    EmployeeType selectedType = employee?.type ?? EmployeeType.sijainen;
    EmployeeRole selectedRole = employee?.role ?? EmployeeRole.varu1;
    ShiftCycle selectedShiftCycle = employee?.shiftCycle ?? ShiftCycle.none;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(employee == null ? 'Add Employee' : 'Edit Employee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EmployeeCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: EmployeeCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(_getCategoryName(cat)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EmployeeType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: EmployeeType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EmployeeRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: EmployeeRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ShiftCycle>(
                  value: selectedShiftCycle,
                  decoration: const InputDecoration(
                    labelText: 'Shift Cycle',
                    border: OutlineInputBorder(),
                  ),
                  items: ShiftCycle.values.map((cycle) {
                    return DropdownMenuItem(
                      value: cycle,
                      child: Text(cycle.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedShiftCycle = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                
                final newEmployee = Employee(
                  id: employee?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  category: selectedCategory,
                  type: selectedType,
                  role: selectedRole,
                  shiftCycle: selectedShiftCycle,
                );
                
                setState(() {
                  if (employee == null) {
                    employees.add(newEmployee);
                  } else {
                    final index = employees.indexWhere((emp) => emp.id == employee.id);
                    if (index != -1) {
                      employees[index] = newEmployee;
                    }
                  }
                });
                _saveEmployees();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                employees.removeWhere((emp) => emp.id == employee.id);
              });
              _saveEmployees();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _manageVacations(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => VacationDialog(employee: employee),
    );
  }

  String _getCategoryName(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
        return 'Vakituiset A/B';
      case EmployeeCategory.cd:
        return 'Vakituiset C/D';
      case EmployeeCategory.huolto:
        return 'Huolto';
      case EmployeeCategory.sijainen:
        return 'Sijaiset';
    }
  }

  Color _getCategoryColor(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
        return const Color(0xFF9DB4C0);
      case EmployeeCategory.cd:
        return const Color(0xFF5C6B73);
      case EmployeeCategory.huolto:
        return const Color(0xFF253237);
      case EmployeeCategory.sijainen:
        return const Color(0xFFBDBDBD);
    }
  }

  Color _getTextColor(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
      case EmployeeCategory.sijainen:
        return Colors.black87;
      case EmployeeCategory.cd:
      case EmployeeCategory.huolto:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<EmployeeCategory, List<Employee>> employeesByCategory = {};
    for (final employee in employees) {
      employeesByCategory.putIfAbsent(employee.category, () => []).add(employee);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Employee Settings'),
        backgroundColor: const Color(0xFF9DB4C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _addEmployee,
            icon: const Icon(Icons.add),
            tooltip: 'Add Employee',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Employee Management',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF253237),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${employees.length} employees',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF5C6B73),
              ),
            ),
            const SizedBox(height: 24),
            ...EmployeeCategory.values.map((category) {
              final categoryEmployees = employeesByCategory[category] ?? [];
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_getCategoryName(category)} (${categoryEmployees.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(category),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (categoryEmployees.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'No employees in this category',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...categoryEmployees.map((employee) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        title: Text(
                          employee.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF253237),
                          ),
                        ),
                        subtitle: Text(
                          '${employee.role.name} - ${employee.type.name}',
                          style: const TextStyle(color: Color(0xFF5C6B73)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _manageVacations(employee),
                              icon: const Icon(Icons.calendar_today, color: Color(0xFF5C6B73)),
                              tooltip: 'Manage Vacations',
                            ),
                            IconButton(
                              onPressed: () => _editEmployee(employee),
                              icon: const Icon(Icons.edit, color: Color(0xFF5C6B73)),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: () => _deleteEmployee(employee),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class VacationDialog extends StatefulWidget {
  final Employee employee;

  const VacationDialog({super.key, required this.employee});

  @override
  State<VacationDialog> createState() => _VacationDialogState();
}

class _VacationDialogState extends State<VacationDialog> {
  List<VacationAbsence> vacations = [];

  @override
  void initState() {
    super.initState();
    _loadVacations();
  }

  void _loadVacations() {
    setState(() {
      vacations = VacationManager.getEmployeeVacations(widget.employee.id);
    });
  }

  void _addVacation() {
    DateTime? startDate;
    DateTime? endDate;
    VacationAbsenceType selectedType = VacationAbsenceType.loma;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Vacation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<VacationAbsenceType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: VacationAbsenceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type == VacationAbsenceType.loma ? 'Vacation' : 'Absence'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setDialogState(() {
                            startDate = date;
                            if (endDate == null || endDate!.isBefore(startDate!)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          startDate != null
                              ? '${startDate!.day}.${startDate!.month}.${startDate!.year}'
                              : 'Select date',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) {
                          setDialogState(() {
                            endDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          endDate != null
                              ? '${endDate!.day}.${endDate!.month}.${endDate!.year}'
                              : 'Select date',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (startDate == null || endDate == null) return;
                
                final vacation = VacationAbsence(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  employeeId: widget.employee.id,
                  startDate: startDate!,
                  endDate: endDate!,
                  type: selectedType,
                );
                
                VacationManager.addVacation(vacation);
                _loadVacations();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteVacation(VacationAbsence vacation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vacation'),
        content: const Text('Delete this vacation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              VacationManager.removeVacation(vacation.id);
              _loadVacations();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.employee.name} - Vacations'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vacations (${vacations.length})', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _addVacation,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Vacation',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: vacations.isEmpty
                  ? const Center(child: Text('No vacations'))
                  : ListView.builder(
                      itemCount: vacations.length,
                      itemBuilder: (context, index) {
                        final vacation = vacations[index];
                        return Card(
                          child: ListTile(
                            title: Text(vacation.getDisplayText()),
                            subtitle: Text(
                              '${vacation.startDate.day}.${vacation.startDate.month}.${vacation.startDate.year} - '
                              '${vacation.endDate.day}.${vacation.endDate.month}.${vacation.endDate.year}',
                            ),
                            trailing: IconButton(
                              onPressed: () => _deleteVacation(vacation),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
} 
