// lib/screens/light_alarm_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:light/light.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:light_alarm_prototype/screens/conversation_screen.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();

  String _statusText = "部屋を明るくしてアラームを止めてください！";
  int _lightLevel = 0;
  bool _isAlarmPlaying = false;
  StreamSubscription? _lightSubscription;
  Timer? _pulseTimer;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  final int _brightnessThreshold = 400;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAlarm();
    _startListeningToLightSensor();
    _startTimer();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  void _startTimer() {
    _pulseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isAlarmPlaying) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _stopListeningToLightSensor();
    _pulseTimer?.cancel();
    _ringtonePlayer.stop();
    super.dispose();
  }

  void _startAlarm() {
    setState(() {
      _isAlarmPlaying = true;
      _secondsElapsed = 0;
    });
    _ringtonePlayer.playAlarm(looping: true, asAlarm: true);
  }

  void _stopAlarm() {
    setState(() {
      _isAlarmPlaying = false;
      _statusText = "おはようございます！アラームは停止しました。";
    });

    _pulseController.stop();
    _waveController.stop();
    _pulseTimer?.cancel();
    _ringtonePlayer.stop();

    // 3秒後に自動で画面を閉じる
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // 現在の画面を置き換える形で遷移する (戻るボタンで戻れないように)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ConversationScreen()),
        );
      }
    });
  }

  void _startListeningToLightSensor() {
    try {
      _lightSubscription = Light().lightSensorStream.listen((int luxValue) {
        if (mounted) {
          setState(() {
            _lightLevel = luxValue;
          });

          if (_isAlarmPlaying && luxValue > _brightnessThreshold) {
            _stopAlarm();
            _stopListeningToLightSensor();
          }
        }
      });
    } catch (e) {
      setState(() {
        _statusText = "光センサーを利用できませんでした。\n手動でアラームを停止してください。";
      });
    }
  }

  void _stopListeningToLightSensor() {
    _lightSubscription?.cancel();
  }

  void _snoozeAlarm() {
    _ringtonePlayer.stop();
    setState(() {
      _statusText = "5分後にスヌーズします";
      _isAlarmPlaying = false;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _manualStop() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アラームを停止'),
        content: const Text('光センサーを使わずにアラームを停止しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopAlarm();
            },
            child: const Text('停止'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isAlarmActive = _isAlarmPlaying;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isAlarmActive
                ? [Colors.red[400]!, Colors.red[600]!, Colors.red[800]!]
                : [Colors.green[300]!, Colors.green[500]!, Colors.green[700]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー部分
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      TimeOfDay.now().format(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (isAlarmActive)
                      Text(
                        _formatDuration(_secondsElapsed),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),

              // メイン表示エリア
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // アニメーション付きアイコン
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: isAlarmActive ? _pulseAnimation.value : 1.0,
                            child: AnimatedBuilder(
                              animation: _waveAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    boxShadow: isAlarmActive
                                        ? [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius:
                                                  20 +
                                                  sin(_waveAnimation.value) *
                                                      10,
                                              spreadRadius: 5,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    isAlarmActive
                                        ? Icons.wb_sunny
                                        : Icons.check_circle,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      // ステータステキスト
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 光センサー情報
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '現在の明るさ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '$_lightLevel lux',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: (_lightLevel / _brightnessThreshold).clamp(
                                0.0,
                                1.0,
                              ),
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _lightLevel >= _brightnessThreshold
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '目標: $_brightnessThreshold lux',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ボタンエリア
              if (isAlarmActive)
                Container(
                  padding: const EdgeInsets.all(30),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _snoozeAlarm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: const Text(
                            'スヌーズ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _manualStop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '停止',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
