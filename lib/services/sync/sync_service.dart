import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../local/database/local_database.dart';

/// Offline-first sync engine.
/// Watches connectivity and drains the sync queue when online.
/// All writes go through local DB first, then queued for Firebase.
class SyncService {
  final LocalDatabase _localDb;
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  final Logger _log = Logger();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  Timer? _retryTimer;

  SyncService({
    required LocalDatabase localDb,
    required FirebaseFirestore firestore,
    required Connectivity connectivity,
  })  : _localDb = localDb,
        _firestore = firestore,
        _connectivity = connectivity;

  // ─── Start Listening ──────────────────────────────────────────────────────

  void startListening() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final isOnline = results.any(
          (r) =>
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.ethernet,
        );

        if (isOnline) {
          _log.i('Back online — starting sync');
          await _syncAll();
        }
      },
    );

    // Also try sync every 5 minutes as a heartbeat
    _retryTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _syncAll(),
    );
  }

  // ─── Sync Queue Drain ─────────────────────────────────────────────────────

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final items = await _localDb.getPendingSyncItems(limit: 100);
      if (items.isEmpty) {
        _isSyncing = false;
        return;
      }

      _log.i('Syncing ${items.length} pending items');

      for (final item in items) {
        await _syncItem(item);
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final tableName = item['table_name'] as String;
    final operation = item['operation'] as String;
    final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;

    try {
      final collection = _tableToCollection(tableName);
      final docRef = _firestore.collection(collection).doc(payload['id'] as String);

      switch (operation) {
        case 'insert':
        case 'update':
          await docRef.set(payload, SetOptions(merge: true));
        case 'delete':
          await docRef.delete();
      }

      // Mark local record as synced
      await _markLocalAsSynced(tableName, payload['id'] as String);

      // Remove from sync queue
      await _localDb.removeSyncItem(id);
      _log.d('Synced: $tableName/${payload['id']} ($operation)');
    } catch (e) {
      _log.e('Sync failed for $id: $e');
      await _localDb.incrementSyncRetry(id, e.toString());
    }
  }

  Future<void> _markLocalAsSynced(String tableName, String recordId) async {
    final db = await _localDb.database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [recordId],
    );
  }

  String _tableToCollection(String tableName) {
    switch (tableName) {
      case 'attendance':
        return AppConstants.colAttendance;
      case 'sessions':
        return AppConstants.colSessions;
      case 'students':
        return AppConstants.colStudents;
      case 'embeddings':
        return AppConstants.colEmbeddings;
      case 'audit_log':
        return AppConstants.colAuditLog;
      default:
        return tableName;
    }
  }

  // ─── Enqueue Write ────────────────────────────────────────────────────────

  /// Add a local write to the sync queue for later Firebase sync.
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final queueItem = {
      'id': '${tableName}_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    await _localDb.addToSyncQueue(queueItem);

    // Try immediate sync if online
    final result = await _connectivity.checkConnectivity();
    final isOnline = result.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile,
    );
    if (isOnline) {
      unawaited(_syncAll());
    }
  }

  // ─── Pull from Firebase (Initial Sync) ───────────────────────────────────

  /// Download student roster from Firestore when first setting up offline.
  Future<void> pullStudentsForClass(String classId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.colStudents)
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        await _localDb.upsertStudent({
          'id': data['id'],
          'name': data['name'],
          'roll_number': data['rollNumber'],
          'class_id': data['classId'],
          'college_id': data['collegeId'],
          'department_id': data['departmentId'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'semester': data['semester'] ?? 1,
          'academic_year': data['academicYear'] ?? '',
          'biometric_consent': (data['biometricConsent'] as bool? ?? false) ? 1 : 0,
          'enrollment_status': data['enrollmentStatus'] ?? 'pending',
          'is_active': 1,
          'is_synced': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      _log.i('Pulled ${snap.docs.length} students for class $classId');
    } catch (e) {
      _log.e('Failed to pull students: $e');
    }
  }

  Future<int> get pendingCount => _localDb.getUnsyncedCount();

  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
  }
}
