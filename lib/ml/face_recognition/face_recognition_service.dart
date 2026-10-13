import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/entities.dart';
import '../embedding/embedding_manager.dart';
import '../anti_spoofing/anti_spoof_service.dart';

/// Orchestrates face detection, quality checks, embedding extraction,
/// and matching for the live scan session.
class FaceRecognitionService {
  final FaceDetector _faceDetector;
  final Interpreter _mobileFaceNetInterpreter;
  final EmbeddingManager _embeddingManager;
  final AntiSpoofService _antiSpoofService;
  final Logger _log = Logger();

  FaceRecognitionService({
    required FaceDetector faceDetector,
    required Interpreter mobileFaceNetInterpreter,
    required EmbeddingManager embeddingManager,
    required AntiSpoofService antiSpoofService,
  })  : _faceDetector = faceDetector,
        _mobileFaceNetInterpreter = mobileFaceNetInterpreter,
        _embeddingManager = embeddingManager,
        _antiSpoofService = antiSpoofService;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Process a single camera frame: detect faces, check quality,
  /// extract embeddings, run anti-spoof, match against enrolled students.
  Future<List<FaceMatch>> processFrame(
    CameraImage cameraImage, {
    bool isEnrollment = false,
  }) async {
    final results = <FaceMatch>[];

    try {
      // 1. Convert camera image to ML Kit InputImage
      final inputImage = _cameraImageToInputImage(cameraImage);

      // 2. Detect faces
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) return results;

      // 3. Convert CameraImage to img.Image for processing
      final processedImage = _convertCameraImage(cameraImage);
      if (processedImage == null) return results;

      // 4. Process each detected face
      for (final face in faces) {
        // 4a. Quality check
        final qualityResult = _checkFrameQuality(face, processedImage);
        if (!qualityResult.isAcceptable && !isEnrollment) continue;

        // 4b. Crop face region
        final faceImage = _cropFace(processedImage, face);
        if (faceImage == null) continue;

        // 4c. Anti-spoof check (skip for enrollment — handled separately)
        if (!isEnrollment) {
          final spoofResult = await _antiSpoofService.checkLiveness(faceImage);
          if (!spoofResult.isLive) {
            _log.w('Spoof detected! Score: ${spoofResult.antiSpoofScore}');
            continue;
          }
        }

        // 4d. Extract embedding
        final embedding = _extractEmbedding(faceImage);

        // 4e. Match against enrolled students
        if (!isEnrollment) {
          final match = await _matchEmbedding(embedding);
          results.add(match);
        }
      }
    } catch (e) {
      _log.e('Error processing frame: $e');
    }

