import 'package:equatable/equatable.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../ml/anti_spoofing/anti_spoof_service.dart';

abstract class ScanState extends Equatable {
  const ScanState();

  @override
  List<Object?> get props => [];
}

class ScanInitial extends ScanState {}

class ScanLoading extends ScanState {}

class ScanInProgress extends ScanState {
  final String sessionId;
  final String subjectName;
  final String date;
  final int period;
  final int totalStudents;
  final int presentCount;
  final int reviewCount;
  final int pendingSyncCount;
  final List<dynamic> detectedFaces;       // ML Kit Face objects
  final List<FaceMatch> recentMatches;     // Last ~5 detected
  final List<Map<String, dynamic>> absentees;
  final LivenessChallenge? livenessChallenge;
  final String? qualityMessage;
  final Set<String> markedStudentIds;      // Prevents duplicates

  const ScanInProgress({
    required this.sessionId,
    required this.subjectName,
    required this.date,
    required this.period,
    required this.totalStudents,
    required this.presentCount,
    required this.reviewCount,
    required this.pendingSyncCount,
    required this.detectedFaces,
    required this.recentMatches,
    required this.absentees,
    this.livenessChallenge,
    this.qualityMessage,
    required this.markedStudentIds,
  });

  ScanInProgress copyWith({
    int? presentCount,
    int? reviewCount,
    int? pendingSyncCount,
    List<dynamic>? detectedFaces,
    List<FaceMatch>? recentMatches,
    List<Map<String, dynamic>>? absentees,
    LivenessChallenge? livenessChallenge,
    String? qualityMessage,
    Set<String>? markedStudentIds,
  }) {
    return ScanInProgress(
      sessionId: sessionId,
      subjectName: subjectName,
      date: date,
      period: period,
      totalStudents: totalStudents,
      presentCount: presentCount ?? this.presentCount,
      reviewCount: reviewCount ?? this.reviewCount,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      detectedFaces: detectedFaces ?? this.detectedFaces,
      recentMatches: recentMatches ?? this.recentMatches,
      absentees: absentees ?? this.absentees,
      livenessChallenge: livenessChallenge ?? this.livenessChallenge,
      qualityMessage: qualityMessage,
      markedStudentIds: markedStudentIds ?? this.markedStudentIds,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        presentCount,
        reviewCount,
        recentMatches,
        qualityMessage,
        markedStudentIds,
      ];
}

class ScanSessionSubmitted extends ScanState {
  final String sessionId;
  final int presentCount;
  final int totalStudents;

  const ScanSessionSubmitted({
    required this.sessionId,
    required this.presentCount,
    required this.totalStudents,
  });

  @override
  List<Object?> get props => [sessionId, presentCount];
}

class ScanError extends ScanState {
  final String message;
  const ScanError({required this.message});

  @override
  List<Object?> get props => [message];
}
