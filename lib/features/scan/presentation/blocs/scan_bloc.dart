import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

import 'scan_event.dart';
import 'scan_state.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../ml/face_recognition/face_recognition_service.dart';
import '../../../../data/local/database/local_database.dart';
import '../../../../services/sync/sync_service.dart';
import '../../../../services/audit/audit_service.dart';
import '../../../../core/constants/app_constants.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final FaceRecognitionService _faceRecognition;
  final LocalDatabase _localDb;
  final SyncService _syncService;
  final AuditService _auditService;
  final Logger _log = Logger();
  final _uuid = const Uuid();

  // Multi-frame majority voting buffer
  final Map<String, List<double>> _frameBuffer = {};
  final Map<String, int> _voteCount = {};

  ScanBloc({
    required FaceRecognitionService faceRecognition,
    required LocalDatabase localDb,
    required SyncService syncService,
    required AuditService auditService,
  })  : _faceRecognition = faceRecognition,
        _localDb = localDb,
        _syncService = syncService,
        _auditService = auditService,
        super(ScanInitial()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanFrameReceived>(_onFrameReceived);
    on<ScanManualOverride>(_onManualOverride);
    on<ScanSubmitted>(_onSubmitted);
    on<ScanDisposed>(_onDisposed);
    on<ScanReviewConfirmed>(_onReviewConfirmed);
  }

  // ─── Start Session ─────────────────────────────────────────────────────────

  Future<void> _onScanStarted(
    ScanStarted event,
    Emitter<ScanState> emit,
  ) async {
    emit(ScanLoading());

    try {
      final session = await _localDb.getSession(event.sessionId);
      if (session == null) {
        emit(const ScanError(message: 'Session not found'));
        return;
      }

      final classId = session['class_id'] as String;
      final students = await _localDb.getStudentsByClass(classId);

      // Build initial absentees list (everyone starts absent)
      final absentees = students
          .where((s) => s['biometric_consent'] == 1)
          .map((s) => {
                'id': s['id'],
                'name': s['name'],
                'rollNumber': s['roll_number'],
              })
          .toList();

      emit(ScanInProgress(
        sessionId: event.sessionId,
        subjectName: session['subject_id'] as String? ?? 'Subject',
        date: DateFormat('dd MMM yyyy').format(DateTime.now()),
        period: session['period'] as int? ?? 1,
        totalStudents: students.length,
        presentCount: 0,
        reviewCount: 0,
        pendingSyncCount: await _syncService.pendingCount,
        detectedFaces: const [],
        recentMatches: const [],
        absentees: absentees,
        markedStudentIds: {},
      ));
    } catch (e) {
      _log.e('ScanStarted error: $e');
      emit(ScanError(message: e.toString()));
    }
  }

  // ─── Process Camera Frame ─────────────────────────────────────────────────

  Future<void> _onFrameReceived(
    ScanFrameReceived event,
    Emitter<ScanState> emit,
  ) async {
    final current = state;
    if (current is! ScanInProgress) return;

    try {
      // Run face recognition on frame
      final matches = await _faceRecognition.processFrame(event.cameraImage);
      if (matches.isEmpty) return;

      final updatedState = await _processMatches(current, matches);
      emit(updatedState);
    } catch (e) {
      _log.w('Frame processing error: $e');
    }
  }

  Future<ScanInProgress> _processMatches(
    ScanInProgress current,
    List<FaceMatch> matches,
  ) async {
    int presentCount = current.presentCount;
    int reviewCount = current.reviewCount;
    final markedStudentIds = Set<String>.from(current.markedStudentIds);
    final absentees = List<Map<String, dynamic>>.from(current.absentees);
    final recentMatches = <FaceMatch>[];

    for (final match in matches) {
      recentMatches.add(match);

      // Skip already marked students (prevent duplicates)
      if (match.studentId != null &&
          markedStudentIds.contains(match.studentId)) {
        continue;
      }

      // ── Multi-Frame Majority Voting ──────────────────────────────────────
      if (match.studentId != null) {
        _voteCount[match.studentId!] =
            (_voteCount[match.studentId!] ?? 0) + 1;

        // Only mark after majority votes
        if (_voteCount[match.studentId!]! < AppConstants.majorityVotesRequired) {
          continue;
        }
        _voteCount.remove(match.studentId);
      }
      // ────────────────────────────────────────────────────────────────────

      switch (match.result) {
        case MatchResult.autoPresent:
          if (match.studentId != null) {
            if (match.requiresManualConfirmation) {
              // Twins/lookalikes — add to review instead of auto-marking
              reviewCount++;
              await _saveAttendance(
                studentId: match.studentId!,
                sessionId: current.sessionId,
                status: AttendanceStatus.review,
                match: match,
              );
            } else {
              presentCount++;
              markedStudentIds.add(match.studentId!);
              absentees.removeWhere((s) => s['id'] == match.studentId);

              await _saveAttendance(
                studentId: match.studentId!,
                sessionId: current.sessionId,
                status: AttendanceStatus.present,
                match: match,
              );
            }
          }

        case MatchResult.needsReview:
          if (match.studentId != null &&
              !markedStudentIds.contains(match.studentId)) {
            reviewCount++;
            markedStudentIds.add(match.studentId!);
            await _saveAttendance(
              studentId: match.studentId!,
              sessionId: current.sessionId,
              status: AttendanceStatus.review,
              match: match,
            );
          }

        case MatchResult.unrecognized:
          // Log but don't mark anyone
          _log.d('Unrecognized face, confidence: ${match.confidence}');
      }
    }

    // Keep only last 5 matches visible
    final visible = recentMatches.reversed.take(5).toList();

    return current.copyWith(
      presentCount: presentCount,
      reviewCount: reviewCount,
      recentMatches: visible,
      absentees: absentees,
      markedStudentIds: markedStudentIds,
    );
  }

  // ─── Save Attendance to Local DB ─────────────────────────────────────────

  Future<void> _saveAttendance({
    required String studentId,
    required String sessionId,
    required AttendanceStatus status,
    required FaceMatch match,
  }) async {
    final session = await _localDb.getSession(sessionId);
    if (session == null) return;

    final id = _uuid.v4();
    final now = DateTime.now();

    final record = {
      'id': id,
      'session_id': sessionId,
      'student_id': studentId,
      'class_id': session['class_id'],
      'subject_id': session['subject_id'],
      'teacher_id': session['teacher_id'],
      'date': DateFormat('yyyy-MM-dd').format(now),
      'period': session['period'],
      'status': status.name,
      'marked_by': MarkedBy.faceScan.name,
      'confidence': match.confidence,
      'edit_window_expires_at': now
          .add(const Duration(minutes: AppConstants.postSubmissionEditWindowMinutes))
          .millisecondsSinceEpoch,
      'is_synced': 0,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    };

    await _localDb.upsertAttendance(record);
    await _auditService.log(
      action: 'mark_attendance',
      targetType: 'attendance',
      targetId: id,
      newValue: record,
    );

    // Enqueue for Firebase sync
    await _syncService.enqueue(
      tableName: 'attendance',
      recordId: id,
      operation: 'insert',
      payload: record,
    );
  }

  // ─── Manual Override ──────────────────────────────────────────────────────

  Future<void> _onManualOverride(
    ScanManualOverride event,
    Emitter<ScanState> emit,
  ) async {
    final current = state;
    if (current is! ScanInProgress) return;

    try {
      await _saveAttendance(
        studentId: event.studentId,
        sessionId: current.sessionId,
        status: AttendanceStatus.manual,
        match: FaceMatch(
          studentId: event.studentId,
          confidence: 1.0,
          result: MatchResult.autoPresent,
          requiresManualConfirmation: false,
        ),
      );

      await _auditService.log(
        action: 'manual_override',
        targetType: 'attendance',
        targetId: event.studentId,
        newValue: {'status': event.status, 'reason': event.reason},
      );

      final markedStudentIds = Set<String>.from(current.markedStudentIds)
        ..add(event.studentId);
      final absentees = List<Map<String, dynamic>>.from(current.absentees)
        ..removeWhere((s) => s['id'] == event.studentId);

      emit(current.copyWith(
        presentCount: current.presentCount + 1,
        absentees: absentees,
        markedStudentIds: markedStudentIds,
      ));
    } catch (e) {
      emit(ScanError(message: 'Override failed: $e'));
    }
  }

  // ─── Submit Session ───────────────────────────────────────────────────────

  Future<void> _onSubmitted(
    ScanSubmitted event,
    Emitter<ScanState> emit,
  ) async {
    final current = state;
    if (current is! ScanInProgress) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Mark all remaining absentees
      for (final absentee in current.absentees) {
        final studentId = absentee['id'] as String;
        if (!current.markedStudentIds.contains(studentId)) {
          final id = _uuid.v4();
          final session = await _localDb.getSession(current.sessionId);
          if (session == null) continue;

          final record = {
            'id': id,
            'session_id': current.sessionId,
            'student_id': studentId,
            'class_id': session['class_id'],
            'subject_id': session['subject_id'],
            'teacher_id': session['teacher_id'],
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'period': session['period'],
            'status': 'absent',
            'marked_by': 'system',
            'is_synced': 0,
            'created_at': now,
            'updated_at': now,
          };
          await _localDb.upsertAttendance(record);
          await _syncService.enqueue(
            tableName: 'attendance',
            recordId: id,
            operation: 'insert',
            payload: record,
          );
        }
      }

      // Update session status
      await _localDb.updateSession(current.sessionId, {
        'status': 'submitted',
        'submitted_at': now,
        'present_count': current.presentCount,
        'review_count': current.reviewCount,
        'absent_count': current.absentees.length,
        'end_time': now,
      });

      emit(ScanSessionSubmitted(
        sessionId: current.sessionId,
        presentCount: current.presentCount,
        totalStudents: current.totalStudents,
      ));
    } catch (e) {
      emit(ScanError(message: 'Submit failed: $e'));
    }
  }

  Future<void> _onReviewConfirmed(
    ScanReviewConfirmed event,
    Emitter<ScanState> emit,
  ) async {
    // Update borderline match to present after roll-number verification
    final current = state;
    if (current is! ScanInProgress) return;

    await _localDb.upsertAttendance({
      'student_id': event.studentId,
      'status': 'present',
      'marked_by': 'manual_teacher',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _onDisposed(ScanDisposed event, Emitter<ScanState> emit) async {
    _frameBuffer.clear();
    _voteCount.clear();
  }
}
