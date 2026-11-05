import 'dart:convert';

import 'app_store.dart';

/// A backup file: all the user's data as one JSON document.
/// `{"app":"one-tracker","format":1,"version":"1.4.2","exportedAt":"…","data":{key: value}}`
class Backup {
  const Backup({
    required this.data,
    required this.exportedAt,
    required this.version,
    required this.payments,
  });

  static const appId = 'one-tracker';
  static const format = 1;

  final Map<String, Object> data;
  final DateTime? exportedAt;
  final String? version;
  final int payments;

  static String fileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'one-tracker-backup-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  static String encode(
    Map<String, Object> data, {
    required String version,
    required DateTime now,
  }) => jsonEncode({
    'app': appId,
    'format': format,
    'version': version,
    'exportedAt': now.toIso8601String(),
    'data': data,
  });

  /// Reads and checks a file. Throws [BackupException] (friendly text) when
  /// it isn't a usable One Tracker backup; nothing is touched either way.
  static Backup parse(String raw) {
    final Object? doc;
    try {
      doc = jsonDecode(raw);
    } catch (_) {
      throw const BackupException("That file isn't a One Tracker backup.");
    }
    if (doc is! Map || doc['app'] != appId) {
      throw const BackupException("That file isn't a One Tracker backup.");
    }
    final fmt = doc['format'];
    if (fmt is! int || fmt > format) {
      throw const BackupException(
        'That backup is from a newer One Tracker. Update the app and try again.',
      );
    }
    final rawData = doc['data'];
    if (rawData is! Map) {
      throw const BackupException("That backup file is damaged.");
    }

    final data = <String, Object>{};
    try {
      for (final e in AppStore.backupKeys.entries) {
        final v = rawData[e.key];
        if (v == null) continue; // older backups may lack keys
        switch (e.value) {
          case BackupType.string:
            if (v is! String) {
              throw const FormatException();
            }
            jsonDecode(v); // must be valid JSON
            data[e.key] = v;
          case BackupType.int:
            if (v is! int) {
              throw const FormatException();
            }
            data[e.key] = v;
          case BackupType.list:
            if (v is! List || v.any((x) => x is! String)) {
              throw const FormatException();
            }
            data[e.key] = List<String>.from(v);
        }
      }
    } on FormatException {
      throw const BackupException('That backup file is damaged.');
    }

    var payments = 0;
    final txns = data['txns_v1'];
    if (txns is String) {
      final list = jsonDecode(txns);
      if (list is! List) {
        throw const BackupException('That backup file is damaged.');
      }
      payments = list.length;
    }
    final at = doc['exportedAt'];
    final ver = doc['version'];
    return Backup(
      data: data,
      exportedAt: at is String ? DateTime.tryParse(at) : null,
      version: ver is String ? ver : null,
      payments: payments,
    );
  }
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}
