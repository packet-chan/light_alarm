// lib/screens/conversation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with TickerProviderStateMixin {
  final List<({bool isUser, String text})> _chatHistory = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  // 状態管理用の変数
  bool _isProcessing = false; // AIが考え中の状態
  bool _isListening = false; // ユーザーの音声入力中の状態
  bool _conversationFinished = false; // 会話が終了したか

  // アニメーション用のコントローラー
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startConversation();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 最初の会話を開始
  void _startConversation() async {
    const initialMessage =
        'おはようございます！まず今日の天気をお知らせします。東京は曇り時々雨、最高気温は28度です。ちなみに、今日の13時からの予定を覚えていますか？';
    setState(() {
      _chatHistory.add((isUser: false, text: initialMessage));
    });
    _scrollToBottom();
    await _audioPlayer.play(AssetSource('audio/ai_response_1.mp3'));
  }

  // マイクボタンが押されたときの処理
  Future<void> _onMicPressed() async {
    if (_isProcessing || _conversationFinished) return;

    setState(() {
      _isProcessing = true;
      _isListening = true; // 聞き取りアニメーションを開始
    });

    // 音声を取っている演出（アニメーションが終わるまで待つ）
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _chatHistory.add((isUser: true, text: 'ハッカソンの最終発表です。'));
      _isListening = false; // 聞き取りアニメーションを終了
    });
    _scrollToBottom();

    // AIが考える時間を演出
    await Future.delayed(const Duration(seconds: 1));

    const finalMessage = 'その通りです。準備はすでに完了していますか？さあ、頭もスッキリしてきた頃でしょう。頑張ってください！';
    setState(() {
      _chatHistory.add((isUser: false, text: finalMessage));
      _conversationFinished = true; // 会話を終了済みにする
    });
    _scrollToBottom();
    await _audioPlayer.play(AssetSource('audio/ai_response_2.mp3'));

    // 最後のセリフの後、操作可能にする
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('モーニングセッション'),
        // 戻るボタンを明示的に追加
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 8.0,
                    ),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Colors.blue[100]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          // --- UIの状態によって表示を切り替える ---
          if (_isListening) _buildListeningIndicator(),
          if (_isProcessing && !_isListening)
            const Padding(padding: EdgeInsets.all(16.0), child: Text("考え中...")),
          if (!_isListening && !_isProcessing)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: IconButton(
                icon: const Icon(Icons.mic),
                iconSize: 64,
                color: _conversationFinished ? Colors.grey : Colors.blue,
                onPressed: _onMicPressed,
              ),
            ),
        ],
      ),
    );
  }

  // 聞き取り中のアニメーションWidget
  Widget _buildListeningIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: CircleWavePainter(
              waveRadius: _animationController.value * 50.0,
              waveColor: Colors.blue.withOpacity(
                1.0 - _animationController.value,
              ),
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Icon(Icons.mic, color: Colors.white, size: 40),
            ),
          );
        },
      ),
    );
  }
}

// 波紋アニメーションを描画するためのクラス
class CircleWavePainter extends CustomPainter {
  final double waveRadius;
  final Color waveColor;

  CircleWavePainter({required this.waveRadius, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, waveRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
