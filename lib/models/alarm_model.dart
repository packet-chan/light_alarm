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

    if (!isRepeating || weekdays.every((d) => !d)) {
      // 繰り返しがオフ、または曜日が一つも選択されていない場合
      return today.isAfter(now) ? today : today.add(const Duration(days: 1));
    }

    // 繰り返しアラームの場合
    for (int i = 0; i < 8; i++) {
      final checkDate = now.add(Duration(days: i));
      // DateTime.weekdayは 月曜日:1, ..., 日曜日:7
      final weekdayIndex = checkDate.weekday - 1; // 0:月, ..., 6:日

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
    if (!isRepeating || weekdays.every((d) => !d)) return '一回のみ';

    final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
    final selectedDays = <String>[];

    for (int i = 0; i < weekdays.length; i++) {
      if (weekdays[i]) {
        selectedDays.add(weekdayNames[i]);
      }
    }

    if (selectedDays.isEmpty) return '一回のみ';
    if (selectedDays.length == 7) return '毎日';
    if (selectedDays.length == 2 && selectedDays.contains('土') && selectedDays.contains('日')) return '週末';
    if (selectedDays.length == 5 && !selectedDays.contains('土') && !selectedDays.contains('日')) return '平日';

    return selectedDays.join(', ');
  }
}