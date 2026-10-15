// Stub — audit service uses SQLite, Android only
class AuditService {
  AuditService();
  void setActor(String actorId, String role) {}
  Future<void> log({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
    String? reason,
  }) async {}
}

class AuditActions {
  static const String loginSuccess = 'login_success';
  static const String loginFailure = 'login_failure';
  static const String markPresent  = 'mark_present';
  static const String markAbsent   = 'mark_absent';
}
