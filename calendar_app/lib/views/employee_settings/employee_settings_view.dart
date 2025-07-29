import 'package:flutter/material.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/services/shared_data_service.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newEmployee = Employee(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _selectedCategory,
      type: EmployeeType.vakityontekija, // Default type
      role: EmployeeRole.varu1, // Default role
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
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _employees.length,
                          itemBuilder: (context, index) {
                            final employee = _employees[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: SharedAssignmentData.getCategoryColor(employee.category),
                                  child: Text(
                                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(employee.name),
                                subtitle: Text(_getCategoryDisplayName(employee.category)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteEmployee(employee),
                                ),
                              ),
                            );
                          },
                        ),
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
}
