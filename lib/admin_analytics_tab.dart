// lib/features/admin/admin_analytics_tab.dart
import 'package:finadvise/app_theme.dart';
import 'package:finadvise/models/models.dart';
import 'package:finadvise/services/analytics_service.dart';
import 'package:finadvise/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // FIX 1: Used DashboardAnalytics instead of AnalyticsData
  DashboardAnalytics? _data; 
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // FIX 2: getFullDashboard() is the correct method name in AnalyticsService
    _data = (await _analyticsService.getFullDashboard()) as DashboardAnalytics?;
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return const EmptyState(icon: Icons.bar_chart, title: 'No analytics data');

    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI row
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              StatCard(title: 'Total Tickets', value: '${d.totalTickets}', icon: Icons.confirmation_number, color: AppColors.primaryLight),
              StatCard(title: 'Resolved', value: '${d.resolvedTickets}', icon: Icons.check_circle_outline, color: AppColors.success),
              StatCard(title: 'SLA Breaches', value: '${d.slaBreaches}', icon: Icons.timer_off, color: AppColors.danger),
              StatCard(title: 'Avg Rating', value: d.avgRating.toStringAsFixed(1), icon: Icons.star_rounded, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 24),

          // Tickets by Status Pie
          if (d.ticketsByStatus.isNotEmpty)
            _ChartCard(
              title: 'Tickets by Status',
              legend: d.ticketsByStatus.entries.map((e) => _LegendItem(label: e.key, color: getStatusColor(e.key), value: e.value)).toList(),
              child: SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: d.ticketsByStatus.entries.map((e) {
                      final color = getStatusColor(e.key);
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.value}',
                        color: color,
                        radius: 60,
                        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Tickets by Priority Bar
          if (d.ticketsByPriority.isNotEmpty)
            _ChartCard(
              title: 'Tickets by Priority',
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final priorities = d.ticketsByPriority.keys.toList();
                            if (v.toInt() < priorities.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(priorities[v.toInt()], style: const TextStyle(fontSize: 10)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: d.ticketsByPriority.entries.toList().asMap().entries.map((entry) {
                      final color = getPriorityColor(entry.value.key);
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: color,
                            width: 28,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Avg Response & Resolution
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Response Times', style: AppTextStyles.h4),
                const SizedBox(height: 16),
                _TimeRow(label: 'Avg First Response', hours: d.avgResponseTime, color: AppColors.info),
                const SizedBox(height: 12),
                _TimeRow(label: 'Avg Resolution Time', hours: d.avgResolutionTime, color: AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<_LegendItem>? legend;

  const _ChartCard({required this.title, required this.child, this.legend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 16),
          child,
          if (legend != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: legend!.map((l) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: l.color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${l.label} (${l.value})', style: AppTextStyles.caption),
                ],
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  final int value;
  _LegendItem({required this.label, required this.color, required this.value});
}

class _TimeRow extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;

  const _TimeRow({required this.label, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.label),
            Text('${hours.toStringAsFixed(1)}h', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (hours / 48).clamp(0, 1),
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ─── ADMIN SETTINGS TAB ───────────────────────────────────────────────────────

class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'Account',
          items: [
            _SettingsItem(icon: Icons.person_outline, label: 'Profile', onTap: () {}),
            _SettingsItem(icon: Icons.lock_outline, label: 'Change Password', onTap: () {}),
            _SettingsItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Support Config',
          items: [
            _SettingsItem(icon: Icons.chat_bubble_outline, label: 'Canned Responses', onTap: () {}),
            _SettingsItem(icon: Icons.label_outline, label: 'Categories', onTap: () {}),
            _SettingsItem(icon: Icons.access_time, label: 'Business Hours', onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'System',
          items: [
            _SettingsItem(icon: Icons.info_outline, label: 'App Version', trailing: const Text('1.0.0', style: TextStyle(color: AppColors.textMuted)), onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: AppTextStyles.label),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsItem({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label, style: AppTextStyles.body),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: onTap,
    );
  }
}