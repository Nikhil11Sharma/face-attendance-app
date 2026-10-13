import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';

import '../blocs/enrollment_bloc.dart';
import '../blocs/enrollment_event.dart';
import '../blocs/enrollment_state.dart';
import '../widgets/enrollment_progress_widget.dart';
import '../widgets/face_capture_overlay.dart';
import '../../../../ml/anti_spoofing/anti_spoof_service.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../core/constants/app_constants.dart';

/// Guided 5-photo enrollment screen.
/// Guides teacher through capturing face at different angles/lighting.
class EnrollStudentScreen extends StatefulWidget {
  final String studentId;

  const EnrollStudentScreen({super.key, required this.studentId});

  @override
  State<EnrollStudentScreen> createState() => _EnrollStudentScreenState();
}

class _EnrollStudentScreenState extends State<EnrollStudentScreen> {
  CameraController? _camera;

  static const _angles = [
    ('Look straight at camera', 'frontal', Icons.face),
    ('Turn slightly to the LEFT', 'left_15', Icons.arrow_back),
    ('Turn slightly to the RIGHT', 'right_15', Icons.arrow_forward),
    ('Look slightly UP', 'up_10', Icons.arrow_upward),
    ('Look slightly DOWN', 'down_10', Icons.arrow_downward),
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
    context.read<EnrollmentBloc>().add(
          EnrollmentStarted(studentId: widget.studentId),
        );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use front camera for enrollment
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (mounted) setState(() => _camera = controller);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EnrollmentBloc, EnrollmentState>(
      listener: (context, state) {
        if (state is EnrollmentError) {
          AppSnackBar.showError(context, state.message);
        }
        if (state is EnrollmentComplete) {
          AppSnackBar.showSuccess(
            context,
            '✅ ${state.studentName} enrolled successfully!',
          );
          context.pop();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              state is EnrollmentInProgress
                  ? 'Enrolling: ${state.studentName}'
                  : 'Enrollment',
            ),
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, EnrollmentState state) {
    if (state is EnrollmentLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state is! EnrollmentInProgress) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final currentAngle = _angles[state.currentPhotoIndex];

    return Column(
      children: [
        // Progress indicator
        EnrollmentProgressWidget(
          current: state.currentPhotoIndex + 1,
          total: AppConstants.embeddingsPerStudent,
          capturedAngles: state.capturedAngles,
        ),

        // Camera preview
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_camera != null && _camera!.value.isInitialized)
                CameraPreview(_camera!)
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Face framing guide overlay
              FaceCaptureOverlay(
                qualityMessage: state.qualityMessage,
                isGoodQuality: state.isGoodQuality,
              ),
            ],
          ),
        ),

        // Instruction panel
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                currentAngle.$3,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                currentAngle.$1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Photo ${state.currentPhotoIndex + 1} of ${AppConstants.embeddingsPerStudent}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Quality indicator
              if (state.qualityMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.qualityMessage!,
                    style: TextStyle(
                      color: state.isGoodQuality
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ),

              // Capture button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        state.isGoodQuality ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: state.isGoodQuality
                      ? () => _capturePhoto(context, currentAngle.$2)
                      : null,
                ),
              ),

              if (state.currentPhotoIndex > 0)
                TextButton(
                  onPressed: () {
                    context.read<EnrollmentBloc>().add(
                          EnrollmentPhotoRetake(),
                        );
                  },
                  child: const Text(
                    'Retake Previous',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _capturePhoto(BuildContext context, String angle) async {
    if (_camera == null) return;

    final image = await _camera!.takePicture();
    if (!mounted) return;

    context.read<EnrollmentBloc>().add(
          EnrollmentPhotoCaptured(
            imagePath: image.path,
            angle: angle,
          ),
        );
  }
}
