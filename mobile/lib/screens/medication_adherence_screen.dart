import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class MedicationAdherenceScreen extends StatefulWidget {
  const MedicationAdherenceScreen({super.key});

  @override
  State<MedicationAdherenceScreen> createState() => _MedicationAdherenceScreenState();
}

class _MedicationAdherenceScreenState extends State<MedicationAdherenceScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _adherence = {};
  Map<String, dynamic> _todayMeds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getMedicationAdherence(),
        _apiService.getTodayMedications(),
      ]);
      setState(() {
        _adherence = results[0];
        _todayMeds = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _recordEvent(int medId, String scheduledTime, String status) async {
    await _apiService.recordMedicationEvent(medId, scheduledTime, status);
    _loadData();
  }

  String _formatTimeIST(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        final minStr = minute.toString().padLeft(2, '0');
        return '$hour12:$minStr $period';
      }
    } catch (_) {}
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9);

    final adherencePct = (_adherence['adherence_percentage'] as num?)?.toDouble() ?? 0.0;
    final taken = _adherence['taken'] ?? 0;
    final missed = _adherence['missed'] ?? 0;
    final skipped = _adherence['skipped'] ?? 0;
    final total = _adherence['total_scheduled'] ?? 0;

    final todayMeds = (_todayMeds['medications'] as List?) ?? [];
    final todayCompleted = _todayMeds['completed'] ?? 0;
    final todayTotal = _todayMeds['total_scheduled'] ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Medication Adherence', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Overall adherence card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: adherencePct >= 80
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('Overall Adherence', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('${adherencePct.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatBadge('Taken', taken.toString(), Colors.white),
                            _buildStatBadge('Missed', missed.toString(), Colors.white),
                            _buildStatBadge('Skipped', skipped.toString(), Colors.white),
                            _buildStatBadge('Total', total.toString(), Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Today's status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today's Medications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      Text('$todayCompleted / $todayTotal', style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (todayMeds.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        Icon(Icons.check_circle, size: 48, color: subTextColor),
                        const SizedBox(height: 12),
                        Text('No medications scheduled for today.', style: TextStyle(color: subTextColor)),
                      ]),
                    )
                  else
                    ...todayMeds.map((med) {
                      final medMap = med as Map<String, dynamic>;
                      final status = medMap['status'] ?? 'Pending';
                      final name = medMap['medication_name'] ?? '';
                      final dosage = medMap['dosage'] ?? '';
                      final time = medMap['scheduled_time'] ?? '';
                      final medId = medMap['medication_id'] ?? 0;

                      Color statusColor = const Color(0xFFF59E0B);
                      IconData statusIcon = Icons.pending;
                      if (status == 'Taken') { statusColor = const Color(0xFF10B981); statusIcon = Icons.check_circle; }
                      if (status == 'Missed') { statusColor = const Color(0xFFEF4444); statusIcon = Icons.cancel; }
                      if (status == 'Skipped') { statusColor = Colors.grey; statusIcon = Icons.skip_next; }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
                                Text('$dosage • ${_formatTimeIST(time)}', style: TextStyle(color: subTextColor, fontSize: 13)),
                              ]),
                            ),
                            if (status == 'Pending') ...[
                              IconButton(
                                icon: const Icon(Icons.check, color: Color(0xFF10B981)),
                                onPressed: () => _recordEvent(medId, time, 'Taken'),
                                tooltip: 'Mark as taken',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
                                onPressed: () => _recordEvent(medId, time, 'Missed'),
                                tooltip: 'Mark as missed',
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
    ]);
  }
}
