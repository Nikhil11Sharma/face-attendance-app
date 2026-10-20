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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInEmailCtrl = TextEditingController();
  final _signInPassCtrl  = TextEditingController();

  final _signUpEmailCtrl    = TextEditingController();
  final _signUpPassCtrl     = TextEditingController();
  final _signUpConfirmCtrl  = TextEditingController();

  bool _signInObscure    = true;
  bool _signUpObscure    = true;
  bool _signUpConfirmObs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPassCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPassCtrl.dispose();
    _signUpConfirmCtrl.dispose();
    super.dispose();
  }

  void _submitSignIn(BuildContext ctx) {
    if (!_signInFormKey.currentState!.validate()) return;
    ctx.read<AuthBloc>().add(AuthLoginRequested(
      email: _signInEmailCtrl.text.trim(),
      password: _signInPassCtrl.text,
    ));
  }

  void _submitSignUp(BuildContext ctx) {
    if (!_signUpFormKey.currentState!.validate()) return;
    ctx.read<AuthBloc>().add(AuthSignUpRequested(
      email: _signUpEmailCtrl.text.trim(),
      password: _signUpPassCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            // ── Left blue panel (desktop only) ──────────────────────────
            if (isWide)
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
                          _FeatureRow(
                              icon: Icons.bolt,
                              text: 'Mark attendance in seconds'),
                          SizedBox(height: 12),
                          _FeatureRow(
                              icon: Icons.security,
                              text: 'Anti-spoofing liveness check'),
                          SizedBox(height: 12),
                          _FeatureRow(
                              icon: Icons.cloud_sync,
                              text: 'Offline-first, syncs automatically'),
                          SizedBox(height: 12),
                          _FeatureRow(
                              icon: Icons.bar_chart,
                              text: 'Monthly & yearly reports'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Right panel (form) ────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo (mobile only)
                        if (!isWide) ...[
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
                          const SizedBox(height: 24),
                        ],

                        const Text('Teacher Portal',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            )),
                        const SizedBox(height: 4),
                        const Text(
                            'Sign in to your account or create a new one',
                            style: TextStyle(
                                color: AppColors.textSecond, fontSize: 14)),
                        const SizedBox(height: 24),

                        // ── Tabs ──────────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textSecond,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Tab Content ───────────────────────────────────
                        SizedBox(
                          height: 320,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSignInForm(context),
                              _buildSignUpForm(context),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'DPDP Act 2023 Compliant  •  AES-256 Encrypted',
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

  // ── Sign In Form ──────────────────────────────────────────────────────────

  Widget _buildSignInForm(BuildContext context) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _signInEmailCtrl,
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
          TextFormField(
            controller: _signInPassCtrl,
            obscureText: _signInObscure,
            onFieldSubmitted: (_) => _submitSignIn(context),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_signInObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _signInObscure = !_signInObscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final email = _signInEmailCtrl.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your email first')));
                  return;
                }
                context
                    .read<AuthBloc>()
                    .add(AuthPasswordResetRequested(email: email));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password reset email sent ✅')));
              },
              child: const Text('Forgot password?',
                  style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
          ),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (ctx, state) {
              return SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      state is AuthLoading ? null : () => _submitSignIn(ctx),
                  child: state is AuthLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 16)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Sign Up Form ──────────────────────────────────────────────────────────

  Widget _buildSignUpForm(BuildContext context) {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _signUpEmailCtrl,
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
          const SizedBox(height: 14),
          TextFormField(
            controller: _signUpPassCtrl,
            obscureText: _signUpObscure,
            decoration: InputDecoration(
              labelText: 'Password (min 6 characters)',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_signUpObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _signUpObscure = !_signUpObscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _signUpConfirmCtrl,
            obscureText: _signUpConfirmObs,
            onFieldSubmitted: (_) => _submitSignUp(context),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_signUpConfirmObs
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _signUpConfirmObs = !_signUpConfirmObs),
              ),
            ),
            validator: (v) {
              if (v != _signUpPassCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (ctx, state) {
              return SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      state is AuthLoading ? null : () => _submitSignUp(ctx),
                  child: state is AuthLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16)),
                ),
              );
            },
          ),
        ],
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
