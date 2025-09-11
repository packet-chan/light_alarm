// lib/main.dart
import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/screens/alarm_list_screen.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:light_alarm_prototype/services/alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // AlarmManagerを初期化
    final initialized = await AndroidAlarmManager.initialize();
    await AlarmService.addDebugLog(
      'AlarmManager初期化: ${initialized ? '成功' : '失敗'}',
    );

    if (!initialized) {
      await AlarmService.addDebugLog('⚠️ AlarmManagerの初期化に失敗しました');
    }
  } catch (e) {
    await AlarmService.addDebugLog('AlarmManager初期化エラー: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Light Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AlarmListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}