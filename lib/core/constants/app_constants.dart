class AppConstants {
  // Matching Thresholds (cosine similarity, 0.0 – 1.0)
  static const double highConfidenceThreshold = 0.82;   // Auto-present
  static const double borderlineThreshold = 0.65;        // Needs review
  // Below 0.65 = Unrecognized

  // Enrollment
  static const int embeddingsPerStudent = 5;
  static const int minFaceSize = 80;       // pixels — min for quality
  static const double minBlurScore = 0.65; // Laplacian variance normalized
  static const double minBrightnessScore = 0.3;
  static const double maxBrightnessScore = 0.95;

  // Anti-Spoofing
  static const double livenessThreshold = 0.75;
  static const double antiSpoofThreshold = 0.80;
  static const int blinkCountRequired = 1;
  static const int headTurnRequired = 1;
  static const int livenessTimeoutSeconds = 10;

  // Multi-frame matching
  static const int framesForMajority = 5;
  static const int majorityVotesRequired = 3;

  // Session
  static const int postSubmissionEditWindowMinutes = 15;
  static const int sessionTimeoutMinutes = 120;

  // Sync
  static const int maxSyncRetries = 5;
  static const int syncRetryDelaySeconds = 30;
  static const int maxOfflineDays = 7;

  // Data retention
  static const int dataRetentionYears = 2;

  // Embedding dimensions (MobileFaceNet output)
  static const int embeddingDimensions = 128;

  // Snapshot
  static const int snapshotThumbnailSize = 112; // px, for audit

  // Low attendance alert
  static const double lowAttendanceThreshold = 0.75; // 75%

  // Local DB version
  static const int dbVersion = 1;
  static const String dbName = 'face_attendance.db';

  // Model file names
  static const String mobileFaceNetModel = 'assets/models/mobilefacenet.tflite';
  static const String antiSpoofModel = 'assets/models/anti_spoof.tflite';

  // Routes
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeDashboard = '/dashboard';
  static const String routeEnrollment = '/enrollment';
  static const String routeScan = '/scan';
  static const String routeReports = '/reports';
  static const String routeSettings = '/settings';

  // Firestore collections
  static const String colColleges = 'colleges';
  static const String colTeachers = 'teachers';
  static const String colStudents = 'students';
  static const String colEmbeddings = 'embeddings';
  static const String colClasses = 'classes';
  static const String colSubjects = 'subjects';
  static const String colAttendance = 'attendance';
  static const String colSessions = 'sessions';
  static const String colAuditLog = 'audit_log';
  static const String colConsentRecords = 'consent_records';

  // Secure storage keys
  static const String keyEncryptionKey = 'embedding_encryption_key';
  static const String keyTeacherId = 'teacher_id';
  static const String keyCollegeId = 'college_id';
}
