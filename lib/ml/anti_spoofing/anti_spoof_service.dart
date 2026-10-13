import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';

/// Handles liveness detection using two layers:
/// 1. Challenge-based: random blink + head-turn check via ML Kit landmarks
/// 2. Texture-based: TFLite anti-spoofing model (Silent-Face inspired)
class AntiSpoofService {
  final Interpreter _antiSpoofInterpreter;
  final Logger _log = Logger();

  AntiSpoofService({required Interpreter antiSpoofInterpreter})
      : _antiSpoofInterpreter = antiSpoofInterpreter;

  // ─── Texture-Based Anti-Spoofing ─────────────────────────────────────────

  /// Runs the TFLite anti-spoofing model on the cropped face image.
  /// Returns a score where > threshold = live face.
  Future<AntiSpoofResult> checkLiveness(img.Image faceImage) async {
    try {
      // Resize to model input size (80×80 for typical anti-spoof models)
      final resized = img.copyResize(faceImage, width: 80, height: 80);

      // Prepare input tensor [1, 80, 80, 3]
      final input = List.generate(
        1,
        (_) => List.generate(
          80,
          (y) => List.generate(
            80,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Output: [1, 2] — [spoof_prob, live_prob]
      final output = List.generate(1, (_) => List.filled(2, 0.0));

      _antiSpoofInterpreter.run(input, output);

      final liveProbability = (output[0] as List)[1] as double;
      final antiSpoofScore = liveProbability;

      final isLive = antiSpoofScore >= AppConstants.antiSpoofThreshold;

      return AntiSpoofResult(
        isLive: isLive,
        antiSpoofScore: antiSpoofScore,
        method: AntiSpoofMethod.texture,
      );
    } catch (e) {
      _log.e('Anti-spoof error: $e');
      // Fail-safe: if model errors, allow but flag for review
      return AntiSpoofResult(
        isLive: true,
        antiSpoofScore: 0.0,
        method: AntiSpoofMethod.texture,
        error: e.toString(),
      );
    }
  }

  void dispose() => _antiSpoofInterpreter.close();
}

// ─── Challenge-Based Liveness Controller ─────────────────────────────────────

/// Manages the random blink/head-turn challenge sequence.
/// Integrates with ML Kit face landmarks (eye open probability, head euler angles).
class LivenessChallenge {
  final List<LivenessChallengeStep> _steps;
  int _currentStepIndex = 0;
  bool _isComplete = false;
  bool _isFailed = false;
  final DateTime _startTime;

  LivenessChallenge()
      : _steps = _generateRandomChallenge(),
        _startTime = DateTime.now();

  static List<LivenessChallengeStep> _generateRandomChallenge() {
    // Always require at least 1 blink + 1 head turn
    final steps = <LivenessChallengeStep>[];
    final random = DateTime.now().millisecondsSinceEpoch;

    // Random head direction
    final directions = [
      ChallengeType.turnLeft,
      ChallengeType.turnRight,
      ChallengeType.lookUp,
    ];
    final selectedDirection = directions[random % directions.length];

    // 50% chance blink first, 50% head turn first
    if (random % 2 == 0) {
      steps.add(LivenessChallengeStep(type: ChallengeType.blink));
      steps.add(LivenessChallengeStep(type: selectedDirection));
    } else {
      steps.add(LivenessChallengeStep(type: selectedDirection));
      steps.add(LivenessChallengeStep(type: ChallengeType.blink));
    }

    return steps;
  }

  LivenessChallengeStep get currentStep => _steps[_currentStepIndex];
  bool get isComplete => _isComplete;
  bool get isFailed => _isFailed;
  List<LivenessChallengeStep> get steps => List.unmodifiable(_steps);

  /// Check if timeout has exceeded
  bool get isTimedOut {
    final elapsed = DateTime.now().difference(_startTime).inSeconds;
    return elapsed > AppConstants.livenessTimeoutSeconds;
  }

  /// Update based on ML Kit face landmark data.
  /// [leftEyeOpen] and [rightEyeOpen] are 0.0–1.0 probabilities.
  /// [eulerY] is head rotation around Y axis (left/right, degrees).
  /// [eulerX] is head rotation around X axis (up/down, degrees).
  void update({
    required double leftEyeOpen,
    required double rightEyeOpen,
    required double eulerY,
    required double eulerX,
  }) {
    if (_isComplete || _isFailed || isTimedOut) {
      if (isTimedOut && !_isComplete) _isFailed = true;
      return;
    }

    final step = _steps[_currentStepIndex];
    bool stepCompleted = false;

    switch (step.type) {
      case ChallengeType.blink:
        // Both eyes closed then open
        final eyesClosed = leftEyeOpen < 0.2 && rightEyeOpen < 0.2;
        if (eyesClosed && !step.started) {
          step.started = true;
        } else if (!eyesClosed && step.started) {
          stepCompleted = true;
        }

      case ChallengeType.turnLeft:
        if (eulerY < -20) stepCompleted = true;

      case ChallengeType.turnRight:
        if (eulerY > 20) stepCompleted = true;

      case ChallengeType.lookUp:
        if (eulerX > 15) stepCompleted = true;
    }

    if (stepCompleted) {
      step.completed = true;
      _currentStepIndex++;
      if (_currentStepIndex >= _steps.length) {
        _isComplete = true;
      }
    }
  }
}

class LivenessChallengeStep {
  final ChallengeType type;
  bool started = false;
  bool completed = false;

  LivenessChallengeStep({required this.type});

  String get instruction {
    switch (type) {
      case ChallengeType.blink:
        return 'Please blink once';
      case ChallengeType.turnLeft:
        return 'Turn head left';
      case ChallengeType.turnRight:
        return 'Turn head right';
      case ChallengeType.lookUp:
        return 'Look up briefly';
    }
  }
}

enum ChallengeType { blink, turnLeft, turnRight, lookUp }

// ─── Result Objects ───────────────────────────────────────────────────────────

class AntiSpoofResult {
  final bool isLive;
  final double antiSpoofScore;
  final AntiSpoofMethod method;
  final String? error;

  const AntiSpoofResult({
    required this.isLive,
    required this.antiSpoofScore,
    required this.method,
    this.error,
  });
}

enum AntiSpoofMethod { texture, challenge, combined }
