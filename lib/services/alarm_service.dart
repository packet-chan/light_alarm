// lib/services/alarm_service.dart

import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';

class AlarmService {
  static const String _debugLogKey = 'debug_log';

  static Future<void> addDebugLog(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_debugLogKey) ?? [];
    logs.add('${DateTime.now().toIso8601String()}: $message');

    if (logs.length > 50) {
      logs.removeRange(0, logs.length - 50);
    }

    await prefs.setStringList(_debugLogKey, logs);
    print('[AlarmService] $message');
  }

  static Future<List<String>> getDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_debugLogKey) ?? [];
  }

  static Future<void> clearDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_debugLogKey);
  }

  static Future<bool> scheduleAlarm(Alarm alarm) async {
    if (!alarm.isActive) {
      await addDebugLog('アラーム ${alarm.id} は非アクティブのためスケジュールをスキップ');
      return true; // スキップも成功とみなす
    }

    final nextTime = alarm.getNextAlarmTime();
    if (nextTime == null) {
      await addDebugLog('アラーム ${alarm.id} の次回実行時刻が計算できませんでした');
      return false;
    }

    final alarmId = _generateAlarmId(alarm.id);
    await addDebugLog('アラーム ${alarm.id} をスケジュール開始: $nextTime (ID: $alarmId)');

    try {
      final success = await AndroidAlarmManager.oneShotAt(
        nextTime,
        alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );

      if (success) {
        await addDebugLog('アラーム ${alarm.id} のスケジュールに成功: $nextTime');
        await _saveScheduledAlarm(alarmId, alarm, nextTime);
      } else {
        await addDebugLog('アラーム ${alarm.id} のスケジュールに失敗');
      }
      return success;
    } catch (e) {
      await addDebugLog('アラーム ${alarm.id} のスケジュールでエラー: $e');
      return false;
    }
  }

  static Future<bool> cancelAlarm(String alarmId) async {
    final intId = _generateAlarmId(alarmId);
    try {
      final success = await AndroidAlarmManager.cancel(intId);
      await addDebugLog('アラーム $alarmId ($intId) のキャンセル: ${success ? '成功' : '失敗'}');
      await _removeScheduledAlarm(intId);
      return success;
    } catch (e) {
      await addDebugLog('アラーム $alarmId ($intId) のキャンセルでエラー: $e');
      return false;
    }
  }

  static int _generateAlarmId(String alarmId) {
    return alarmId.hashCode.abs() % 2147483647;
  }

  static Future<void> _saveScheduledAlarm(
    int alarmId,
    Alarm alarm,
    DateTime scheduledTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledInfo = {
      'alarmId': alarmId,
      'originalId': alarm.id,
      'scheduledTime': scheduledTime.toIso8601String(),
      'label': alarm.label,
    };
    await prefs.setString('scheduled_$alarmId', jsonEncode(scheduledInfo));
  }

  static Future<void> _removeScheduledAlarm(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_$alarmId');
  }

  static Future<List<Map<String, dynamic>>> getScheduledAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('scheduled_'));
    final scheduledAlarms = <Map<String, dynamic>>[];
    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          scheduledAlarms.add(jsonDecode(jsonStr));
        } catch (e) {
          await addDebugLog('スケジュールアラーム情報の解析エラー: $e');
        }
      }
    }
    return scheduledAlarms;
  }
}

@pragma('vm:entry-point')
void _alarmCallback(int alarmId) async {
  print('[AlarmCallback] アラームコールバック実行: ID $alarmId, 時刻: ${DateTime.now()}');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('alarm_triggered', true);
  await prefs.setString('triggered_alarm_id', alarmId.toString());
  print('[AlarmCallback] 置き手紙を設定完了');
}