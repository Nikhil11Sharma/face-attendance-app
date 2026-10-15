// Stub — SQLite local DB runs on Android only
import 'package:flutter/foundation.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._();
  LocalDatabase._();
  factory LocalDatabase() => _instance;

  Future<void> initialize() async {}
  Future<void> close() async {}
  bool get isAvailable => !kIsWeb;

  Future<void> insertAuditLog(Map<String, dynamic> entry) async {}

  Future<Map<String, dynamic>?> getSession(String sessionId) async => null;

  Future<List<Map<String, dynamic>>> getStudentsByClass(String classId) async =>
      [];

  Future<void> upsertAttendance(Map<String, dynamic> record) async {}

  Future<void> updateSession(
    String sessionId,
    Map<String, dynamic> data,
  ) async {}

  Future<List<Map<String, dynamic>>> getEmbeddingsByStudent(
    String studentId,
  ) async => [];

  Future<void> upsertEmbedding(Map<String, dynamic> record) async {}
}
