import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import '../blocs/scan_bloc.dart';
import '../blocs/scan_event.dart';
import '../blocs/scan_state.dart';
import '../widgets/face_overlay_painter.dart';
import '../widgets/liveness_challenge_widget.dart';
import '../widgets/attendance_counter_widget.dart';
import '../widgets/detected_face_chip.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../core/constants/app_constants.dart';

/// The main live scanning screen.
/// Shows camera preview with face overlays, liveness challenge,
/// attendance counter, and detected student chips.
class LiveScanScreen extends StatefulWidget {
  final String sessionId;

  const LiveScanScreen({super.key, required this.sessionId});

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    context.read<ScanBloc>().add(ScanStarted(sessionId: widget.sessionId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    context.read<ScanBloc>().add(ScanDisposed());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      AppSnackBar.showError(context, 'No camera found on this device');
      return;
    }

    // Prefer front camera for enrollment, back for row scanning
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();

    if (!mounted) return;

    setState(() => _cameraController = controller);

    // Start image stream for continuous face detection
    await controller.startImageStream(_processFrame);
  }

  void _processFrame(CameraImage image) {
    if (_isProcessing) return;
    _isProcessing = true;

    context.read<ScanBloc>().add(
          ScanFrameReceived(cameraImage: image),
        );

    // Throttle to ~10 FPS for performance
    Future.delayed(const Duration(milliseconds: 100), () {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state is ScanError) {
          AppSnackBar.showError(context, state.message);
        }
        if (state is ScanSessionSubmitted) {
          context.go('/scan/review/${widget.sessionId}');
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state),
          bottomNavigationBar: _buildBottomBar(context, state),
        );
      },
    );
  }

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
        // Sync status indicator
        if (scanState?.pendingSyncCount != null && scanState!.pendingSyncCount > 0)
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
        IconButton(
          icon: const Icon(Icons.edit_note),
          tooltip: 'Manual Entry',
          onPressed: () => context.push('/manual/${widget.sessionId}'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ScanState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview
        CameraPreview(_cameraController!),

        // Face detection overlays
        if (state is ScanInProgress)
          CustomPaint(
            painter: FaceOverlayPainter(
              faces: state.detectedFaces,
              imageSize: Size(
                _cameraController!.value.previewSize!.height,
                _cameraController!.value.previewSize!.width,
              ),
              screenSize: MediaQuery.of(context).size,
            ),
          ),

        // Top: Liveness challenge overlay
        if (state is ScanInProgress && state.livenessChallenge != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: LivenessChallengeWidget(
              challenge: state.livenessChallenge!,
            ),
          ),

        // Bottom: Attendance counter + detected student chips
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomOverlay(state),
        ),

        // Quality warning
        if (state is ScanInProgress && state.qualityMessage != null)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ],
    );
  }

  Widget _buildBottomOverlay(ScanState state) {
    final scanState = state is ScanInProgress ? state : null;

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
          // Attendance counter
          if (scanState != null)
            AttendanceCounterWidget(
              present: scanState.presentCount,
              total: scanState.totalStudents,
              review: scanState.reviewCount,
            ),
          const SizedBox(height: 12),

          // Scrollable list of recently detected students
          if (scanState != null && scanState.recentMatches.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: scanState.recentMatches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final match = scanState.recentMatches[index];
                  return DetectedFaceChip(
                    match: match,
                    onTap: () => _handleFaceChipTap(match),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ScanState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Review Absentees'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: () => _showAbsenteeList(context, state),
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
                onPressed: () => _confirmSubmit(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFaceChipTap(dynamic match) {
    // Show detail dialog — allow manual override
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(match.studentName ?? 'Unrecognized'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Roll: ${match.rollNumber ?? 'N/A'}'),
            Text('Confidence: ${(match.confidence * 100).toStringAsFixed(1)}%'),
            if (match.requiresManualConfirmation)
              const Text(
                '⚠️ Similar to another student — manual confirmation needed',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (match.result.name != 'autoPresent')
            ElevatedButton(
              onPressed: () {
                context.read<ScanBloc>().add(
                      ScanManualOverride(
                        studentId: match.studentId ?? '',
                        status: 'present',
                        reason: 'Teacher manual override from scan screen',
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('Mark Present'),
            ),
        ],
      ),
    );
  }

  void _showAbsenteeList(BuildContext context, ScanState state) {
    final scanState = state is ScanInProgress ? state : null;
    final absentees = scanState?.absentees ?? [];

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
                itemCount: absentees.length,
                itemBuilder: (ctx, i) {
                  final s = absentees[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: Text(
                        s['rollNumber'] ?? '?',
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
                                reason: 'Teacher tap-to-correct from absentee list',
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

  void _confirmSubmit(BuildContext context) {
    final state = context.read<ScanBloc>().state;
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
            if ((scanState?.reviewCount ?? 0) > 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Review items will need manual confirmation.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
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
