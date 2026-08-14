import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  String _wakeTime = '07:00';
  String _breakfastTime = '08:00';
  String _lunchTime = '13:00';
  String _dinnerTime = '20:00';
  String _sleepTime = '23:00';

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    setState(() => _isLoading = true);
    try {
      final routine = await _apiService.getRoutine();
      if (routine != null) {
        setState(() {
          _wakeTime = routine.wakeTime;
          _breakfastTime = routine.breakfastTime;
          _lunchTime = routine.lunchTime;
          _dinnerTime = routine.dinnerTime;
          _sleepTime = routine.sleepTime;
        });
      }
    } catch (e) {
      // Use defaults
    }
    setState(() => _isLoading = false);
  }

  Future<void> _selectTime(String label, String currentValue, Function(String) onChanged) async {
    final parts = currentValue.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select $label',
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChanged(formatted);
    }
  }

  Future<void> _saveRoutine() async {
    setState(() => _isSaving = true);
    try {
      final success = await _apiService.saveRoutine({
        'wake_time': _wakeTime,
        'breakfast_time': _breakfastTime,
        'lunch_time': _lunchTime,
        'dinner_time': _dinnerTime,
        'sleep_time': _sleepTime,
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Routine saved successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save routine.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error.')),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  String _formatTimeDisplay(String time) {
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Daily Routine', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Configure your daily schedule for personalized health reminders.',
                  style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),

                _buildTimeCard(
                  icon: Icons.wb_sunny,
                  color: const Color(0xFFF59E0B),
                  label: 'Wake Time',
                  value: _wakeTime,
                  onTap: () => _selectTime('Wake Time', _wakeTime, (v) => setState(() => _wakeTime = v)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTimeCard(
                  icon: Icons.free_breakfast,
                  color: const Color(0xFFEC4899),
                  label: 'Breakfast Time',
                  value: _breakfastTime,
                  onTap: () => _selectTime('Breakfast Time', _breakfastTime, (v) => setState(() => _breakfastTime = v)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTimeCard(
                  icon: Icons.restaurant,
                  color: const Color(0xFF10B981),
                  label: 'Lunch Time',
                  value: _lunchTime,
                  onTap: () => _selectTime('Lunch Time', _lunchTime, (v) => setState(() => _lunchTime = v)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTimeCard(
                  icon: Icons.dinner_dining,
                  color: const Color(0xFF8B5CF6),
                  label: 'Dinner Time',
                  value: _dinnerTime,
                  onTap: () => _selectTime('Dinner Time', _dinnerTime, (v) => setState(() => _dinnerTime = v)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildTimeCard(
                  icon: Icons.bedtime,
                  color: const Color(0xFF3B82F6),
                  label: 'Sleep Time',
                  value: _sleepTime,
                  onTap: () => _selectTime('Sleep Time', _sleepTime, (v) => setState(() => _sleepTime = v)),
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveRoutine,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Routine', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildTimeCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Text(_formatTimeDisplay(value), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }
}
