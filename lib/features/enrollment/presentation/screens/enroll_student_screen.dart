import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Enrollment screen.
/// On web: shows a "requires Android" placeholder.
/// On Android: guided 5-photo face capture flow.
class EnrollStudentScreen extends StatefulWidget {
  final String studentId;

  const EnrollStudentScreen({super.key, required this.studentId});

  @override
  State<EnrollStudentScreen> createState() => _EnrollStudentScreenState();
}

class _EnrollStudentScreenState extends State<EnrollStudentScreen> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebPlaceholder(context);
    }
    return _buildAndroidEnrollment(context);
  }

  // ── Web Placeholder ─────────────────────────────────────────────────────────

  Widget _buildWebPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Student'),
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
                      Icons.person_add_alt_1,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Face Enrollment',
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
                  _InfoTile(
                    icon: Icons.camera_alt,
                    color: Colors.blue,
                    title: '5 photo capture',
                    subtitle:
                        'Captures face at different angles for better accuracy',
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    title: 'Liveness check',
                    subtitle: 'Blink, smile, and turn head to prove it\'s real',
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.lock,
                    color: Colors.orange,
                    title: 'Encrypted storage',
                    subtitle:
                        'Face embeddings are AES-256 encrypted on device',
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.gavel,
                    color: Colors.purple,
                    title: 'DPDP Act 2023 compliant',
                    subtitle: 'Consent captured before any biometric data',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.android),
                      label: const Text('Use Android App to Enroll'),
                      onPressed: null, // disabled — info only
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

  // ── Android Enrollment Flow ─────────────────────────────────────────────────

  Widget _buildAndroidEnrollment(BuildContext context) {
    // Full Android enrollment would use camera + ML Kit here.
    // Showing a setup guide until Android implementation is connected.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Student'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.face_retouching_natural,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ready to Enroll',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Student ID: ${widget.studentId}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              const Text(
                'Position the student\'s face in the frame.\nCapture 5 photos at different angles.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Start Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Camera enrollment — place mobilefacenet.tflite in assets/models/ to activate',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: () => context.go('/'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
