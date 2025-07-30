import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/employee.dart';
import '../models/vacation_absence.dart';

class VacationDialog extends StatefulWidget {
  final List<Employee> employees;
  final Function(VacationAbsence) onSave;

  const VacationDialog({
    Key? key,
    required this.employees,
    required this.onSave,
  }) : super(key: key);

  @override
  State<VacationDialog> createState() => _VacationDialogState();
}

class _VacationDialogState extends State<VacationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  
  Employee? _selectedEmployee;
  VacationAbsenceType _selectedType = VacationAbsenceType.loma;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.beach_access, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Text(
                    'Lisää Loma/Poissaolo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Employee Selection
              Text(
                'Työntekijä',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Employee>(
                value: _selectedEmployee,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Valitse työntekijä',
                ),
                items: widget.employees.map((employee) {
                  return DropdownMenuItem<Employee>(
                    value: employee,
                    child: Text(employee.name),
                  );
                }).toList(),
                onChanged: (Employee? value) {
                  setState(() {
                    _selectedEmployee = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Valitse työntekijä';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

                             // Type Selection
               Text(
                 'Tyyppi',
                 style: Theme.of(context).textTheme.labelLarge,
               ),
               const SizedBox(height: 8),
               Row(
                 children: [
                   Expanded(
                     child: RadioListTile<VacationAbsenceType>(
                       title: const Text('Loma'),
                       value: VacationAbsenceType.loma,
                       groupValue: _selectedType,
                       onChanged: (VacationAbsenceType? value) {
                         setState(() {
                           _selectedType = value ?? VacationAbsenceType.loma;
                         });
                       },
                     ),
                   ),
                   Expanded(
                     child: RadioListTile<VacationAbsenceType>(
                       title: const Text('Poissaolo'),
                       value: VacationAbsenceType.poissaolo,
                       groupValue: _selectedType,
                       onChanged: (VacationAbsenceType? value) {
                         setState(() {
                           _selectedType = value ?? VacationAbsenceType.loma;
                         });
                       },
                     ),
                   ),
                 ],
               ),
              const SizedBox(height: 20),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alkupäivä',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _selectStartDate(),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            '${_startDate.day}.${_startDate.month}.${_startDate.year}',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loppupäivä',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _selectEndDate(),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            '${_endDate.day}.${_endDate.month}.${_endDate.year}',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Reason
              Text(
                'Syy (valinnainen)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Esim. Vuosiloma, Sairaus, Koulutus...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Peruuta'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _saveVacation,
                    icon: const Icon(Icons.save),
                    label: const Text('Tallenna'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (date != null) {
      setState(() {
        _startDate = date;
        // Ensure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate.add(const Duration(days: 1)) : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _saveVacation() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valitse työntekijä')),
      );
      return;
    }

    final vacation = VacationAbsence(
      id: const Uuid().v4(),
      employeeId: _selectedEmployee!.id,
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    widget.onSave(vacation);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }
} 