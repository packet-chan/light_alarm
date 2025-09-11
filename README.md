# light_alarm_prototype

光センサーを使ったスマートアラームアプリケーション

## セットアップ

### API設定

アプリケーションを動作させるには、API Gateway エンドポイントの設定が必要です。

1. `lib/config/api_config.dart.example` をコピーして `lib/config/api_config.dart` を作成
```bash
cp lib/config/api_config.dart.example lib/config/api_config.dart
```

2. `lib/config/api_config.dart` を編集し、実際のAPI Gateway エンドポイントを設定
```dart
class ApiConfig {
  static const String voiceApiEndpoint = 'https://your-api-id.execute-api.region.amazonaws.com/prod/voice-conversation';
}
```

## 機能

- 光センサーを使ったアラーム機能
- AI音声会話機能（AWS Bedrock連携）
- 天気情報取得
- 位置情報連携

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
