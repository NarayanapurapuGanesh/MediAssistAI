import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/health.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HealthDetailScreen extends StatefulWidget {
  final String metricType;
  const HealthDetailScreen({super.key, required this.metricType});

  @override
  State<HealthDetailScreen> createState() => _HealthDetailScreenState();
}

class _HealthDetailScreenState extends State<HealthDetailScreen> {
  final ApiService _apiService = ApiService();
  List<HealthMeasurement> _history = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getHealthHistory(type: widget.metricType, days: _selectedDays),
        _apiService.getHealthAnalytics(days: _selectedDays),
      ]);
      setState(() {
        _history = results[0] as List<HealthMeasurement>;
        final analyticsResponse = results[1] as Map<String, dynamic>;
        _analytics = (analyticsResponse['analytics'] as Map<String, dynamic>?)?[widget.metricType] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getIcon() {
    switch (widget.metricType) {
      case 'Heart Rate': return Icons.monitor_heart;
      case 'SpO2': return Icons.air;
      case 'Blood Pressure': return Icons.favorite_border;
      case 'Steps': return Icons.directions_walk;
      case 'Sleep': return Icons.bedtime;
      default: return Icons.health_and_safety;
    }
  }

  Color _getColor() {
    switch (widget.metricType) {
      case 'Heart Rate': return const Color(0xFFF43F5E);
      case 'SpO2': return const Color(0xFF06B6D4);
      case 'Blood Pressure': return const Color(0xFF8B5CF6);
      case 'Steps': return const Color(0xFFF59E0B);
      case 'Sleep': return const Color(0xFF3B82F6);
      default: return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9);
    final accentColor = _getColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(children: [
          Icon(_getIcon(), color: accentColor, size: 24),
          const SizedBox(width: 8),
          Text(widget.metricType, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        ]),
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
                  // Period selector
                  _buildPeriodSelector(cardColor, textColor, accentColor),
                  const SizedBox(height: 20),

                  // Analytics summary cards
                  if (_analytics.isNotEmpty) ...[
                    _buildAnalyticsSummary(cardColor, textColor, subTextColor, accentColor),
                    const SizedBox(height: 20),
                  ],

                  // Chart
                  if (_history.isNotEmpty) ...[
                    _buildChart(cardColor, textColor, accentColor, isDark),
                    const SizedBox(height: 20),
                  ],

                  // History list
                  Text('Recent Readings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('No data available for this period.', style: TextStyle(color: subTextColor)),
                    ))
                  else
                    ..._history.map((m) => _buildReadingTile(m, cardColor, textColor, subTextColor, accentColor)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(Color cardColor, Color textColor, Color accentColor) {
    return Row(
      children: [7, 14, 30].map((days) {
        final isSelected = _selectedDays == days;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedDays = days);
              _loadData();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$days Days',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalyticsSummary(Color cardColor, Color textColor, Color subTextColor, Color accentColor) {
    final status = _analytics['status'] ?? 'normal';
    final trend = _analytics['trend'] ?? 'stable';
    final current = _analytics['current']?.toString() ?? '--';
    final avg = _analytics['average']?.toString() ?? '--';
    final min = _analytics['min']?.toString() ?? '--';
    final max = _analytics['max']?.toString() ?? '--';
    final changePct = (_analytics['change_percent'] as num?)?.toDouble() ?? 0.0;
    final unit = _analytics['unit'] ?? '';

    Color statusColor = const Color(0xFF10B981);
    String statusLabel = 'Normal';
    if (status == 'attention') { statusColor = const Color(0xFFF59E0B); statusLabel = 'Attention'; }
    if (status == 'abnormal') { statusColor = const Color(0xFFEF4444); statusLabel = 'Abnormal'; }

    IconData trendIcon = Icons.trending_flat;
    if (trend == 'increasing') trendIcon = Icons.trending_up;
    if (trend == 'decreasing') trendIcon = Icons.trending_down;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current', style: TextStyle(color: subTextColor, fontSize: 13)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(current, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(width: 4),
                    Text(unit, style: TextStyle(color: subTextColor, fontSize: 14)),
                  ],
                ),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  Icon(Icons.circle, size: 8, color: statusColor),
                  const SizedBox(width: 6),
                  Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('Average', avg, subTextColor, textColor),
              _buildStatItem('Min', min, subTextColor, textColor),
              _buildStatItem('Max', max, subTextColor, textColor),
              Expanded(
                child: Column(children: [
                  Text('Trend', style: TextStyle(color: subTextColor, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(trendIcon, color: accentColor, size: 20),
                    const SizedBox(width: 4),
                    Text('${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color subTextColor, Color textColor) {
    return Expanded(
      child: Column(children: [
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
      ]),
    );
  }

  Widget _buildChart(Color cardColor, Color textColor, Color accentColor, bool isDark) {
    final reversed = List<HealthMeasurement>.from(_history.reversed);
    if (reversed.length < 2) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < reversed.length && i < 30; i++) {
      final v = reversed[i].value;
      spots.add(FlSpot(i.toDouble(), v));
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
    }

    final padding = (maxY - minY) * 0.1;
    minY -= padding.clamp(1, 20);
    maxY += padding.clamp(1, 20);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.metricType} Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark ? Colors.white12 : Colors.black12,
                  strokeWidth: 1,
                ),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        spot.y.toStringAsFixed(1),
                        TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: accentColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: spots.length < 15),
                  belowBarData: BarAreaData(
                    show: true,
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTile(HealthMeasurement m, Color cardColor, Color textColor, Color subTextColor, Color accentColor) {
    String displayValue = m.value.toStringAsFixed(1);
    if (m.type == 'Blood Pressure' && m.secondaryValue != null) {
      displayValue = '${m.value.toInt()}/${m.secondaryValue!.toInt()}';
    } else if (m.type == 'Steps') {
      displayValue = m.value.toInt().toString();
    }

    String dateStr = '';
    try {
      final dt = DateTime.parse(m.recordedAt);
      dateStr = DateFormat('MMM dd, hh:mm a').format(dt);
    } catch (e) {
      dateStr = m.recordedAt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$displayValue ${m.unit}', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
              Text(dateStr, style: TextStyle(color: subTextColor, fontSize: 12)),
            ]),
          ]),
        ],
      ),
    );
  }
}
