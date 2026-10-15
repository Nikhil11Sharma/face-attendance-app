import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/constants/app_constants.dart';

/// Reports screen — shows attendance charts and student summaries.
/// Data is loaded from Firestore on web, SQLite on Android.
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

  // Demo data until Firestore is connected
  final List<double> _demoTrend = [72, 78, 81, 76, 83, 88, 85, 79, 91, 87];
  final List<Map<String, dynamic>> _demoStudents = [
    {'id': '1', 'name': 'Rahul Sharma', 'rollNumber': 'CS001', 'present': 45, 'total': 50, 'percentage': 90.0},
    {'id': '2', 'name': 'Priya Patel', 'rollNumber': 'CS002', 'present': 38, 'total': 50, 'percentage': 76.0},
    {'id': '3', 'name': 'Amit Kumar', 'rollNumber': 'CS003', 'present': 30, 'total': 50, 'percentage': 60.0},
    {'id': '4', 'name': 'Sneha Singh', 'rollNumber': 'CS004', 'present': 47, 'total': 50, 'percentage': 94.0},
    {'id': '5', 'name': 'Ravi Gupta', 'rollNumber': 'CS005', 'present': 32, 'total': 50, 'percentage': 64.0},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export',
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
          _buildPeriodSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildStudentTab(),
                _buildAlertsTab(),
              ],
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
            onSelectionChanged: (v) =>
                setState(() => _selectedPeriod = v.first),
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
                    ['Jan','Feb','Mar','Apr','May','Jun',
                     'Jul','Aug','Sep','Oct','Nov','Dec'][i],
                  ),
                );
              }),
              onChanged: (v) {
                if (v != null) setState(() => _selectedMonth = v);
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
              if (v != null) setState(() => _selectedYear = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final avg = _demoStudents.fold(0.0, (s, e) => s + (e['percentage'] as double)) /
        _demoStudents.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard('Classes Held', '50', Colors.blue),
              const SizedBox(width: 12),
              _statCard('Avg Attendance', '${avg.toStringAsFixed(1)}%', Colors.green),
              const SizedBox(width: 12),
              _statCard(
                'Low Attendance',
                _demoStudents
                    .where((s) => (s['percentage'] as double) <
                        AppConstants.lowAttendanceThreshold * 100)
                    .length
                    .toString(),
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Attendance Trend',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: true),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: _demoTrend
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
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
          const SizedBox(height: 16),
          const Card(
            color: Color(0xFFFFF8E1),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing sample data. Connect Firestore to see live attendance.',
                      style: TextStyle(fontSize: 12),
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

  Widget _buildStudentTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _demoStudents.length,
      itemBuilder: (context, index) {
        final student = _demoStudents[index];
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
                  fontSize: 10,
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
          ),
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    final lowStudents = _demoStudents
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${format.toUpperCase()} export requires Android app.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
