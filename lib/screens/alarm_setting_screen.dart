// lib/screens/alarm_setting_screen.dart

import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';
import 'voice_conversation_screen.dart';
import 'package:uuid/uuid.dart';

class AlarmSettingScreen extends StatefulWidget {
  final Alarm? alarm;

  const AlarmSettingScreen({super.key, this.alarm});

  @override
  State<AlarmSettingScreen> createState() => _AlarmSettingScreenState();
}

class _AlarmSettingScreenState extends State<AlarmSettingScreen> {
  late TimeOfDay _selectedTime;
  late TextEditingController _labelController;
  late bool _isRepeating;
  late List<bool> _selectedWeekdays;

  @override
  void initState() {
    super.initState();
    if (widget.alarm != null) {
      _selectedTime = widget.alarm!.time;
      _labelController = TextEditingController(text: widget.alarm!.label);
      _isRepeating = widget.alarm!.isRepeating;
      _selectedWeekdays = List.from(widget.alarm!.weekdays);
    } else {
      _selectedTime = TimeOfDay.now();
      _labelController = TextEditingController(text: 'アラーム');
      _isRepeating = false;
      _selectedWeekdays = List.filled(7, false);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveAlarm() {
    if (_isRepeating && _selectedWeekdays.every((day) => !day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('繰り返しアラームの場合は曜日を1つ以上選択してください')),
      );
      return;
    }
    final alarm = Alarm(
      id: widget.alarm?.id ?? const Uuid().v4(),
      time: _selectedTime,
      label: _labelController.text.trim().isEmpty
          ? 'アラーム'
          : _labelController.text.trim(),
      isRepeating: _isRepeating,
      weekdays: _isRepeating ? _selectedWeekdays : List.filled(7, false),
      isActive: true,
    );
    Navigator.pop(context, alarm);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'アラーム作成' : 'アラーム編集'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blue, size: 28),
                      const SizedBox(width: 16),
                      Text(
                        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'ラベル',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('繰り返し', style: TextStyle(fontSize: 16)),
                        Switch(
                          value: _isRepeating,
                          onChanged: (value) {
                            setState(() {
                              _isRepeating = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isRepeating) ...[
                      const Divider(height: 24),
                      _buildWeekdaySelector(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VoiceConversationScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.cloud, color: Colors.purple),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'AWS音声会話テスト',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(7, (index) {
        return FilterChip(
          label: Text(weekdayNames[index]),
          selected: _selectedWeekdays[index],
          onSelected: (selected) {
            setState(() {
              _selectedWeekdays[index] = selected;
            });
          },
        );
      }),
    );
  }
}