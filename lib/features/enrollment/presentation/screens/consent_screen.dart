import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/enrollment_bloc.dart';
import '../blocs/enrollment_event.dart';
import '../blocs/enrollment_state.dart';

/// DPDP Act 2023 compliance: informed consent screen shown before enrollment.
/// Records consent with timestamp, device fingerprint, and full text shown.
class ConsentScreen extends StatefulWidget {
  final String studentId;

  const ConsentScreen({super.key, required this.studentId});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _hasReadFully = false;
  bool _consentChecked = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset >=
          _scrollController.position.maxScrollExtent - 50) {
        setState(() => _hasReadFully = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Consent'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<EnrollmentBloc, EnrollmentState>(
        listener: (context, state) {
          if (state is EnrollmentConsentRecorded) {
            context.go('/enrollment/enroll/${widget.studentId}');
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Consent text (must scroll to enable consent checkbox)
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildConsentText(context),
                ),
              ),

              // Bottom panel
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!_hasReadFully)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Please scroll down to read the full consent',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    CheckboxListTile(
                      value: _consentChecked,
                      onChanged: _hasReadFully
                          ? (v) => setState(() => _consentChecked = v ?? false)
                          : null,
                      title: const Text(
                        'I have read and understood the above information and '
                        'I voluntarily consent to the collection and use of my '
                        'facial biometric data for attendance purposes.',
                        style: TextStyle(fontSize: 13),
                      ),
                      activeColor: Theme.of(context).colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Decline option (manual attendance)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleDecline(context),
                            child: const Text('Decline\n(Manual Attendance)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Grant consent
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _consentChecked && _hasReadFully
                                ? () => _handleConsent(context)
                                : null,
                            child: const Text('I Consent'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConsentText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Biometric Data Collection Notice'),
        _paragraph(
          'This notice is provided under the Digital Personal Data Protection '
          'Act, 2023 (India DPDP Act) and informs you about how your facial '
          'biometric data will be collected, processed, and stored.',
        ),

        _heading('What We Collect'),
        _bullet('Mathematical representation (embedding) of your face'),
        _bullet('NOT your raw photograph — only an encrypted numerical vector'),
        _bullet('Quality metadata (blur score, brightness) for system reliability'),

        _heading('How It Is Used'),
        _bullet('Automated attendance marking during class sessions'),
        _bullet('Verifying your identity to prevent proxy attendance'),
        _bullet(
            'Generating attendance reports for academic purposes'),

        _heading('How We Protect Your Data'),
        _bullet('AES-256-GCM encryption applied before any storage'),
        _bullet('Stored only on your institution\'s secure servers'),
        _bullet('Never shared with third parties'),
        _bullet('Role-based access: only your teacher and institution admin'),

        _heading('Data Retention'),
        _paragraph(
          'Your biometric data will be retained for the duration of your '
          'enrollment plus 2 academic years, after which it will be '
          'automatically deleted. You may request early deletion at any time.',
        ),

        _heading('Your Rights'),
        _bullet('Right to Access: Request a copy of your stored data'),
        _bullet('Right to Correct: Update inaccurate data'),
        _bullet('Right to Erase: Request deletion at any time'),
        _bullet(
          'Right to Withdraw Consent: You may withdraw at any time. '
          'Withdrawal will not affect past attendance records but will '
          'switch you to manual attendance going forward.',
        ),
        _bullet('No penalty for declining — manual attendance is available'),

        _heading('Contact'),
        _paragraph(
          'Data Protection Officer\n'
          'Email: dpo@college.edu.in\n'
          'Address: College Administration Office\n\n'
          'Consent Version: v1.0 | Date: October 2026',
        ),

        const SizedBox(height: 40), // Ensure must scroll to bottom
      ],
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A73E8),
          ),
        ),
      );

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      );

  void _handleConsent(BuildContext context) {
    context.read<EnrollmentBloc>().add(
          EnrollmentConsentGranted(studentId: widget.studentId),
        );
  }

  void _handleDecline(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Biometric Enrollment'),
        content: const Text(
          'Your attendance will be recorded manually by your teacher. '
          'You will not be affected academically by this choice.\n\n'
          'You can change your mind and enroll biometrically at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EnrollmentBloc>().add(
                    EnrollmentConsentDeclined(studentId: widget.studentId),
                  );
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Confirm Decline'),
          ),
        ],
      ),
    );
  }
}
