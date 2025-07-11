import 'package:flutter/material.dart';

/// Comprehensive text encoding utility to handle markdown symbols
/// and prevent them from appearing in the frontend UI
class TextEncodingUtils {
  
  /// Process text with markdown formatting and return styled TextSpan
  static TextSpan processMarkdownText(String rawText, {TextStyle? baseStyle}) {
    final style = baseStyle ?? const TextStyle(
      color: Color(0xFF202123),
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );

    // Clean and process the text
    String processedText = _cleanMarkdownText(rawText);
    
    // Convert to styled spans
    return _buildStyledTextSpans(processedText, style);
  }

  /// Clean markdown text by only fixing excessive symbol doubling
  static String _cleanMarkdownText(String text) {
    String cleaned = text;
    
    // Only clean up excessive symbol doubling, preserve proper markdown
    cleaned = _cleanStraySymbols(cleaned);
    
    return cleaned;
  }

  /// Process bold patterns and mark them for styling
  static String _processBoldPatterns(String text) {
    // Replace **text** with a marker for bold styling
    return text.replaceAllMapped(
      RegExp(r'\*\*([^*]+?)\*\*'),
      (match) => '<<BOLD_START>>${match.group(1)}<<BOLD_END>>'
    );
  }

  /// Process italic patterns and mark them for styling
  static String _processItalicPatterns(String text) {
    // Replace *text* with a marker for italic styling (avoid conflicts with bold)
    return text.replaceAllMapped(
      RegExp(r'(?<!<)(?<!\*)\*([^*\n]+?)\*(?!\*)(?!>)'),
      (match) => '<<ITALIC_START>>${match.group(1)}<<ITALIC_END>>'
    );
  }

  /// Process code patterns and mark them for styling
  static String _processCodePatterns(String text) {
    // Replace `code` with a marker for code styling
    return text.replaceAllMapped(
      RegExp(r'`([^`]+?)`'),
      (match) => '<<CODE_START>>${match.group(1)}<<CODE_END>>'
    );
  }

  /// Clean up any remaining stray markdown symbols - only remove EXCESSIVE doubling
  static String _cleanStraySymbols(String text) {
    String cleaned = text;
    
    // Remove excessive bold markers (3 or more asterisks in a row)
    cleaned = cleaned.replaceAll(RegExp(r'\*{3,}'), '**');
    
    // Remove excessive hash symbols (more than 6 hashes for headers)
    cleaned = cleaned.replaceAll(RegExp(r'^#{7,}', multiLine: true), '######');
    
    // Remove excessive underscores (more than 2 for formatting)
    cleaned = cleaned.replaceAll(RegExp(r'_{3,}'), '__');
    
    // Remove excessive tildes (more than 2 for strikethrough)
    cleaned = cleaned.replaceAll(RegExp(r'~{3,}'), '~~');
    
    // Remove excessive backticks (more than 3 for code blocks)
    cleaned = cleaned.replaceAll(RegExp(r'`{4,}'), '```');
    
    return cleaned;
  }

  /// Build styled TextSpan from processed text with markers
  static TextSpan _buildStyledTextSpans(String processedText, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    
    // Pattern to match our style markers
    final markerPattern = RegExp(
      r'<<(BOLD|ITALIC|CODE)_START>>(.*?)<<(BOLD|ITALIC|CODE)_END>>'
    );
    
    int lastIndex = 0;
    
    for (final match in markerPattern.allMatches(processedText)) {
      // Add text before the marker
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: processedText.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      
      // Get the style type and content
      final styleType = match.group(1);
      final content = match.group(2) ?? '';
      
      TextStyle styledTextStyle = baseStyle;
      
      switch (styleType) {
        case 'BOLD':
          styledTextStyle = baseStyle.copyWith(fontWeight: FontWeight.w600);
          break;
        case 'ITALIC':
          styledTextStyle = baseStyle.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'CODE':
          styledTextStyle = baseStyle.copyWith(
            fontFamily: 'Consolas',
            backgroundColor: const Color(0xFFF3F4F6),
            color: const Color(0xFFDC2626),
            fontSize: 13,
          );
          break;
      }
      
      spans.add(TextSpan(text: content, style: styledTextStyle));
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < processedText.length) {
      spans.add(TextSpan(
        text: processedText.substring(lastIndex),
        style: baseStyle,
      ));
    }
    
    return TextSpan(children: spans.isEmpty ? [TextSpan(text: processedText, style: baseStyle)] : spans);
  }

  /// Simple method to just remove all markdown symbols without styling
  static String removeAllMarkdownSymbols(String text) {
    String cleaned = text;
    
    // Remove all bold markers
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]*?)\*\*'), r'$1');
    
    // Remove all italic markers
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\*)\*([^*\n]*?)\*(?!\*)'), r'$1');
    
    // Remove all code markers
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]*?)`'), r'$1');
    
    // Remove all headers
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    
    // Remove strikethrough
    cleaned = cleaned.replaceAll(RegExp(r'~~([^~]*?)~~'), r'$1');
    
    // Remove underline
    cleaned = cleaned.replaceAll(RegExp(r'__([^_]*?)__'), r'$1');
    
    // Clean up any remaining symbols
    cleaned = cleaned.replaceAll(RegExp(r'[*_~`#]{1,}'), '');
    
    return cleaned.trim();
  }

  /// Debug method to see what symbols are in the text
  static Map<String, int> analyzeMarkdownSymbols(String text) {
    final symbols = <String, int>{};
    
    // Count different types of symbols
    symbols['**'] = RegExp(r'\*\*').allMatches(text).length;
    symbols['*'] = RegExp(r'(?<!\*)\*(?!\*)').allMatches(text).length;
    symbols['`'] = RegExp(r'`').allMatches(text).length;
    symbols['#'] = RegExp(r'#').allMatches(text).length;
    symbols['~~'] = RegExp(r'~~').allMatches(text).length;
    symbols['__'] = RegExp(r'__').allMatches(text).length;
    
    return symbols;
  }

  /// Test method to validate markdown processing
  static void testMarkdownProcessing() {
    final testCases = [
      '**Bold text**',
      '*Italic text*',
      '`Code text`',
      '### Header',
      '**Bones**: These are important',
      '1. **First item**',
      'Mix of **bold** and *italic* and `code`',
    ];
    
    print('=== Markdown Processing Tests ===');
    for (final test in testCases) {
      final cleaned = removeAllMarkdownSymbols(test);
      print('Input:  "$test"');
      print('Output: "$cleaned"');
      print('---');
    }
  }
} 