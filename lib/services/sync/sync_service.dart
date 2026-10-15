// Stub — sync service uses SQLite, Android only
import 'package:flutter/foundation.dart';

class SyncService {
  SyncService();
  void startListening() {}
  void stopListening() {}
  Future<int> get pendingCount async => 0;
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {}
  bool get isAvailable => !kIsWeb;
}
