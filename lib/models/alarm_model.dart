// lib/models/alarm_model.dart

import 'package:flutter/material.dart';

class Alarm {
  final String id;
  TimeOfDay time;
  bool isActive;
  String label; // アラームのラベル
  List<bool> weekdays; // 0:月曜日 〜 6:日曜日
  bool isRepeating; // 繰り返しアラームかどうか

  Alarm({
    required this.id,
    required this.time,
    this.isActive = true,
    this.label = 'アラーム',
    List<bool>? weekdays,
    this.isRepeating = false,
  }) : weekdays = weekdays ?? List.filled(7, false);

  // JSONからAlarmオブジェクトを作成
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      isActive: json['isActive'] ?? true,
      label: json['label'] ?? 'アラーム',
      weekdays: List<bool>.from(json['weekdays'] ?? List.filled(7, false)),
      isRepeating: json['isRepeating'] ?? false,
    );
  }

  // AlarmオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'isActive': isActive,
      'label': label,
      'weekdays': weekdays,
      'isRepeating': isRepeating,
    };
  }

  // 次にアラームが鳴る日時を計算
  DateTime? getNextAlarmTime() {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!isRepeating) {
      // 一度きりのアラーム
      return today.isAfter(now) ? today : today.add(const Duration(days: 1));
    }

    // 繰り返しアラームの場合
    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final weekdayIndex = (checkDate.weekday - 1) % 7; // 月曜日を0に調整

      if (weekdays[weekdayIndex]) {
        final alarmTime = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          time.hour,
          time.minute,
        );

        if (alarmTime.isAfter(now)) {
          return alarmTime;
        }
      }
    }
    return null;
  }

  // 選択された曜日の文字列表現を取得
  String getWeekdaysString() {
    if (!isRepeating) return '一回のみ';

    final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
    final selectedDays = <String>[];

    for (int i = 0; i < weekdays.length; i++) {
      if (weekdays[i]) {
        selectedDays.add(weekdayNames[i]);
      }
    }

    if (selectedDays.isEmpty) return '設定なし';
    if (selectedDays.length == 7) return '毎日';

    return selectedDays.join(', ');
  }
}
