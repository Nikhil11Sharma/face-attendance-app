import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../auth/presentation/blocs/auth_event.dart';
import '../../../auth/presentation/blocs/auth_state.dart';
import '../../../scan/presentation/screens/live_scan_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthBloc, String>(
      (b) => b.state is AuthAuthenticated
          ? (b.state as AuthAuthenticated).email
          : '',
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Face Attendance'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Welcome card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Good day, Teacher!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(email,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Today',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Today's stats ─────────────────────────────────────────
            Row(
              children: [
                _StatTile(label: 'Sessions', value: '0',
                    icon: Icons.today, color: AppColors.primary),
                const SizedBox(width: 12),
                _StatTile(label: 'Present', value: '0',
                    icon: Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 12),
                _StatTile(label: 'Absent', value: '0',
                    icon: Icons.cancel, color: AppColors.error),
              ],
            ),

            const SizedBox(height: 28),
            const _SectionHeader('Quick Actions'),
            const SizedBox(height: 12),

            // ── Action grid ───────────────────────────────────────────
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _ActionCard(
                  icon: Icons.face_retouching_natural,
                  label: 'Start Face Scan',
                  subtitle: 'Mark attendance',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const FaceScanPlaceholderScreen())),
                ),
                _ActionCard(
                  icon: Icons.person_add_rounded,
                  label: 'Enroll Student',
                  subtitle: 'Add new student',
                  color: AppColors.accent,
                  onTap: () => _showComingSoon(context, 'Enrollment'),
                ),
                _ActionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  subtitle: 'View analytics',
                  color: const Color(0xFF7B1FA2),
                  onTap: () => _showComingSoon(context, 'Reports'),
                ),
                _ActionCard(
                  icon: Icons.edit_note_rounded,
                  label: 'Manual Entry',
                  subtitle: 'Override attendance',
                  color: AppColors.warning,
                  onTap: () => _showComingSoon(context, 'Manual Entry'),
                ),
              ],
            ),

            const SizedBox(height: 28),
            const _SectionHeader('Upcoming'),
            const SizedBox(height: 12),

            _ScheduleCard(
              subject: 'Computer Science — Sec A',
              time: '10:00 AM',
              room: 'Room 204',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const FaceScanPlaceholderScreen())),
            ),
            const SizedBox(height: 10),
            _ScheduleCard(
              subject: 'Data Structures — Sec B',
              time: '12:30 PM',
              room: 'Room 108',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const FaceScanPlaceholderScreen())),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext ctx, String name) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text('$name — coming soon!'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecond)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecond)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String subject, time, room;
  final VoidCallback onTap;
  const _ScheduleCard(
      {required this.subject,
      required this.time,
      required this.room,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.school_rounded,
              color: AppColors.primary, size: 22),
        ),
        title: Text(subject,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textPrimary)),
        subtitle: Text('$time  •  $room',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecond)),
        trailing: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.face_retouching_natural, size: 14),
          label: const Text('Scan', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
          ),
        ),
      ),
    );
  }
}

// ── Face Scan Placeholder ──────────────────────────────────────────────────
class FaceScanPlaceholderScreen extends StatelessWidget {
  const FaceScanPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Scan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.face_retouching_natural,
                    size: 80, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              const Text('Camera-based Face Scanning',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              const Text(
                'Face scanning requires:\n'
                '• Android phone with camera\n'
                '• MobileFaceNet TFLite model\n'
                '• Students enrolled in the system',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecond, height: 1.6),
              ),
              const SizedBox(height: 32),
              Card(
                color: const Color(0xFFFFF3E0),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline,
                            color: AppColors.warning, size: 18),
                        SizedBox(width: 8),
                        Text('Setup Required',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning)),
                      ]),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Download AI models (see docs/MODEL_SOURCES.md)\n'
                        '2. Place in assets/models/ folder\n'
                        '3. Run on Android phone (not web)',
                        style: TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('View Model Setup Guide'),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
