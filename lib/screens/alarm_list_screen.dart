// lib/screens/alarm_list_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';
import 'package:light_alarm_prototype/screens/alarm_setting_screen.dart';
import 'package:light_alarm_prototype/screens/light_alarm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:light_alarm_prototype/services/alarm_service.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  final List<Alarm> _alarms = [];
  Timer? _timer;
  int _headerTapCount = 0;
  Timer? _tapResetTimer;

  @override
  void initState() {
    super.initState();
    _loadAlarms();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkAlarmTrigger();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  // アラームデータの読み込み
  Future<void> _loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = prefs.getStringList('alarms') ?? [];

    setState(() {
      _alarms.clear();
      _alarms.addAll(
        alarmStrings
            .map((alarmString) => Alarm.fromJson(jsonDecode(alarmString)))
            .toList(),
      );
    });
  }

  // アラームデータの保存
  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = _alarms
        .map((alarm) => jsonEncode(alarm.toJson()))
        .toList();

    await prefs.setStringList('alarms', alarmStrings);
  }

  // アラームのスケジュール設定
  Future<void> _scheduleAlarm(Alarm alarm) async {
    final success = await AlarmService.scheduleAlarm(alarm);
    if (!success) {
      // ユーザーへの通知はしない（ハッカソン仕様）
      print('アラームの設定に失敗しました');
    }
  }

  // アラームのキャンセル
  Future<void> _cancelAlarm(Alarm alarm) async {
    await AlarmService.cancelAlarm(alarm.id);
  }

  void _checkAlarmTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    final isAlarmTriggered = prefs.getBool('alarm_triggered') ?? false;

    if (isAlarmTriggered) {
      await prefs.setBool('alarm_triggered', false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AlarmScreen()),
        );
      }
    }
  }

  Future<void> _navigateToAlarmSetting([Alarm? alarm]) async {
    final result = await Navigator.push<Alarm>(
      context,
      MaterialPageRoute(builder: (context) => AlarmSettingScreen(alarm: alarm)),
    );

    if (result != null) {
      setState(() {
        if (alarm == null) {
          // 新規追加
          _alarms.add(result);
        } else {
          // 編集
          final index = _alarms.indexWhere((a) => a.id == alarm.id);
          if (index != -1) {
            _alarms[index] = result;
          }
        }
      });

      await _saveAlarms();
      await _scheduleAlarm(result);
    }
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    await _cancelAlarm(alarm);

    setState(() {
      _alarms.remove(alarm);
    });

    await _saveAlarms();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('アラームを削除しました'),
          action: SnackBarAction(
            label: '元に戻す',
            onPressed: () async {
              setState(() {
                _alarms.add(alarm);
              });
              await _saveAlarms();
              if (alarm.isActive) {
                await _scheduleAlarm(alarm);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _toggleAlarm(Alarm alarm) async {
    setState(() {
      alarm.isActive = !alarm.isActive;
    });

    if (alarm.isActive) {
      await _scheduleAlarm(alarm);
    } else {
      await _cancelAlarm(alarm);
    }

    await _saveAlarms();
  }

  // 隠しコマンド: ヘッダーを3回タップで光アラーム画面に遷移
  void _onHeaderTap() {
    _headerTapCount++;
    _tapResetTimer?.cancel();

    if (_headerTapCount >= 3) {
      _headerTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AlarmScreen()),
      );
    } else {
      _tapResetTimer = Timer(const Duration(seconds: 2), () {
        _headerTapCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onHeaderTap,
          child: const Text(
            'アラーム',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      body: _alarms.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alarms.length,
              itemBuilder: (context, index) => _buildAlarmCard(_alarms[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAlarmSetting(),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.alarm, size: 60, color: Colors.blue[300]),
          ),
          const SizedBox(height: 24),
          Text(
            'アラームがありません',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '右下の追加ボタンから\n新しいアラームを作成できます',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(Alarm alarm) {
    final nextAlarmTime = alarm.getNextAlarmTime();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToAlarmSetting(alarm),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: alarm.isActive
                                    ? Colors.black87
                                    : Colors.grey[400],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alarm.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: alarm.isActive
                                    ? Colors.grey[700]
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: alarm.isActive,
                    onChanged: (_) => _toggleAlarm(alarm),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _navigateToAlarmSetting(alarm);
                          break;
                        case 'delete':
                          _showDeleteDialog(alarm);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 12),
                            Text('編集'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('削除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: alarm.isActive
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      alarm.getWeekdaysString(),
                      style: TextStyle(
                        color: alarm.isActive
                            ? Colors.blue[700]
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (alarm.isActive && nextAlarmTime != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getTimeUntilAlarm(nextAlarmTime),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeUntilAlarm(DateTime alarmTime) {
    final now = DateTime.now();
    final difference = alarmTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}日後';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間後';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分後';
    } else {
      return 'まもなく';
    }
  }

  void _showDeleteDialog(Alarm alarm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アラームを削除'),
        content: Text('「${alarm.label}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAlarm(alarm);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}