// lib/services/alarm_service.dart (更新版)

import 'dart:convert';
import 'dart:isolate';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';
import 'package:flutter/services.dart';

class AlarmService {
  static const String _alarmsKey = 'alarms';
  static const String _debugLogKey = 'debug_log';
  static const MethodChannel _channel = MethodChannel('alarm_service');

  // アプリを前面に持ってくるためのネイティブメソッド
  static Future<void> bringAppToForeground() async {
    try {
      await _channel.invokeMethod('bringToForeground');
    } catch (e) {
      await addDebugLog('アプリ前面表示エラー: $e');
    }
  }

  // 通知を表示
  static Future<void> showAlarmNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'autoCancel': false,
        'ongoing': true,
      });
    } catch (e) {
      await addDebugLog('通知表示エラー: $e');
    }
  }

  // 通知をキャンセル
  static Future<void> cancelAlarmNotification() async {
    try {
      await _channel.invokeMethod('cancelNotification');
    } catch (e) {
      await addDebugLog('通知キャンセルエラー: $e');
    }
  }

  // デバッグ用のログを追加
  static Future<void> addDebugLog(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_debugLogKey) ?? [];
    logs.add('${DateTime.now().toIso8601String()}: $message');

    // 最新の50件のログのみを保持
    if (logs.length > 50) {
      logs.removeRange(0, logs.length - 50);
    }

    await prefs.setStringList(_debugLogKey, logs);
    print('[AlarmService] $message');
  }

  // デバッグログを取得
  static Future<List<String>> getDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_debugLogKey) ?? [];
  }

  // デバッグログをクリア
  static Future<void> clearDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_debugLogKey);
  }

  // アラームをスケジュールする
  static Future<bool> scheduleAlarm(Alarm alarm) async {
    if (!alarm.isActive) {
      await addDebugLog('アラーム ${alarm.id} は非アクティブのためスケジュールをスキップ');
      return false;
    }

    final nextTime = alarm.getNextAlarmTime();
    if (nextTime == null) {
      await addDebugLog('アラーム ${alarm.id} の次回実行時刻が計算できませんでした');
      return false;
    }

    // アラームIDを生成（より安全な方法）
    final alarmId = _generateAlarmId(alarm.id);

    await addDebugLog('アラーム ${alarm.id} をスケジュール開始: $nextTime (ID: $alarmId)');

    try {
      // 既存のアラームをキャンセル
      await AndroidAlarmManager.cancel(alarmId);
      await addDebugLog('既存のアラーム $alarmId をキャンセル');

      // 新しいアラームをスケジュール
      final success = await AndroidAlarmManager.oneShotAt(
        nextTime,
        alarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true, // 追加: Doze modeでも実行
      );

      if (success) {
        await addDebugLog('アラーム ${alarm.id} のスケジュールに成功: $nextTime');

        // スケジュールされたアラーム情報を保存
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

  // アラームをキャンセルする
  static Future<bool> cancelAlarm(String alarmId) async {
    final intId = _generateAlarmId(alarmId);

    try {
      final success = await AndroidAlarmManager.cancel(intId);
      await addDebugLog('アラーム $alarmId のキャンセル: ${success ? '成功' : '失敗'}');

      // スケジュール情報を削除
      await _removeScheduledAlarm(intId);

      return success;
    } catch (e) {
      await addDebugLog('アラーム $alarmId のキャンセルでエラー: $e');
      return false;
    }
  }

  // より安全なID生成
  static int _generateAlarmId(String alarmId) {
    final hashCode = alarmId.hashCode.abs();
    return (hashCode % 2000000000) + 1000000000;
  }

  // スケジュールされたアラーム情報を保存
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

  // スケジュールされたアラーム情報を削除
  static Future<void> _removeScheduledAlarm(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scheduled_$alarmId');
  }

  // スケジュールされたアラーム一覧を取得
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

// アラームコールバック関数（isolateで実行される）
@pragma('vm:entry-point')
void alarmCallback(int alarmId) async {
  print('[AlarmCallback] アラームコールバック実行: ID $alarmId, 時刻: ${DateTime.now()}');

  try {
    final prefs = await SharedPreferences.getInstance();

    // デバッグログに記録
    final logs = prefs.getStringList('debug_log') ?? [];
    logs.add('${DateTime.now().toIso8601String()}: アラームコールバック実行 ID:$alarmId');
    await prefs.setStringList('debug_log', logs);

    // アラーム情報を取得
    String alarmLabel = 'アラーム';
    final scheduledInfo = prefs.getString('scheduled_$alarmId');
    if (scheduledInfo != null) {
      final info = jsonDecode(scheduledInfo);
      alarmLabel = info['label'] ?? 'アラーム';
      print(
        '[AlarmCallback] 実行されたアラーム: $alarmLabel (${info['scheduledTime']})',
      );
    }

    // 「置き手紙」を残す
    await prefs.setBool('alarm_triggered', true);
    await prefs.setString('triggered_alarm_id', alarmId.toString());
    await prefs.setString('triggered_alarm_label', alarmLabel);

    // アプリを前面に持ってくる + 通知を表示
    try {
      // MethodChannelを使ってネイティブ側でアプリを起動
      const MethodChannel(
        'alarm_service',
      ).invokeMethod('launchAlarm', {'alarmId': alarmId, 'label': alarmLabel});
    } catch (e) {
      print('[AlarmCallback] アプリ起動エラー: $e');
      // フォールバック: 通知のみ表示
      const MethodChannel('alarm_service').invokeMethod('showNotification', {
        'title': 'アラーム: $alarmLabel',
        'body': 'タップしてアラームを停止してください',
        'autoCancel': false,
        'ongoing': true,
      });
    }

    print('[AlarmCallback] 置き手紙を設定完了');
  } catch (e) {
    print('[AlarmCallback] エラー: $e');
  }
}
