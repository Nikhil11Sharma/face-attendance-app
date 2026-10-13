import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../blocs/reports_bloc.dart';
import '../blocs/reports_event.dart';
import '../blocs/reports_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/export/export_service.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'package:get_it/get_it.dart';

/// Reports screen showing monthly/yearly attendance charts,
/// low-attendance alerts, and PDF/Excel export options.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'monthly';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadReports() {
    context.read<ReportsBloc>().add(
          ReportsLoadRequested(
            period: _selectedPeriod,
            month: _selectedMonth,
            year: _selectedYear,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: _handleExport,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
              const PopupMenuItem(value: 'excel', child: Text('Export Excel')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'By Student'),
            Tab(text: '⚠️ Alerts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Period selector
          _buildPeriodSelector(),

          // Tab content
          Expanded(
            child: BlocBuilder<ReportsBloc, ReportsState>(
              builder: (context, state) {
                if (state is ReportsLoading) return const LoadingWidget();
                if (state is ReportsError) {
                  return Center(child: Text(state.message));
                }
                if (state is! ReportsLoaded) return const SizedBox();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(state),
                    _buildStudentTab(state),
                    _buildAlertsTab(state),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ButtonSegment(value: 'yearly', label: Text('Yearly')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (v) {
              setState(() => _selectedPeriod = v.first);
              _loadReports();
            },
          ),
          const Spacer(),
          if (_selectedPeriod == 'monthly')
            DropdownButton<int>(
              value: _selectedMonth,
              underline: const SizedBox(),
              items: List.generate(12, (i) {
                return DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i],
                  ),
                );
              }),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedMonth = v);
                  _loadReports();
                }
              },
            ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            items: [2024, 2025, 2026, 2027].map((y) {
              return DropdownMenuItem(value: y, child: Text('$y'));
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _selectedYear = v);
                _loadReports();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ReportsLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _statCard('Classes Held', state.totalClasses.toString(), Colors.blue),
              const SizedBox(width: 12),
              _statCard('Avg. Attendance',
                  '${state.averageAttendance.toStringAsFixed(1)}%', Colors.green),
              const SizedBox(width: 12),
              _statCard('Low Attendance', state.lowAttendanceCount.toString(),
                  Colors.red),
            ],
          ),

          const SizedBox(height: 24),

          // Attendance trend chart
          const Text(
            'Attendance Trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: state.trendData
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTab(ReportsLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.studentSummaries.length,
      itemBuilder: (context, index) {
        final student = state.studentSummaries[index];
        final pct = student['percentage'] as double;
        final isLow = pct < AppConstants.lowAttendanceThreshold * 100;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLow ? Colors.red[100] : Colors.green[100],
              child: Text(
                student['rollNumber'] as String? ?? '?',
                style: TextStyle(
                  fontSize: 11,
                  color: isLow ? Colors.red[800] : Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student['name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${student['present']}/${student['total']} classes attended',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLow ? Colors.red : Colors.green[700],
                    fontSize: 16,
                  ),
                ),
                if (isLow)
                  const Text(
                    'LOW',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            onTap: () => context.push(
              '/reports/student/${student['id']}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsTab(ReportsLoaded state) {
    final lowStudents = state.studentSummaries
        .where((s) =>
            (s['percentage'] as double) <
            AppConstants.lowAttendanceThreshold * 100)
        .toList();

    if (lowStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('All students above 75% attendance!'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                '${lowStudents.length} students below 75% attendance',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: lowStudents.length,
            itemBuilder: (context, index) {
              final s = lowStudents[index];
              return Card(
                color: Colors.red[50],
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s['name'] as String? ?? ''),
                  subtitle: Text('Roll: ${s['rollNumber']}'),
                  trailing: Text(
                    '${(s['percentage'] as double).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  onTap: () =>
                      context.push('/reports/student/${s['id']}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExport(String format) async {
    final state = context.read<ReportsBloc>().state;
    if (state is! ReportsLoaded) return;

    final exportService = GetIt.instance<ExportService>();

    try {
      if (format == 'pdf') {
        await exportService.exportPdf(state);
      } else {
        await exportService.exportExcel(state);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} exported!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
