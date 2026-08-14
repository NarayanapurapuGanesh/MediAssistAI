import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'dart:ui';

class AddHealthScreen extends StatefulWidget {
  const AddHealthScreen({super.key});

  @override
  State<AddHealthScreen> createState() => _AddHealthScreenState();
}

class _AddHealthScreenState extends State<AddHealthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _secondaryController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  String _selectedType = 'Heart Rate';
  final Map<String, String> _metrics = {
    'Heart Rate': 'BPM',
    'SpO2': '%',
    'Blood Pressure': 'mmHg',
    'Steps': 'steps',
    'Sleep': 'hours',
  };

  final Map<String, String> _hints = {
    'Heart Rate': 'e.g. 72',
    'SpO2': 'e.g. 98',
    'Blood Pressure': 'Systolic (e.g. 120)',
    'Steps': 'e.g. 8500',
    'Sleep': 'e.g. 7.5',
  };

  final Map<String, IconData> _icons = {
    'Heart Rate': Icons.monitor_heart,
    'SpO2': Icons.air,
    'Blood Pressure': Icons.favorite_border,
    'Steps': Icons.directions_walk,
    'Sleep': Icons.bedtime,
  };

  final Map<String, Color> _colors = {
    'Heart Rate': const Color(0xFFF43F5E),
    'SpO2': const Color(0xFF06B6D4),
    'Blood Pressure': const Color(0xFF8B5CF6),
    'Steps': const Color(0xFFF59E0B),
    'Sleep': const Color(0xFF3B82F6),
  };

  bool get _isBP => _selectedType == 'Blood Pressure';

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final value = double.tryParse(_valueController.text);
    double? secondaryValue;
    if (_isBP && _secondaryController.text.isNotEmpty) {
      secondaryValue = double.tryParse(_secondaryController.text);
    }

    if (value != null) {
      try {
        final success = await _apiService.addHealthMeasurement(
          _selectedType,
          value,
          _metrics[_selectedType]!,
          "Manual",
          secondaryValue: secondaryValue,
        );

        setState(() => _isLoading = false);
        if (success && mounted) {
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add data')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error.')),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.7);
    final accentColor = _colors[_selectedType] ?? const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Add Health Data', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.2),
                boxShadow: [BoxShadow(blurRadius: 100, color: accentColor.withValues(alpha: 0.2))],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFF06B6D4).withValues(alpha: 0.2))],
              ),
            ),
          ),
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
                          Text('Metric Type',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(_icons[_selectedType], color: accentColor),
                            ),
                            items: _metrics.keys.map((type) =>
                              DropdownMenuItem(
                                value: type,
                                child: Row(children: [
                                  Icon(_icons[type], size: 18, color: _colors[type]),
                                  const SizedBox(width: 8),
                                  Text(type, style: TextStyle(color: textColor)),
                                ]),
                              ),
                            ).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedType = val;
                                  _valueController.clear();
                                  _secondaryController.clear();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _valueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: _isBP ? 'Systolic (${_metrics[_selectedType]})' : 'Value (${_metrics[_selectedType]})',
                              hintText: _hints[_selectedType],
                              labelStyle: TextStyle(color: Colors.grey.shade500),
                              hintStyle: TextStyle(color: Colors.grey.shade600),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.edit, color: textColor),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (double.tryParse(val) == null) return 'Must be a number';
                              return null;
                            },
                          ),
                          if (_isBP) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _secondaryController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Diastolic (${_metrics[_selectedType]})',
                                hintText: 'e.g. 80',
                                labelStyle: TextStyle(color: Colors.grey.shade500),
                                hintStyle: TextStyle(color: Colors.grey.shade600),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: Icon(Icons.edit, color: textColor),
                              ),
                              validator: (val) {
                                if (_isBP) {
                                  if (val == null || val.isEmpty) return 'Required for Blood Pressure';
                                  if (double.tryParse(val) == null) return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Save & Analyze',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
