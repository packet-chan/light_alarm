// lib/screens/alarm_list_screen.dart

import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';
import 'package:light_alarm_prototype/screens/alarm_setting_screen.dart';
import 'package:light_alarm_prototype/screens/light_alarm_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  // アラームのリストを管理する
  final List<Alarm> _alarms = [];

  // アラーム設定画面に遷移し、結果を受け取る関数
  void _navigateAndGetAlarm(BuildContext context) async {
    // 設定画面から新しいアラーム情報を受け取る
    final newAlarm = await Navigator.push<Alarm>(
      context,
      MaterialPageRoute(builder: (context) => const AlarmSettingScreen()),
    );

    // 新しいアラームが保存された場合
    if (newAlarm != null) {
      setState(() {
        _alarms.add(newAlarm);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アラーム一覧')),
      body: _alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('アラームが設定されていません'),
                  const SizedBox(height: 20),
                  // 光センサー画面をテストするためのボタン
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AlarmScreen(),
                        ),
                      );
                    },
                    child: const Text('光センサー画面をテスト'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _alarms.length,
              itemBuilder: (context, index) {
                final alarm = _alarms[index];
                return ListTile(
                  title: Text(
                    '${alarm.time.hour}:${alarm.time.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (value) {
                      setState(() {
                        alarm.isActive = value;
                      });
                    },
                  ),
                );
              },
            ),
      // 新しいアラームを追加するためのフローティングボタン
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateAndGetAlarm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
