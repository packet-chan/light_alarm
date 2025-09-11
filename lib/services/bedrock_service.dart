import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class BedrockService {
  static String get _voiceApiEndpoint => ApiConfig.voiceApiEndpoint;

  Future<String> startMorningConversation() async {
    try {
      final position = await _getCurrentPosition();

      print(
        'Calling API Gateway with lat: ${position.latitude}, lon: ${position.longitude}',
      );

      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'start_conversation',
              'latitude': position.latitude,
              'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('API Gateway Response status: ${response.statusCode}');
      print('API Gateway Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'おはようございます！今日も素敵な一日になりそうですね。';
      }

      throw Exception(
        'API Gateway call failed: ${response.statusCode}\nBody: ${response.body}',
      );
    } catch (e) {
      print('Error calling API Gateway: $e');

      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;

      String timeGreeting;
      if (hour < 6) {
        timeGreeting = 'おはようございます！早起きですね。';
      } else if (hour < 12) {
        timeGreeting = 'おはようございます！';
      } else if (hour < 18) {
        timeGreeting = 'こんにちは！';
      } else {
        timeGreeting = 'こんばんは！';
      }

      return '$timeGreeting現在${hour}時${minute}分です。\n\n'
          '今日は${now.month}月${now.day}日ですね。申し訳ございませんが、現在天気情報を取得できません。\n\n'
          'それでも今日が素敵な一日になりますように！';
    }
  }

  Future<Map<String, dynamic>> processVoiceMessage(
    String text,
    double latitude,
    double longitude,
  ) async {
    try {
      print('Processing voice message via API Gateway: $text');

      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'text_only',
              'text': text,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('Voice processing response status: ${response.statusCode}');
      print('Voice processing response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        return {
          'message': result['response_text'] ?? 'AI応答を取得できませんでした。',
          'audio_url': result['audio_url'],
          'weather': result['weather'],
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error processing voice message via API Gateway: $e');

      String fallbackResponse;

      if (text.contains('天気') ||
          text.contains('気温') ||
          text.contains('降水') ||
          text.contains('雨')) {
        fallbackResponse =
            '申し訳ございません。現在天気情報を取得できませんが、外出される際は念のため天気予報をご確認くださいね。';
      } else if (text.contains('おはよう') ||
          text.contains('朝') ||
          text.contains('起き')) {
        final hour = DateTime.now().hour;
        if (hour < 6) {
          fallbackResponse = 'おはようございます！とても早起きですね。素晴らしいスタートです！';
        } else if (hour < 10) {
          fallbackResponse = 'おはようございます！気持ちの良い朝ですね。今日も良い一日になりそうです！';
        } else {
          fallbackResponse = 'おはようございます！今日も元気にスタートしましょう！';
        }
      } else if (text.contains('時間') || text.contains('時刻')) {
        final now = DateTime.now();
        fallbackResponse = '現在は${now.hour}時${now.minute}分です。';
      } else if (text.contains('今日') || text.contains('日付')) {
        final now = DateTime.now();
        fallbackResponse = '今日は${now.month}月${now.day}日です。';
      } else {
        fallbackResponse =
            'お話しいただき、ありがとうございます。現在システムに接続できませんが、あなたのメッセージは受け取りました。';
      }

      return {'message': fallbackResponse, 'audio_url': null, 'weather': null};
    }
  }

  Future<Map<String, dynamic>> getWeatherInfo(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'weather_only',
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'weather_info': data['weather_info']};
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error getting weather info via API Gateway: $e');

      return {
        'weather_info': '申し訳ございません。現在天気情報を取得できません。お出かけの際は、念のため天気予報をご確認ください。',
      };
    }
  }

  Future<Position> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('位置情報の権限が拒否されています');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return Position(
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
}