    return results;
  }

  /// Extract embedding from a face image for enrollment.
  Future<List<double>?> extractEmbeddingForEnrollment(
    img.Image faceImage,
    FrameQuality quality,
  ) async {
    if (!quality.isAcceptable) return null;
    return _extractEmbedding(faceImage);
  }

  /// Check frame quality — returns blur score, brightness, face size.
  FrameQuality checkQuality(Face face, img.Image image) {
    return _checkFrameQuality(face, image);
  }

  // ─── Embedding Extraction ─────────────────────────────────────────────────

  List<double> _extractEmbedding(img.Image faceImage) {
    // Resize to 112×112 (MobileFaceNet input)
    final resized = img.copyResize(faceImage, width: 112, height: 112);

    // Normalize to [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128.0,
              (pixel.g - 127.5) / 128.0,
              (pixel.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );

    // Output: 128-dim embedding
    final output = List.filled(1 * 128, 0.0).reshape([1, 128]);

    _mobileFaceNetInterpreter.run(input, output);

    final embedding = List<double>.from(output[0] as List);

    // L2 normalize
    return _l2Normalize(embedding);
  }

  // ─── Matching Logic ───────────────────────────────────────────────────────

  /// Two-threshold matching:
  /// ≥ 0.82 → auto-present
  /// 0.65–0.82 → needs review
  /// < 0.65 → unrecognized
  Future<FaceMatch> _matchEmbedding(List<double> queryEmbedding) async {
    final enrolled = await _embeddingManager.getAllActiveEmbeddings();

    double bestSimilarity = 0.0;
    String? bestStudentId;
    String? bestStudentName;
    String? bestRollNumber;

    double secondBestSimilarity = 0.0;
    String? secondBestStudentId;

    for (final record in enrolled) {
      // Average similarity across all embeddings for this student
      final studentEmbeddings = record.embeddings;
      double maxSim = 0.0;

      for (final storedEmbedding in studentEmbeddings) {
        final sim = _cosineSimilarity(queryEmbedding, storedEmbedding);
        if (sim > maxSim) maxSim = sim;
      }

      if (maxSim > bestSimilarity) {
        secondBestSimilarity = bestSimilarity;
        secondBestStudentId = bestStudentId;
        bestSimilarity = maxSim;
        bestStudentId = record.studentId;
        bestStudentName = record.studentName;
        bestRollNumber = record.rollNumber;
      } else if (maxSim > secondBestSimilarity) {
        secondBestSimilarity = maxSim;
        secondBestStudentId = record.studentId;
      }
    }

    // Twins/lookalikes: if top-2 scores are very close, require manual confirm
    final ambiguous = (bestSimilarity - secondBestSimilarity) < 0.05 &&
        secondBestSimilarity > AppConstants.borderlineThreshold;

    // Determine match result
    MatchResult result;
    if (bestSimilarity >= AppConstants.highConfidenceThreshold) {
      result = MatchResult.autoPresent;
    } else if (bestSimilarity >= AppConstants.borderlineThreshold) {
      result = MatchResult.needsReview;
    } else {
      result = MatchResult.unrecognized;
    }

    return FaceMatch(
      studentId: result != MatchResult.unrecognized ? bestStudentId : null,
      studentName: result != MatchResult.unrecognized ? bestStudentName : null,
      rollNumber: result != MatchResult.unrecognized ? bestRollNumber : null,
      confidence: bestSimilarity,
      result: result,
      requiresManualConfirmation: ambiguous,
      secondBestStudentId: secondBestStudentId,
      secondBestConfidence: secondBestSimilarity,
    );
  }

  // ─── Quality Check ────────────────────────────────────────────────────────

  FrameQuality _checkFrameQuality(Face face, img.Image image) {
    // Minimum face size
    final faceWidth = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;
    final meetsMinSize = faceWidth >= AppConstants.minFaceSize &&
        faceHeight >= AppConstants.minFaceSize;

    // Blur score (Laplacian variance approximation)
    final faceImage = _cropFace(image, face);
    double blurScore = 1.0;
    if (faceImage != null) {
      blurScore = _computeBlurScore(faceImage);
    }

    // Brightness
    double brightness = 0.5;
    if (faceImage != null) {
      brightness = _computeBrightness(faceImage);
    }

    return FrameQuality(
      blurScore: blurScore,
      brightness: brightness,
      faceWidth: faceWidth,
      faceHeight: faceHeight,
      meetsMinSize: meetsMinSize,
    );
  }

  double _computeBlurScore(img.Image image) {
    // Simplified Laplacian variance — real impl uses convolution
    final gray = img.grayscale(image);
    double variance = 0.0;
    final pixels = <double>[];

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        pixels.add(gray.getPixel(x, y).r.toDouble());
      }
    }

    final mean = pixels.reduce((a, b) => a + b) / pixels.length;
    for (final p in pixels) {
      variance += (p - mean) * (p - mean);
    }
    variance /= pixels.length;

    // Normalize to 0–1; threshold is ~500 raw Laplacian
    return (variance / 5000).clamp(0.0, 1.0);
  }

  double _computeBrightness(img.Image image) {
    double total = 0.0;
    final count = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        // Luminance formula
        total += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }

    return (total / count / 255.0).clamp(0.0, 1.0);
  }

  // ─── Math Helpers ─────────────────────────────────────────────────────────

  /// Cosine similarity between two L2-normalized vectors.
  double _cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Embedding dimensions must match');
    double dot = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    // Already L2-normalized, so dot product = cosine similarity
    return dot.clamp(-1.0, 1.0);
  }

  List<double> _l2Normalize(List<double> v) {
    double norm = 0.0;
    for (final x in v) {
      norm += x * x;
    }
    norm = sqrt(norm);
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  // ─── Image Helpers ────────────────────────────────────────────────────────

  img.Image? _cropFace(img.Image image, Face face) {
    final box = face.boundingBox;

    // Add 20% padding
    final padX = (box.width * 0.2).toInt();
    final padY = (box.height * 0.2).toInt();

    final x = (box.left - padX).clamp(0.0, image.width.toDouble()).toInt();
    final y = (box.top - padY).clamp(0.0, image.height.toDouble()).toInt();
    final w = (box.width + 2 * padX).clamp(0.0, image.width - x.toDouble()).toInt();
    final h = (box.height + 2 * padY).clamp(0.0, image.height - y.toDouble()).toInt();

    if (w <= 0 || h <= 0) return null;

    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(cameraImage);
      }
    } catch (e) {
      _log.e('Failed to convert camera image: $e');
    }
    return null;
  }

  img.Image _convertYUV420(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yVal = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;
        final uVal = uPlane.bytes[uvIndex];
        final vVal = vPlane.bytes[uvIndex];

        final r = (yVal + 1.370705 * (vVal - 128)).clamp(0, 255).toInt();
        final g = (yVal - 0.698001 * (vVal - 128) - 0.337633 * (uVal - 128)).clamp(0, 255).toInt();
        final b = (yVal + 1.732446 * (uVal - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }

  img.Image _convertBGRA8888(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      format: img.Format.uint8,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
  }

  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    final bytes = Uint8List.fromList(
      cameraImage.planes.fold(
        <int>[],
        (buf, plane) => buf..addAll(plane.bytes),
      ),
    );

    final metadata = InputImageMetadata(
      size: Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      ),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.yuv_420_888,
      bytesPerRow: cameraImage.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  void dispose() {
    _faceDetector.close();
    _mobileFaceNetInterpreter.close();
  }
}

// ─── Data Classes ─────────────────────────────────────────────────────────────

class FrameQuality {
  final double blurScore;
  final double brightness;
  final double faceWidth;
  final double faceHeight;
  final bool meetsMinSize;

  const FrameQuality({
    required this.blurScore,
    required this.brightness,
    required this.faceWidth,
    required this.faceHeight,
    required this.meetsMinSize,
  });

  bool get isAcceptable =>
      meetsMinSize &&
      blurScore >= AppConstants.minBlurScore &&
      brightness >= AppConstants.minBrightnessScore &&
      brightness <= AppConstants.maxBrightnessScore;

  String get qualityMessage {
    if (!meetsMinSize) return 'Move closer to camera';
    if (blurScore < AppConstants.minBlurScore) return 'Hold camera steady';
    if (brightness < AppConstants.minBrightnessScore) return 'More light needed';
    if (brightness > AppConstants.maxBrightnessScore) return 'Too bright';
    return 'Good';
  }
}

class StudentEmbeddingSet {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final List<List<double>> embeddings; // Multiple embeddings per student

  const StudentEmbeddingSet({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.embeddings,
  });
}
