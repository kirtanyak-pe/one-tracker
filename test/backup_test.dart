import 'dart:convert';

import 'package:auto_split/storage/app_store.dart';
import 'package:auto_split/storage/backup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  Future<Map<String, Object?>> everything() async {
    final prefs = SharedPreferencesAsync();
    final keys = await prefs.getKeys();
    return {
      for (final k in keys) k: (await prefs.getAll(allowList: {k}))[k],
    };
  }

  Future<void> fill() async {
    final p = SharedPreferencesAsync();
    await p.setString(
      'txns_v1',
      jsonEncode([
        {'id': 'a'},
        {'id': 'b'},
      ]),
    );
    await p.setString('rules_v1', jsonEncode([]));
    await p.setString('profile_v1', jsonEncode({'name': 'Asha'}));
    await p.setInt('last_sms_scan', 1700000000000);
    await p.setString('auto_rules_v1', jsonEncode([]));
    await p.setString('budgets_v1', jsonEncode({}));
    await p.setStringList('sent_alerts_v1', ['x', 'y']);
    await p.setStringList('month_nudge_dismissed_v1', ['2026-10']);
    await p.setString('split_records_v1', jsonEncode([]));
    await p.setStringList('split_skipped_v1', ['a']);
    await p.setString('split_settings_v1', jsonEncode({}));
    await p.setString('appearance_v1', jsonEncode({}));
    await p.setInt('parser_version', 7);
  }

  test('export then import restores identical store contents', () async {
    await fill();
    final store = AppStore();
    final before = await everything();
    final file = Backup.encode(
      await store.readBackupData(),
      version: '1.4.2',
      now: DateTime(2026, 11, 5),
    );

    await SharedPreferencesAsync().clear();
    expect(await everything(), isEmpty);

    final backup = Backup.parse(file);
    expect(backup.payments, 2);
    expect(backup.version, '1.4.2');
    await store.writeBackupData(backup.data);
    expect(await everything(), before);
  });

  test('file name is dated', () {
    expect(
      Backup.fileName(DateTime(2026, 11, 5)),
      'one-tracker-backup-2026-11-05.json',
    );
  });

  test('restore replaces what was there, even keys the backup lacks', () async {
    final store = AppStore();
    await SharedPreferencesAsync().setStringList('sent_alerts_v1', ['old']);
    await SharedPreferencesAsync().setString('budgets_v1', '{"old":1}');
    final file = jsonEncode({
      'app': 'one-tracker',
      'format': 1,
      'data': {'txns_v1': '[]'}, // an older backup: most keys missing
    });
    await store.writeBackupData(Backup.parse(file).data);
    final now = await everything();
    expect(now, {'txns_v1': '[]'});
  });

  test('foreign or garbled files are rejected and nothing changes', () async {
    await fill();
    final before = await everything();
    final bad = [
      'not json at all',
      '[]',
      jsonEncode({'app': 'other', 'format': 1, 'data': {}}),
      jsonEncode({'app': 'one-tracker', 'format': 99, 'data': {}}),
      jsonEncode({'app': 'one-tracker', 'format': 1}),
      jsonEncode({
        'app': 'one-tracker',
        'format': 1,
        'data': {'txns_v1': 5},
      }),
      jsonEncode({
        'app': 'one-tracker',
        'format': 1,
        'data': {'txns_v1': '{broken'},
      }),
      jsonEncode({
        'app': 'one-tracker',
        'format': 1,
        'data': {
          'sent_alerts_v1': [1, 2],
        },
      }),
      jsonEncode({
        'app': 'one-tracker',
        'format': 1,
        'data': {'parser_version': 'x'},
      }),
    ];
    for (final raw in bad) {
      expect(
        () => Backup.parse(raw),
        throwsA(isA<BackupException>()),
        reason: raw,
      );
    }
    expect(await everything(), before);
  });
}
