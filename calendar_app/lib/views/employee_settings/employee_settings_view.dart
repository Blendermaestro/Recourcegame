import 'package:flutter/material.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:uuid/uuid.dart';

class EmployeeSettingsView extends StatefulWidget {
  const EmployeeSettingsView({Key? key}) : super(key: key);

  @override
  State<EmployeeSettingsView> createState() => _EmployeeSettingsViewState();
}

class _EmployeeSettingsViewState extends State<EmployeeSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  EmployeeCategory _selectedCategory = EmployeeCategory.ab;
  EmployeeType _selectedType = EmployeeType.vakityontekija;
  EmployeeRole _selectedRole = EmployeeRole.varu1;
  ShiftCycle _selectedShiftCycle = ShiftCycle.a;
  
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await SharedDataService.loadEmployees();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employees: $e')),
        );
      }
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newEmployee = Employee(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      type: _selectedType,
      role: _selectedRole,
      shiftCycle: _selectedShiftCycle,
    );

    try {
      await SharedDataService.saveEmployee(newEmployee);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee saved successfully')),
        );
        _nameController.clear();
        _loadEmployees(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving employee: $e')),
        );
      }
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SharedDataService.deleteEmployee(employee.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee deleted successfully')),
          );
          _loadEmployees(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting employee: $e')),
          );
        }
      }
    }
  }

  String _getCategoryDisplayName(EmployeeCategory category) {
    switch (category) {
      case EmployeeCategory.ab:
        return 'A/B';
      case EmployeeCategory.cd:
        return 'C/D';
      case EmployeeCategory.huolto:
        return 'Huolto';
      case EmployeeCategory.sijainen:
        return 'Sijainen';
    }
  }

  String _getTypeDisplayName(EmployeeType type) {
    switch (type) {
      case EmployeeType.vakityontekija:
        return 'Vakityöntekijä';
      case EmployeeType.sijainen:
        return 'Sijainen';
    }
  }

  String _getRoleDisplayName(EmployeeRole role) {
    // Use shared full name or fallback to default descriptions
    final fullName = SharedAssignmentData.customProfessionFullNames[role];
    if (fullName != null) return fullName;
    
    // Fallback for roles without custom full names
    switch (role) {
      case EmployeeRole.tj: return 'Työnjohtaja';
      case EmployeeRole.varu1: return 'Varu1';
      case EmployeeRole.varu2: return 'Varu2';
      case EmployeeRole.varu3: return 'Varu3';
      case EmployeeRole.varu4: return 'Varu4';
      case EmployeeRole.pasta1: return 'Pasta1';
      case EmployeeRole.pasta2: return 'Pasta2';
      case EmployeeRole.ict: return 'ICT';
      case EmployeeRole.tarvike: return 'Tarvike';
      case EmployeeRole.pora: return 'Pora';
      case EmployeeRole.huolto: return 'Huolto';
      case EmployeeRole.custom: return 'Custom';
      case EmployeeRole.slot1:
      case EmployeeRole.slot2:
      case EmployeeRole.slot3:
      case EmployeeRole.slot4:
      case EmployeeRole.slot5:
      case EmployeeRole.slot6:
      case EmployeeRole.slot7:
      case EmployeeRole.slot8:
      case EmployeeRole.slot9:
      case EmployeeRole.slot10:
        return 'Custom Slot ${role.name.substring(4)}'; // "slot1" -> "Custom Slot 1"
    }
  }

  String _getShiftCycleDisplayName(ShiftCycle cycle) {
    switch (cycle) {
      case ShiftCycle.a:
        return 'A';
      case ShiftCycle.b:
        return 'B';
      case ShiftCycle.c:
        return 'C';
      case ShiftCycle.d:
        return 'D';
      case ShiftCycle.abDay:
        return 'AB Day';
      case ShiftCycle.cdDay:
        return 'CD Day';
      case ShiftCycle.none:
        return 'None';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Employee',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<EmployeeCategory>(
                              value: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                              items: EmployeeCategory.values.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(_getCategoryDisplayName(category)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<EmployeeType>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                              ),
                              items: EmployeeType.values.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(_getTypeDisplayName(type)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<EmployeeRole>(
                              value: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                border: OutlineInputBorder(),
                              ),
                              items: EmployeeRole.values.map((role) {
                                return DropdownMenuItem(
                                  value: role,
                                  child: Text(_getRoleDisplayName(role)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<ShiftCycle>(
                              value: _selectedShiftCycle,
                              decoration: const InputDecoration(
                                labelText: 'Shift Cycle',
                                border: OutlineInputBorder(),
                              ),
                              items: ShiftCycle.values.map((cycle) {
                                return DropdownMenuItem(
                                  value: cycle,
                                  child: Text(_getShiftCycleDisplayName(cycle)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedShiftCycle = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveEmployee,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Save Employee'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Existing Employees',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _employees.isEmpty
                      ? const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No employees found'),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _employees.length,
                          itemBuilder: (context, index) {
                            final employee = _employees[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: employee.category.color,
                                  child: Text(
                                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(employee.name),
                                subtitle: Text(
                                  '${_getCategoryDisplayName(employee.category)} • ${_getTypeDisplayName(employee.type)} • ${_getRoleDisplayName(employee.role)} • ${_getShiftCycleDisplayName(employee.shiftCycle)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteEmployee(employee),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
