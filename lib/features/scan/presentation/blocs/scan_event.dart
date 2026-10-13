import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';

abstract class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => [];
}

class ScanStarted extends ScanEvent {
  final String sessionId;
  const ScanStarted({required this.sessionId});

  @override
  List<Object?> get props => [sessionId];
}

class ScanFrameReceived extends ScanEvent {
  final CameraImage cameraImage;
  const ScanFrameReceived({required this.cameraImage});

  @override
  List<Object?> get props => [];  // Don't compare frame contents
}

class ScanManualOverride extends ScanEvent {
  final String studentId;
  final String status;
  final String reason;
  const ScanManualOverride({
    required this.studentId,
    required this.status,
    required this.reason,
  });

  @override
  List<Object?> get props => [studentId, status];
}

class ScanSubmitted extends ScanEvent {}

class ScanDisposed extends ScanEvent {}

class ScanReviewConfirmed extends ScanEvent {
  final String studentId;
  final String rollNumber;
  const ScanReviewConfirmed({
    required this.studentId,
    required this.rollNumber,
  });

  @override
  List<Object?> get props => [studentId];
}
