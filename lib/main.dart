import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/blocs/auth_bloc.dart';
import 'features/auth/presentation/blocs/auth_event.dart';
import 'features/auth/presentation/blocs/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only lock orientation on mobile, not web
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FaceAttendanceApp());
}

class FaceAttendanceApp extends StatelessWidget {
  const FaceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc()..add(AuthCheckRequested()),
      child: MaterialApp(
        title: 'Face Attendance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          // Show splash while checking auth state
          return const Scaffold(
            backgroundColor: Color(0xFF0D47A1),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.face_retouching_natural,
                      size: 72, color: Colors.white),
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          );
        }
        if (state is AuthAuthenticated) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
