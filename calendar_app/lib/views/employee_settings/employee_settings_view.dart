import 'package:flutter/material.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:calendar_app/models/vacation_absence.dart';
import 'package:calendar_app/data/vacation_manager.dart';
import 'package:calendar_app/vacation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class EmployeeSettingsView extends StatefulWidget {
  const EmployeeSettingsView({Key? key}) : super(key: key);

  @override
  State<EmployeeSettingsView> createState() => _EmployeeSettingsViewState();
}

class _EmployeeSettingsViewState extends State<EmployeeSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  EmployeeCategory _selectedCategory = EmployeeCategory.ab;
  
  List<Employee> _employees = [];
  List<VacationAbsence> _vacations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadVacations();
    _loadCategoryColors();
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

  Future<void> _loadVacations() async {
    try {
      await VacationManager.loadVacations();
      setState(() {
        _vacations = VacationManager.vacations;
      });
    } catch (e) {
      print('Error loading vacations: $e');
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 🔥 Automatically set role based on category
    final role = _selectedCategory == EmployeeCategory.kommentit 
        ? EmployeeRole.kommentit 
        : EmployeeRole.varu1;
    
    final newEmployee = Employee(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      type: EmployeeType.vakityontekija, // Default type
      role: role, // 🔥 Auto-set role based on category
      shiftCycle: ShiftCycle.a, // Default shift cycle
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

  Future<void> _editEmployee(Employee employee) async {
    EmployeeCategory selectedCategory = employee.category;
    
    final result = await showDialog<EmployeeCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category for ${employee.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current category: ${_getCategoryDisplayName(employee.category)}'),
            const SizedBox(height: 16),
            Text('Select new category:'),
            const SizedBox(height: 8),
            ...EmployeeCategory.values.map((category) => RadioListTile<EmployeeCategory>(
              title: Text(_getCategoryDisplayName(category)),
              value: category,
              groupValue: selectedCategory,
              onChanged: (value) {
                selectedCategory = value!;
                Navigator.pop(context, selectedCategory);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result != employee.category) {
      try {
        // Create updated employee with new category
        final updatedEmployee = Employee(
          id: employee.id,
          name: employee.name,
          category: result,
          type: employee.type,
          role: employee.role,
          shiftCycle: employee.shiftCycle,
        );

        await SharedDataService.saveEmployee(updatedEmployee);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${employee.name} category updated to ${_getCategoryDisplayName(result)}')),
          );
          _loadEmployees(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating employee: $e')),
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
      case EmployeeCategory.kommentit:
        return 'Kommentit'; // 🔥 Comments category
    }
  }

  void _showColorPicker(EmployeeCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose Color for ${_getCategoryDisplayName(category)}'),
        content: Container(
          width: 300,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _colorOptions.length,
            itemBuilder: (context, index) {
              final color = _colorOptions[index];
              final isSelected = SharedAssignmentData.getCategoryColor(category).value == color.value;
              
              return GestureDetector(
                onTap: () {
                  _updateCategoryColor(category, color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _updateCategoryColor(EmployeeCategory category, Color color) {
    setState(() {
      SharedAssignmentData.customCategoryColors[category] = color;
    });
    _saveCategoryColors();
  }

  Future<void> _saveCategoryColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorMap = SharedAssignmentData.customCategoryColors.map(
        (category, color) => MapEntry(category.name, color.value),
      );
      await prefs.setString('custom_category_colors', json.encode(colorMap));
      print('✅ Saved custom category colors');
    } catch (e) {
      print('❌ Error saving category colors: $e');
    }
  }

  Future<void> _loadCategoryColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorJson = prefs.getString('custom_category_colors');
      if (colorJson != null) {
        final Map<String, dynamic> colorMap = json.decode(colorJson);
        for (final entry in colorMap.entries) {
          final category = EmployeeCategory.values.firstWhere(
            (c) => c.name == entry.key,
            orElse: () => EmployeeCategory.ab,
          );
          SharedAssignmentData.customCategoryColors[category] = Color(entry.value);
        }
        print('✅ Loaded custom category colors');
      }
    } catch (e) {
      print('❌ Error loading category colors: $e');
    }
  }

  // Color palette options
  static const List<Color> _colorOptions = [
    // Reds
    Color(0xFFFFCDD2), Color(0xFFEF9A9A), Color(0xFFE57373), Color(0xFFEF5350), Color(0xFFF44336),
    // Blues  
    Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF2196F3),
    // Greens
    Color(0xFFC8E6C9), Color(0xFFA5D6A7), Color(0xFF81C784), Color(0xFF66BB6A), Color(0xFF4CAF50),
    // Yellows
    Color(0xFFFFF9C4), Color(0xFFFFF59D), Color(0xFFFFF176), Color(0xFFFFEE58), Color(0xFFFFEB3B),
    // Oranges
    Color(0xFFFFE0B2), Color(0xFFFFCC80), Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFF9800),
    // Purples
    Color(0xFFE1BEE7), Color(0xFFCE93D8), Color(0xFFBA68C8), Color(0xFFAB47BC), Color(0xFF9C27B0),
    // Pinks
    Color(0xFFF8BBD9), Color(0xFFF48FB1), Color(0xFFF06292), Color(0xFFEC407A), Color(0xFFE91E63),
    // Teals
    Color(0xFFB2DFDB), Color(0xFF80CBC4), Color(0xFF4DB6AC), Color(0xFF26A69A), Color(0xFF009688),
    // Greys
    Color(0xFFE0E0E0), Color(0xFFBDBDBD), Color(0xFF9E9E9E), Color(0xFF757575), Color(0xFF616161),
  ];

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
                  // 🔥 NEW: Vacation Management Section
                  _buildVacationSection(),
                  const SizedBox(height: 20),
                  
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
                      : _buildCategorizedEmployeeList(),
                  const SizedBox(height: 24),
                  Text(
                    'Category Colors',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customize category colors that appear in calendars:',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ...EmployeeCategory.values.map((category) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  // Color preview circle
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: SharedAssignmentData.getCategoryColor(category),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[300]!, width: 2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Category name
                                  Expanded(
                                    child: Text(
                                      _getCategoryDisplayName(category),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  // Change color button
                                  ElevatedButton.icon(
                                    onPressed: () => _showColorPicker(category),
                                    icon: const Icon(Icons.palette, size: 18),
                                    label: const Text('Change Color'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 🔥 NEW: Vacation Management Section
  Widget _buildVacationSection() {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.beach_access, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Lomat ja Poissaolot'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_vacations.length}',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Add vacation button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddVacationDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Lisää Loma/Poissaolo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Current vacations list
                if (_vacations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Ei lomia tai poissaoloja',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else
                  ...(_vacations.map((vacation) => _buildVacationItem(vacation))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationItem(VacationAbsence vacation) {
    final employee = _employees.where((e) => e.id == vacation.employeeId).firstOrNull;
    final employeeName = employee?.name ?? 'Tuntematon työntekijä';
    
    final now = DateTime.now();
    final isActive = vacation.isActiveOn(now);
    final isUpcoming = vacation.startDate.isAfter(now);
    
    Color statusColor = Colors.grey;
    String statusText = 'Päättynyt';
    IconData statusIcon = Icons.history;
    
    if (isActive) {
      statusColor = Colors.red;
      statusText = 'Käynnissä';
      statusIcon = Icons.block;
    } else if (isUpcoming) {
      statusColor = Colors.orange;
      statusText = 'Tuleva';
      statusIcon = Icons.schedule;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: statusColor.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(statusIcon, color: statusColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  vacation.getDisplayText(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (vacation.reason != null && vacation.reason!.isNotEmpty)
                  Text(
                    vacation.reason!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _deleteVacation(vacation.id),
            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _showAddVacationDialog() {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lisää ensin työntekijöitä!')),
      );
      return;
    }
    
    // Filter out comment employees from vacation system
    final vacationEmployees = _employees.where((e) => e.role != EmployeeRole.kommentit).toList();
    
    if (vacationEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ei työntekijöitä lomajärjestelmään!')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => VacationDialog(
        employees: vacationEmployees,
        onSave: (vacation) async {
          try {
            await VacationManager.addVacation(vacation);
            await _loadVacations(); // Refresh the list
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ Loma/poissaolo lisätty: ${vacation.getDisplayText()}')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Virhe: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // 🔥 NEW: Build categorized employee list
  Widget _buildCategorizedEmployeeList() {
    // Group employees by CATEGORY (not role!) for better organization
    final employeesByCategory = <EmployeeCategory, List<Employee>>{};
    
    for (final employee in _employees) {
      employeesByCategory.putIfAbsent(employee.category, () => []);
      employeesByCategory[employee.category]!.add(employee);
    }
    
    // Sort categories to put comments at the bottom
    final sortedCategories = employeesByCategory.keys.toList()..sort((a, b) {
      if (a == EmployeeCategory.kommentit) return 1;
      if (b == EmployeeCategory.kommentit) return -1;
      return a.name.compareTo(b.name);
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedCategories.map((category) {
        final employees = employeesByCategory[category]!;
        final isCommentCategory = category == EmployeeCategory.kommentit;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Row(
              children: [
                                 Container(
                   width: 16,
                   height: 16,
                   decoration: BoxDecoration(
                     color: isCommentCategory ? Colors.black : SharedAssignmentData.getCategoryColor(category),
                     borderRadius: BorderRadius.circular(3),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text(
                   _getCategoryDisplayName(category),
                   style: const TextStyle(fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(width: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(
                     color: (isCommentCategory ? Colors.black : SharedAssignmentData.getCategoryColor(category)).withOpacity(0.1),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Text(
                     '${employees.length}',
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                   ),
                 ),
              ],
            ),
            initiallyExpanded: true,
            children: employees.map((employee) => ListTile(
              leading: CircleAvatar(
                backgroundColor: isCommentCategory ? Colors.black : SharedAssignmentData.getCategoryColor(employee.category),
                child: Text(
                  employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(employee.name),
              subtitle: Text('${_getCategoryDisplayName(employee.category)} - ${SharedAssignmentData.getRoleDisplayName(employee.role)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editEmployee(employee),
                    tooltip: 'Edit Category',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEmployee(employee),
                    tooltip: 'Delete Employee',
                  ),
                ],
              ),
            )).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _deleteVacation(String vacationId) async {
    final vacation = _vacations.where((v) => v.id == vacationId).firstOrNull;
    if (vacation == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poista loma/poissaolo'),
        content: Text('Haluatko varmasti poistaa: ${vacation.getDisplayText()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Peruuta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Poista'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await VacationManager.removeVacation(vacationId);
        await _loadVacations(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Loma/poissaolo poistettu')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Virhe: $e')),
          );
        }
      }
    }
  }
}
