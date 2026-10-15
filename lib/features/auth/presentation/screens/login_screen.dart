import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../blocs/auth_bloc.dart';
import '../blocs/auth_event.dart';
import '../blocs/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    ctx.read<AuthBloc>().add(AuthLoginRequested(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (ctx, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(state.message)),
            ]),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            // ── Left panel (desktop) ────────────────────────────────────
            if (MediaQuery.of(context).size.width > 800)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, Color(0xFF1976D2)],
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.face_retouching_natural,
                              size: 72, color: Colors.white),
                          SizedBox(height: 24),
                          Text('Face Attendance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              )),
                          SizedBox(height: 12),
                          Text(
                            'AI-powered attendance system\nfor modern colleges.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 48),
                          _FeatureRow(icon: Icons.bolt, text: 'Mark attendance in seconds'),
                          SizedBox(height: 12),
                          _FeatureRow(icon: Icons.security, text: 'Anti-spoofing liveness check'),
                          SizedBox(height: 12),
                          _FeatureRow(icon: Icons.cloud_sync, text: 'Offline-first, syncs automatically'),
                          SizedBox(height: 12),
                          _FeatureRow(icon: Icons.bar_chart, text: 'Monthly & yearly reports'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Right panel (login form) ────────────────────────────────
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo (mobile only)
                        if (MediaQuery.of(context).size.width <= 800) ...[
                          const Center(
                            child: Icon(Icons.face_retouching_natural,
                                size: 56, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('Face Attendance',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                )),
                          ),
                          const SizedBox(height: 32),
                        ],

                        const Text('Welcome back',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            )),
                        const SizedBox(height: 4),
                        const Text('Sign in to your teacher account',
                            style: TextStyle(
                                color: AppColors.textSecond, fontSize: 14)),
                        const SizedBox(height: 32),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Email
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email address',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Enter your email';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                onFieldSubmitted: (_) => _submit(context),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    final email = _emailCtrl.text.trim();
                                    if (email.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Enter your email first')));
                                      return;
                                    }
                                    context.read<AuthBloc>().add(
                                        AuthPasswordResetRequested(
                                            email: email));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Password reset email sent ✅')));
                                  },
                                  child: const Text('Forgot password?',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 13)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Sign In Button
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (ctx, state) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: state is AuthLoading
                                          ? null
                                          : () => _submit(ctx),
                                      child: state is AuthLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))
                                          : const Text('Sign In'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'DPDP Act 2023 Compliant  •  AES-256 Encrypted\nOn-device AI  •  Offline First',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecond, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
