import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/chat_provider.dart';
import '../services/file_service.dart';
import '../services/speech_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FileService _fileService = FileService();
  final SpeechService _speechService = SpeechService();
  final ImagePicker picker = ImagePicker();
  
  List<File> _selectedImages = [];
  bool _canSend = false;
  bool _isListening = false;
  String _speechText = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _exitController;
  late Animation<double> _exitAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _exitAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInOut,
    ));
    
    _messageController.addListener(_updateSendButton);
    _fadeController.forward();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    await _speechService.initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _fadeController.dispose();
    _exitController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  void _updateSendButton() {
    final canSend = _messageController.text.trim().isNotEmpty || _selectedImages.isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Main content area with smooth exit animation
          Expanded(
            child: AnimatedBuilder(
              animation: _exitAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - _exitAnimation.value)),
                  child: Opacity(
                    opacity: _exitAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height - 200, // Account for input section
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Title - adjusted to match original ChatGPT size
                              const Text(
                                'What can I help with?',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D0E10),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 48),
                              
                              // Action cards
                              _buildActionCards(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom input section - no gaps, sticks to bottom
          _buildInputSection(context),
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    final cards = [
      _ActionCard(
        icon: Icons.image_outlined,
        iconColor: const Color(0xFF10A37F),
        title: 'Create image',
        onTap: () => _handleActionCard('Create a detailed image of'),
      ),
      _ActionCard(
        icon: Icons.lightbulb_outline,
        iconColor: const Color(0xFFF59E0B),
        title: 'Brainstorm',
        onTap: () => _handleActionCard('Help me brainstorm'),
      ),
      _ActionCard(
        icon: Icons.description_outlined,
        iconColor: const Color(0xFFEF4444),
        title: 'Summarize text',
        onTap: () => _handleActionCard('Summarize this text:'),
      ),
      _ActionCard(
        icon: Icons.more_horiz,
        iconColor: const Color(0xFF6B7280),
        title: 'More',
        onTap: () => _handleActionCard(''),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: cards.map((card) => 
        TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (cards.indexOf(card) * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: card,
            );
          },
        ),
      ).toList(),
    );
  }

  void _handleActionCard(String prompt) {
    if (prompt.isNotEmpty) {
      _messageController.text = prompt;
      _updateSendButton();
    }
  }

  Widget _buildInputSection(BuildContext context) {
    return Container(
      // Remove all padding and make it stick to bottom
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selected images preview
              if (_selectedImages.isNotEmpty)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                _selectedImages[index],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
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
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              
              // Input field - Updated to match original ChatGPT style with repositioned icons
              Container(
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
                          controller: _messageController,
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
                              _sendMessage();
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
                          // Attach button
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
                          
                          // Send or Mic button
                          Consumer<ChatProvider>(
                            builder: (context, chatProvider, child) {
                              final isTyping = chatProvider.isSendingMessage;
                              final isStreaming = chatProvider.isStreaming;
                              final isStreamingPaused = chatProvider.isStreamingPaused;
                              
                              // Show pause/resume button during the entire streaming process
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
                                    if (isStreamingPaused) {
                                      chatProvider.resumeStreaming();
                                    } else {
                                      chatProvider.pauseStreaming();
                                    }
                                  },
                                );
                              } else if (_canSend) {
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
                                  onPressed: _sendMessage,
                                );
                              } else {
                                if (_isListening) {
                                  return _buildSpeechVisualization();
                                } else {
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
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final filesToSend = List<File>.from(_selectedImages);
    
    // Start exit animation immediately when user sends message
    _exitController.forward();
    
    // Clear input immediately for smooth UX
    _messageController.clear();
    setState(() {
      _selectedImages.clear();
      _canSend = false;
    });
    
    // Send message after starting animation
    try {
      await chatProvider.sendMessage(content, images: filesToSend);
    } catch (e) {
      // If error, restore the welcome screen
      _exitController.reverse();
      if (content.isNotEmpty) {
        _messageController.text = content;
      }
      if (filesToSend.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(filesToSend);
        });
      }
      _updateSendButton();
      
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
          _messageController.text = text;
          _updateSendButton();
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
        _messageController.text = _speechText;
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
          _selectedImages.addAll(files);
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

  Future<void> _selectFiles() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_camera, color: Color(0xFF6B7280)),
                ),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _selectedImages.add(File(image.path));
                    });
                    _updateSendButton();
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF6B7280)),
                ),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final List<XFile> images = await picker.pickMultiImage();
                  if (images.isNotEmpty) {
                    setState(() {
                      _selectedImages.addAll(images.map((image) => File(image.path)));
                    });
                    _updateSendButton();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _updateSendButton();
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 