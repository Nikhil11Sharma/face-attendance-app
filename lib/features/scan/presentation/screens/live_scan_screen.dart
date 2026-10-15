import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/scan_bloc.dart';
import '../blocs/scan_event.dart';
import '../blocs/scan_state.dart';
import '../../../../core/constants/app_constants.dart';

/// Live scan screen.
/// On web: shows a "requires Android" placeholder.
/// On Android: would launch camera + face recognition (full impl).
class LiveScanScreen extends StatefulWidget {
  final String sessionId;

  const LiveScanScreen({super.key, required this.sessionId});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // On Android, start scan session
      context.read<ScanBloc>().add(ScanStarted(sessionId: widget.sessionId));
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      context.read<ScanBloc>().add(ScanDisposed());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebPlaceholder(context);
    }
    return BlocConsumer<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state is ScanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state is ScanSessionSubmitted) {
          context.go('/');
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, state),
          body: _buildAndroidBody(context, state),
          bottomNavigationBar: _buildBottomBar(context, state),
        );
      },
    );
  }

  // ── Web Placeholder ─────────────────────────────────────────────────────────

  Widget _buildWebPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Scan'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.face_retouching_natural,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Face Scanning',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requires Android App',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.android,
                    color: Colors.green,
                    text: 'Download the Android APK from the dashboard',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.face,
                    color: Colors.blue,
                    text:
                        'Face recognition uses MobileFaceNet AI model on-device',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.security,
                    color: Colors.orange,
                    text:
                        'Anti-spoofing prevents photo/video fraud — Android only',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Manual Attendance Instead'),
                      onPressed: () => context.go('/'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Dashboard'),
                      onPressed: () => context.go('/'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Android UI ──────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, ScanState state) {
    final scanState = state is ScanInProgress ? state : null;
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scanState?.subjectName ?? 'Scanning...',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            'Period ${scanState?.period ?? ''} • ${scanState?.date ?? ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
      actions: [
        if (scanState?.pendingSyncCount != null &&
            scanState!.pendingSyncCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(
                '⏳ ${scanState.pendingSyncCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              backgroundColor: Colors.orange[800],
            ),
          ),
      ],
    );
  }

  Widget _buildAndroidBody(BuildContext context, ScanState state) {
    if (state is ScanLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading session...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    if (state is ScanError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                state.message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }
    if (state is ScanInProgress) {
      return _buildScanningUI(context, state);
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildScanningUI(BuildContext context, ScanInProgress state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera placeholder (replace with actual CameraPreview on Android)
        Container(color: Colors.black12),

        // Quality message
        if (state.qualityMessage != null)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.qualityMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),

        // Bottom overlay: counters + detected chips
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomOverlay(context, state),
        ),
      ],
    );
  }

  Widget _buildBottomOverlay(BuildContext context, ScanInProgress state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Counter row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CounterBadge(
                label: 'Present',
                count: state.presentCount,
                color: Colors.green,
              ),
              _CounterBadge(
                label: 'Absent',
                count: state.absentees.length,
                color: Colors.red,
              ),
              _CounterBadge(
                label: 'Review',
                count: state.reviewCount,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Recent matches chips
          if (state.recentMatches.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.recentMatches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final m = state.recentMatches[i];
                  return Chip(
                    label: Text(
                      m.studentName ?? '?',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: m.result.name == 'autoPresent'
                        ? Colors.green[800]
                        : Colors.orange[800],
                    padding: EdgeInsets.zero,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ScanState state) {
    final scanState = state is ScanInProgress ? state : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Absentees'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: scanState != null
                    ? () => _showAbsenteeList(context, scanState)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _confirmSubmit(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbsenteeList(BuildContext context, ScanInProgress state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Absentees',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: state.absentees.length,
                itemBuilder: (ctx, i) {
                  final s = state.absentees[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: Text(
                        (s['rollNumber'] ?? '?').toString(),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    title: Text(s['name'] ?? ''),
                    subtitle: Text('Roll: ${s['rollNumber'] ?? ''}'),
                    trailing: TextButton(
                      onPressed: () {
                        context.read<ScanBloc>().add(
                              ScanManualOverride(
                                studentId: s['id'] ?? '',
                                status: 'present',
                                reason: 'Teacher tap from absentee list',
                              ),
                            );
                        Navigator.pop(context);
                      },
                      child: const Text('Mark Present'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSubmit(BuildContext context, ScanState state) {
    final scanState = state is ScanInProgress ? state : null;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Attendance?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Present: ${scanState?.presentCount ?? 0}'),
            Text('❌ Absent: ${scanState?.absentees.length ?? 0}'),
            Text('⚠️ Review: ${scanState?.reviewCount ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ScanBloc>().add(ScanSubmitted());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _CounterBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CounterBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
