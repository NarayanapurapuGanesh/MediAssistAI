import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/user.dart';
import '../models/health.dart';
import '../models/medication.dart';
import 'add_medication_screen.dart';
import 'add_health_screen.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_insights_screen.dart';
import 'health_detail_screen.dart';
import 'health_history_screen.dart';
import 'medication_adherence_screen.dart';
import 'routine_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';

// In-memory cache across rebuilds for instant rendering
Map<String, dynamic> _cachedHealthSummary = {};
Map<String, dynamic> _cachedHealthTrends = {};
List<Medication> _cachedMedications = [];
List<AIAlert> _cachedAlerts = [];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  List<AIAlert> _alerts = _cachedAlerts;
  List<Medication> _medications = _cachedMedications;
  Map<String, dynamic> _healthSummary = _cachedHealthSummary;
  Map<String, dynamic> _healthTrends = _cachedHealthTrends;
  bool _isLoading = _cachedHealthSummary.isEmpty && _cachedMedications.isEmpty;
  int _currentNavIndex = 0;
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_healthSummary.isEmpty && _medications.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        _apiService.getAlerts(),
        _apiService.getMedications(),
        _apiService.getHealthSummary(),
        _apiService.getHealthTrends(),
      ]);

      _cachedAlerts = results[0] as List<AIAlert>;
      _cachedMedications = results[1] as List<Medication>;
      _cachedHealthSummary = results[2] as Map<String, dynamic>;
      _cachedHealthTrends = results[3] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _alerts = _cachedAlerts;
          _medications = _cachedMedications;
          _healthSummary = _cachedHealthSummary;
          _healthTrends = _cachedHealthTrends;
          _isLoading = false;
        });
      }

      // Schedule notifications in background without blocking UI
      Future.microtask(() {
        for (var med in _medications) {
          NotificationService().scheduleMedicationNotifications(med);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteMedication(Medication med) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Delete Medication?'),
              content: Text('Are you sure you want to delete ${med.name}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ));
    if (confirm == true) {
      await _apiService.deleteMedication(med.id);
      await NotificationService().cancelNotificationsForMedication(med.id);
      _fetchData();
    }
  }

  void _editMedication(Medication med) async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => AddMedicationScreen(medicationToEdit: med)));
    if (result == true) _fetchData();
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
    final user = Provider.of<AuthProvider>(context).user;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    // Determine greeting in IST
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomePage(user, isDark, bgColor, cardColor, textColor, subTextColor, greeting),
          _loadedTabs.contains(1) ? const HealthHistoryScreen() : const SizedBox(),
          const SizedBox(), // Placeholder for center Add button
          _loadedTabs.contains(3) ? const MedicationAdherenceScreen() : const SizedBox(),
          _loadedTabs.contains(4) ? const AIInsightsScreen() : const SizedBox(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard, 'Home', textColor, subTextColor),
                _buildNavItem(1, Icons.history, 'History', textColor, subTextColor),
                _buildAddButton(isDark, textColor),
                _buildNavItem(3, Icons.medication, 'Meds', textColor, subTextColor),
                _buildNavItem(4, Icons.insights, 'AI', textColor, subTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color textColor, Color subTextColor) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentNavIndex = index;
          _loadedTabs.add(index);
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF6366F1) : subTextColor, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: isSelected ? const Color(0xFF6366F1) : subTextColor,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => _showAddOptions(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              _buildAddOption(Icons.medication, 'Add Medication', const Color(0xFF6366F1), textColor, () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMedicationScreen()));
                if (result == true) _fetchData();
              }),
              _buildAddOption(Icons.monitor_heart, 'Add Health Reading', const Color(0xFFEC4899), textColor, () async {
                Navigator.pop(context);
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHealthScreen()));
                if (result == true) _fetchData();
              }),
              _buildAddOption(Icons.smart_toy, 'AI Chat', const Color(0xFF8B5CF6), textColor, () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
              }),
              _buildAddOption(Icons.schedule, 'Daily Routine', const Color(0xFF10B981), textColor, () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen()));
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, Color textColor, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }

  Widget _buildHomePage(User? user, bool isDark, Color bgColor, Color cardColor, Color textColor, Color subTextColor, String greeting) {
    return Stack(
      children: [
        // Background Gradient Orbs
        Positioned(top: -100, left: -100,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.15),
              boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.15))]))),
        Positioned(bottom: -50, right: -50,
          child: Container(width: 250, height: 250,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.2 : 0.1),
              boxShadow: [BoxShadow(blurRadius: 100, color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.2 : 0.1))]))),

        SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFF6366F1),
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  title: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: TextStyle(fontSize: 14, color: subTextColor)),
                        Text('${user?.name ?? user?.email ?? 'User'} 👋',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      color: textColor,
                      onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      color: textColor,
                      onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_isLoading)
                        _buildShimmerLoading(isDark)
                      else ...[
                        // Health status badge
                        _buildStatusBadge(textColor, subTextColor),
                        const SizedBox(height: 24),

                        if (_alerts.isNotEmpty) _buildAlertsSection(),
                        if (_alerts.isNotEmpty) const SizedBox(height: 24),

                        _buildSectionHeader('Health Metrics', textColor),
                        const SizedBox(height: 14),
                        if (_healthSummary['metrics'] == null || (_healthSummary['metrics'] as Map).isEmpty)
                          Center(child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No health data yet. Tap + to add readings.', style: TextStyle(color: subTextColor)),
                          ))
                        else
                          _buildHealthGrid(cardColor, textColor, subTextColor),

                        const SizedBox(height: 24),
                        _buildSectionHeader('Medications', textColor),
                        const SizedBox(height: 14),
                        if (_medications.isEmpty)
                          Center(child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No medications added yet.', style: TextStyle(color: subTextColor)),
                          ))
                        else
                          ..._medications.map((m) => _buildMedicationCard(m, cardColor, textColor, subTextColor, isDark)),

                        const SizedBox(height: 24),
                        _buildSectionHeader('Adherence', textColor),
                        const SizedBox(height: 14),
                        _buildAdherenceCard(cardColor, textColor, subTextColor, isDark),

                        const SizedBox(height: 24),
                        _buildSectionHeader('Trends (7 Days)', textColor),
                        const SizedBox(height: 14),
                        _buildTrendsChart('Heart Rate', cardColor, textColor, const Color(0xFFF43F5E), isDark),
                        const SizedBox(height: 14),
                        _buildTrendsChart('SpO2', cardColor, textColor, const Color(0xFF06B6D4), isDark),

                        const SizedBox(height: 24),
                        // Quick actions row
                        _buildQuickActions(textColor, subTextColor, isDark),
                        const SizedBox(height: 80),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Color textColor, Color subTextColor) {
    final status = _healthSummary['status'] ?? 'No Data';
    final lastUpdated = _healthSummary['last_updated'];

    Color statusColor = const Color(0xFF10B981);
    IconData statusIcon = Icons.check_circle;
    if (status == 'Fair' || status == 'Attention') { statusColor = const Color(0xFFF59E0B); statusIcon = Icons.warning_amber_rounded; }
    if (status == 'Needs Attention') { statusColor = const Color(0xFFEF4444); statusIcon = Icons.error; }
    if (status == 'No Data') { statusColor = Colors.grey; statusIcon = Icons.info_outline; }

    String timeStr = '';
    if (lastUpdated != null) {
      try {
        final dt = DateTime.parse(lastUpdated.endsWith('Z') ? lastUpdated : '${lastUpdated}Z').toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) { timeStr = '${diff.inMinutes}m ago'; }
        else if (diff.inHours < 24) { timeStr = '${diff.inHours}h ago'; }
        else { timeStr = '${diff.inDays}d ago'; }
      } catch (_) {}
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Text('Health: $status', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 15)),
        if (timeStr.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text('• Updated $timeStr', style: TextStyle(color: subTextColor, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF334155) : Colors.grey.shade100,
      child: Column(
        children: List.generate(4, (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        )),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5));
  }

  Widget _buildAlertsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFDA4AF), size: 20),
            SizedBox(width: 8),
            Text('Health Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          ..._alerts.take(3).map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${alert.message}', style: const TextStyle(color: Colors.redAccent, fontSize: 14, height: 1.4)),
          )),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication med, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.medication, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 2),
                Text('${med.dosage} • ${med.frequency}', style: TextStyle(color: subTextColor, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: subTextColor, size: 20),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                onSelected: (val) {
                  if (val == 'Edit') _editMedication(med);
                  if (val == 'Delete') _deleteMedication(med);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'Edit', child: Text('Edit', style: TextStyle(color: textColor))),
                  const PopupMenuItem(value: 'Delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
              ...med.schedules.map((time) {
                return Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF4338CA)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatTimeIST(time),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthGrid(Color cardColor, Color textColor, Color subTextColor) {
    final metrics = _healthSummary['metrics'] as Map<String, dynamic>? ?? {};
    final List<HealthMeasurement> dataList = metrics.values
        .map((e) => HealthMeasurement.fromJson(e))
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final data = dataList[index];
        IconData icon = Icons.monitor_heart;
        Color color = const Color(0xFFF43F5E);

        if (data.type.toLowerCase().contains('spo2') || data.type.toLowerCase().contains('oxygen')) {
          icon = Icons.air; color = const Color(0xFF06B6D4);
        } else if (data.type.toLowerCase().contains('pressure')) {
          icon = Icons.favorite_border; color = const Color(0xFF8B5CF6);
        } else if (data.type.toLowerCase().contains('step')) {
          icon = Icons.directions_walk; color = const Color(0xFFF59E0B);
        } else if (data.type.toLowerCase().contains('sleep')) {
          icon = Icons.bedtime; color = const Color(0xFF3B82F6);
        }

        String displayValue = data.value.toStringAsFixed(1);
        if (data.type.toLowerCase().contains('pressure') && data.secondaryValue != null) {
          displayValue = "${data.value.toInt()}/${data.secondaryValue!.toInt()}";
        } else if (data.type.toLowerCase().contains('step')) {
          displayValue = data.value.toInt().toString();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => HealthDetailScreen(metricType: data.type)));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.type, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(displayValue, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(width: 4),
                          Text(data.unit, style: TextStyle(fontSize: 11, color: subTextColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendsChart(String metricType, Color cardColor, Color textColor, Color lineColor, bool isDark) {
    final trendsData = _healthTrends['trends'] as Map<String, dynamic>? ?? {};
    final metricData = trendsData[metricType] as List<dynamic>? ?? [];

    if (metricData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('Not enough data for $metricType trends.', style: TextStyle(color: textColor, fontSize: 13))),
      );
    }

    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < metricData.length; i++) {
      final value = (metricData[i]['value'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), value));
      if (value < minY) minY = value;
      if (value > maxY) maxY = value;
    }

    minY -= (minY * 0.05); maxY += (maxY * 0.05);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HealthDetailScreen(metricType: metricType))),
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$metricType Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
              Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3), size: 20),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: (spots.length - 1).toDouble(), minY: minY, maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) =>
                      LineTooltipItem(s.y.toStringAsFixed(1), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots, isCurved: true, color: lineColor, barWidth: 3,
                    isStrokeCapRound: true, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.1)),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    final adherence = (_healthSummary['adherence'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicationAdherenceScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Medication Adherence', style: TextStyle(color: subTextColor, fontSize: 13)),
                const SizedBox(height: 6),
                Text('${adherence.toInt()}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            SizedBox(
              height: 56, width: 56,
              child: CircularProgressIndicator(
                value: adherence / 100,
                strokeWidth: 6,
                backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  adherence > 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Color textColor, Color subTextColor, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildQuickAction(Icons.smart_toy, 'AI Chat', const Color(0xFF8B5CF6), cardColor, textColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen()));
            }),
            const SizedBox(width: 12),
            _buildQuickAction(Icons.schedule, 'Routine', const Color(0xFF10B981), cardColor, textColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen()));
            }),
            const SizedBox(width: 12),
            _buildQuickAction(Icons.person, 'Profile', const Color(0xFFF59E0B), cardColor, textColor, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, Color cardColor, Color textColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
