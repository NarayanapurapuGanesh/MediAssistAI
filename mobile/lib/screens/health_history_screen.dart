import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/health.dart';
import 'package:intl/intl.dart';

class HealthHistoryScreen extends StatefulWidget {
  const HealthHistoryScreen({super.key});

  @override
  State<HealthHistoryScreen> createState() => _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends State<HealthHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<HealthMeasurement> _history = [];
  bool _isLoading = true;
  String? _selectedType;
  int _selectedDays = 7;

  final List<String> _metricTypes = ['All', 'Heart Rate', 'SpO2', 'Blood Pressure', 'Steps', 'Sleep'];
  final Map<int, String> _periodLabels = {1: 'Today', 2: 'Yesterday', 7: '7 Days', 30: '30 Days'};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _history = await _apiService.getHealthHistory(
        type: _selectedType,
        days: _selectedDays,
        limit: 100,
      );
    } catch (e) {
      _history = [];
    }
    setState(() => _isLoading = false);
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Heart Rate': return const Color(0xFFF43F5E);
      case 'SpO2': return const Color(0xFF06B6D4);
      case 'Blood Pressure': return const Color(0xFF8B5CF6);
      case 'Steps': return const Color(0xFFF59E0B);
      case 'Sleep': return const Color(0xFF3B82F6);
      default: return const Color(0xFF6366F1);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Heart Rate': return Icons.monitor_heart;
      case 'SpO2': return Icons.air;
      case 'Blood Pressure': return Icons.favorite_border;
      case 'Steps': return Icons.directions_walk;
      case 'Sleep': return Icons.bedtime;
      default: return Icons.health_and_safety;
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
        title: Text('Health History', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // Period filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periodLabels.entries.map((entry) {
                  final isSelected = _selectedDays == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedDays = entry.key);
                        _loadData();
                      },
                      selectedColor: const Color(0xFF6366F1),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: cardColor,
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Type filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _metricTypes.map((type) {
                  final isAll = type == 'All';
                  final isSelected = isAll ? _selectedType == null : _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isAll) Icon(_getIconForType(type), size: 14, color: isSelected ? Colors.white : _getColorForType(type)),
                          if (!isAll) const SizedBox(width: 4),
                          Text(type),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedType = isAll ? null : type);
                        _loadData();
                      },
                      selectedColor: isAll ? const Color(0xFF6366F1) : _getColorForType(type),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : textColor,
                        fontSize: 13,
                      ),
                      backgroundColor: cardColor,
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: subTextColor),
                          const SizedBox(height: 16),
                          Text('No health data for this period.', style: TextStyle(color: subTextColor, fontSize: 16)),
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final m = _history[index];
                            return _buildHistoryTile(m, cardColor, textColor, subTextColor);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(HealthMeasurement m, Color cardColor, Color textColor, Color subTextColor) {
    final color = _getColorForType(m.type);
    String displayValue = m.value.toStringAsFixed(1);
    if (m.type == 'Blood Pressure' && m.secondaryValue != null) {
      displayValue = '${m.value.toInt()}/${m.secondaryValue!.toInt()}';
    } else if (m.type == 'Steps') {
      displayValue = m.value.toInt().toString();
    }

    String dateStr = '';
    try {
      final dt = DateTime.parse(m.recordedAt);
      dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (e) {
      dateStr = m.recordedAt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIconForType(m.type), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.type, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 2),
              Text(dateStr, style: TextStyle(color: subTextColor, fontSize: 12)),
            ]),
          ),
          Text('$displayValue ${m.unit}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
