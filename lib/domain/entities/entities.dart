// ─── Domain Entities ───────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

// ── Student ─────────────────────────────────────────────────────────────────
class Student extends Equatable {
  final String id;
  final String name;
  final String rollNumber;
  final String classId;
  final String collegeId;
  final String departmentId;
  final String email;
  final String phone;
  final int semester;
  final String academicYear;
  final bool biometricConsent;
  final DateTime? consentTimestamp;
  final EnrollmentStatus enrollmentStatus;
  final DateTime? enrolledAt;
  final bool isActive;

  const Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.classId,
    required this.collegeId,
    required this.departmentId,
    required this.email,
    required this.phone,
    required this.semester,
    required this.academicYear,
    required this.biometricConsent,
    this.consentTimestamp,
    required this.enrollmentStatus,
    this.enrolledAt,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, rollNumber, classId, enrollmentStatus];
}

enum EnrollmentStatus { enrolled, pending, declined }

// ── Teacher ──────────────────────────────────────────────────────────────────
class Teacher extends Equatable {
  final String id;
  final String name;
  final String email;
  final String employeeId;
  final String collegeId;
  final TeacherRole role;
  final List<String> classIds;
  final bool isActive;

  const Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.collegeId,
    required this.role,
    required this.classIds,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, email, role];
}

enum TeacherRole { teacher, hod, admin }

// ── AttendanceRecord ─────────────────────────────────────────────────────────
class AttendanceRecord extends Equatable {
  final String id;
  final String sessionId;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String date;
  final int period;
  final AttendanceStatus status;
  final MarkedBy markedBy;
  final double? confidence;
  final double? livenessScore;
  final double? antiSpoofScore;
  final double? frameQualityScore;
  final String? snapshotPath;
  final String? overrideReason;
  final String? overriddenBy;
  final DateTime? editWindowExpiresAt;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.date,
    required this.period,
    required this.status,
    required this.markedBy,
    this.confidence,
    this.livenessScore,
    this.antiSpoofScore,
    this.frameQualityScore,
    this.snapshotPath,
    this.overrideReason,
    this.overriddenBy,
    this.editWindowExpiresAt,
    required this.isSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get canEdit =>
      editWindowExpiresAt != null &&
      DateTime.now().isBefore(editWindowExpiresAt!);

  @override
  List<Object?> get props => [id, studentId, date, period, status];
}

enum AttendanceStatus { present, absent, review, manual }
enum MarkedBy { faceScan, manualTeacher, manualStudent }

// ── Session ──────────────────────────────────────────────────────────────────
class Session extends Equatable {
  final String id;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String date;
  final int period;
  final DateTime? startTime;
  final DateTime? endTime;
  final int scanDurationSeconds;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int reviewCount;
  final SessionStatus status;
  final DateTime? submittedAt;
  final bool isSynced;

  const Session({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.date,
    required this.period,
    this.startTime,
    this.endTime,
    required this.scanDurationSeconds,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.reviewCount,
    required this.status,
    this.submittedAt,
    required this.isSynced,
  });

  String get attendancePercentage {
    if (totalStudents == 0) return '0%';
    return '${((presentCount / totalStudents) * 100).toStringAsFixed(1)}%';
  }

  @override
  List<Object?> get props => [id, classId, date, period];
}

enum SessionStatus { inProgress, submitted, locked }

// ── FaceMatch ────────────────────────────────────────────────────────────────
class FaceMatch extends Equatable {
  final String? studentId;
  final String? studentName;
  final String? rollNumber;
  final double confidence;
  final MatchResult result;
  final bool requiresManualConfirmation; // twins/lookalikes
  final String? secondBestStudentId;
  final double? secondBestConfidence;

  const FaceMatch({
    this.studentId,
    this.studentName,
    this.rollNumber,
    required this.confidence,
    required this.result,
    required this.requiresManualConfirmation,
    this.secondBestStudentId,
    this.secondBestConfidence,
  });

  @override
  List<Object?> get props => [studentId, confidence, result];
}

enum MatchResult { autoPresent, needsReview, unrecognized }

// ── EmbeddingRecord ──────────────────────────────────────────────────────────
class EmbeddingRecord extends Equatable {
  final String id;
  final String studentId;
  final List<double> embedding; // 128-dim, decrypted in memory only
  final String angle;
  final double qualityScore;
  final DateTime createdAt;

  const EmbeddingRecord({
    required this.id,
    required this.studentId,
    required this.embedding,
    required this.angle,
    required this.qualityScore,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, studentId, angle];
}

// ── AuditLog ─────────────────────────────────────────────────────────────────
class AuditLog extends Equatable {
  final String id;
  final String actorId;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final DateTime timestamp;

  const AuditLog({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.previousValue,
    this.newValue,
    this.reason,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, action, targetId, timestamp];
}
