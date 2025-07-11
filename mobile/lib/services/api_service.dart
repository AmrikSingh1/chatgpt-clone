import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:mime/mime.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/ai_model.dart';

class ApiService {
  static String get _baseUrl {
    // Use HTTPS URLs for secure communication
    if (Platform.isAndroid) {
      return 'https://10.0.2.2:3443'; // Android emulator with HTTPS
    } else if (Platform.isIOS) {
      return 'https://localhost:3443'; // iOS simulator with HTTPS
    } else {
      return 'https://localhost:3443'; // macOS, Windows, Linux with HTTPS
    }
  }
  
  late final Dio _dio;
  
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add interceptor to handle self-signed certificates in development
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Allow self-signed certificates for localhost in development
        return host == 'localhost' || host == '10.0.2.2';
      };
      return client;
    };
    
    // Add logging interceptor for debugging
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
    ));
  }

  // Chat endpoints
  Future<List<ChatPreview>> getChats() async {
    try {
      final response = await _dio.get('/api/chat');
      
      if (response.data['success'] == true) {
        final List<dynamic> chatList = response.data['data'];
        return chatList.map((chat) => ChatPreview.fromJson(chat)).toList();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch chats');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Chat> getChat(String chatId) async {
    try {
      final response = await _dio.get('/api/chat/$chatId');
      
      if (response.data['success'] == true) {
        return Chat.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch chat');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    String? chatId,
    required String content,
    List<MessageImage>? images,
    String model = 'gpt-3.5-turbo',
  }) async {
    try {
      final data = {
        if (chatId != null) 'chatId': chatId,
        'model': model,
        'message': {
          'content': content,
          if (images != null && images.isNotEmpty)
            'images': images.map((img) => img.toApiJson()).toList(),
        },
      };

      // Detect large requests that need extended timeout
      final isLargeRequest = content.length > 500 || 
          content.toLowerCase().contains('create') ||
          content.toLowerCase().contains('generate') ||
          content.toLowerCase().contains('build') ||
          content.toLowerCase().contains('write') ||
          content.toLowerCase().contains('develop') ||
          content.toLowerCase().contains('code') ||
          content.toLowerCase().contains('game') ||
          content.toLowerCase().contains('application') ||
          content.toLowerCase().contains('program');

      // Use extended timeout for large requests
      final response = await _dio.post(
        '/api/chat', 
        data: data,
        options: isLargeRequest ? Options(
          receiveTimeout: const Duration(minutes: 10), // 10 minutes for very large responses
          sendTimeout: const Duration(minutes: 2), // 2 minutes for sending
        ) : null,
      );
      
      if (response.data['success'] == true) {
        return response.data['data'];
      } else {
        throw Exception(response.data['error'] ?? 'Failed to send message');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final response = await _dio.delete('/api/chat/$chatId');
      
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to delete chat');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // Upload endpoints
  Future<MessageImage> uploadImage(File imageFile) async {
    try {
      // Convert image to base64 for better compatibility
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final base64Data = 'data:$mimeType;base64,$base64String';
      
      final data = {
        'image': base64Data,
        'filename': imageFile.path.split('/').last,
      };

      final response = await _dio.post('/api/upload', data: data);
      
      if (response.data['success'] == true) {
        final imageData = response.data['data'];
        return MessageImage(
          url: imageData['url'],
          publicId: imageData['publicId'],
          filename: imageData['filename'],
        );
      } else {
        throw Exception(response.data['error'] ?? 'Failed to upload image');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  Future<List<MessageImage>> uploadMultipleImages(List<File> imageFiles) async {
    try {
      final formData = FormData.fromMap({
        'images': await Future.wait(
          imageFiles.map((file) async => await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          )),
        ),
      });

      final response = await _dio.post('/api/upload/multiple', data: formData);
      
      if (response.data['success'] == true) {
        final List<dynamic> imagesData = response.data['data'];
        return imagesData.map((imageData) => MessageImage(
          url: imageData['url'],
          publicId: imageData['publicId'],
          filename: imageData['filename'],
        )).toList();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to upload images');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // Models endpoints
  Future<List<AIModel>> getModels() async {
    try {
      final response = await _dio.get('/api/models');
      
      if (response.data['success'] == true) {
        final List<dynamic> modelList = response.data['data'];
        return modelList.map((model) => AIModel.fromJson(model)).toList();
      } else {
        throw Exception(response.data['error'] ?? 'Failed to fetch models');
      }
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'OK';
    } on DioException catch (e) {
      print('Health check failed: ${e.message}');
      return false;
    }
  }

  // Rename chat
  Future<void> renameChat(String chatId, String newTitle) async {
    try {
      await _dio.put(
        '/api/chat/$chatId/rename',
        data: {'title': newTitle},
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception('Failed to rename chat: ${e.response?.data['error'] ?? e.message}');
      }
      throw Exception('Failed to rename chat: $e');
    }
  }

  Exception _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ?? 'Server error';
        
        switch (statusCode) {
          case 400:
            return Exception('Bad request: $message');
          case 401:
            return Exception('Unauthorized: $message');
          case 402:
            return Exception('Payment required: $message');
          case 404:
            return Exception('Not found: $message');
          case 500:
            return Exception('Server error: $message');
          default:
            return Exception('HTTP $statusCode: $message');
        }
      
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return Exception('No internet connection');
        }
        return Exception('Network error: ${e.message}');
      
      default:
        return Exception('Unexpected error: ${e.message}');
    }
  }
} 