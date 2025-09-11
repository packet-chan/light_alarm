// lib/screens/voice_conversation_screen.dart

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../services/bedrock_service.dart';

class VoiceConversationScreen extends StatefulWidget {
  const VoiceConversationScreen({super.key});

  @override
  State<VoiceConversationScreen> createState() =>
      _VoiceConversationScreenState();
}

class _VoiceConversationScreenState extends State<VoiceConversationScreen> {
  final BedrockService _bedrockService = BedrockService();
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _responseText = '';
  String _userInput = '';
  bool _isLoading = false;
  bool _isListening = false;
  bool _isPlaying = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _startMorningConversation();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // 音声認識初期化
  void _initSpeech() async {
    await Permission.microphone.request();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  // 朝の挨拶開始
  Future<void> _startMorningConversation() async {
    setState(() => _isLoading = true);

    try {
      final greeting = await _bedrockService.startMorningConversation();
      setState(() {
        _responseText = greeting;
        _isLoading = false;
      });
    } catch (e) {
      print('Error starting conversation: $e');
      setState(() {
        _responseText = 'おはようございます！今日も素敵な一日になりそうですね。';
        _isLoading = false;
      });
    }
  }

  // 音声認識開始
  void _startListening() async {
    if (!_speechEnabled) return;

    setState(() {
      _isListening = true;
      _userInput = '';
    });

    await _speechToText.listen(onResult: _onSpeechResult);
  }

  // 音声認識停止
  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);

    if (_userInput.isNotEmpty) {
      await _processUserInput(_userInput);
    }
  }

  // 音声認識結果処理
  void _onSpeechResult(result) {
    setState(() {
      _userInput = result.recognizedWords;
    });
  }

  // ユーザー入力処理
  Future<void> _processUserInput(String input) async {
    setState(() => _isLoading = true);

    try {
      final position = await Geolocator.getCurrentPosition();
      final result = await _bedrockService.processVoiceMessage(
        input,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _responseText = result['message'] ?? 'お話しいただき、ありがとうございます。';
        _isLoading = false;
      });

      // 音声再生（URL が提供された場合）
      if (result['audio_url'] != null) {
        await _playAudio(result['audio_url']);
      }
    } catch (e) {
      print('Error processing input: $e');
      setState(() {
        _responseText = 'お話しいただき、ありがとうございます。';
        _isLoading = false;
      });
    }
  }

  // 音声再生
  Future<void> _playAudio(String audioUrl) async {
    try {
      setState(() => _isPlaying = true);
      await _audioPlayer.play(UrlSource(audioUrl));
      
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() => _isPlaying = false);
    }
  }

  // 音声再生停止
  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朝の音声会話'),
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade100, Colors.orange.shade100],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // アイコン（状態によって変化）
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? Colors.red.withOpacity(0.3)
                              : _isPlaying
                              ? Colors.green.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.mic
                          : _isPlaying
                          ? Icons.volume_up
                          : Icons.wb_sunny,
                      size: 60,
                      color: _isListening
                          ? Colors.red
                          : _isPlaying
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // 状態表示
                  Text(
                    _isListening
                        ? '音声を聞いています...'
                        : _isPlaying
                        ? '音声を再生中...'
                        : '朝の音声アシスタント',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ユーザー入力表示
                  if (_userInput.isNotEmpty)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'あなた:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _userInput,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_userInput.isNotEmpty) const SizedBox(height: 20),

                  // AI応答テキスト
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _isLoading
                          ? Column(
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _isListening
                                      ? '音声を聞いています...'
                                      : 'AWS Bedrockと通信中...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI アシスタント:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _responseText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 使用方法の説明
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🎤 マイクボタンを押して音声で話しかけてください\n'
                      '☀️ 朝の天気や今日の予定について聞いてみましょう\n'
                      '🔄 再開ボタンで新しい会話を始められます',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // コントロールボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // マイクボタン
                      FloatingActionButton(
                        onPressed: _speechEnabled
                            ? (_isListening ? _stopListening : _startListening)
                            : null,
                        backgroundColor: _isListening
                            ? Colors.red
                            : Colors.blue.shade600,
                        child: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // 再開ボタン
                      FloatingActionButton(
                        onPressed: _isLoading ? null : _startMorningConversation,
                        backgroundColor: Colors.orange.shade600,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // 音声停止ボタン
                      FloatingActionButton(
                        onPressed: _isPlaying ? _stopAudio : null,
                        backgroundColor: _isPlaying
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                        child: Icon(
                          _isPlaying ? Icons.stop : Icons.volume_up,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 戻るボタン
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('戻る'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
