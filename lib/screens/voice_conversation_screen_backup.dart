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
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _getCurrentLocation();
    _startConversation();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    // マイク権限の確認・要求
    final micPermission = await Permission.microphone.request();
    if (micPermission != PermissionStatus.granted) {
      print('マイクの権限が拒否されました');
      return;
    }

    _speechEnabled = await _speechToText.initialize(
      onError: (error) => print('音声認識エラー: $error'),
      onStatus: (status) => print('音声認識ステータス: $status'),
    );

    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('位置情報取得エラー: $e');
      // デフォルト位置（東京駅）
      _currentPosition = Position(
        latitude: 35.6762,
        longitude: 139.6503,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  Future<void> _startConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _bedrockService.startMorningConversation();
      setState(() {
        _responseText = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'エラーが発生しました。もう一度お試しください。';
        _isLoading = false;
      });
    }
  }

  // 音声録音開始
  Future<void> _startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      return;
    }

    setState(() {
      _isListening = true;
      _userInput = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _userInput = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      cancelOnError: true,
      partialResults: true,
      localeId: 'ja_JP',
    );
  }

  // 音声録音停止
  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    if (_userInput.isNotEmpty) {
      await _processVoiceInput(_userInput);
    }
  }

  // 音声入力の処理
  Future<void> _processVoiceInput(String text) async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    setState(() {
      _isLoading = true;
      _responseText = '処理中...';
    });

    try {
      final result = await _bedrockService.processVoiceMessage(
        text,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _responseText = result['message'] ?? 'AI応答を取得できませんでした。';
        _isLoading = false;
      });

      // 音声URLがある場合は再生
      if (result['audio_url'] != null) {
        await _playAudioResponse(result['audio_url']);
      }
    } catch (e) {
      setState(() {
        _responseText = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  // 音声レスポンスの再生
  Future<void> _playAudioResponse(String audioUrl) async {
    try {
      setState(() {
        _isPlaying = true;
      });

      await _audioPlayer.play(UrlSource(audioUrl));

      // 再生完了を監視
      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
        });
      });
    } catch (e) {
      print('音声再生エラー: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  // 音声再生停止
  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
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
                        : Colors.orange.shade600,
                  ),
                ),

                const SizedBox(height: 20),

                // ユーザー入力表示
                if (_userInput.isNotEmpty)
                  Card(
                    elevation: 4,
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userInput,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blue.shade800,
                              ),
                            ),
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
                        : Row(
                            children: [
                              Icon(
                                Icons.smart_toy,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _responseText,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 40),

                // 音声録音ボタン
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red : Colors.blue.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isListening ? Colors.red : Colors.blue.shade600)
                                .withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: _speechEnabled
                          ? (_isListening ? _stopListening : _startListening)
                          : null,
                      child: Center(
                        child: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  _isListening ? 'タップして録音停止' : 'タップして音声入力',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),

                const SizedBox(height: 30),

                // ボタン群
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 再実行ボタン
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _startConversation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('再実行'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
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

                    // 音声停止ボタン
                    if (_isPlaying)
                      ElevatedButton.icon(
                        onPressed: _stopAudio,
                        icon: const Icon(Icons.stop),
                        label: const Text('停止'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
