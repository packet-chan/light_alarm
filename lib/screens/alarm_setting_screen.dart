// lib/screens/alarm_setting_screen.dart

import 'package:flutter/material.dart';
import 'package:light_alarm_prototype/models/alarm_model.dart';
import 'package:light_alarm_prototype/services/alarm_service.dart';

class AlarmSettingScreen extends StatefulWidget {
  final Alarm? alarm; // 既存のアラームを編集する場合

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
      // 編集モード
      _selectedTime = widget.alarm!.time;
      _labelController = TextEditingController(text: widget.alarm!.label);
      _isRepeating = widget.alarm!.isRepeating;
      _selectedWeekdays = List.from(widget.alarm!.weekdays);
    } else {
      // 新規作成モード
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAlarm() async {
    if (!_isRepeating || _selectedWeekdays.any((selected) => selected)) {
      final alarm = Alarm(
        id:
            widget.alarm?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        time: _selectedTime,
        label: _labelController.text.trim().isEmpty
            ? 'アラーム'
            : _labelController.text.trim(),
        isRepeating: _isRepeating,
        weekdays: List.from(_selectedWeekdays),
        isActive: true,
      );

      Navigator.pop(context, alarm);
    } else {
      // 繰り返しが選択されているのに曜日が選択されていない場合
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('繰り返しアラームの場合は曜日を選択してください')));
    }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 時間選択カード
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '時間',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ラベル入力カード
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.label_outline,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'ラベル',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        hintText: 'アラームの名前を入力',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 繰り返し設定カード
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.repeat,
                            color: Colors.orange[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '繰り返し',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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
                      const SizedBox(height: 20),
                      Text(
                        '繰り返す曜日',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildWeekdaySelector(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
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
      children: List.generate(7, (index) {
        final isSelected = _selectedWeekdays[index];
        final isWeekend = index >= 5; // 土日

        return FilterChip(
          label: Text(
            weekdayNames[index],
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isWeekend
                  ? Colors.red[600]
                  : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedWeekdays[index] = selected;
            });
          },
          selectedColor: isWeekend ? Colors.red[400] : Colors.blue[500],
          checkmarkColor: Colors.white,
          backgroundColor: Colors.grey[100],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}
