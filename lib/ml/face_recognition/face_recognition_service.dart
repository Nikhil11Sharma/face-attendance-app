// Stub — face recognition runs on Android only (TFLite + camera not available on web)
import 'package:flutter/foundation.dart';
import '../../domain/entities/entities.dart';

class FaceRecognitionService {
  FaceRecognitionService();

  Future<void> initialize() async {}
  Future<void> dispose() async {}

  bool get isAvailable => !kIsWeb;

  /// Returns an empty list on web / when not available.
  Future<List<FaceMatch>> processFrame(dynamic cameraImage) async => [];
}
