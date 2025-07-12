import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/chat_interface.dart';
import '../widgets/welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _showSidebar = false;
  late AnimationController _sidebarController;
  late Animation<Offset> _sidebarAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize sidebar animation
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _sidebarAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOut,
    ));
    
    // Initialize the chat provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
    
    if (_showSidebar) {
      _sidebarController.forward();
    } else {
      _sidebarController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content area
            Row(
              children: [
                // Sidebar (always visible on desktop)
                if (isDesktop)
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const ChatSidebar(),
                  ),
                
                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Top bar - ChatGPT style
                      _buildAppBar(context, isDesktop),
                      
                      // Chat content
                      Expanded(
                        child: Consumer<ChatProvider>(
                          builder: (context, chatProvider, child) {
                            if (chatProvider.hasActiveChat) {
                              return const ChatInterface();
                            } else {
                              return const WelcomeScreen();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Mobile sidebar overlay
            if (_showSidebar && !isDesktop) ...[
              // Backdrop
              GestureDetector(
                onTap: _toggleSidebar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: Colors.black.withOpacity(_showSidebar ? 0.5 : 0.0),
                ),
              ),
              
              // Sidebar
              SlideTransition(
                position: _sidebarAnimation,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(4, 0),
                      ),
                    ],
                  ),
                  child: const ChatSidebar(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDesktop) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Menu button (mobile only) or ChatGPT icon
            if (!isDesktop)
              IconButton(
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _showSidebar ? Icons.close : Icons.menu,
                    size: 24,
                    color: const Color(0xFF202123),
                  ),
                ),
                onPressed: _toggleSidebar,
                style: IconButton.styleFrom(
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10A37F), Color(0xFF0F8C6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            
            const SizedBox(width: 12),
            
            // Title - Always show "ChatGPT" like original app
            const Expanded(
              child: Text(
                'ChatGPT',
                style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202123),
                    ),
                    overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Action buttons
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                    // New chat button - shows as pencil icon when in active chat
                    if (chatProvider.hasActiveChat)
                      IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        chatProvider.createNewChat();
                        if (_showSidebar && !isDesktop) {
                          _toggleSidebar();
                        }
                      },
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF202123),
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'New chat',
                ),
                
                    // More options button - show always (both home screen and chat)
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                  ),
                  onPressed: () {
                    // Show more options menu
                    _showMoreOptions(context, chatProvider.hasActiveChat);
                  },
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF202123),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                  tooltip: 'More options',
                ),
              ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, bool hasActiveChat) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      items: [
        // Models - always show
        PopupMenuItem<String>(
          value: 'models',
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Models',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF202123),
                ),
              ),
            ],
          ),
        ),
        // View details - always show
        PopupMenuItem<String>(
          value: 'view_details',
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: Color(0xFF6B6C7E),
              ),
              const SizedBox(width: 12),
              const Text(
                'View details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF202123),
                ),
              ),
            ],
          ),
        ),
        // Rename and Delete - only show when there's an active chat
        if (hasActiveChat) ...[
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF6B6C7E),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Rename',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF202123),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFFE53E3E),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFE53E3E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'models':
            _showModelsBottomSheet(context);
            break;
          case 'view_details':
            _showViewDetailsPage(context);
            break;
          case 'rename':
            _showRenameDialog(context);
            break;
          case 'delete':
            _showDeleteDialog(context);
            break;
        }
      }
    });
  }

  void _showModelsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              return Container(
                padding: const EdgeInsets.all(24),
          child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
                    Center(
                      child: Container(
                        width: 36,
                height: 4,
                decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    const Text(
                      'Switch model',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Models list
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: chatProvider.availableModels.map((model) {
                          final isSelected = chatProvider.selectedModel == model.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                chatProvider.setSelectedModel(model.id);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Selection indicator
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected 
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFD1D5DB),
                                          width: 2,
                                        ),
                                        color: isSelected 
                                          ? const Color(0xFF3B82F6)
                                          : Colors.transparent,
                                      ),
                                      child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          )
                                        : null,
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Model info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                model.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected 
                                                    ? const Color(0xFF3B82F6)
                                                    : const Color(0xFF111827),
                                                ),
                                              ),
                                              if (model.name.contains('4.5'))
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3F4F6),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'RESEARCH PREVIEW',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            model.description,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF6B7280),
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
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showViewDetailsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            final selectedModel = chatProvider.getModelById(chatProvider.selectedModel);
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF111827),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'ChatGPT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                centerTitle: true,
              ),
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // ChatGPT icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SvgPicture.asset(
                            'assets/icons/icons8-chatgpt.svg',
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    const Text(
                      'ChatGPT',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Model Info section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Model Info',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Current model
                          Row(
                            children: [
                              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                  ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedModel?.name ?? 'GPT-4o',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      selectedModel?.description ?? 'Newest and most advanced model',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final currentChat = chatProvider.currentChat;
    
    if (currentChat == null) return;
    
    final controller = TextEditingController(text: currentChat.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF374151),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    final newTitle = controller.text.trim();
                    if (newTitle.isNotEmpty && newTitle != currentChat.title) {
                      chatProvider.renameChatConversation(currentChat.id!, newTitle);
                    }
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                  ),
                  child: const Text(
                    'Rename',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to delete this chat? To clear any memories from this chat, visit your ',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            GestureDetector(
              onTap: () {
                // Handle settings link
                Navigator.pop(context);
              },
              child: const Text(
                'settings',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF374151),
                  decoration: TextDecoration.underline,
                  height: 1.5,
                ),
              ),
            ),
            const Text(
              '.',
          style: TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 32),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      final chatProvider = context.read<ChatProvider>();
                      final currentChat = chatProvider.currentChat;
                      
                      if (currentChat?.id != null) {
                        chatProvider.deleteChatConversation(currentChat!.id!);
                        Navigator.pop(context); // Close dialog
                        // User returns to home screen automatically
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 