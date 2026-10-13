import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

import '../../../core/constants/app_constants.dart';

/// SQLite local database for offline-first operation.
/// Sensitive data (embeddings) stored encrypted.
class LocalDatabase {
  static LocalDatabase? _instance;
  Database? _database;
  final Logger _log = Logger();

  LocalDatabase._();
  factory LocalDatabase() => _instance ??= LocalDatabase._();

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<void> initialize() async {
    _database = await _initDB();
    _log.i('LocalDatabase initialized');
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable WAL mode for concurrent reads
        await db.execute('PRAGMA journal_mode=WAL');
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys=ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        roll_number TEXT NOT NULL,
        class_id TEXT NOT NULL,
        college_id TEXT NOT NULL,
        department_id TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        semester INTEGER DEFAULT 1,
        academic_year TEXT,
        biometric_consent INTEGER DEFAULT 0,
        consent_timestamp INTEGER,
        enrollment_status TEXT DEFAULT 'pending',
        enrolled_at INTEGER,
        is_active INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_students_class ON students(class_id)',
    );
    await db.execute(
      'CREATE INDEX idx_students_roll ON students(roll_number)',
    );

    await db.execute('''
      CREATE TABLE embeddings (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        encrypted_embedding TEXT NOT NULL,
        embedding_index INTEGER NOT NULL,
        angle TEXT,
        quality_score REAL,
        embedding_version TEXT DEFAULT 'mobilefacenet_v1',
        is_active INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_embeddings_student ON embeddings(student_id)',
    );

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        date TEXT NOT NULL,
        period INTEGER NOT NULL,
        start_time INTEGER,
        end_time INTEGER,
        scan_duration_seconds INTEGER DEFAULT 0,
        total_students INTEGER DEFAULT 0,
        present_count INTEGER DEFAULT 0,
        absent_count INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'in_progress',
        submitted_at INTEGER,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        teacher_id TEXT NOT NULL,
        date TEXT NOT NULL,
        period INTEGER NOT NULL,
        status TEXT DEFAULT 'absent',
        marked_by TEXT,
        confidence REAL,
        liveness_score REAL,
        anti_spoof_score REAL,
        frame_quality_score REAL,
        snapshot_path TEXT,
        override_reason TEXT,
        overridden_by TEXT,
        edit_window_expires_at INTEGER,
        is_synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY(student_id) REFERENCES students(id),
        UNIQUE(student_id, date, period)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_attendance_date ON attendance(date)',
    );
    await db.execute(
      'CREATE INDEX idx_attendance_session ON attendance(session_id)',
    );
    await db.execute(
      'CREATE INDEX idx_attendance_student ON attendance(student_id)',
    );

    await db.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        actor_id TEXT,
        actor_role TEXT,
        action TEXT NOT NULL,
        target_type TEXT,
        target_id TEXT,
        previous_value TEXT,
        new_value TEXT,
        reason TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    _log.i('SQLite tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
    _log.i('DB upgrade from $oldVersion to $newVersion');
  }

  // ─── Student Operations ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStudentsByClass(String classId) async {
    final db = await database;
    return db.query(
      'students',
      where: 'class_id = ? AND is_active = 1',
      whereArgs: [classId],
      orderBy: 'roll_number ASC',
    );
  }

  Future<Map<String, dynamic>?> getStudentById(String id) async {
    final db = await database;
    final results = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isEmpty ? null : results.first;
  }

  Future<void> upsertStudent(Map<String, dynamic> student) async {
    final db = await database;
    await db.insert(
      'students',
      student,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStudentSyncStatus(String id, bool synced) async {
    final db = await database;
    await db.update(
      'students',
      {'is_synced': synced ? 1 : 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Embedding Operations ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEmbeddingsByStudent(
    String studentId,
  ) async {
    final db = await database;
    return db.query(
      'embeddings',
      where: 'student_id = ? AND is_active = 1',
      whereArgs: [studentId],
      orderBy: 'embedding_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllActiveEmbeddings() async {
    final db = await database;
    // Join with students to filter by active enrolled students
    return db.rawQuery('''
      SELECT e.*, s.name as student_name, s.roll_number
      FROM embeddings e
      JOIN students s ON e.student_id = s.id
      WHERE e.is_active = 1 AND s.is_active = 1
        AND s.enrollment_status = 'enrolled'
        AND s.biometric_consent = 1
    ''');
  }

  Future<void> insertEmbedding(Map<String, dynamic> embedding) async {
    final db = await database;
    await db.insert(
      'embeddings',
      embedding,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deactivateStudentEmbeddings(String studentId) async {
    final db = await database;
    await db.update(
      'embeddings',
      {'is_active': 0},
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  // ─── Session Operations ───────────────────────────────────────────────────

  Future<String?> createSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert('sessions', session);
    return session['id'] as String;
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return results.isEmpty ? null : results.first;
  }

  Future<void> updateSession(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'sessions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Attendance Operations ────────────────────────────────────────────────

  Future<void> upsertAttendance(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert(
      'attendance',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAttendanceBySession(
    String sessionId,
  ) async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.*, s.name as student_name, s.roll_number
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      WHERE a.session_id = ?
      ORDER BY s.roll_number ASC
    ''', [sessionId]);
  }

  Future<List<Map<String, dynamic>>> getStudentAttendance(
    String studentId, {
    String? startDate,
    String? endDate,
    String? subjectId,
  }) async {
    final db = await database;
    final where = StringBuffer('student_id = ?');
    final args = <dynamic>[studentId];

    if (startDate != null) {
      where.write(' AND date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      where.write(' AND date <= ?');
      args.add(endDate);
    }
    if (subjectId != null) {
      where.write(' AND subject_id = ?');
      args.add(subjectId);
    }

    return db.query(
      'attendance',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'date DESC',
    );
  }

  Future<Map<String, dynamic>> getAttendanceSummary(
    String studentId,
    String subjectId,
  ) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN status = 'present' OR status = 'manual' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent
      FROM attendance
      WHERE student_id = ? AND subject_id = ?
    ''', [studentId, subjectId]);

    return result.first;
  }

  // ─── Audit Log ────────────────────────────────────────────────────────────

  Future<void> insertAuditLog(Map<String, dynamic> log) async {
    final db = await database;
    await db.insert('audit_log', log);
  }

  // ─── Sync Queue ───────────────────────────────────────────────────────────

  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 50}) async {
    final db = await database;
    return db.query(
      'sync_queue',
      where: 'retry_count < ?',
      whereArgs: [AppConstants.maxSyncRetries],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> removeSyncItem(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncRetry(String id, String error) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE sync_queue 
      SET retry_count = retry_count + 1, last_error = ?
      WHERE id = ?
    ''', [error, id]);
  }

  // ─── Unsynced Count ───────────────────────────────────────────────────────

  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE retry_count < ?',
      [AppConstants.maxSyncRetries],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
