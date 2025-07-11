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

  const MessageInput({
    super.key,
    required this.controller,
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
      ),
      child: SafeArea(
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
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 48,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach file button
                  Container(
                    margin: const EdgeInsets.only(left: 4, bottom: 4),
                    child: IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: Color(0xFF666666),
                        size: 22,
                      ),
                      onPressed: _selectFiles,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
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
                  
                  // Mic or Send button
                  Container(
                    margin: const EdgeInsets.only(right: 4, bottom: 4),
                    child: _canSend
                        ? _buildSendButton(isTyping)
                        : _buildMicButton(),
                  ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool isTyping) {
    if (isTyping) {
      // Show pause button while AI is generating response
      return IconButton(
        icon: const Icon(
          Icons.pause,
          color: Color(0xFF666666),
          size: 20,
        ),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE5E5E5),
          shape: const CircleBorder(),
          minimumSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          // TODO: Implement stop generation
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          // Add pause/stop functionality here
        },
      );
    } else {
      // Show send button
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
          color: Color(0xFF007AFF),
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
                          color: const Color(0xFF007AFF).withOpacity(1.0 - value),
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

  Future<void> _selectFiles() async {
    try {
      // Show camera/gallery options
      final source = await _showImageSourceDialog();
      if (source == null) return;
      
      List<File> files = [];
      
      if (source == ImageSource.camera) {
        final cameraFile = await _fileService.takePhoto();
        if (cameraFile != null) {
          files.add(cameraFile);
        }
      } else {
        // Pick from gallery
        files = await _fileService.pickImages(allowMultiple: true);
      }
      
      if (files.isNotEmpty) {
    setState(() {
          // Use List.from to create a growable list
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
  
  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                // Handle bar
              Container(
                  width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
                const SizedBox(height: 16),
                
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Camera option
              ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10A37F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF10A37F),
                    ),
                  ),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                
                // Gallery option
              ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                
                const SizedBox(height: 8),
            ],
          ),
        ),
        );
      },
    );
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
      // Send message with files
      await chatProvider.sendMessage(
        messageText.isEmpty ? 'Image' : messageText,
        images: filesToSend.isNotEmpty ? filesToSend : null,
      );
      
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
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
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
                        size: 12,
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