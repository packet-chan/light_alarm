import 'dart:async';
import 'package:flutter/material.dart';
import 'package:light/light.dart'; // 光センサーのライブラリをインポート
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // アラーム音のライブラリをインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AlarmScreen());
  }
}

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  // --- 状態を管理する変数 ---
  String _statusText = "部屋を明るくしてアラームを止めてください！";
  int _lightLevel = 0; // 現在の明るさ（ルクス）
  bool _isAlarmPlaying = false; // アラームが鳴っているか
  StreamSubscription? _lightSubscription; // 光センサーの監視を管理

  // 明るさの基準値（この値を超えたらアラームが止まる）
  final int _brightnessThreshold = 400;

  @override
  void initState() {
    super.initState();
    // 画面が作成されたら、アラームを鳴らし、光センサーの監視を開始する
    startAlarm();
    startListeningToLightSensor();
  }

  @override
  void dispose() {
    // 画面が破棄されるときに、監視を停止してリソースを解放する
    stopListeningToLightSensor();
    super.dispose();
  }

  // アラームを鳴らし始める関数
  void startAlarm() {
    setState(() {
      _isAlarmPlaying = true;
    });
    // デフォルトのアラーム音をループ再生
    _ringtonePlayer.playAlarm(looping: true, asAlarm: true);
  }

  // アラームを止める関数
  void stopAlarm() {
    setState(() {
      _isAlarmPlaying = false;
      _statusText = "おはようございます！アラームは停止しました。";
    });
    _ringtonePlayer.stop();
  }

  // 光センサーの監視を開始する関数
  void startListeningToLightSensor() {
    try {
      // Lightセンサーからのデータの流れ（Stream）を監視開始
      _lightSubscription = Light().lightSensorStream.listen((int luxValue) {
        // 新しい明るさのデータが届くたびに、この部分が実行される
        setState(() {
          _lightLevel = luxValue;
        });

        // アラームが鳴っていて、明るさが基準値を超えたかチェック
        if (_isAlarmPlaying && luxValue > _brightnessThreshold) {
          // 条件を満たしたらアラームを止め、監視も停止する
          stopAlarm();
          stopListeningToLightSensor();
        }
      });
    } catch (e) {
      // センサーが利用できない場合などのエラー処理
      setState(() {
        _statusText = "光センサーを利用できませんでした。";
      });
    }
  }

  // 光センサーの監視を停止する関数
  void stopListeningToLightSensor() {
    _lightSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isAlarmPlaying ? Colors.red[100] : Colors.green[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 現在のステータスを表示
            Text(
              _statusText,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // 現在の明るさを表示
            Text(
              '現在の明るさ: $_lightLevel ルクス',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              '基準値: $_brightnessThreshold ルクス',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
