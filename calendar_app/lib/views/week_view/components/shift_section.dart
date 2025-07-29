import 'package:calendar_app/data/default_employees.dart';
import 'package:calendar_app/models/employee.dart';
import 'package:calendar_app/services/shared_assignment_data.dart';
import 'package:flutter/material.dart';

typedef EmployeeAssignments = Map<String, Employee>;

// Class for tracking assignment blocks with their position info
class AssignmentBlock {
  final Employee employee;
  final int startDay;
  final int duration;
  final int lane;
  
  AssignmentBlock({
    required this.employee,
    required this.startDay,
    required this.duration,
    required this.lane,
  });
}

// Renderable block with exact positioning
class RenderableBlock {
  final Employee employee;
  final int startDay;
  final int duration;
  final int lane;
  
  RenderableBlock({
    required this.employee,
    required this.startDay,
    required this.duration,
    required this.lane,
  });
}

// Resizing state
class ResizingState {
  final Employee employee;
  final int duration;
  final int lane;
  
  ResizingState({
    required this.employee,
    required this.duration,
    required this.lane,
  });
}

class ShiftSection extends StatefulWidget {
  final String title;
  final EmployeeAssignments assignments;
  final Map<EmployeeRole, bool> visibleProfessions;
  final Map<EmployeeRole, int> professionRows;
  final Function(Employee, int, int) onEmployeeDroppedToLane; // employee, day, lane
  final Function(Employee, String, int, int, int) onAssignmentResized; // employee, shift, startDay, oldDuration, newDuration
  final Function(Employee) onAssignmentRemoved;
  final Function(Employee) onEmployeeQuickFillMenu;

  const ShiftSection({
    super.key,
    required this.title,
    required this.assignments,
    required this.visibleProfessions,
    required this.professionRows,
    required this.onEmployeeDroppedToLane,
    required this.onAssignmentResized,
    required this.onAssignmentRemoved,
    required this.onEmployeeQuickFillMenu,
  });

  @override
  _ShiftSectionState createState() => _ShiftSectionState();
}

class _ShiftSectionState extends State<ShiftSection> {
  int? _hoverDay;
  int? _hoverLane;
  String? _longPressedEmployee; // Track which employee is in "long press mode"
  ResizingState? _resizingBlock;

  // Helper methods
  int _getRowsForProfession(EmployeeRole profession) {
    return widget.professionRows[profession] ?? 1;
  }

  String _getRoleDisplayName(EmployeeRole role) {
    // Use shared role display name method
    return SharedAssignmentData.getRoleDisplayName(role);
  }

  Color _getCategoryColor(EmployeeRole role) {
    switch (role) {
      case EmployeeRole.tj: return Colors.red[400]!;
      case EmployeeRole.varu1: return Colors.blue[400]!;
      case EmployeeRole.varu2: return Colors.green[400]!;
      case EmployeeRole.varu3: return Colors.orange[400]!;
      case EmployeeRole.varu4: return Colors.purple[400]!;
      case EmployeeRole.pasta1: return Colors.teal[400]!;
      case EmployeeRole.pasta2: return Colors.indigo[400]!;
      case EmployeeRole.ict: return Colors.brown[400]!;
      case EmployeeRole.tarvike: return Colors.pink[400]!;
      case EmployeeRole.pora: return Colors.amber[400]!;
      case EmployeeRole.huolto: return Colors.lime[400]!;
      case EmployeeRole.custom: return Colors.grey[400]!;
      case EmployeeRole.slot1: return Colors.cyan[400]!;
      case EmployeeRole.slot2: return Colors.deepOrange[400]!;
      case EmployeeRole.slot3: return Colors.lightBlue[400]!;
      case EmployeeRole.slot4: return Colors.deepPurple[400]!;
      case EmployeeRole.slot5: return Colors.lightGreen[400]!;
      case EmployeeRole.slot6: return Colors.redAccent[400]!;
      case EmployeeRole.slot7: return Colors.blueAccent[400]!;
      case EmployeeRole.slot8: return Colors.greenAccent[400]!;
      case EmployeeRole.slot9: return Colors.orangeAccent[400]!;
      case EmployeeRole.slot10: return Colors.purpleAccent[400]!;
    }
  }

