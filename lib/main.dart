import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/screens/alarm_list_screen.dart'; // 作成したファイルをインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // アプリの最初の画面を AlarmListScreen に設定
      home: AlarmListScreen(),
    );
  }
}
