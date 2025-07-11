import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../utils/text_encoding_utils.dart';
import 'chatgpt_message_renderer.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isLast;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLast = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> 
    with SingleTickerProviderStateMixin {
  
  Timer? _streamingTimer;
  String _displayText = '';
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isCopied = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    
    // Only animate for AI messages that haven't been animated before
    if (!widget.message.isUser) {
      if (!widget.message.hasAnimated) {
        // First time showing this message - animate it with ChatGPT-like streaming
        _startChatGPTLikeStreaming();
      } else {
        // Message has been animated before - show full text immediately
        _displayText = widget.message.content;
      }
    } else {
      _displayText = widget.message.content;
    }
  }

  void _startChatGPTLikeStreaming() {
    final fullText = widget.message.content;
    if (fullText.isEmpty) return;

    _isStreaming = true;
    _displayText = '';
    
    // Split text into tokens (words and punctuation) for realistic streaming
    final tokens = _tokenizeText(fullText);
    int currentTokenIndex = 0;
    
    // Start with immediate first token display
    if (tokens.isNotEmpty) {
      setState(() {
        _displayText = tokens[0];
      });
      currentTokenIndex = 1;
    }

    // Stream remaining tokens with variable timing like ChatGPT
    void scheduleNextToken() {
      if (currentTokenIndex >= tokens.length) {
        _isStreaming = false;
        // Mark message as animated when streaming completes
        if (mounted) {
          setState(() {});
          // Update the message in the provider to mark it as animated
          _markMessageAsAnimated();
        }
        return;
      }

      final currentToken = tokens[currentTokenIndex];
      final delay = _getTokenDelay(currentToken, currentTokenIndex > 0 ? tokens[currentTokenIndex - 1] : '');

      _streamingTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted) {
          setState(() {
            _displayText += currentToken;
          });
          
          currentTokenIndex++;
          scheduleNextToken();
        }
      });
    }

    scheduleNextToken();
  }

  void _markMessageAsAnimated() {
    // Update the message in the chat provider to prevent re-animation
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.currentChat != null) {
      final messages = List<Message>.from(chatProvider.currentMessages);
      final messageIndex = messages.indexWhere((msg) => msg.id == widget.message.id);
      
      if (messageIndex != -1) {
        messages[messageIndex] = widget.message.copyWith(hasAnimated: true);
        final updatedChat = chatProvider.currentChat!.copyWith(messages: messages);
        chatProvider.updateCurrentChat(updatedChat);
      }
    }
  }

  int _getTokenDelay(String currentToken, String previousToken) {
    // ChatGPT-like variable timing based on content
    
    // Faster streaming for regular words (like ChatGPT's normal pace)
    if (currentToken.trim().isEmpty) return 10; // Spaces are very fast
    
    // Slower for punctuation (natural pause)
    if (RegExp(r'^[.!?]+$').hasMatch(currentToken.trim())) {
      return 80; // Pause after sentences
    }
    
    if (RegExp(r'^[,;:]+$').hasMatch(currentToken.trim())) {
      return 40; // Brief pause for commas/semicolons
    }
    
    // Slower for code-related content
    if (currentToken.contains('```') || currentToken.contains('`')) {
      return 60;
    }
    
    // Slower for special characters and symbols
    if (RegExp(r'[{}()\[\]<>"]').hasMatch(currentToken)) {
      return 50;
    }
    
    // Variable speed based on word length (longer words stream slightly slower)
    final wordLength = currentToken.trim().length;
    if (wordLength > 8) return 35; // Longer words
    if (wordLength > 5) return 25; // Medium words
    
    // Fast streaming for regular short words (ChatGPT's typical speed)
    return 20;
  }

  List<String> _tokenizeText(String text) {
    // Split text into realistic token chunks similar to how ChatGPT streams
    final List<String> tokens = [];
    
    // Handle code blocks separately to maintain proper formatting
    if (text.contains('```')) {
      return _tokenizeWithCodeBlocks(text);
    }
    
    final words = text.split(' ');
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      
      if (i == 0) {
        // First word appears immediately
        tokens.add(word);
      } else {
        // Add space + word as one token (this mimics ChatGPT's behavior)
        tokens.add(' $word');
      }
      
      // For words with punctuation, sometimes split the punctuation as separate token
      if (word.contains(RegExp(r'[.!?:;,]')) && word.length > 2) {
        final lastChar = word[word.length - 1];
        if (RegExp(r'[.!?]').hasMatch(lastChar)) {
          // Remove punctuation from current token and add it as next token
          final lastTokenIndex = tokens.length - 1;
          tokens[lastTokenIndex] = tokens[lastTokenIndex].substring(0, tokens[lastTokenIndex].length - 1);
          tokens.add(lastChar);
        }
      }
    }
    
    return tokens;
  }

  List<String> _tokenizeWithCodeBlocks(String text) {
    // Special handling for text with code blocks
    final List<String> tokens = [];
    final lines = text.split('\n');
    bool inCodeBlock = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        tokens.add(i == 0 ? line : '\n$line');
        continue;
      }
      
      if (inCodeBlock) {
        // Stream code lines faster but as complete lines
        tokens.add(i == 0 ? line : '\n$line');
      } else {
        // Regular text tokenization
        final words = line.split(' ');
        for (int j = 0; j < words.length; j++) {
          final word = words[j];
          if (i == 0 && j == 0) {
            tokens.add(word);
          } else if (j == 0) {
            tokens.add('\n$word');
          } else {
            tokens.add(' $word');
          }
        }
      }
    }
    
    return tokens;
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isUser) {
      return _buildUserMessage();
    } else {
      return _buildAIMessage();
    }
  }

  Widget _buildUserMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
      child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8), // Light gray user message background
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // Images if any
                  if (widget.message.hasImages) ...[
                    _buildImages(),
                    if (widget.message.content.isNotEmpty) 
                      const SizedBox(height: 8),
                  ],
                  
                  // Text content
                  if (widget.message.content.isNotEmpty)
                    ChatGPTMessageRenderer(
                      content: widget.message.content,
                      baseStyle: const TextStyle(
                        color: Color(0xFF202123),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
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

  Widget _buildAIMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.95,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Images if any
                          if (widget.message.hasImages) ...[
                            _buildImages(),
                            if (widget.message.content.isNotEmpty) 
                              const SizedBox(height: 8),
                          ],
                          
                      // Text content with advanced formatting
                          if (widget.message.content.isNotEmpty)
                        _buildAdvancedContent(),
                    ],
                                ),
                              ),
                            ),
                        ],
          ),
          
          // Action buttons for AI messages
          const SizedBox(height: 8),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildAdvancedContent() {
    return ChatGPTMessageRenderer(
      content: _isStreaming ? '$_displayText●' : _displayText, // Add cursor while streaming
      baseStyle: const TextStyle(
        color: Color(0xFF202123),
        fontSize: 16, // Using 16px like original ChatGPT
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
    );
  }

  // Advanced ChatGPT-style content formatting
  Widget _buildChatGPTFormattedContent(String text, {TextStyle? baseStyle}) {
    final style = baseStyle ?? const TextStyle(
      color: Color(0xFF202123),
      fontSize: 16, // Increased from 14 to 16 to match original ChatGPT
      fontWeight: FontWeight.w400,
      height: 1.5, // Slightly increased line height for better readability
    );

    // Parse the content into structured sections
    return _parseAndRenderStructuredContent(text, style);
  }

  Widget _parseAndRenderStructuredContent(String text, TextStyle baseStyle) {
    final List<Widget> contentWidgets = [];
    final lines = text.split('\n');
    
    String currentSection = '';
    bool inCodeBlock = false;
    String codeBlockContent = '';
    String codeLanguage = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Handle code blocks
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // End of code block
          contentWidgets.add(_buildCodeBlock(codeBlockContent, codeLanguage, baseStyle));
          contentWidgets.add(const SizedBox(height: 16));
          codeBlockContent = '';
          codeLanguage = '';
          inCodeBlock = false;
        } else {
          // Start of code block
          if (currentSection.isNotEmpty) {
            contentWidgets.add(_buildTextContent(currentSection, baseStyle));
            contentWidgets.add(const SizedBox(height: 12));
            currentSection = '';
          }
          codeLanguage = line.trim().substring(3); // Extract language
          inCodeBlock = true;
        }
        continue;
      }
      
      if (inCodeBlock) {
        if (codeBlockContent.isNotEmpty) codeBlockContent += '\n';
        codeBlockContent += line;
        continue;
      }
      
      // Check for numbered sections with diamonds
      if (_isNumberedSection(line)) {
        if (currentSection.isNotEmpty) {
          contentWidgets.add(_buildTextContent(currentSection, baseStyle));
          contentWidgets.add(const SizedBox(height: 16));
          currentSection = '';
        }
        contentWidgets.add(_buildNumberedSection(line, baseStyle));
        contentWidgets.add(const SizedBox(height: 12));
        continue;
      }
      
      // Regular content
      if (currentSection.isNotEmpty) currentSection += '\n';
      currentSection += line;
    }
    
    // Handle any remaining content
    if (inCodeBlock && codeBlockContent.isNotEmpty) {
      contentWidgets.add(_buildCodeBlock(codeBlockContent, codeLanguage, baseStyle));
    } else if (currentSection.isNotEmpty) {
      contentWidgets.add(_buildTextContent(currentSection, baseStyle));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  bool _isNumberedSection(String line) {
    // Check for patterns like "1. Basic Structure" or "♦ 1. Basic Structure"
    return RegExp(r'^\s*(\d+\.\s+.+|♦\s*\d+\.\s+.+)').hasMatch(line.trim());
  }

  Widget _buildNumberedSection(String line, TextStyle baseStyle) {
    final trimmed = line.trim();
    String sectionText = trimmed;
    
    // Remove existing diamond if present
    if (sectionText.startsWith('♦')) {
      sectionText = sectionText.substring(1).trim();
    }
    
    return Container(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue diamond bullet
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            child: const Icon(
              Icons.diamond,
              color: Color(0xFF1976D2), // Blue diamond
              size: 12,
            ),
          ),
          
          // Section content - use TextEncodingUtils to remove ** symbols
          Expanded(
            child: RichText(
              text: TextEncodingUtils.processMarkdownText(
                sectionText,
                baseStyle: baseStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: const Color(0xFF000000),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code, String language, TextStyle baseStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language header with copy button
          if (language.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language,
                    style: baseStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _copyCodeToClipboard(code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.content_copy,
                            size: 12,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy code',
                            style: baseStyle.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Code content with syntax highlighting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: _buildSyntaxHighlightedCode(code, language, baseStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildSyntaxHighlightedCode(String code, String language, TextStyle baseStyle) {
    // Enhanced syntax highlighting for C++ and other languages
    return RichText(
      text: _applySyntaxHighlighting(code, language, baseStyle),
    );
  }

  TextSpan _applySyntaxHighlighting(String code, String language, TextStyle baseStyle) {
    final codeStyle = baseStyle.copyWith(
      fontFamily: 'Consolas',
      fontSize: 13,
      height: 1.4,
      color: const Color(0xFF1F2937),
    );

    if (language.toLowerCase() == 'cpp' || language.toLowerCase() == 'c++') {
      return _applyCppSyntaxHighlighting(code, codeStyle);
    }
    
    // Default code formatting
    return TextSpan(text: code, style: codeStyle);
  }

  TextSpan _applyCppSyntaxHighlighting(String code, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    
    // C++ keywords and patterns
    final keywordPattern = RegExp(r'\b(int|float|double|char|bool|string|void|class|public|private|protected|if|else|for|while|do|return|include|using|namespace|std|cout|cin|endl)\b');
    final stringPattern = RegExp(r'"([^"]*)"');
    final commentPattern = RegExp(r'//.*$', multiLine: true);
    final includePattern = RegExp(r'#include\s*<([^>]+)>');
    final numberPattern = RegExp(r'\b\d+\b');
    
    final lines = code.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      int lastIndex = 0;
      final lineSpans = <TextSpan>[];
      
      // Find all matches in this line
      final allMatches = <Map<String, dynamic>>[];
      
      // Keywords
      for (final match in keywordPattern.allMatches(line)) {
        allMatches.add({
          'match': match,
          'type': 'keyword',
          'color': const Color(0xFF9333EA), // Purple for keywords
        });
      }
      
      // Strings
      for (final match in stringPattern.allMatches(line)) {
        allMatches.add({
          'match': match,
          'type': 'string',
          'color': const Color(0xFF059669), // Green for strings
        });
      }
      
      // Comments
      for (final match in commentPattern.allMatches(line)) {
        allMatches.add({
          'match': match,
          'type': 'comment',
          'color': const Color(0xFF6B7280), // Gray for comments
        });
      }
      
      // Include statements
      for (final match in includePattern.allMatches(line)) {
        allMatches.add({
          'match': match,
          'type': 'include',
          'color': const Color(0xFFDC2626), // Red for includes
        });
      }
      
      // Numbers
      for (final match in numberPattern.allMatches(line)) {
        allMatches.add({
          'match': match,
          'type': 'number',
          'color': const Color(0xFF2563EB), // Blue for numbers
        });
      }
      
      // Sort matches by start position
      allMatches.sort((a, b) => (a['match'] as RegExpMatch).start.compareTo((b['match'] as RegExpMatch).start));
      
      // Build spans for this line
      for (final matchInfo in allMatches) {
        final match = matchInfo['match'] as RegExpMatch;
        final type = matchInfo['type'] as String;
        final color = matchInfo['color'] as Color;
        
        // Add text before match
        if (match.start > lastIndex) {
          lineSpans.add(TextSpan(
            text: line.substring(lastIndex, match.start),
            style: baseStyle,
          ));
        }
        
        // Add colored match
        lineSpans.add(TextSpan(
          text: match.group(0),
          style: baseStyle.copyWith(color: color),
        ));
        
        lastIndex = match.end;
      }
      
      // Add remaining text
      if (lastIndex < line.length) {
        lineSpans.add(TextSpan(
          text: line.substring(lastIndex),
          style: baseStyle,
        ));
      }
      
      // Add line spans to main spans
      spans.addAll(lineSpans);
      
      // Add newline if not last line
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    
    return TextSpan(children: spans);
  }

  Widget _buildTextContent(String text, TextStyle baseStyle) {
    return RichText(
      text: TextEncodingUtils.processMarkdownText(text, baseStyle: baseStyle),
    );
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build rich text with ChatGPT-like formatting
  Widget _buildFormattedContent(String text, {TextStyle? baseStyle}) {
    return RichText(
      text: TextEncodingUtils.processMarkdownText(text, baseStyle: baseStyle),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    // Only show action buttons for AI messages (not user messages)
    if (widget.message.isUser) {
      return const SizedBox.shrink();
    }

    // Don't show action buttons while streaming - they appear after animation completes
    if (_isStreaming) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Copy button
          _ActionButton(
            icon: Icons.content_copy_outlined,
            onTap: () => _copyToClipboard(context),
            isActive: _isCopied,
          ),
          
          const SizedBox(width: 12),
          
          // Like button
          _ActionButton(
            icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            onTap: _toggleLike,
            isActive: _isLiked,
          ),
          
          const SizedBox(width: 12),
          
          // Dislike button
          _ActionButton(
            icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
            onTap: _toggleDislike,
            isActive: _isDisliked,
          ),
          
          const SizedBox(width: 12),
          
          // Regenerate button
          _ActionButton(
            icon: Icons.refresh,
            onTap: () => _showRegenerateContainer(context),
            isActive: false,
          ),
        ],
      ),
    );
  }

  void _showRegenerateContainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RegenerateContainer(),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
      } else {
        _isLiked = true;
        _isDisliked = false; // Can't like and dislike at the same time
      }
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLiked ? 'Response rated as helpful' : 'Rating removed'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleDislike() {
    setState(() {
      if (_isDisliked) {
        _isDisliked = false;
      } else {
        _isDisliked = true;
        _isLiked = false; // Can't like and dislike at the same time
      }
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isDisliked ? 'Response rated as unhelpful' : 'Rating removed'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildImages() {
    if (widget.message.images.length == 1) {
      return _buildSingleImage(widget.message.images.first);
    } else {
      return _buildMultipleImages();
    }
  }

  Widget _buildSingleImage(MessageImage image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _isLocalFile(image.url) 
        ? Image.file(
            File(image.url),
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImageError(200),
          )
        : CachedNetworkImage(
        imageUrl: image.url,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10A37F)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildImageError(200),
          ),
    );
  }

  bool _isLocalFile(String url) {
    return !url.startsWith('http') && !url.startsWith('https');
  }

  Widget _buildMultipleImages() {
    final images = widget.message.images;
    
    if (images.length == 2) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLocalFile(images[0].url)
                ? Image.file(
                    File(images[0].url),
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImageError(150),
                  )
                : CachedNetworkImage(
                    imageUrl: images[0].url,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildImagePlaceholder(150),
                    errorWidget: (context, url, error) => _buildImageError(150),
                  ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLocalFile(images[1].url)
                ? Image.file(
                    File(images[1].url),
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildImageError(150),
                  )
                : CachedNetworkImage(
                    imageUrl: images[1].url,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildImagePlaceholder(150),
                    errorWidget: (context, url, error) => _buildImageError(150),
                  ),
            ),
          ),
        ],
      );
    }

    // For 3+ images, show grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: images.length > 4 ? 4 : images.length,
      itemBuilder: (context, index) {
        if (index == 3 && images.length > 4) {
          // Show "+X more" overlay for last item
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLocalFile(images[index].url)
                  ? Image.file(
                      File(images[index].url),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildImageError(null),
                    )
                  : CachedNetworkImage(
                      imageUrl: images[index].url,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildImagePlaceholder(null),
                      errorWidget: (context, url, error) => _buildImageError(null),
                    ),
              ),
              Container(
                  decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '+${images.length - 3}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isLocalFile(images[index].url)
            ? Image.file(
                File(images[index].url),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImageError(null),
              )
            : CachedNetworkImage(
                imageUrl: images[index].url,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildImagePlaceholder(null),
                errorWidget: (context, url, error) => _buildImageError(null),
              ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder(double? height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10A37F)),
        ),
      ),
    );
  }

  Widget _buildImageError(double? height) {
          return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Color(0xFF6B6C7E),
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            'Error',
            style: TextStyle(
              color: Color(0xFF6B6C7E),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Action button widget matching original ChatGPT style
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 18,
          color: isActive 
            ? const Color(0xFF10A37F)
            : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// Regenerate container widget matching original ChatGPT style
class _RegenerateContainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10A37F), Color(0xFF0F8C6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ChatGPT can make mistakes. Check important info.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    minimumSize: const Size(32, 32),
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Change model button
                _RegenerateAction(
                  icon: Icons.tune,
                  title: 'Change model',
                  subtitle: 'Choose a different model for this response',
                  onTap: () {
                    Navigator.pop(context);
                    _showModelSelector(context);
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Regenerate button
                _RegenerateAction(
                  icon: Icons.refresh,
                  title: 'Regenerate',
                  subtitle: 'Generate a new response',
                  onTap: () {
                    Navigator.pop(context);
                    _regenerateResponse(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showModelSelector(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
      backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
      ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose model',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D0E10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              
              // Model list
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: chatProvider.availableModels.length,
                      itemBuilder: (context, index) {
                        final model = chatProvider.availableModels[index];
                        final isSelected = model.id == chatProvider.selectedModel;
                        
                        return ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? const Color(0xFF10A37F).withOpacity(0.1)
                                : const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.psychology,
                              size: 18,
                              color: isSelected 
                                ? const Color(0xFF10A37F)
                                : const Color(0xFF6B7280),
                            ),
                          ),
                          title: Text(
                            model.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isSelected 
                                ? const Color(0xFF10A37F)
                                : const Color(0xFF0D0E10),
                            ),
                          ),
                          subtitle: Text(
                            model.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF10A37F),
                                size: 20,
                              )
                            : null,
                  onTap: () {
                            chatProvider.setSelectedModel(model.id);
                    Navigator.pop(context);
                            _regenerateWithModel(context, model.id);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _regenerateResponse(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    
    try {
      chatProvider.regenerateLastMessage();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating response: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _regenerateWithModel(BuildContext context, String modelId) {
    final chatProvider = context.read<ChatProvider>();
    
    try {
      chatProvider.regenerateLastMessageWithModel(modelId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating with $modelId: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Regenerate action item widget
class _RegenerateAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RegenerateAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D0E10),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
} 