  List<AssignmentBlock> _getAssignmentBlocks() {
    final List<AssignmentBlock> blocks = [];
    final Map<String, List<int>> employeeDays = {};
    
    // Group days by employee
    for (final entry in widget.assignments.entries) {
      final key = entry.key;
      final employee = entry.value;
      
      if (!key.startsWith(widget.title)) continue;
      
      final keyParts = key.split('-');
      if (keyParts.length >= 3) {
        final day = int.tryParse(keyParts[1]);
        final lane = int.tryParse(keyParts[2]);
        if (day != null && lane != null) {
          final employeeKey = '${employee.id}|$lane';
          employeeDays.putIfAbsent(employeeKey, () => []);
          employeeDays[employeeKey]!.add(day);
        }
      }
    }
    
    // Create blocks for continuous day ranges
    for (final entry in employeeDays.entries) {
      final employeeKey = entry.key;
      final days = entry.value..sort();
      final keyParts = employeeKey.split('|');
      final employeeId = keyParts[0];
      final lane = int.parse(keyParts[1]);
      
      final employee = widget.assignments.values.firstWhere((e) => e.id == employeeId);
      
      // Find continuous ranges
      int startDay = days[0];
      int currentDay = days[0];
      
      for (int i = 1; i < days.length; i++) {
        if (days[i] == currentDay + 1) {
          currentDay = days[i];
        } else {
          // End of continuous range
          blocks.add(AssignmentBlock(
            employee: employee,
            startDay: startDay,
            duration: currentDay - startDay + 1,
            lane: lane,
          ));
          startDay = days[i];
          currentDay = days[i];
        }
      }
      
      // Add the last block
      blocks.add(AssignmentBlock(
        employee: employee,
        startDay: startDay,
        duration: currentDay - startDay + 1,
        lane: lane,
      ));
    }
    
    return blocks;
  }

  List<RenderableBlock> _calculateLayout(List<AssignmentBlock> blocks) {
    return blocks.map((block) => RenderableBlock(
      employee: block.employee,
      startDay: block.startDay,
      duration: block.duration,
      lane: block.lane,
    )).toList();
  }

  void _handleEmployeeDrop(Employee employee, int targetDay, int targetLane) {
    // Just call the drop handler - the logic is now in week_view.dart
    widget.onEmployeeDroppedToLane(employee, targetDay, targetLane);
  }

