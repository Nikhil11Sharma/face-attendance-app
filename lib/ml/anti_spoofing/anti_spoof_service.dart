// Stub — anti-spoofing runs on Android only
import 'package:flutter/foundation.dart';

/// Challenge types shown during liveness check
enum ChallengeType { blink, turnLeft, turnRight, smile, nod }

/// Liveness challenge instruction
class LivenessChallenge {
  final ChallengeType type;
  final String instruction;
  final int durationMs;

  const LivenessChallenge({
    required this.type,
    required this.instruction,
    this.durationMs = 3000,
  });
}

class AntiSpoofService {
  AntiSpoofService();
  Future<void> initialize() async {}
  Future<void> dispose() async {}
  bool get isAvailable => !kIsWeb;
}
