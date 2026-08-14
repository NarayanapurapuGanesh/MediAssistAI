import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../providers/theme_provider.dart';
import '../models/medication.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class AddMedicationScreen extends StatefulWidget {
  final Medication? medicationToEdit;
  const AddMedicationScreen({super.key, this.medicationToEdit});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  String _frequency = 'Once daily';
  final List<String> _frequencies = ['Once daily', 'Twice daily', 'Thrice daily'];
  
  DateTime? _startDate;
  DateTime? _endDate;
  List<TimeOfDay> _schedules = [const TimeOfDay(hour: 8, minute: 0)];

  @override
  void initState() {
    super.initState();
    if (widget.medicationToEdit != null) {
      final med = widget.medicationToEdit!;
      _nameController.text = med.name;
      _dosageController.text = med.dosage;
      _frequency = med.frequency;
      
      try {
        _startDate = DateFormat('yyyy-MM-dd').parse(med.startDate);
        _endDate = DateFormat('yyyy-MM-dd').parse(med.endDate);
      } catch (e) {
        // Fallback
      }

      if (med.schedules.isNotEmpty) {
        _schedules = med.schedules.map((timeStr) {
          final parts = timeStr.split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }).toList();
      }
    }
  }

  void _updateSchedulesList() {
    int count = 1;
    if (_frequency == 'Twice daily') count = 2;
    if (_frequency == 'Thrice daily') count = 3;
    
    setState(() {
      if (_schedules.length < count) {
        while (_schedules.length < count) {
          _schedules.add(const TimeOfDay(hour: 12, minute: 0));
        }
      } else if (_schedules.length > count) {
        _schedules.removeRange(count, _schedules.length);
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _schedules[index],
    );
    if (picked != null) {
      setState(() {
        _schedules[index] = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select start and end dates')));
      return;
    }

    setState(() => _isLoading = true);
    
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startStr = dateFormat.format(_startDate!);
    final endStr = dateFormat.format(_endDate!);
    
    List<String> scheduleStrs = _schedules.map((t) {
      final hour = t.hour.toString().padLeft(2, '0');
      final minute = t.minute.toString().padLeft(2, '0');
      return '$hour:$minute:00';
    }).toList();

    try {
      bool success;
      if (widget.medicationToEdit == null) {
        success = await _apiService.addMedication(
          _nameController.text, 
          _dosageController.text, 
          _frequency, 
          startStr, 
          endStr, 
          scheduleStrs
        );
      } else {
        success = await _apiService.updateMedication(
          widget.medicationToEdit!.id,
          _nameController.text, 
          _dosageController.text, 
          _frequency, 
          startStr, 
          endStr, 
          scheduleStrs
        );
      }
      
      setState(() => _isLoading = false);
      if (success && mounted) {
        await NotificationService().requestPermissions();
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save medication')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.medicationToEdit == null ? 'Add Medication' : 'Edit Medication', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(top: -50, right: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6366F1).withValues(alpha: 0.2), boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFF6366F1).withValues(alpha: 0.2))]))),
          Positioned(bottom: -50, left: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A90E2).withValues(alpha: 0.2), boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFF4A90E2).withValues(alpha: 0.2))]))),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Medicine Name',
                              labelStyle: TextStyle(color: Colors.grey.shade500),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.medication, color: textColor),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dosageController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Dosage (e.g. 500mg)',
                              labelStyle: TextStyle(color: Colors.grey.shade500),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.scale, color: textColor),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),
                          Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _frequency,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: textColor)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _frequency = val;
                                _updateSchedulesList();
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectDate(context, true),
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  label: Text(_startDate == null ? 'Start Date' : DateFormat('MMM dd').format(_startDate!)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _selectDate(context, false),
                                  icon: const Icon(Icons.event, size: 18),
                                  label: Text(_endDate == null ? 'End Date' : DateFormat('MMM dd').format(_endDate!)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text('Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 8),
                          ...List.generate(_schedules.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                                ),
                                leading: const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                                title: Text('Dose ${index + 1}', style: TextStyle(color: textColor)),
                                trailing: Text(_schedules[index].format(context), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                onTap: () => _selectTime(context, index),
                              ),
                            );
                          }),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(widget.medicationToEdit == null ? 'Save Medication' : 'Update Medication', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
