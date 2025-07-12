import 'dart:io';
import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

class OpenAIService {
  static const String _apiKey = 'openai';
  late final Dio _dio;
  
  OpenAIService() {
    // Initialize OpenAI with your API key
    OpenAI.apiKey = _apiKey;
    
    // Initialize Dio for custom requests
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.openai.com/v1',
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 10), // Extended for large responses
    ));
  }

  /// Generate a chat title from the first user message using GPT-4
  Future<String> generateChatTitle(String firstMessage) async {
    try {
      final response = await OpenAI.instance.chat.create(
        model: 'gpt-4',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'Generate a concise, descriptive title (max 5 words) for a chat conversation based on the user\'s first message. Only return the title, nothing else.'
              )
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(firstMessage)
            ],
          ),
        ],
        maxTokens: 20,
        temperature: 0.7,
      );

      return response.choices.first.message.content?.first.text?.trim() ?? 'New Chat';
    } catch (e) {
      print('Error generating chat title: $e');
      return 'New Chat';
    }
  }

  /// Analyze image with Vision API and return description
  Future<String> analyzeImage(File imageFile, {String? prompt}) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

      final response = await OpenAI.instance.chat.create(
        model: 'gpt-4-vision-preview',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                prompt ?? 'What do you see in this image? Provide a detailed description.'
              ),
              OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
                'data:$mimeType;base64,$base64Image'
              ),
            ],
          ),
        ],
        maxTokens: 500,
      );

      return response.choices.first.message.content?.first.text ?? 'Unable to analyze image';
    } catch (e) {
      print('Error analyzing image: $e');
      throw Exception('Failed to analyze image: ${e.toString()}');
    }
  }

  /// Analyze multiple images with Vision API
  Future<String> analyzeMultipleImages(List<File> imageFiles, {String? prompt}) async {
    try {
      final List<OpenAIChatCompletionChoiceMessageContentItemModel> contentItems = [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          prompt ?? 'Analyze all these images and provide a comprehensive description of what you see.'
        ),
      ];

      // Add all images to content
      for (final imageFile in imageFiles) {
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
        
        contentItems.add(
          OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
            'data:$mimeType;base64,$base64Image'
          )
        );
      }

      final response = await OpenAI.instance.chat.create(
        model: 'gpt-4-vision-preview',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: contentItems,
          ),
        ],
        maxTokens: 1000,
      );

      return response.choices.first.message.content?.first.text ?? 'Unable to analyze images';
    } catch (e) {
      print('Error analyzing images: $e');
      throw Exception('Failed to analyze images: ${e.toString()}');
    }
  }

  /// Analyze document (PDF, Word, etc.) - extract text and analyze with GPT-4
  Future<String> analyzeDocument(File documentFile, {String? prompt}) async {
    try {
      // For now, we'll handle text extraction on the backend
      // In a real implementation, you might use libraries like:
      // - pdf_text for PDF extraction
      // - docx_template for Word documents
      // Here we'll send the document to your backend for processing
      
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(
          documentFile.path,
          filename: documentFile.path.split('/').last,
        ),
        'prompt': prompt ?? 'Analyze this document and provide a summary of its contents.',
      });

      final response = await _dio.post('/analyze-document', data: formData);
      
      return response.data['analysis'] ?? 'Unable to analyze document';
    } catch (e) {
      print('Error analyzing document: $e');
      throw Exception('Failed to analyze document: ${e.toString()}');
    }
  }

  /// Convert speech to text using Whisper API
  Future<String> speechToText(File audioFile) async {
    try {
      final audioTranscription = await OpenAI.instance.audio.createTranscription(
        file: audioFile,
        model: 'whisper-1',
        language: 'en', // You can make this dynamic based on user preference
        responseFormat: OpenAIAudioResponseFormat.json,
      );

      return audioTranscription.text;
    } catch (e) {
      print('Error converting speech to text: $e');
      throw Exception('Failed to convert speech to text: ${e.toString()}');
    }
  }

  /// Send a chat message with multimodal content (text + images + documents)
  Future<String> sendChatMessage({
    required String message,
    List<File>? images,
    List<File>? documents,
    String model = 'gpt-4',
  }) async {
    try {
      final List<OpenAIChatCompletionChoiceMessageContentItemModel> contentItems = [];

      // Add text content
      contentItems.add(
        OpenAIChatCompletionChoiceMessageContentItemModel.text(message)
      );

      // Add images if provided
      if (images != null && images.isNotEmpty) {
        for (final imageFile in images) {
          final bytes = await imageFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
          
          contentItems.add(
            OpenAIChatCompletionChoiceMessageContentItemModel.imageUrl(
              'data:$mimeType;base64,$base64Image'
            )
          );
        }
        // Use vision model if images are present
        model = 'gpt-4-vision-preview';
      }

      // Add document analysis if documents are provided
      if (documents != null && documents.isNotEmpty) {
        for (final doc in documents) {
          try {
            final docAnalysis = await analyzeDocument(doc);
            contentItems.add(
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'Document analysis: $docAnalysis'
              )
            );
          } catch (e) {
            contentItems.add(
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'Failed to analyze document: ${doc.path.split('/').last}'
              )
            );
          }
        }
      }

      final response = await OpenAI.instance.chat.create(
        model: model,
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: contentItems,
          ),
        ],
        // Remove maxTokens limit for unlimited generation - let OpenAI determine optimal length
        // maxTokens: 2000, // Commented out to allow unlimited generation
        temperature: 0.7,
      );

      return response.choices.first.message.content?.first.text ?? 'No response generated';
    } catch (e) {
      print('Error sending chat message: $e');
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  /// Get available models
  Future<List<String>> getAvailableModels() async {
    try {
      final models = await OpenAI.instance.model.list();
      return models
          .where((model) => model.id.contains('gpt'))
          .map((model) => model.id)
          .toList();
    } catch (e) {
      print('Error fetching models: $e');
      return ['gpt-3.5-turbo', 'gpt-4', 'gpt-4-vision-preview'];
    }
  }

  /// Check if the service is properly configured
  bool get isConfigured => _apiKey.isNotEmpty && _apiKey != 'your-openai-api-key-here';
} 