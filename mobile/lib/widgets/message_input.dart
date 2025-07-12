import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/chat_provider.dart';
import '../services/file_service.dart';
import '../services/speech_service.dart';
import '../services/openai_service.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const MessageInput({
    super.key,
    required this.controller,
    this.focusNode,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _canSend = false;
  bool _isListening = false;
  String _speechText = '';
  
  final FileService _fileService = FileService();
  final SpeechService _speechService = SpeechService();
  final OpenAIService _openAIService = OpenAIService();
  
  List<File> _selectedFiles = <File>[]; // Initialize as growable list
  List<bool> _uploadingStates = <bool>[]; // Initialize as growable list

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSendButton);
    _initializeSpeech();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSendButton);
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    await _speechService.initialize();
  }

  void _updateSendButton() {
    final canSend = widget.controller.text.trim().isNotEmpty || _selectedFiles.isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        // Add rounded corners only on top-left and top-right with more curvature
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        // Add slightly stronger shadow on top to distinguish from screen content
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, -3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        // Only apply safe area to bottom to avoid gaps
        top: false,
        child: Column(
          children: [
            // Selected files preview
            if (_selectedFiles.isNotEmpty)
              _buildFilePreview(),
            
            // Speech recognition indicator
            if (_isListening)
              _buildSpeechIndicator(),
            
            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
          final isImage = _fileService.isImageFile(file.path);
          
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: _ChatGPTImagePreview(
              file: file,
              isImage: isImage,
              onRemove: () => _removeFile(index),
              isUploading: _uploadingStates[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeechIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10A37F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              color: Color(0xFF10A37F),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Listening...',
                  style: TextStyle(
                    color: Color(0xFF10A37F),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_speechText.isNotEmpty)
                  Text(
                    _speechText,
                    style: const TextStyle(
                      color: Color(0xFF202123),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop, color: Color(0xFF10A37F)),
            onPressed: _stopListening,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final chatProvider = Provider.of<ChatProvider>(context);
    final isTyping = chatProvider.isSendingMessage;
    final isStreaming = chatProvider.isStreaming;
    final isStreamingPaused = chatProvider.isStreamingPaused;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 52,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text input area
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 32,
                        maxHeight: 80,
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        cursorColor: Colors.black,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF000000),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask anything',
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (_canSend) {
                            _sendMessageWithFiles();
                          }
                        },
                      ),
                    ),
                  ),
                  
                  // Bottom row with icons
                  Container(
                    height: 40,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Attach file button
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.attach_file,
                            color: Color(0xFF666666),
                            size: 22,
                          ),
                          iconSize: 22,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          offset: const Offset(0, -120),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'camera',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Camera',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'photos',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.photo,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Photos',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'files',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Files',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (String value) {
                            _handleAttachmentSelection(value);
                          },
                        ),
                        
                        // Dynamic button based on state
                        _buildActionButton(isTyping, isStreaming, isStreamingPaused),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isTyping, bool isStreaming, bool isStreamingPaused) {
    // Show pause/resume button during the entire streaming process (including content animation)
    if (isStreaming || isTyping) {
      return IconButton(
        icon: Icon(
          isStreamingPaused ? Icons.play_arrow : Icons.pause,
          color: const Color(0xFF666666),
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE5E5E5),
          shape: const CircleBorder(),
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          if (isStreamingPaused) {
            chatProvider.resumeStreaming();
          } else {
            chatProvider.pauseStreaming();
          }
        },
      );
    } else if (_canSend) {
      // Show send button when there's content to send
      return IconButton(
        icon: const Icon(
          Icons.arrow_upward,
          color: Colors.white,
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF000000),
          shape: const CircleBorder(),
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
        onPressed: _sendMessageWithFiles,
      );
    } else {
      // Show mic button when idle
      return _buildMicButton();
    }
  }

  Widget _buildMicButton() {
    if (_isListening) {
      // Show speech visualization when listening
      return _buildSpeechVisualization();
    } else {
      // Show mic button
      return IconButton(
        icon: const Icon(
          Icons.mic,
          color: Color(0xFF666666),
          size: 20,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
        onPressed: _startListening,
      );
    }
  }

  Widget _buildSpeechVisualization() {
    return GestureDetector(
      onTap: _stopListening,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated pulse rings
            ...List.generate(3, (index) => 
              TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 1000 + (index * 200)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 0.5),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF000000).withOpacity(1.0 - value),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Restart animation if still listening
                  if (_isListening && mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
            // Mic icon
            const Icon(
              Icons.mic,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAttachmentSelection(String value) async {
    try {
      List<File> files = [];
      if (value == 'camera') {
        final cameraFile = await _fileService.takePhoto();
        if (cameraFile != null) {
          files.add(cameraFile);
        }
      } else if (value == 'photos') {
        files = await _fileService.pickImages(allowMultiple: true);
             } else if (value == 'files') {
         files = await _fileService.pickAnyFile();
       }

      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles = List<File>.from(_selectedFiles)..addAll(files);
          _uploadingStates = List<bool>.from(_uploadingStates)..addAll(List.filled(files.length, false));
        });
        _updateSendButton();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  void _removeFile(int index) {
        setState(() {
      _selectedFiles.removeAt(index);
      _uploadingStates.removeAt(index);
        });
        _updateSendButton();
  }

  Future<void> _startListening() async {
    try {
      final hasPermission = await _speechService.requestMicrophonePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
        _speechText = '';
      });

      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _speechText = text;
            _isListening = false;
          });
        },
        onPartialResult: (text) {
          setState(() {
            _speechText = text;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting speech recognition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechService.stopListening();
      
      if (_speechText.isNotEmpty) {
        widget.controller.text = _speechText;
        _updateSendButton();
      }
      
      setState(() {
        _isListening = false;
        _speechText = '';
      });
    } catch (e) {
      setState(() {
        _isListening = false;
        _speechText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping speech recognition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Enhanced message sending with upload progress
  void _sendMessageWithFiles() async {
    if (widget.controller.text.trim().isEmpty && _selectedFiles.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messageText = widget.controller.text.trim();
    final filesToSend = List<File>.from(_selectedFiles); // Copy files before clearing
    
    // Clear input and files immediately for better UX
    widget.controller.clear();
    setState(() {
      _selectedFiles.clear();
      _uploadingStates.clear();
    });
    _updateSendButton();
    
    try {
      // Check if we're editing a message
      if (chatProvider.editingMessageId != null) {
        await chatProvider.sendEditedMessage(messageText);
      } else {
        // Send message with files
        await chatProvider.sendMessage(
          messageText.isEmpty ? 'Image' : messageText,
          images: filesToSend.isNotEmpty ? filesToSend : null,
        );
      }
      
    } catch (e) {
      // Restore message text and files on error
      if (messageText.isNotEmpty) {
        widget.controller.text = messageText;
      }
      
      if (filesToSend.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(filesToSend);
          _uploadingStates = List.filled(filesToSend.length, false);
        });
        _updateSendButton();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ChatGPT-like Image Preview Widget
class _ChatGPTImagePreview extends StatefulWidget {
  final File file;
  final bool isImage;
  final VoidCallback onRemove;
  final bool isUploading;

  const _ChatGPTImagePreview({
    required this.file,
    required this.isImage,
    required this.onRemove,
    required this.isUploading,
  });

  @override
  State<_ChatGPTImagePreview> createState() => _ChatGPTImagePreviewState();
}

class _ChatGPTImagePreviewState extends State<_ChatGPTImagePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12), // More rounded like ChatGPT
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.isImage
                        ? _buildImageContent()
                        : _buildFileContent(),
                  ),
                ),
                
                // Upload progress overlay
                if (widget.isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Remove button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageContent() {
    return Stack(
      children: [
        // Main image
        Positioned.fill(
          child: Image.file(
            widget.file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorContent();
            },
          ),
        ),
        
        // Shimmer effect while loading (simulating processing)
        if (widget.isUploading)
          Positioned.fill(
            child: _buildShimmerEffect(),
          ),
      ],
    );
  }

  Widget _buildFileContent() {
    final fileName = widget.file.path.split('/').last;
    final extension = fileName.split('.').last.toUpperCase();
    
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(extension),
            size: 24,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(height: 4),
          Text(
            extension,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              fileName.length > 12 ? '${fileName.substring(0, 12)}...' : fileName,
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xFF9CA3AF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      color: const Color(0xFFFEF2F2),
      child: const Center(
        child: Icon(
          Icons.error_outline,
          size: 24,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.0),
              ],
              stops: [
                (_animationController.value - 0.3).clamp(0.0, 1.0),
                _animationController.value,
                (_animationController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.attach_file;
    }
  }
} 