import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT Input Box Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  bool _isGeneratingResponse = false;

  void _handleSendMessage(String message) {
    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isGeneratingResponse = true;
    });

    // Simulate AI response after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _messages.add(ChatMessage(
          text: "This is a simulated response to: \"$message\"",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isGeneratingResponse = false;
      });
    });
  }

  void _handleMicPressed() {
    // Handle microphone functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone pressed!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('ChatGPT Input Box Demo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation!',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(message: message);
                    },
                  ),
          ),
          if (_isGeneratingResponse)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  SizedBox(width: 12),
            Text(
                    'AI is typing...',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ChatGPTInputBox(
            onSend: _handleSendMessage,
            onMicPressed: _handleMicPressed,
            isGeneratingResponse: _isGeneratingResponse,
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue : Colors.grey[800],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatGPTInputBox extends StatefulWidget {
  final Function(String message) onSend;
  final Function()? onMicPressed;
  final bool isGeneratingResponse;

  const ChatGPTInputBox({
    super.key,
    required this.onSend,
    this.onMicPressed,
    this.isGeneratingResponse = false,
  });

  @override
  State<ChatGPTInputBox> createState() => _ChatGPTInputBoxState();
}

class _ChatGPTInputBoxState extends State<ChatGPTInputBox>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _showMicUI = false;
  late AnimationController _micWaveController;

  @override
  void initState() {
    super.initState();
    _micWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _micWaveController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_controller.text.trim().isNotEmpty && !_isSending) {
      widget.onSend(_controller.text.trim());
      _controller.clear();
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: const [
          BoxShadow(
            color: Colors.white12,
            offset: Offset(0, -2),
            blurRadius: 6,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: _showMicUI
          ? _buildMicInputUI()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.image_not_supported_outlined,
                      color: Colors.white60),
                ),
                IconButton(
                  onPressed: () => setState(() => _showMicUI = true),
                  icon: const Icon(Icons.mic, color: Colors.white60),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 150,
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.isGeneratingResponse ? null : _handleSend,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.green,
                    child: Icon(
                      widget.isGeneratingResponse ? Icons.pause : Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMicInputUI() {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => _showMicUI = false),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'See text',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              FadeTransition(
                opacity: _micWaveController,
                child: Container(
                  height: 20,
                  width: 100,
                  color: Colors.white12,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: widget.onMicPressed,
            icon: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
