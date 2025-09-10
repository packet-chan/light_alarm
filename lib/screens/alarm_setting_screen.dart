// lib/screens/alarm_setting_screen.dart

import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';

class AlarmSettingScreen extends StatefulWidget {
  const AlarmSettingScreen({super.key});

  @override
  State<AlarmSettingScreen> createState() => _AlarmSettingScreenState();
}

class _AlarmSettingScreenState extends State<AlarmSettingScreen> {
  TimeOfDay? _selectedTime;

  // タイムピッカーを表示して時間を選択させる関数
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // アラームを保存して前の画面に戻る関数
  void _saveAlarm() {
    if (_selectedTime != null) {
      final newAlarm = Alarm(
        // IDは現在時刻を使って仮作成
        id: DateTime.now().toIso8601String(),
        time: _selectedTime!,
      );
      // `pop`を使って、前の画面に新しいアラーム情報を渡す
      Navigator.pop(context, newAlarm);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラーム設定'),
        actions: [
          // 保存ボタン
          IconButton(icon: const Icon(Icons.save), onPressed: _saveAlarm),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _selectedTime == null
                  ? '時間を設定してください'
                  : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectTime(context),
              child: const Text('時間を選択'),
            ),
          ],
        ),
      ),
    );
  }
}
