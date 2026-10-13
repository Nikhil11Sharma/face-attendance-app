import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

import '../../data/local/database/local_database.dart';
import '../../services/sync/sync_service.dart';

/// Immutable audit log service.
/// Every sensitive action (mark attendance, override, enrollment, delete)
/// is recorded here for compliance and dispute resolution.
class AuditService {
  final LocalDatabase _localDb;
  final SyncService _syncService;
  final Logger _log = Logger();
  final _uuid = const Uuid();

  String? _currentActorId;
  String _currentActorRole = 'system';

  AuditService({
    required LocalDatabase localDb,
    required SyncService syncService,
  })  : _localDb = localDb,
        _syncService = syncService;

  void setActor(String actorId, String role) {
    _currentActorId = actorId;
    _currentActorRole = role;
  }

  Future<void> log({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
  }) async {
    final id = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final entry = {
      'id': id,
      'actor_id': _currentActorId ?? 'system',
      'actor_role': _currentActorRole,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'previous_value': previousValue != null ? jsonEncode(previousValue) : null,
      'new_value': newValue != null ? jsonEncode(newValue) : null,
      'reason': reason,
      'timestamp': timestamp,
    };

    // Write to local SQLite
    await _localDb.insertAuditLog(entry);

    // Enqueue for Firestore sync (audit_log is append-only, no conflicts)
    await _syncService.enqueue(
      tableName: 'audit_log',
      recordId: id,
      operation: 'insert',
      payload: {
        'id': id,
        'actorId': _currentActorId ?? 'system',
        'actorRole': _currentActorRole,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'previousValue': previousValue,
        'newValue': newValue,
        'reason': reason,
        'timestamp': timestamp,
      },
    );

    _log.d('AUDIT: [$_currentActorRole] $action → $targetType/$targetId');
  }
}

/// Predefined audit action constants
class AuditActions {
  static const String markPresent = 'mark_present';
  static const String markAbsent = 'mark_absent';
  static const String manualOverride = 'manual_override';
  static const String enrollStudent = 'enroll_student';
  static const String consentGranted = 'consent_granted';
  static const String consentRevoked = 'consent_revoked';
  static const String deleteEmbeddings = 'delete_embeddings';
  static const String deleteStudent = 'delete_student';
  static const String exportReport = 'export_report';
  static const String sessionSubmitted = 'session_submitted';
  static const String reEnrollment = 're_enrollment';
  static const String loginSuccess = 'login_success';
  static const String loginFailure = 'login_failure';
}