  @override
  Widget build(BuildContext context) {
    final assignmentBlocks = _getAssignmentBlocks();
    final renderableBlocks = _calculateLayout(assignmentBlocks);
    
    // Calculate visible professions and their total height
    final visibleProfessions = EmployeeRole.values
        .where((role) => widget.visibleProfessions[role] == true)
        .toList();
    
    final rowHeight = 20.0;
    final totalRows = visibleProfessions.fold<int>(0, (sum, role) => sum + _getRowsForProfession(role));
    final totalHeight = totalRows * rowHeight + 40; // +40 for title
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final double dayWidth = (constraints.maxWidth - 60) / 7; // Account for profession labels

        return Container(
          height: totalHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Container(
                padding: const EdgeInsets.all(6.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4.0),
                    topRight: Radius.circular(4.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Profession labels
                    Container(
                      width: 60,
                      child: Column(
                        children: visibleProfessions.expand((profession) {
                          final rows = _getRowsForProfession(profession);
                          return List.generate(rows, (rowIndex) => 
                            Container(
                              height: rowHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[600]!, width: 0.5),
                                ),
                                color: rowIndex % 2 == 0 ? Colors.grey[850] : Colors.grey[900],
                              ),
                              child: Text(
                                rowIndex == 0 ? _getRoleDisplayName(profession) : '${rowIndex + 1}',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600, 
                                  color: rowIndex == 0 ? Colors.white : Colors.white60,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Calendar grid
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _longPressedEmployee = null;
                          });
                        },
                        child: Container(
                          color: Colors.white,
                          child: SingleChildScrollView(
                            child: Stack(
                              children: [
                                // Grid background with drag targets
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(totalRows, (row) => 
                                    Container(
                                      height: rowHeight,
                                      child: Row(
                                        children: List.generate(7, (day) => 
                                          Expanded(
                                            child: DragTarget<Employee>(
                                              onAcceptWithDetails: (details) {
                                                _handleEmployeeDrop(details.data, day, row);
                                              },
                                              onWillAcceptWithDetails: (details) {
                                                setState(() {
                                                  _hoverDay = day;
                                                  _hoverLane = row;
                                                });
                                                return true;
                                              },
                                              onLeave: (data) {
                                                setState(() {
                                                  _hoverDay = null;
                                                  _hoverLane = null;
                                                });
                                              },
                                              builder: (context, candidateData, rejectedData) {
                                                final isHovered = _hoverDay == day && _hoverLane == row;
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey[200]!, width: 0.5),
                                                    color: isHovered ? Colors.green.withOpacity(0.3) : null,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Assignment blocks
                                ...renderableBlocks.map((renderableBlock) {
                                  final isResizing = _resizingBlock?.employee.id == renderableBlock.employee.id && 
                                                    _resizingBlock?.lane == renderableBlock.lane;
                                  
                                  final displayDuration = isResizing ? _resizingBlock!.duration : renderableBlock.duration;
                                  
                                  return Positioned(
                                    left: renderableBlock.startDay * dayWidth,
                                    top: renderableBlock.lane * rowHeight,
                                    width: displayDuration * dayWidth - 0.5,
                                    height: rowHeight - 1,
                                    child: GestureDetector(
                                      onLongPress: () {
                                        setState(() {
                                          _longPressedEmployee = renderableBlock.employee.id;
                                        });
                                      },
                                      child: Draggable<Employee>(
                                        data: renderableBlock.employee,
                                        onDragEnd: (details) {
                                          final RenderBox renderBox = context.findRenderObject() as RenderBox;
                                          final localPosition = renderBox.globalToLocal(details.offset);
                                          if (localPosition.dx < 0 || localPosition.dx > constraints.maxWidth ||
                                              localPosition.dy < 0 || localPosition.dy > totalRows * rowHeight) {
                                            widget.onAssignmentRemoved(renderableBlock.employee);
                                            // NO MORE ANNOYING NOTIFICATIONS! 🎉
                                          }
                                        },
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: displayDuration * dayWidth - 0.5,
                                            height: rowHeight - 1,
                                            decoration: BoxDecoration(
                                              color: Colors.blue[400],
                                              border: Border.all(color: Colors.blue[600]!, width: 1),
                                            ),
                                            child: Center(
                                              child: Text(
                                                renderableBlock.employee.name,
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            border: Border.all(color: Colors.grey[400]!, width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              renderableBlock.employee.name,
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(renderableBlock.employee.role),
                                            border: Border.all(color: Colors.grey[400]!, width: 1),
                                          ),
                                          child: Row(
                                            children: [
                                              // Close button
                                              GestureDetector(
                                                onTap: () => widget.onAssignmentRemoved(renderableBlock.employee),
                                                child: Container(
                                                  width: 12,
                                                  color: Colors.red[400],
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 8,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              // Employee name
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => widget.onEmployeeQuickFillMenu(renderableBlock.employee),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                                    child: Center(
                                                      child: Text(
                                                        '${renderableBlock.employee.name}${displayDuration == 7 ? ' ★' : ''}',
                                                        style: const TextStyle(
                                                          fontSize: 8,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 