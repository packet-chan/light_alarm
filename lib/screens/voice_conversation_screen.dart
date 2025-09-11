// lib/screens/voice_conversation_screen.dart

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  final FlutterTts _flutterTts = FlutterTts();

  String _responseText = '';
  String _userInput = '';
  bool _isLoading = false;
  bool _isListening = false;
  bool _isPlaying = false;
  bool _speechEnabled = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _startMorningConversation();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // 音声認識初期化
  void _initSpeech() async {
    await Permission.microphone.request();
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  // TTS初期化
  void _initTts() async {
    await _flutterTts.setLanguage("ja-JP");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
      print("TTS Error: $msg");
    });
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
      // AI応答を読み上げ
      await _speakText(greeting);
    } catch (e) {
      print('Error starting conversation: $e');
      final fallbackText = 'おはようございます！今日も素敵な一日になりそうですね。';
      setState(() {
        _responseText = fallbackText;
        _isLoading = false;
      });
      // フォールバック応答も読み上げ
      await _speakText(fallbackText);
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

      final responseMessage = result['message'] ?? 'お話しいただき、ありがとうございます。';
      setState(() {
        _responseText = responseMessage;
        _isLoading = false;
      });

      // AI応答を読み上げ
      await _speakText(responseMessage);

      // 音声再生（URL が提供された場合）
      if (result['audio_url'] != null) {
        await _playAudio(result['audio_url']);
      }
    } catch (e) {
      print('Error processing input: $e');
      final fallbackMessage = 'お話しいただき、ありがとうございます。';
      setState(() {
        _responseText = fallbackMessage;
        _isLoading = false;
      });
      // エラー時も読み上げ
      await _speakText(fallbackMessage);
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

  // テキスト読み上げ
  Future<void> _speakText(String text) async {
    try {
      // 既に読み上げ中の場合は停止
      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      // テキストを読み上げ
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  // 読み上げ停止
  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } catch (e) {
      print('TTS Stop Error: $e');
    }
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
                              : _isSpeaking
                              ? Colors.purple.withOpacity(0.3)
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
                          : _isSpeaking
                          ? Icons.record_voice_over
                          : _isPlaying
                          ? Icons.volume_up
                          : Icons.wb_sunny,
                      size: 60,
                      color: _isListening
                          ? Colors.red
                          : _isSpeaking
                          ? Colors.purple
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
                        : _isSpeaking
                        ? 'AIが話しています...'
                        : _isPlaying
                        ? '音声を再生中...'
                        : '朝の音声アシスタント',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isSpeaking
                          ? Colors.purple.shade800
                          : Colors.blue.shade800,
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
                      '🗣️ AIからの応答は自動的に読み上げられます\n'
                      '⏸️ 紫のボタンで読み上げを停止できます\n'
                      '🔄 再開ボタンで新しい会話を始められます',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // コントロールボタン
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: [
                      // マイクボタン
                      FloatingActionButton(
                        heroTag: "mic_button",
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
                        heroTag: "refresh_button",
                        onPressed: _isLoading
                            ? null
                            : _startMorningConversation,
                        backgroundColor: Colors.orange.shade600,
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // TTS停止ボタン
                      FloatingActionButton(
                        heroTag: "tts_button",
                        onPressed: _isSpeaking ? _stopSpeaking : null,
                        backgroundColor: _isSpeaking
                            ? Colors.purple.shade600
                            : Colors.grey.shade400,
                        child: Icon(
                          _isSpeaking ? Icons.stop : Icons.record_voice_over,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // 音声停止ボタン
                      FloatingActionButton(
                        heroTag: "audio_button",
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
