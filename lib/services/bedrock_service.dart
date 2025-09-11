import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class BedrockService {
  // API Gateway エンドポイントに変更
  static const String _voiceApiEndpoint =
      'https://5t131v2kva.execute-api.ap-northeast-1.amazonaws.com/prod/voice-conversation';

  Future<String> startMorningConversation() async {
    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(seconds: 1));
        final now = DateTime.now();
        final hour = now.hour;
        final minute = now.minute;
        return 'おはようございます！${hour}時${minute}分ですね。\n\n'
            '今日は${now.month}月${now.day}日です。API Gateway経由でテスト中です！\n\n'
            '今日も素敵な一日になりそうですね！';
      }

      final position = await _getCurrentPosition();

      print(
        'Calling API Gateway with lat: ${position.latitude}, lon: ${position.longitude}',
      );

      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
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
      return 'おはようございます！今日も素敵な一日になりそうですね。申し訳ございませんが、現在天気情報を取得できません。';
    }
  }

  // 音声処理用メソッドも同様に更新
  Future<Map<String, dynamic>> processVoiceMessage(
    String text,
    double latitude,
    double longitude,
  ) async {
    try {
      print('Processing voice message via API Gateway: $text');

      if (kIsWeb) {
        await Future.delayed(const Duration(seconds: 1));
        
        String response;
        if (text.contains('天気') || text.contains('気温')) {
          response = 'API Gateway経由でテスト中：天気情報を処理しています。実機版では詳細な天気をお伝えできます。';
        } else if (text.contains('おはよう') || text.contains('挨拶')) {
          response = 'おはようございます！API Gateway経由でのテストです。実機では音声での自然な会話ができます。';
        } else {
          response = 'API Gateway経由でメッセージを受け取りました：「$text」\n実機版では、このメッセージに対してAIが自然に応答します。';
        }

        return {
          'message': response,
          'audio_url': null,
          'weather': null,
        };
      }

      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
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
      
      if (kIsWeb) {
        return {
          'message': 'API Gateway経由でのテストです。実機版では完全な機能をご利用いただけます。',
          'audio_url': null,
          'weather': null,
        };
      }
      
      throw Exception('音声処理エラー: $e');
    }
  }

  // 天気情報取得メソッドも同様に更新
  Future<Map<String, dynamic>> getWeatherInfo(
    double latitude,
    double longitude,
  ) async {
    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(seconds: 1));
        return {
          'weather_info': 'API Gateway経由でのテスト中です。実機版では現在地の詳細な天気情報をお伝えできます。',
        };
      }

      final response = await http
          .post(
            Uri.parse(_voiceApiEndpoint),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'action': 'weather_only',
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'weather_info': data['weather_info'],
        };
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error getting weather info via API Gateway: $e');
      throw Exception('天気情報取得エラー: $e');
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
