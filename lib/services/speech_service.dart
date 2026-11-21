import 'dart:typed_data';
import 'api_client.dart';

class SpeechResult {
  const SpeechResult({
    required this.text,
    this.language,
    this.noSpeech = false,
  });

  final String text;
  final String? language;
  final bool noSpeech;
}

class SpeechService {
  SpeechService._();

  /// Supported Speech-to-Text languages: Russian ('ru'), English ('en').
  static const List<(String code, String label)> supportedLanguages = [
    ('ru', 'RUS'),
    ('en', 'ENG'),
  ];

  static Future<SpeechResult> transcribe({
    required Uint8List bytes,
    required String mimeType,
    required String filename,
    required String language,
  }) async {
    final res = await ApiClient.instance.postBinary(
      '/api/speech/transcribe',
      bytes,
      contentType: mimeType,
      filename: filename,
      language: language,
    );

    if (res is Map) {
      return SpeechResult(
        text: (res['text'] ?? '').toString().trim(),
        language: res['language']?.toString(),
        noSpeech: res['noSpeech'] == true,
      );
    }

    return const SpeechResult(text: '', noSpeech: true);
  }
}
