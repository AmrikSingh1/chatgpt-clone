import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'openai_service.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  final OpenAIService _openAI = OpenAIService();
  bool _isListening = false;
  bool _isAvailable = false;
  String _recognizedText = '';

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get recognizedText => _recognizedText;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      final permissionStatus = await Permission.microphone.request();
      if (permissionStatus != PermissionStatus.granted) {
        print('Microphone permission denied');
        return false;
      }

      // Initialize speech-to-text
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          print('Speech error: $error');
          _isListening = false;
        },
      );

      return _isAvailable;
    } catch (e) {
      print('Error initializing speech service: $e');
      return false;
    }
  }

  /// Start listening for speech
  Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    String language = 'en_US',
  }) async {
    if (!_isAvailable) {
      await initialize();
    }

    if (_isAvailable && !_isListening) {
      _isListening = true;
      _recognizedText = '';

      await _speech.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          
          // Call partial result callback for real-time updates
          if (onPartialResult != null && !result.finalResult) {
            onPartialResult(_recognizedText);
          }
          
          // Call final result callback when speech is complete
          if (result.finalResult) {
            onResult(_recognizedText);
            _isListening = false;
          }
        },
        listenFor: const Duration(seconds: 30), // Maximum listening duration
        pauseFor: const Duration(seconds: 3),   // Pause detection
        partialResults: true,
        localeId: language,
        onSoundLevelChange: null, // Could be used for voice level visualization
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      _recognizedText = '';
    }
  }

  /// Convert audio file to text using OpenAI Whisper
  Future<String> transcribeAudioFile(File audioFile) async {
    try {
      return await _openAI.speechToText(audioFile);
    } catch (e) {
      print('Error transcribing audio file: $e');
      throw Exception('Failed to transcribe audio: ${e.toString()}');
    }
  }

  /// Get available languages for speech recognition
  List<String> getAvailableLanguages() {
    return [
      'en_US', // English (US)
      'en_GB', // English (UK)
      'es_ES', // Spanish
      'fr_FR', // French
      'de_DE', // German
      'it_IT', // Italian
      'pt_BR', // Portuguese (Brazil)
      'ru_RU', // Russian
      'ja_JP', // Japanese
      'ko_KR', // Korean
      'zh_CN', // Chinese (Simplified)
      'ar_SA', // Arabic
      'hi_IN', // Hindi
    ];
  }

  /// Check microphone permission status
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Get localized language name
  String getLanguageName(String localeId) {
    switch (localeId) {
      case 'en_US':
        return 'English (US)';
      case 'en_GB':
        return 'English (UK)';
      case 'es_ES':
        return 'Spanish';
      case 'fr_FR':
        return 'French';
      case 'de_DE':
        return 'German';
      case 'it_IT':
        return 'Italian';
      case 'pt_BR':
        return 'Portuguese';
      case 'ru_RU':
        return 'Russian';
      case 'ja_JP':
        return 'Japanese';
      case 'ko_KR':
        return 'Korean';
      case 'zh_CN':
        return 'Chinese';
      case 'ar_SA':
        return 'Arabic';
      case 'hi_IN':
        return 'Hindi';
      default:
        return 'English (US)';
    }
  }

  /// Create temporary audio file for recording
  Future<File> createTempAudioFile() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${tempDir.path}/audio_$timestamp.wav');
  }

  /// Dispose resources
  void dispose() {
    _speech.stop();
  }
} 