import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';


class ChatGPTMessageRenderer extends StatelessWidget {
  final String content;
  final TextStyle? baseStyle;
  final bool isDarkMode;

  const ChatGPTMessageRenderer({
    super.key,
    required this.content,
    this.baseStyle,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = baseStyle ?? _getSystemTextStyle();
    
    // Parse and render the content with ChatGPT-style formatting
    return _parseAndRenderContent(content, style, context);
  }

  TextStyle _getSystemTextStyle() {
    // Use system fonts like original ChatGPT
    if (Platform.isIOS) {
      return const TextStyle(
        fontFamily: '.SF Pro Text', // iOS system font
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: Color(0xFF000000),
      );
    } else {
      return GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: const Color(0xFF000000),
      );
    }
  }

  Widget _parseAndRenderContent(String text, TextStyle baseStyle, BuildContext context) {
    // Only clean excessive symbol doubling, preserve proper markdown
    final cleanedText = _cleanExcessiveSymbols(text);
    final sections = _detectContentSections(cleanedText);
    final widgets = <Widget>[];

    for (final section in sections) {
      switch (section.type) {
        case ContentType.markdown:
          widgets.add(_buildMarkdownSection(section.content, baseStyle, context));
          break;
        case ContentType.codeBlock:
          widgets.add(_buildCodeBlock(section.content, section.language ?? '', baseStyle));
          break;
        case ContentType.table:
          widgets.add(_buildTable(section.content, baseStyle));
          break;
        case ContentType.qaFormat:
          widgets.add(_buildQAFormat(section.content, baseStyle));
          break;
        case ContentType.noteBlock:
          widgets.add(_buildNoteBlock(section.content, section.noteType ?? NoteType.note, baseStyle));
          break;
        case ContentType.checklist:
          widgets.add(_buildChecklist(section.content, baseStyle));
          break;
        case ContentType.dialogue:
          widgets.add(_buildDialogue(section.content, baseStyle));
          break;
        case ContentType.comparison:
          widgets.add(_buildComparison(section.content, baseStyle));
          break;
        case ContentType.horizontalRule:
          widgets.add(_buildHorizontalRule());
          break;
        case ContentType.mathFormula:
          widgets.add(_buildMathFormula(section.content, baseStyle));
          break;
        case ContentType.definitionList:
          widgets.add(_buildDefinitionList(section.content, baseStyle));
          break;
        case ContentType.stepByStep:
          widgets.add(_buildStepByStep(section.content, baseStyle));
          break;
        case ContentType.timeline:
          widgets.add(_buildTimeline(section.content, baseStyle));
          break;
        case ContentType.asciiChart:
          widgets.add(_buildAsciiChart(section.content, baseStyle));
          break;
        case ContentType.collapsible:
          widgets.add(_buildCollapsible(section.content, baseStyle, section.title ?? 'Details'));
          break;
      }
      
      if (section != sections.last && section.type != ContentType.horizontalRule) {
        widgets.add(const SizedBox(height: 16));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<ContentSection> _detectContentSections(String text) {
    final sections = <ContentSection>[];
    final lines = text.split('\n');
    
    String currentContent = '';
    ContentType currentType = ContentType.markdown;
    String? currentLanguage;
    NoteType? currentNoteType;

    bool inCodeBlock = false;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Detect code blocks
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // End code block
          sections.add(ContentSection(
            type: ContentType.codeBlock,
            content: currentContent.trim(),
            language: currentLanguage,
          ));
          currentContent = '';
          inCodeBlock = false;
          currentType = ContentType.markdown;
        } else {
          // Start code block
          if (currentContent.trim().isNotEmpty) {
            sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          }
          currentContent = '';
          currentLanguage = line.trim().substring(3).trim();
          inCodeBlock = true;
          currentType = ContentType.codeBlock;
        }
        continue;
      }
      
      if (inCodeBlock) {
        currentContent += (currentContent.isEmpty ? '' : '\n') + line;
        continue;
      }
      
      // Detect Q&A format
      if (_isQAFormat(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.qaFormat) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.qaFormat;
      }
      
      // Detect note blocks
      else if (_isNoteBlock(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.noteBlock) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.noteBlock;
        currentNoteType = _getNoteType(line);
      }
      
      // Detect checklist
      else if (_isChecklist(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.checklist) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.checklist;
      }
      
      // Detect dialogue
      else if (_isDialogue(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.dialogue) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.dialogue;
      }
      
      // Detect table
      else if (_isTable(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.table) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.table;
      }
      
      // If we're building a table and encounter a non-table line, end the table
      else if (currentType == ContentType.table && !_isTable(line) && !line.contains('---')) {
        // Check if this looks like a summary/conclusion line
        final trimmed = line.trim();
        if (RegExp(r'^(This table|Summary|Note:|In summary|Overall|Conclusion)', caseSensitive: false).hasMatch(trimmed)) {
          // End the table and start new content
          sections.add(ContentSection(type: ContentType.table, content: currentContent.trim()));
          currentContent = line;
          currentType = ContentType.markdown;
          continue;
        }
      }
      
      // Detect horizontal rule
      else if (_isHorizontalRule(line)) {
        if (currentContent.trim().isNotEmpty) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        sections.add(ContentSection(type: ContentType.horizontalRule, content: ''));
        currentType = ContentType.markdown;
        continue;
      }
      
      // Detect math formula
      else if (_isMathFormula(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.mathFormula) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.mathFormula;
      }
      
      // Detect definition list
      else if (_isDefinitionList(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.definitionList) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.definitionList;
      }
      
      // Detect step by step
      else if (_isStepByStep(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.stepByStep) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.stepByStep;
      }
      
      // Detect timeline
      else if (_isTimeline(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.timeline) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.timeline;
      }
      
      // Detect ASCII chart
      else if (_isAsciiChart(line)) {
        if (currentContent.trim().isNotEmpty && currentType != ContentType.asciiChart) {
          sections.add(ContentSection(type: currentType, content: currentContent.trim()));
          currentContent = '';
        }
        currentType = ContentType.asciiChart;
      }
      
      // Continue building current section
      currentContent += (currentContent.isEmpty ? '' : '\n') + line;
    }
    
    // Add final section
    if (currentContent.trim().isNotEmpty) {
      sections.add(ContentSection(
        type: currentType,
        content: currentContent.trim(),
        language: currentLanguage,
        noteType: currentNoteType,
      ));
    }
    
    return sections.isEmpty ? [ContentSection(type: ContentType.markdown, content: text)] : sections;
  }

