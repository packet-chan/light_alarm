// lib/screens/voice_conversation_screen.dart

import 'dart:io';
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

class _VoiceConversationScreenState extends State<VoiceConversationScreen>
    with TickerProviderStateMixin {
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
  bool _hasStartedConversation = false;
  bool _isInitialized = false; // ★ 初期化完了フラグを追加

  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // ★ 初期化から会話開始までを安全な順序で実行するメソッドを呼び出す
    _initializeAndStart();
  }

  // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
  // ★ ここが重要な修正箇所です！
  // ★ 初期化処理を安全な順番で実行するように変更しました。
  // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
  Future<void> _initializeAndStart() async {
    // まずは音声関連のコンポーネントの初期化を完了させる
    await _initializeAudioComponents();
    
    // mountedプロパティをチェックして、ウィジェットがまだツリーに存在することを確認
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      // 初期化がすべて完了してから、朝の挨拶を開始する
      await _startMorningConversation();
    }
  }

  void _setupAnimations() {
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeAudioComponents() async {
    try {
      await _requestPermissions();
      await _initTts();
      await _initSpeech();
      print('Audio components initialized successfully');
    } catch (e) {
      print('Error initializing audio components: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.microphone,
      Permission.audio,
    ];

    if (Platform.isAndroid) {
      permissions.add(Permission.speech);
    }

    for (final permission in permissions) {
      final status = await permission.request();
      if (status != PermissionStatus.granted) {
        print('Permission denied: $permission');
      }
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage("ja-JP");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.7);
      await _flutterTts.setVolume(0.8);
      
      if (Platform.isAndroid) {
        await _flutterTts.setQueueMode(1);
      }

      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = true);
          _startSpeakingAnimation();
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _stopSpeakingAnimation();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        print("TTS Error: $msg");
        if (mounted) {
          setState(() => _isSpeaking = false);
          _stopSpeakingAnimation();
        }
      });

      print('TTS initialized successfully');
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          if (mounted) {
            setState(() => _isListening = false);
            _stopListeningAnimation();
          }
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' && _isListening) {
            if (mounted) {
              setState(() => _isListening = false);
              _stopListeningAnimation();
            }
          }
        },
      );
      
      print('Speech recognition initialized: $_speechEnabled');
    } catch (e) {
      print('Speech initialization error: $e');
      _speechEnabled = false;
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  void _startSpeakingAnimation() {
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  void _stopSpeakingAnimation() {
    _pulseController.stop();
    _waveController.stop();
  }

  void _startListeningAnimation() {
    _waveController.repeat();
  }

  void _stopListeningAnimation() {
    _waveController.stop();
  }

  Future<void> _startMorningConversation() async {
    if (_hasStartedConversation && !_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasStartedConversation = true;
    });

    try {
      final greeting = await _bedrockService.startMorningConversation();
      setState(() {
        _responseText = greeting;
        _isLoading = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      await _speakText(greeting);
    } catch (e) {
      print('Error starting conversation: $e');
      final fallbackText = 'おはようございます！今日も素敵な一日になりそうですね。';
      setState(() {
        _responseText = fallbackText;
        _isLoading = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      await _speakText(fallbackText);
    }
  }

  // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
  // ★ ここも重要な修正箇所です！
  // ★ 処理の衝突を防ぐためのチェックを強化しました。
  // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★
  Future<void> _startListening() async {
    if (!_speechEnabled || _isSpeaking || _isListening || _isLoading) {
      print(
        'Cannot start listening. Conditions: speechEnabled: $_speechEnabled, isSpeaking: $_isSpeaking, isListening: $_isListening, isLoading: $_isLoading',
      );
      return;
    }

    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      setState(() {
        _isListening = true;
        _userInput = '';
      });
      
      _startListeningAnimation();

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      setState(() => _isListening = false);
      _stopListeningAnimation();
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
    _stopListeningAnimation();

    if (_userInput.trim().isNotEmpty) {
      await _processUserInput(_userInput);
    }
  }

  void _onSpeechResult(result) {
    setState(() {
      _userInput = result.recognizedWords;
    });
  }

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

      await Future.delayed(const Duration(milliseconds: 500));
      await _speakText(responseMessage);

      if (result['audio_url'] != null) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _playAudio(result['audio_url']);
      }
    } catch (e) {
      print('Error processing input: $e');
      final fallbackMessage = 'お話しいただき、ありがとうございます。';
      setState(() {
        _responseText = fallbackMessage;
        _isLoading = false;
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      await _speakText(fallbackMessage);
    }
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return;

    try {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
      if (mounted) {
        setState(() => _isSpeaking = false);
        _stopSpeakingAnimation();
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      _stopSpeakingAnimation();
    } catch (e) {
      print('TTS Stop Error: $e');
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      setState(() => _isPlaying = true);
      await _audioPlayer.play(UrlSource(audioUrl));

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() => _isPlaying = false);
  }

  Color _getStatusColor() {
    if (_isListening) return Colors.red;
    if (_isSpeaking) return Colors.purple;
    if (_isPlaying) return Colors.green;
    return Colors.blue;
  }

  IconData _getStatusIcon() {
    if (_isListening) return Icons.mic;
    if (_isSpeaking) return Icons.record_voice_over;
    if (_isPlaying) return Icons.volume_up;
    return Icons.wb_sunny;
  }

  String _getStatusText() {
    if (!_isInitialized) return '音声機能を準備中...';
    if (_isListening) return '音声を聞いています...';
    if (_isSpeaking) return 'AIが話しています...';
    if (_isPlaying) return '音声を再生中...';
    return '朝の音声アシスタント';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getStatusColor().withOpacity(0.1),
              _getStatusColor().withOpacity(0.2),
              Colors.orange.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '🌅 おはよう！',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                
                const SizedBox(height: 40),

                Expanded(
                  flex: 2,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isSpeaking ? _pulseAnimation.value : 1.0,
                          child: AnimatedBuilder(
                            animation: _waveAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _getStatusColor().withOpacity(0.3),
                                      _getStatusColor().withOpacity(0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getStatusColor().withOpacity(0.3),
                                      blurRadius: (_isListening || _isSpeaking) ? 30 : 15,
                                      spreadRadius: (_isListening || _isSpeaking) ? 10 : 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _getStatusIcon(),
                                  size: 80,
                                  color: _getStatusColor(),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor().withOpacity(0.8),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                if (_userInput.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
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
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _isLoading && _responseText.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  color: _getStatusColor(),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'AIが考えています...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.psychology,
                                      color: Colors.green.shade600,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'AI アシスタント',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _responseText.isEmpty ? '音声で話しかけてみてください' : _responseText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        onPressed: _isInitialized
                            ? (_isListening ? _stopListening : _startListening)
                            : null,
                        icon: _isListening ? Icons.mic_off : Icons.mic,
                        color: _isListening ? Colors.red : Colors.blue,
                        isActive: _isListening,
                        label: _isListening ? '停止' : 'マイク',
                      ),

                      _buildControlButton(
                        onPressed: _isLoading || !_isInitialized ? null : _startMorningConversation,
                        icon: Icons.refresh,
                        color: Colors.orange,
                        isActive: false,
                        label: '再開',
                      ),

                      _buildControlButton(
                        onPressed: _isSpeaking ? _stopSpeaking : null,
                        icon: _isSpeaking ? Icons.stop : Icons.record_voice_over,
                        color: _isSpeaking ? Colors.purple : Colors.grey,
                        isActive: _isSpeaking,
                        label: _isSpeaking ? '停止' : 'TTS',
                      ),

                      _buildControlButton(
                        onPressed: _isPlaying ? _stopAudio : null,
                        icon: _isPlaying ? Icons.stop : Icons.volume_up,
                        color: _isPlaying ? Colors.green : Colors.grey,
                        isActive: _isPlaying,
                        label: _isPlaying ? '停止' : '音声',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('戻る'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
    required bool isActive,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: FloatingActionButton(
            heroTag: label,
            onPressed: onPressed,
            backgroundColor: onPressed != null ? color : Colors.grey.shade400,
            elevation: isActive ? 8 : 2,
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? color : Colors.grey.shade500,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}