// lib/models/alarm_model.dart

import 'package:flutter/material.dart';

class Alarm {
  final String id; // アラームを識別するための一意なID
  TimeOfDay time; // 時刻
  bool isActive; // オンかオフか

  Alarm({required this.id, required this.time, this.isActive = true});
}