  bool _isQAFormat(String line) {
    return RegExp(r'^(Question|Q\d*|Answer|A\d*):').hasMatch(line.trim());
  }

  bool _isNoteBlock(String line) {
    return RegExp(r'^(Note|Tip|Warning|Important|Caution):').hasMatch(line.trim());
  }

  bool _isChecklist(String line) {
    return RegExp(r'^[\s]*[✅❌☑️✓×]\s').hasMatch(line.trim());
  }

  bool _isDialogue(String line) {
    return RegExp(r'^(User|Agent|Support|Customer|Assistant):').hasMatch(line.trim());
  }

  bool _isTable(String line) {
    return line.contains('|') && line.split('|').length >= 3;
  }

  bool _isHorizontalRule(String line) {
    final trimmed = line.trim();
    return RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed);
  }

  bool _isMathFormula(String line) {
    return RegExp(r'(\$\$.*\$\$|\\\[.*\\\]|\\begin\{.*\}.*\\end\{.*\})').hasMatch(line) ||
           RegExp(r'^(Formula|Equation):').hasMatch(line.trim());
  }

  bool _isDefinitionList(String line) {
    final trimmed = line.trim();
    
    // Don't treat regular sentences as definition lists
    // A definition list should be short terms followed by definitions
    if (trimmed.length > 100) return false; // Too long to be a definition term
    
    // Check if it has the basic pattern but exclude common sentence patterns
    final hasBasicPattern = RegExp(r'^[A-Za-z][^:]*:\s+[^\s]').hasMatch(trimmed);
    if (!hasBasicPattern) return false;
    
    // Exclude common sentence starters that aren't definitions
    if (RegExp(r'^(Question|Answer|User|Agent|Support|Customer|Assistant|Note|Tip|Warning|Important|Caution|Certainly|Let|Here|This|That|In|For|With|When|Where|Why|How|What|The|A|An):').hasMatch(trimmed)) {
      return false;
    }
    
    // Exclude sentences that are too conversational
    if (RegExp(r"(let's|we'll|you'll|I'll|can't|won't|don't|isn't|aren't|wasn't|weren't)").hasMatch(trimmed.toLowerCase())) {
      return false;
    }
    
    // Must be a short, simple term-definition pattern
    final colonIndex = trimmed.indexOf(':');
    if (colonIndex == -1) return false;
    
    final term = trimmed.substring(0, colonIndex).trim();
    final definition = trimmed.substring(colonIndex + 1).trim();
    
    // Term should be short and not contain common sentence words
    if (term.split(' ').length > 4) return false; // Too many words for a term
    if (definition.isEmpty) return false;
    
    return true;
  }

  bool _isStepByStep(String line) {
    return RegExp(r'^\d+\.\s+.+').hasMatch(line.trim()) ||
           RegExp(r'^Step\s+\d+:|^Phase\s+\d+:|^Stage\s+\d+:').hasMatch(line.trim());
  }

  bool _isTimeline(String line) {
    return RegExp(r'^\d{4}(-\d{2})?(-\d{2})?:|\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}:').hasMatch(line.trim()) ||
           RegExp(r'^(Timeline|History):').hasMatch(line.trim());
  }

  bool _isAsciiChart(String line) {
    final trimmed = line.trim();
    return (trimmed.contains('█') || trimmed.contains('▓') || trimmed.contains('▒') || 
            trimmed.contains('░') || trimmed.contains('■') || trimmed.contains('□') ||
            (trimmed.contains('|') && trimmed.contains('-') && trimmed.length > 10)) &&
           !_isTable(line);
  }

  bool _isCollapsible(String line) {
    return RegExp(r'^<details>|^<summary>|^Details:|^Show more:|^Expand:').hasMatch(line.trim());
  }

  NoteType _getNoteType(String line) {
    final lower = line.toLowerCase();
    if (lower.startsWith('tip:')) return NoteType.tip;
    if (lower.startsWith('warning:') || lower.startsWith('caution:')) return NoteType.warning;
    if (lower.startsWith('important:')) return NoteType.important;
    return NoteType.note;
  }

  Widget _buildMarkdownSection(String content, TextStyle baseStyle, BuildContext context) {
    // Clean the content before processing
    final cleanedContent = _removeUnwantedMarkdownSymbols(content);
    
    return MarkdownBody(
      data: cleanedContent,
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        h1: baseStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
        h2: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        h3: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        strong: baseStyle.copyWith(fontWeight: FontWeight.bold),
        em: baseStyle.copyWith(fontStyle: FontStyle.italic),
        code: baseStyle.copyWith(
          fontFamily: Platform.isIOS ? 'Menlo' : 'monospace',
          backgroundColor: const Color(0xFFF3F4F6),
          color: const Color(0xFFDC2626),
        ),
        listBullet: baseStyle,
        listIndent: 24,
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        blockquoteDecoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          border: const Border(left: BorderSide(color: Color(0xFF10A37F), width: 4)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          // Handle link taps
          Clipboard.setData(ClipboardData(text: href));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copied to clipboard')),
          );
        }
      },
    );
  }
  
  String _removeUnwantedMarkdownSymbols(String content) {
    String cleaned = content;
    
    // Remove standalone ** symbols
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\w)\*\*(?!\w)'), '');
    
    // Remove standalone ### symbols that aren't headers
    cleaned = cleaned.replaceAll(RegExp(r'^###\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'###(?!\s+[A-Za-z])'), '');
    
    // Remove standalone #### symbols
    cleaned = cleaned.replaceAll(RegExp(r'^####\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'####(?!\s+[A-Za-z])'), '');
    
    // Clean up multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Clean up empty lines with just symbols
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[#*]+\s*$', multiLine: true), '');
    
    return cleaned.trim();
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
                          const Icon(Icons.content_copy, size: 12, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text('Copy code', style: baseStyle.copyWith(fontSize: 11, color: const Color(0xFF6B7280))),
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
            padding: const EdgeInsets.all(16),
            child: HighlightView(
              code,
              language: language.isNotEmpty ? language : 'text',
              theme: githubTheme,
              textStyle: TextStyle(
                fontFamily: Platform.isIOS ? 'Menlo' : 'monospace',
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildTable(String content, TextStyle baseStyle) {
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return Text(content, style: baseStyle);
    }
    
    // Parse table headers and clean markdown symbols
    final headers = lines[0]
        .split('|')
        .map((e) => _cleanTableCell(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList();
    
    if (headers.isEmpty) {
      return Text(content, style: baseStyle);
    }
    
    final rows = <List<String>>[];
    
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      
      // Skip separator lines
      if (line.contains('---') || line.contains('═══')) continue;
      
      // Skip lines that don't look like table content (summary/conclusion lines)
      if (!line.contains('|') || line.split('|').length < 2) continue;
      
      // Skip lines that start with text like "This table", "Summary", etc.
      final trimmedLine = line.trim();
      if (RegExp(r'^(This table|Summary|Note:|In summary|Overall|Conclusion)', caseSensitive: false).hasMatch(trimmedLine)) {
        continue;
      }
      
      final cells = line
          .split('|')
          .map((e) => _cleanTableCell(e.trim()))
          .where((e) => e.isNotEmpty)
          .toList();
      
      if (cells.isNotEmpty && cells.length >= headers.length) {
        // Ensure all rows have same number of cells as headers
        while (cells.length < headers.length) {
          cells.add('');
        }
        if (cells.length > headers.length) {
          cells.removeRange(headers.length, cells.length);
        }
        rows.add(cells);
      }
    }
    
    if (rows.isEmpty) {
      return Text(content, style: baseStyle);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: headers.map((header) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: const Color(0xFFE5E7EB),
                        width: headers.indexOf(header) < headers.length - 1 ? 1 : 0,
                      ),
                    ),
                  ),
                  child: Text(
                    header,
                    style: baseStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              )).toList(),
            ),
          ),
          
          // Table rows
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final isLastRow = index == rows.length - 1;
            
            return Container(
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                borderRadius: isLastRow ? const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ) : null,
              ),
              child: Row(
                children: row.map((cell) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: const Color(0xFFE5E7EB),
                          width: row.indexOf(cell) < row.length - 1 ? 1 : 0,
                        ),
                        bottom: !isLastRow ? const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ) : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      cell,
                      style: baseStyle.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF1F2937),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                      softWrap: true,
                    ),
                  ),
                )).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
  
  String _cleanTableCell(String cell) {
    // Remove markdown symbols and clean up cell content
    return cell
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // Remove bold markdown
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // Remove italic markdown
        .replaceAll(RegExp(r'`(.+?)`'), r'$1') // Remove code markdown
        .replaceAll(RegExp(r'~~(.+?)~~'), r'$1') // Remove strikethrough
        .trim();
  }
  


  Widget _buildQAFormat(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      if (RegExp(r'^(Question|Q\d*):').hasMatch(line.trim())) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            line.trim(),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1976D2),
            ),
          ),
        ));
      } else if (RegExp(r'^(Answer|A\d*):').hasMatch(line.trim())) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.trim(),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
            ),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(line.trim(), style: baseStyle),
        ));
      }
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildNoteBlock(String content, NoteType noteType, TextStyle baseStyle) {
    Color backgroundColor;
    Color borderColor;
    IconData icon;
    Color iconColor;
    
    switch (noteType) {
      case NoteType.tip:
        backgroundColor = const Color(0xFFF0F9FF);
        borderColor = const Color(0xFF0EA5E9);
        icon = Icons.lightbulb_outline;
        iconColor = const Color(0xFF0EA5E9);
        break;
      case NoteType.warning:
        backgroundColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFF59E0B);
        icon = Icons.warning_outlined;
        iconColor = const Color(0xFFF59E0B);
        break;
      case NoteType.important:
        backgroundColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        icon = Icons.error_outline;
        iconColor = const Color(0xFFEF4444);
        break;
      case NoteType.note:
      default:
        backgroundColor = const Color(0xFFF8F9FA);
        borderColor = const Color(0xFF6B7280);
        icon = Icons.info_outline;
        iconColor = const Color(0xFF6B7280);
        break;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content.replaceFirst(RegExp(r'^(Note|Tip|Warning|Important|Caution):\s*'), ''),
              style: baseStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      bool isChecked = false;
      String text = line.trim();
      
      if (text.startsWith('✅') || text.startsWith('☑️') || text.startsWith('✓') || text.startsWith('✔️')) {
        isChecked = true;
        text = text.substring(text.startsWith('✔️') ? 2 : 1).trim();
      } else if (text.startsWith('❌') || text.startsWith('×') || text.startsWith('✗') || text.startsWith('❎')) {
        isChecked = false;
        text = text.substring(text.startsWith('❎') ? 2 : 1).trim();
      } else if (text.startsWith('⭕') || text.startsWith('🔴')) {
        isChecked = false;
        text = text.substring(2).trim();
      }
      
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isChecked ? Icons.check_circle : Icons.cancel,
              color: isChecked ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: baseStyle.copyWith(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ));
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildDialogue(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final match = RegExp(r'^(User|Agent|Support|Customer|Assistant):\s*(.*)').firstMatch(line.trim());
      if (match != null) {
        final speaker = match.group(1)!;
        final message = match.group(2)!;
        
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: speaker == 'User' || speaker == 'Customer' 
                ? const Color(0xFFE3F2FD) 
                : const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$speaker: ',
                  style: baseStyle.copyWith(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: message,
                  style: baseStyle,
                ),
              ],
            ),
          ),
        ));
      } else {
        widgets.add(Text(line.trim(), style: baseStyle));
      }
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildComparison(String content, TextStyle baseStyle) {
    // This will be handled by the table builder if it's a comparison table
    return Text(content, style: baseStyle);
  }

  Widget _buildHorizontalRule() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0xFFE5E7EB), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildMathFormula(String content, TextStyle baseStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: SelectableText(
          content,
          style: baseStyle.copyWith(
            fontFamily: Platform.isIOS ? 'Menlo' : 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDefinitionList(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        final term = line.substring(0, colonIndex).trim();
        final definition = line.substring(colonIndex + 1).trim();
        
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$term: ',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1976D2),
                  ),
                ),
                TextSpan(
                  text: definition,
                  style: baseStyle,
                ),
              ],
            ),
          ),
        ));
      } else {
        widgets.add(Text(line.trim(), style: baseStyle));
      }
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildStepByStep(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    int stepNumber = 1;
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      if (RegExp(r'^\d+\.\s+').hasMatch(line.trim())) {
        // It's already a numbered step
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF10A37F),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line.replaceFirst(RegExp(r'^\d+\.\s+'), ''),
                  style: baseStyle,
                ),
              ),
            ],
          ),
        ));
        stepNumber++;
      } else {
        // Regular content
        widgets.add(Text(line.trim(), style: baseStyle));
      }
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildTimeline(String content, TextStyle baseStyle) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      final isLast = i == lines.length - 1;
      
      widgets.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF10A37F),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: const Color(0xFFE5E7EB),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(line.trim(), style: baseStyle),
            ),
          ),
        ],
      ));
    }
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildAsciiChart(String content, TextStyle baseStyle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SelectableText(
        content,
        style: baseStyle.copyWith(
          fontFamily: Platform.isIOS ? 'Menlo' : 'monospace',
          fontSize: 12,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildCollapsible(String content, TextStyle baseStyle, String title) {
    return _CollapsibleSection(
      title: title,
      content: content,
      baseStyle: baseStyle,
    );
  }

  void _copyCodeToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
  }

  String _cleanExcessiveSymbols(String text) {
    String cleaned = text;
    
    // Remove excessive bold markers (3 or more asterisks in a row)
    cleaned = cleaned.replaceAll(RegExp(r'\*{3,}'), '**');
    
    // Remove standalone markdown symbols that aren't part of proper formatting
    // Remove standalone ** that aren't wrapping text
    cleaned = cleaned.replaceAll(RegExp(r'\*\*(?!\w)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\w)\*\*'), '');
    
    // Remove excessive hash symbols (more than 6 hashes for headers)
    cleaned = cleaned.replaceAll(RegExp(r'^#{7,}', multiLine: true), '######');
    
    // Remove standalone ### and #### that aren't proper headers
    cleaned = cleaned.replaceAll(RegExp(r'^####+\s*$', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'####+(?!\s+\w)'), '');
    
    // Remove excessive underscores (more than 2 for formatting)
    cleaned = cleaned.replaceAll(RegExp(r'_{3,}'), '__');
    
    // Remove excessive tildes (more than 2 for strikethrough)
    cleaned = cleaned.replaceAll(RegExp(r'~{3,}'), '~~');
    
    // Remove excessive backticks (more than 3 for code blocks)
    cleaned = cleaned.replaceAll(RegExp(r'`{4,}'), '```');
    
    // Clean up orphaned markdown symbols
    // Remove ** that don't have matching pairs
    cleaned = _cleanOrphanedBoldMarkers(cleaned);
    
    // Remove ### that aren't followed by header text
    cleaned = cleaned.replaceAll(RegExp(r'^###\s*$', multiLine: true), '');
    
    return cleaned;
  }
  
  String _cleanOrphanedBoldMarkers(String text) {
    // Find and remove ** that don't have proper pairs
    final lines = text.split('\n');
    final cleanedLines = <String>[];
    
    for (String line in lines) {
      String cleanedLine = line;
      
      // Count ** in the line
      final boldMarkers = RegExp(r'\*\*').allMatches(line).length;
      
      // If odd number of **, remove the last one
      if (boldMarkers % 2 != 0) {
        final lastIndex = line.lastIndexOf('**');
        if (lastIndex != -1) {
          cleanedLine = line.substring(0, lastIndex) + line.substring(lastIndex + 2);
        }
      }
      
      // Remove ** that are standalone (not wrapping text)
      cleanedLine = cleanedLine.replaceAll(RegExp(r'\*\*\s*\*\*'), '');
      cleanedLine = cleanedLine.replaceAll(RegExp(r'\*\*\s*$'), '');
      cleanedLine = cleanedLine.replaceAll(RegExp(r'^\s*\*\*'), '');
      
      cleanedLines.add(cleanedLine);
    }
    
    return cleanedLines.join('\n');
  }
}

// Data models
enum ContentType {
  markdown,
  codeBlock,
  table,
  qaFormat,
  noteBlock,
  checklist,
  dialogue,
  comparison,
  horizontalRule,
  mathFormula,
  definitionList,
  stepByStep,
  timeline,
  asciiChart,
  collapsible,
}

enum NoteType {
  note,
  tip,
  warning,
  important,
}

class ContentSection {
  final ContentType type;
  final String content;
  final String? language;
  final NoteType? noteType;
  final String? title;

  ContentSection({
    required this.type,
    required this.content,
    this.language,
    this.noteType,
    this.title,
  });
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final String content;
  final TextStyle baseStyle;

  const _CollapsibleSection({
    required this.title,
    required this.content,
    required this.baseStyle,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: widget.baseStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.content,
                style: widget.baseStyle,
              ),
            ),
        ],
      ),
    );
  }
} 