import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';

class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  String _searchQuery = '';
  String? _selectedChatId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Initialize slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _slideController.forward();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: 300, // Exact 300dp width as specified
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white, // Flat white surface, no elevation
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              _buildNavigationIcons(),
              Expanded(child: _buildChatList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ChatGPT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500, // Medium (500)
              color: Color(0xFF202123),
            ),
          ),
          IconButton(
            onPressed: () {
              // New chat functionality
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              chatProvider.createNewChat();
              Navigator.of(context).pop(); // Close sidebar
            },
            icon: const Icon(
              Icons.edit,
              size: 24,
              color: Color(0xFF4B5563),
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF202123),
        ),
      ),
    );
  }

  Widget _buildNavigationIcons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildNavIcon(Icons.menu, true), // Active menu icon
          const SizedBox(width: 24),
          _buildNavIcon(Icons.image_outlined, false), // Library
          const SizedBox(width: 24),
          _buildNavIcon(Icons.grid_view, false), // Explore GPTs
          const SizedBox(width: 24),
          _buildNavIcon(Icons.chat_bubble_outline, false), // Chats
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    return Icon(
      icon,
      size: 24,
      color: isActive ? const Color(0xFF10A37F) : const Color(0xFF9CA3AF),
    );
  }

  Widget _buildChatList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final chats = chatProvider.chatPreviews;
        final filteredChats = _searchQuery.isEmpty
            ? chats
            : chats.where((chat) =>
                chat.title.toLowerCase().contains(_searchQuery)).toList();

        if (filteredChats.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)), // Staggered animation
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildChatItem(chat, chatProvider),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatItem(ChatPreview chat, ChatProvider chatProvider) {
    final isSelected = _selectedChatId == chat.id;
    final timeAgo = _formatTimeAgo(chat.updatedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F7F2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: RichText(
          text: _buildFormattedTitle(chat.title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeAgo,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showChatOptions(context, chat, chatProvider),
              child: const Icon(
                Icons.more_vert,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedChatId = chat.id;
          });
          chatProvider.loadChat(chat.id);
          Navigator.of(context).pop(); // Close sidebar
        },
        onLongPress: () => _showChatOptions(context, chat, chatProvider),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No chats found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF10A37F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 32,
              color: Color(0xFF10A37F),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202123),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new chat to begin',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final chatProvider = Provider.of<ChatProvider>(context, listen: false);
              chatProvider.createNewChat();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10A37F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(BuildContext context, ChatPreview chat, ChatProvider chatProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF6B6C7E)),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, chat, chatProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Color(0xFF6B6C7E)),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                // Archive functionality would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Archive feature coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, chat, chatProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Color(0xFF6B6C7E)),
              title: const Text('Move to project'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Projects feature coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, ChatPreview chat, ChatProvider chatProvider) {
    final controller = TextEditingController(text: chat.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty && newTitle != chat.title) {
                chatProvider.renameChatConversation(chat.id, newTitle);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10A37F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatPreview chat, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${chat.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              chatProvider.deleteChat(chat.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat deleted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  TextSpan _buildFormattedTitle(String title) {
    final words = title.split(' ');
    final spans = <TextSpan>[];
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isNotEmpty) {
        // Make first letter of each word bold
        spans.add(TextSpan(
          text: word[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202123),
          ),
        ));
        
        // Add rest of the word in normal weight
        if (word.length > 1) {
          spans.add(TextSpan(
            text: word.substring(1),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202123),
            ),
          ));
        }
        
        // Add space between words (except for the last word)
        if (i < words.length - 1) {
          spans.add(const TextSpan(
            text: ' ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF202123),
            ),
          ));
        }
      }
    }
    
    return TextSpan(children: spans);
  }
} 