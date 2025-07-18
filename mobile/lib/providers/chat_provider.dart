import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/ai_model.dart';
import '../services/api_service.dart';
import '../services/openai_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final OpenAIService _openAIService = OpenAIService();
  final Uuid _uuid = const Uuid();
  
  // Cancellation token for current request
  CancelToken? _currentRequestCancelToken;

  List<ChatPreview> _chatPreviews = [];
  Chat? _currentChat;
  List<AIModel> _availableModels = [];
  String _selectedModel = 'gpt-3.5-turbo';
  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _isStreaming = false;
  bool _isStreamingPaused = false;
  String? _error;

  // Getters
  List<ChatPreview> get chatPreviews => _chatPreviews;
  Chat? get currentChat => _currentChat;
  List<Message> get currentMessages => _currentChat?.messages ?? [];
  List<AIModel> get availableModels => _availableModels;
  String get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isStreaming => _isStreaming;
  bool get isStreamingPaused => _isStreamingPaused;
  String? get error => _error;

  // Initialize
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await Future.wait([
        loadChatPreviews(),
        loadModels(),
      ]);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load chat previews
  Future<void> loadChatPreviews() async {
    try {
      _chatPreviews = await _apiService.getChats();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load chats: ${e.toString()}');
    }
  }

  // Load available models
  Future<void> loadModels() async {
    try {
      _availableModels = await _apiService.getModels();
      if (_availableModels.isNotEmpty) {
        final defaultModel = _availableModels.firstWhere(
          (model) => model.isDefault,
          orElse: () => _availableModels.first,
        );
        _selectedModel = defaultModel.id;
      }
      notifyListeners();
    } catch (e) {
      // Fallback to default models if API fails
      _availableModels = AIModel.defaultModels();
      _selectedModel = 'gpt-3.5-turbo';
      notifyListeners();
    }
  }

  // Select model
  void selectModel(String modelId) {
    if (_availableModels.any((model) => model.id == modelId)) {
      _selectedModel = modelId;
      notifyListeners();
    }
  }

  // Select model (alias for selectModel)
  void setSelectedModel(String modelId) {
    selectModel(modelId);
  }

  // Create new chat
  void createNewChat() {
    _currentChat = null;
    _clearError();
    notifyListeners();
  }

  // Load specific chat
  Future<void> loadChat(String chatId) async {
    _clearError();
    
    // Store the current chat to preserve UI state during loading
    final previousChat = _currentChat;
    
    try {
      print('Loading chat with ID: $chatId');
      
      // Don't set loading state to prevent black screen
      final loadedChat = await _apiService.getChat(chatId);
      
      print('Chat loaded successfully: ${loadedChat.title} with ${loadedChat.messages.length} messages');
      
      _currentChat = loadedChat;
      
      // Mark all messages as already animated to prevent re-animation
      if (_currentChat != null) {
        final updatedMessages = _currentChat!.messages.map((message) {
          return message.copyWith(hasAnimated: true);
        }).toList();
        _currentChat = _currentChat!.copyWith(messages: updatedMessages);
        print('Updated ${updatedMessages.length} messages with hasAnimated=true');
      }
      
      notifyListeners();
      print('Chat provider notified listeners');
    } catch (e) {
      print('Error loading chat: $e');
      // Restore previous chat on error
      _currentChat = previousChat;
      _setError('Failed to load chat: ${e.toString()}');
    }
  }

  // Send message with instant user message display
  Future<void> sendMessage(String content, {List<File>? images}) async {
    if (content.trim().isEmpty && (images == null || images.isEmpty)) return;

    _clearError();

    try {
      // Create temporary message images for instant display
      List<MessageImage> tempMessageImages = [];
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final imageFile = images[i];
          // Create temporary image with local file path for instant display
          tempMessageImages.add(MessageImage(
            id: 'temp_${_uuid.v4()}',
            url: imageFile.path, // Use local file path for instant display
            publicId: 'temp_upload_$i',
            filename: imageFile.path.split('/').last,
          ));
        }
      }

      // Create user message immediately for instant display
      final userMessage = Message(
        id: _uuid.v4(),
        role: 'user',
        content: content.isNotEmpty ? content : 'Image',
        images: tempMessageImages,
        timestamp: DateTime.now(),
      );

      // Create or update current chat immediately
      if (_currentChat == null) {
        // Generate AI title for new chat
        String chatTitle = 'New Chat';
        try {
          if (_openAIService.isConfigured) {
            chatTitle = await _openAIService.generateChatTitle(content);
          } else {
            // Fallback to truncated content
            chatTitle = content.length > 50 ? '${content.substring(0, 50)}...' : content;
          }
        } catch (e) {
          // Fallback to truncated content if title generation fails
          chatTitle = content.length > 50 ? '${content.substring(0, 50)}...' : content;
        }

        // New chat with temporary ID (will be updated with backend response)
        _currentChat = Chat(
          id: 'temp_${_uuid.v4()}', // Temporary ID with prefix
          title: chatTitle,
          model: _selectedModel,
          messages: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      // Add user message immediately to UI
      _currentChat = _currentChat!.copyWith(
        messages: [..._currentChat!.messages, userMessage],
        updatedAt: DateTime.now(),
      );
      notifyListeners(); // Update UI instantly with user message

      // Start backend processing (show typing indicator)
      _setSendingMessage(true);
      _setStreaming(true); // Set streaming state for UI

      // Create cancellation token for this request
      _currentRequestCancelToken = CancelToken();

      // Upload images in background while showing the message instantly
      List<MessageImage> uploadedImages = [];
      if (images != null && images.isNotEmpty) {
        for (File imageFile in images) {
          try {
            final uploadedImage = await _apiService.uploadImage(imageFile);
            uploadedImages.add(uploadedImage);
          } catch (e) {
            print('Failed to upload image: $e');
            // Continue with other images even if one fails
          }
        }
        
        // Update the user message with uploaded images
        final messages = List<Message>.from(_currentChat!.messages);
        final userMessageIndex = messages.indexWhere((msg) => msg.id == userMessage.id);
        if (userMessageIndex != -1) {
          messages[userMessageIndex] = userMessage.copyWith(images: uploadedImages);
          _currentChat = _currentChat!.copyWith(messages: messages);
          notifyListeners(); // Update UI with cloud URLs
        }
      }

      // Send message to backend API
      final response = await _apiService.sendMessage(
        chatId: _currentChat?.id?.startsWith('temp_') == false ? _currentChat?.id : null, // Don't send temp ID
        content: content.isNotEmpty ? content : 'Image',
        images: uploadedImages,
        model: _selectedModel,
        cancelToken: _currentRequestCancelToken,
      );

      // Update chat ID if it was a new chat
      if (_currentChat!.id.startsWith('temp') || response['chatId'] != _currentChat!.id) {
        _currentChat = _currentChat!.copyWith(id: response['chatId']);
      }

      // Update user message with backend response (in case backend modified it)
      final backendUserMessage = Message.fromJson(response['userMessage']);
      final messages = List<Message>.from(_currentChat!.messages);
      final userMessageIndex = messages.indexWhere((msg) => msg.id == userMessage.id);
      if (userMessageIndex != -1) {
        messages[userMessageIndex] = backendUserMessage;
      }

      // Add AI response
      final aiMessage = Message.fromJson(response['aiMessage']);
      messages.add(aiMessage);

      _currentChat = _currentChat!.copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
      );
      
      // Stop typing indicator and update UI
      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
      notifyListeners();

      // Refresh chat previews
      await loadChatPreviews();

    } catch (e) {
      // Handle cancellation gracefully
      if (e is DioException && e.type == DioExceptionType.cancel) {
        print('Request was cancelled by user');
        // Don't show error for user-initiated cancellation
      } else {
        _setError('Failed to send message: ${e.toString()}');
      }
      
      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      await _apiService.deleteChat(chatId);
      
      // Remove from previews
      _chatPreviews.removeWhere((preview) => preview.id == chatId);
      
      // Clear current chat if it's the one being deleted
      if (_currentChat?.id == chatId) {
        _currentChat = null;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete chat: ${e.toString()}');
    }
  }

  // Upload image
  Future<MessageImage?> uploadImage(File imageFile) async {
    try {
      return await _apiService.uploadImage(imageFile);
    } catch (e) {
      _setError('Failed to upload image: ${e.toString()}');
      return null;
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSendingMessage(bool sending) {
    _isSendingMessage = sending;
    notifyListeners();
  }

  void _setStreaming(bool streaming) {
    _isStreaming = streaming;
    notifyListeners();
  }

  void _setStreamingPaused(bool paused) {
    _isStreamingPaused = paused;
    notifyListeners();
  }

  void pauseStreaming() {
    if (_isSendingMessage && !_isStreamingPaused) {
      _setStreamingPaused(true);
      // Cancel the current request
      _currentRequestCancelToken?.cancel('Request paused by user');
    }
  }

  void resumeStreaming() {
    if (_isStreaming && _isStreamingPaused) {
      _setStreamingPaused(false);
      // Note: We can't resume a cancelled request, so this would need to restart
      // For now, we'll just update the UI state
    }
  }

  void stopStreaming() {
    _currentRequestCancelToken?.cancel('Request stopped by user');
    _currentRequestCancelToken = null;
    _setStreaming(false);
    _setStreamingPaused(false);
    _setSendingMessage(false);
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Get model by ID
  AIModel? getModelById(String modelId) {
    try {
      return _availableModels.firstWhere((model) => model.id == modelId);
    } catch (e) {
      return null;
    }
  }

  // Rename chat conversation
  Future<void> renameChatConversation(String chatId, String newTitle) async {
    try {
      // Update via API
      await _apiService.renameChat(chatId, newTitle);
      
      // Update local state
      final previewIndex = _chatPreviews.indexWhere((preview) => preview.id == chatId);
      if (previewIndex != -1) {
        final currentPreview = _chatPreviews[previewIndex];
        _chatPreviews[previewIndex] = ChatPreview(
          id: currentPreview.id,
          title: newTitle,
          model: currentPreview.model,
          lastMessage: currentPreview.lastMessage,
          createdAt: currentPreview.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      
      // Update current chat if it's the one being renamed
      if (_currentChat?.id == chatId) {
        _currentChat = _currentChat!.copyWith(title: newTitle);
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to rename chat: ${e.toString()}');
    }
  }
  
  // Delete chat conversation
  Future<void> deleteChatConversation(String chatId) async {
    try {
      // Delete via API
      await _apiService.deleteChat(chatId);
      
      // Remove from previews
      _chatPreviews.removeWhere((preview) => preview.id == chatId);
      
      // Clear current chat if it's the one being deleted
      if (_currentChat?.id == chatId) {
        _currentChat = null;
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete chat: ${e.toString()}');
    }
  }

  // Check if has active chat
  bool get hasActiveChat {
    final hasChat = _currentChat != null;
    print('hasActiveChat: $hasChat, currentChat: ${_currentChat?.id}');
    return hasChat;
  }

  // Update current chat (used for marking messages as animated)
  void updateCurrentChat(Chat updatedChat) {
    _currentChat = updatedChat;
    notifyListeners();
  }

  // Regenerate last AI message
  Future<void> regenerateLastMessage() async {
    if (_currentChat == null || _currentChat!.messages.isEmpty) return;

    _clearError();

    try {
      // Find the last AI message and its preceding user message
      final messages = _currentChat!.messages;
      int lastAiIndex = -1;
      int userIndex = -1;

      for (int i = messages.length - 1; i >= 0; i--) {
        if (lastAiIndex == -1 && messages[i].role == 'assistant') {
          lastAiIndex = i;
        } else if (lastAiIndex != -1 && messages[i].role == 'user') {
          userIndex = i;
          break;
        }
      }

      if (lastAiIndex == -1 || userIndex == -1) {
        _setError('No messages to regenerate');
        return;
      }

      final userMessage = messages[userIndex];
      
      // Remove the last AI message
      final updatedMessages = List<Message>.from(messages)..removeAt(lastAiIndex);
      _currentChat = _currentChat!.copyWith(messages: updatedMessages);
      notifyListeners();

      // Start regenerating
      _setSendingMessage(true);
      _setStreaming(true);

      // Create cancellation token for this request
      _currentRequestCancelToken = CancelToken();

      // Send regeneration request
      final response = await _apiService.sendMessage(
        chatId: _currentChat!.id,
        content: userMessage.content,
        images: userMessage.images,
        model: _selectedModel,
        cancelToken: _currentRequestCancelToken,
      );

      // Add new AI response
      final newAiMessage = Message.fromJson(response['aiMessage']);
      final finalMessages = List<Message>.from(_currentChat!.messages)..add(newAiMessage);

      _currentChat = _currentChat!.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );

      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
      notifyListeners();

    } catch (e) {
      // Handle cancellation gracefully
      if (e is DioException && e.type == DioExceptionType.cancel) {
        print('Regeneration request was cancelled by user');
        // Don't show error for user-initiated cancellation
      } else {
        _setError('Failed to regenerate message: ${e.toString()}');
      }
      
      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
    }
  }

  // Regenerate last AI message with specific model
  Future<void> regenerateLastMessageWithModel(String modelId) async {
    final previousModel = _selectedModel;
    
    try {
      // Temporarily switch to the requested model
      _selectedModel = modelId;
      await regenerateLastMessage();
    } catch (e) {
      // Restore previous model on error
      _selectedModel = previousModel;
      rethrow;
    } finally {
      // Always restore the previous model after regeneration
      _selectedModel = previousModel;
      notifyListeners();
    }
  }

  // Update user message content
  Future<void> updateUserMessage(String messageId, String newContent) async {
    if (_currentChat == null) return;

    try {
      // Find and update the message
      final messages = List<Message>.from(_currentChat!.messages);
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      
      if (messageIndex == -1) {
        throw Exception('Message not found');
      }

      // Update the message content
      messages[messageIndex] = messages[messageIndex].copyWith(content: newContent);
      
      // Update the current chat
      _currentChat = _currentChat!.copyWith(
        messages: messages,
        updatedAt: DateTime.now(),
      );

      notifyListeners();

      // Optionally update on server (implement later if needed)
      // await _apiService.updateMessage(messageId, newContent);
    } catch (e) {
      _setError('Failed to update message: ${e.toString()}');
    }
  }

  // Editing message state
  String? _editingMessageId;
  String? _editingMessageContent;

  String? get editingMessageId => _editingMessageId;
  String? get editingMessageContent => _editingMessageContent;

  void setEditingMessage(String messageId, String content) {
    _editingMessageId = messageId;
    _editingMessageContent = content;
    notifyListeners();
  }

  void clearEditingMessage() {
    _editingMessageId = null;
    _editingMessageContent = null;
    notifyListeners();
  }

  // Send edited message and regenerate (using same method as regenerate)
  Future<void> sendEditedMessage(String newContent) async {
    if (_editingMessageId == null || _currentChat == null) return;

    _clearError();

    try {
      // Find the message being edited
      final messages = List<Message>.from(_currentChat!.messages);
      final messageIndex = messages.indexWhere((msg) => msg.id == _editingMessageId);
      
      if (messageIndex == -1) {
        throw Exception('Message not found');
      }

      // Update the edited message content (keep the same ID)
      final editedMessage = messages[messageIndex].copyWith(content: newContent);
      
      // Remove all messages after the edited message (including AI responses)
      final messagesToKeep = messages.take(messageIndex).toList();
      messagesToKeep.add(editedMessage);

      // Update the chat with the edited message
      _currentChat = _currentChat!.copyWith(
        messages: messagesToKeep,
        updatedAt: DateTime.now(),
      );

      // Clear editing state
      clearEditingMessage();
      
      notifyListeners();

      // Start regenerating (same as regenerateLastMessage)
      _setSendingMessage(true);
      _setStreaming(true);

      // Create cancellation token for this request
      _currentRequestCancelToken = CancelToken();

      // Send the edited message to get new AI response (same as regeneration)
      final response = await _apiService.sendMessage(
        chatId: _currentChat!.id,
        content: newContent,
        images: editedMessage.images, // Keep original images if any
        model: _selectedModel,
        cancelToken: _currentRequestCancelToken,
      );

      // Add new AI response
      final aiMessage = Message.fromJson(response['aiMessage']);
      final finalMessages = List<Message>.from(_currentChat!.messages)..add(aiMessage);

      _currentChat = _currentChat!.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );

      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
      notifyListeners();

      // Refresh chat previews
      await loadChatPreviews();

    } catch (e) {
      // Handle cancellation gracefully
      if (e is DioException && e.type == DioExceptionType.cancel) {
        print('Edited message request was cancelled by user');
        // Don't show error for user-initiated cancellation
      } else {
        _setError('Failed to send edited message: ${e.toString()}');
      }
      
      _setSendingMessage(false);
      _setStreaming(false);
      _currentRequestCancelToken = null;
    }
  }

  // Track when message animation completes
  void onMessageAnimationComplete() {
    // Only update streaming state if we're currently streaming
    if (_isStreaming && !_isSendingMessage) {
      _setStreaming(false);
    }
  }
} 