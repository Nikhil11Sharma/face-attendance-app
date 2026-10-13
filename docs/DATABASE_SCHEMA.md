# 🗄️ Database Schema

## Overview
- **Firebase Firestore** — remote, synced, authoritative source of truth
- **SQLite (sqflite)** — local, offline-first, encrypted sensitive fields

---

## Firestore Collections

### `/colleges/{collegeId}`
```json
{
  "id": "string",
  "name": "string",
  "address": "string",
  "adminEmail": "string",
  "retentionPolicyYears": 2,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `/teachers/{teacherId}`
```json
{
  "id": "string",                  // Firebase Auth UID
  "name": "string",
  "email": "string",
  "employeeId": "string",
  "collegeId": "string",
  "role": "teacher | hod | admin",
  "departmentId": "string",
  "classIds": ["string"],          // Classes they teach
  "consentGivenAt": "Timestamp",
  "isActive": true,
  "createdAt": "Timestamp"
}
```

### `/students/{studentId}`
```json
{
  "id": "string",
  "name": "string",
  "rollNumber": "string",          // Unique per class
  "collegeId": "string",
  "departmentId": "string",
  "classId": "string",
  "email": "string",
  "phone": "string",
  "semester": 3,
  "academicYear": "2025-26",
  "biometricConsent": true,        // DPDP consent
  "consentTimestamp": "Timestamp",
  "consentIpAddress": "string",
  "enrollmentStatus": "enrolled | pending | declined",
  "enrolledAt": "Timestamp",
  "lastReEnrolledAt": "Timestamp",
  "isActive": true,
  "createdAt": "Timestamp"
}
```

### `/embeddings/{embeddingId}`
```json
{
  "id": "string",
  "studentId": "string",
  "encryptedEmbeddings": ["string"],  // AES-256-GCM encrypted float arrays, 5 per student
  "embeddingVersion": "mobilefacenet_v1",
  "captureAngles": ["frontal", "left_15", "right_15", "up_10", "down_10"],
  "qualityScores": [0.92, 0.89, 0.94, 0.87, 0.91],
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "semester": 3,
  "academicYear": "2025-26",
  "isActive": true                    // false = archived after re-enrollment
}
```

### `/classes/{classId}`
```json
{
  "id": "string",
  "name": "CSE-3B",
  "collegeId": "string",
  "departmentId": "string",
  "semester": 3,
  "academicYear": "2025-26",
  "teacherIds": ["string"],
  "studentIds": ["string"],
  "totalStrength": 60,
  "createdAt": "Timestamp"
}
```

### `/subjects/{subjectId}`
```json
{
  "id": "string",
  "name": "Data Structures",
  "code": "CS301",
  "classId": "string",
  "teacherId": "string",
  "collegeId": "string",
  "weeklyHours": 4,
  "totalClasses": 0,               // updated each session
  "createdAt": "Timestamp"
}
```

### `/attendance/{attendanceId}`
```json
{
  "id": "string",
  "sessionId": "string",
  "studentId": "string",
  "classId": "string",
  "subjectId": "string",
  "teacherId": "string",
  "date": "2025-10-13",            // YYYY-MM-DD
  "period": 3,
  "status": "present | absent | review | manual",
  "markedBy": "face_scan | manual_teacher | manual_student",
  "confidence": 0.94,              // face match confidence (0.0–1.0)
  "snapshotPath": "string",        // encrypted thumbnail path for audit
  "livenessScore": 0.97,
  "antiSpoofScore": 0.99,
  "frameQualityScore": 0.91,
  "overrideReason": "string | null",
  "overriddenBy": "string | null", // teacherId
  "editWindowExpiresAt": "Timestamp", // 15 min post-session
  "isSynced": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### `/sessions/{sessionId}`
```json
{
  "id": "string",
  "classId": "string",
  "subjectId": "string",
  "teacherId": "string",
  "date": "2025-10-13",
  "period": 3,
  "startTime": "Timestamp",
  "endTime": "Timestamp",
  "scanDurationSeconds": 145,
  "totalStudents": 60,
  "presentCount": 52,
  "absentCount": 8,
  "reviewCount": 2,
  "status": "in_progress | submitted | locked",
  "submittedAt": "Timestamp",
  "isSynced": true
}
```

### `/audit_log/{logId}`
```json
{
  "id": "string",
  "actorId": "string",             // teacherId or system
  "actorRole": "teacher | hod | admin | system",
  "action": "mark_present | mark_absent | override | delete_student | export_report | ...",
  "targetType": "attendance | student | embedding | session",
  "targetId": "string",
  "previousValue": {},             // JSON snapshot before change
  "newValue": {},                  // JSON snapshot after change
  "reason": "string",
  "ipAddress": "string",
  "deviceId": "string",
  "timestamp": "Timestamp"
}
```

### `/consent_records/{consentId}`
```json
{
  "id": "string",
  "studentId": "string",
  "collegeId": "string",
  "consentType": "biometric_enrollment | data_retention | data_sharing",
  "status": "granted | revoked",
  "language": "en",
  "consentText": "string",         // Full text shown to student
  "consentTextVersion": "v1.2",
  "grantedAt": "Timestamp | null",
  "revokedAt": "Timestamp | null",
  "revokedReason": "string | null",
  "ipAddress": "string",
  "deviceFingerprint": "string"
}
```

---

## SQLite Local Tables (Offline-First)

### `students`
```sql
CREATE TABLE students (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  roll_number TEXT NOT NULL,
  class_id TEXT NOT NULL,
  enrollment_status TEXT DEFAULT 'pending',
  biometric_consent INTEGER DEFAULT 0,  -- 0=no, 1=yes
  is_synced INTEGER DEFAULT 0,
  created_at INTEGER,  -- Unix timestamp
  updated_at INTEGER
);
CREATE INDEX idx_students_class ON students(class_id);
CREATE INDEX idx_students_roll ON students(roll_number);
```

### `embeddings`
```sql
CREATE TABLE embeddings (
  id TEXT PRIMARY KEY,
  student_id TEXT NOT NULL,
  encrypted_embedding BLOB NOT NULL,   -- AES-256-GCM encrypted
  embedding_index INTEGER,             -- 0-4 (up to 5 per student)
  angle TEXT,
  quality_score REAL,
  is_synced INTEGER DEFAULT 0,
  created_at INTEGER,
  FOREIGN KEY(student_id) REFERENCES students(id)
);
CREATE INDEX idx_embeddings_student ON embeddings(student_id);
```

### `attendance`
```sql
CREATE TABLE attendance (
  id TEXT PRIMARY KEY,
  session_id TEXT,
  student_id TEXT NOT NULL,
  class_id TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  teacher_id TEXT NOT NULL,
  date TEXT NOT NULL,          -- YYYY-MM-DD
  period INTEGER NOT NULL,
  status TEXT DEFAULT 'absent',
  marked_by TEXT,
  confidence REAL,
  liveness_score REAL,
  anti_spoof_score REAL,
  snapshot_path TEXT,          -- local encrypted file path
  override_reason TEXT,
  is_synced INTEGER DEFAULT 0,
  created_at INTEGER,
  updated_at INTEGER,
  FOREIGN KEY(student_id) REFERENCES students(id),
  UNIQUE(student_id, date, period)  -- prevent duplicate marking
);
CREATE INDEX idx_attendance_date ON attendance(date);
CREATE INDEX idx_attendance_session ON attendance(session_id);
```

### `sessions`
```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  class_id TEXT NOT NULL,
  subject_id TEXT NOT NULL,
  teacher_id TEXT NOT NULL,
  date TEXT NOT NULL,
  period INTEGER NOT NULL,
  start_time INTEGER,
  end_time INTEGER,
  present_count INTEGER DEFAULT 0,
  total_students INTEGER DEFAULT 0,
  status TEXT DEFAULT 'in_progress',
  is_synced INTEGER DEFAULT 0,
  created_at INTEGER
);
```

### `audit_log`
```sql
CREATE TABLE audit_log (
  id TEXT PRIMARY KEY,
  actor_id TEXT,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  previous_value TEXT,   -- JSON
  new_value TEXT,        -- JSON
  reason TEXT,
  timestamp INTEGER NOT NULL
);
```

### `sync_queue`
```sql
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  table_name TEXT NOT NULL,   -- which table to sync
  record_id TEXT NOT NULL,
  operation TEXT NOT NULL,    -- insert | update | delete
  payload TEXT NOT NULL,      -- JSON
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  created_at INTEGER
);
```

---

## Firestore Security Rules (Summary)

```javascript
// Teachers can only read/write their own classes
// HOD can read all data in their department
// Admin has full read/write
// Students have NO direct Firestore access
// Embeddings collection is write-once from app, read by auth users only
// audit_log is append-only (no updates, no deletes)
```

Full rules in `firestore.rules`.
