import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic> _insights = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _isLoading = true);
    try {
      _insights = await _apiService.getAIInsights();
    } catch (e) {
      _insights = {
        'summary': 'Unable to load insights. Please check your connection.',
        'insights': [],
        'recommendations': [],
        'severity': 'normal',
        'disclaimer': 'This is informational only.',
      };
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9);

    final severity = _insights['severity'] ?? 'normal';
    Color severityColor = const Color(0xFF10B981);
    IconData severityIcon = Icons.check_circle;
    String severityLabel = 'Normal';
    if (severity == 'attention') {
      severityColor = const Color(0xFFF59E0B);
      severityIcon = Icons.warning_amber_rounded;
      severityLabel = 'Attention';
    } else if (severity == 'urgent') {
      severityColor = const Color(0xFFEF4444);
      severityIcon = Icons.error;
      severityLabel = 'Urgent';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.insights, color: Color(0xFF8B5CF6), size: 24),
          const SizedBox(width: 8),
          Text('AI Health Insights', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInsights,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInsights,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Severity badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(severityIcon, color: severityColor, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Health Status: $severityLabel',
                              style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(_insights['summary'] ?? '', style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
                          ]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Insights
                  if ((_insights['insights'] as List?)?.isNotEmpty == true) ...[
                    Text('Key Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    ...(_insights['insights'] as List).map((insight) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb, color: Color(0xFFF59E0B), size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(insight.toString(), style: TextStyle(color: textColor, fontSize: 14, height: 1.4))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Recommendations
                  if ((_insights['recommendations'] as List?)?.isNotEmpty == true) ...[
                    Text('Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    ...(_insights['recommendations'] as List).map((rec) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tips_and_updates, color: Color(0xFF06B6D4), size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(rec.toString(), style: TextStyle(color: textColor, fontSize: 14, height: 1.4))),
                        ],
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: subTextColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _insights['disclaimer'] ?? 'This is informational only. Consult a healthcare professional for medical advice.',
                            style: TextStyle(color: subTextColor, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
