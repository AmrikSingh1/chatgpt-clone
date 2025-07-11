const express = require('express');
const router = express.Router();
const OpenAI = require('openai');
const { v4: uuidv4 } = require('uuid');
const Joi = require('joi');
const Chat = require('../models/Chat');
const fetch = require('node-fetch');

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Helper function to convert image URL to base64
async function convertImageUrlToBase64(imageUrl) {
  try {
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch image: ${response.statusText}`);
    }
    
    const buffer = await response.buffer();
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    const base64 = buffer.toString('base64');
    
    return `data:${contentType};base64,${base64}`;
  } catch (error) {
    console.error('Error converting image URL to base64:', error);
    throw error;
  }
}

// Validation schemas
const messageSchema = Joi.object({
  content: Joi.string().required().min(1).max(4000),
  images: Joi.array().items(Joi.object({
    url: Joi.string().uri().required(),
    publicId: Joi.string(),
    filename: Joi.string()
  })).optional()
});

  const chatSchema = Joi.object({
    chatId: Joi.string().optional(),
    model: Joi.string().valid('gpt-3.5-turbo', 'gpt-4', 'gpt-4o', 'gpt-4-turbo').default('gpt-3.5-turbo'),
    message: messageSchema.required()
  });

// GET /api/chat - Get all chats
router.get('/', async (req, res) => {
  try {
    const chats = await Chat.find({ isActive: true })
      .sort({ updatedAt: -1 })
      .select('id title model createdAt updatedAt messages')
      .limit(50);

    const chatList = chats.map(chat => ({
      id: chat.id,
      title: chat.title,
      model: chat.model,
      createdAt: chat.createdAt,
      updatedAt: chat.updatedAt,
      lastMessage: chat.messages.length > 0 ? chat.messages[chat.messages.length - 1].content.substring(0, 100) : ''
    }));

    res.json({
      success: true,
      data: chatList
    });
  } catch (error) {
    console.error('Error fetching chats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch chats'
    });
  }
});

// GET /api/chat/:id - Get specific chat
router.get('/:id', async (req, res) => {
  try {
    const chat = await Chat.findOne({ id: req.params.id, isActive: true });
    
    if (!chat) {
      return res.status(404).json({
        success: false,
        error: 'Chat not found'
      });
    }

    res.json({
      success: true,
      data: chat
    });
  } catch (error) {
    console.error('Error fetching chat:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch chat'
    });
  }
});

// POST /api/chat - Send message and get AI response
router.post('/', async (req, res) => {
  try {
    // Validate request
    const { error, value } = chatSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: error.details[0].message
      });
    }

    const { chatId, model, message } = value;
    let chat;

    // Find existing chat or create new one
    if (chatId) {
      chat = await Chat.findOne({ id: chatId, isActive: true });
      if (!chat) {
        return res.status(404).json({
          success: false,
          error: 'Chat not found'
        });
      }
      
      // Update the chat model to the user-selected model
      chat.model = model;
      console.log(`Updated chat ${chatId} to use model: ${model}`);
    } else {
      // Create new chat with AI-generated title
      let chatTitle = 'New Chat';
      try {
        // Generate AI title for the chat based on first message
        const titleCompletion = await openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: 'system',
              content: 'Generate a concise, descriptive title (max 5 words) for a chat conversation based on the user\'s first message. Only return the title, nothing else. Make it specific and informative.'
            },
            {
              role: 'user',
              content: message.content
            }
          ],
          max_tokens: 20,
          temperature: 0.7,
        });
        
        const generatedTitle = titleCompletion.choices[0].message.content?.trim();
        if (generatedTitle && generatedTitle.length > 0) {
          chatTitle = generatedTitle;
        }
      } catch (titleError) {
        console.error('Error generating chat title:', titleError);
        // Fallback to truncated content
        chatTitle = message.content.substring(0, 50) + (message.content.length > 50 ? '...' : '');
      }
      
      chat = new Chat({
        id: uuidv4(),
        title: chatTitle,
        model: model,
        messages: []
      });
      console.log(`Created new chat with AI-generated title: ${chatTitle}`);
    }

    // Add user message
    const userMessage = {
      id: uuidv4(),
      role: 'user',
      content: message.content,
      images: message.images || [],
      timestamp: new Date()
    };

    chat.messages.push(userMessage);

    // Determine which model to use based on whether the CURRENT message has images
    let modelToUse = model;
    if (userMessage.images && userMessage.images.length > 0) {
      // Use GPT-4o for vision capabilities (replaces deprecated gpt-4-vision-preview)
      modelToUse = 'gpt-4o';
      console.log('Images detected, switching to GPT-4o for vision processing');
    }

    // Prepare messages for OpenAI based on the model being used
    const openaiMessages = [];
    
    for (const msg of chat.messages) {
      if (msg.role === 'user' && msg.images && msg.images.length > 0 && modelToUse === 'gpt-4o') {
        // Only include images if we're using a vision-capable model
        const content = [
          { type: 'text', text: msg.content }
        ];
        
        // Add images to content - convert URLs to base64 for OpenAI
        for (const image of msg.images) {
          try {
            const base64Url = await convertImageUrlToBase64(image.url);
            content.push({
              type: 'image_url',
              image_url: {
                url: base64Url,
                detail: 'high'
              }
            });
          } catch (error) {
            console.error('Failed to convert image to base64:', error);
            // Skip this image if conversion fails
            continue;
          }
        }
        
        openaiMessages.push({
          role: msg.role,
          content: content
        });
      } else {
        // Regular text message (or skip images if model doesn't support them)
        openaiMessages.push({
          role: msg.role,
          content: msg.content
        });
      }
    }

    // Get AI response with comprehensive parameters like original ChatGPT
    const startTime = Date.now();
    
    // Prepare comprehensive system message
    const systemMessage = {
      role: 'system',
      content: `You are ChatGPT, a helpful and comprehensive AI assistant created by OpenAI. Your goal is to provide detailed, well-structured, and informative responses that thoroughly address the user's questions or requests.

Guidelines for your responses:
- Be comprehensive and detailed in your explanations
- Use clear structure with headers, bullet points, and numbered lists when appropriate
- Provide examples, context, and background information when relevant
- Break down complex topics into digestible sections
- Use plain text formatting without markdown symbols for headers and important points
- Aim for responses that are informative, engaging, and easy to understand
- If the user asks a simple question, still provide valuable context and additional insights
- For image analysis, be extremely detailed and thorough in your descriptions
- Always strive to be helpful while maintaining accuracy and clarity

Remember: Users appreciate comprehensive, well-organized responses that go beyond just answering the immediate question.`
    };

    // Always include system message for comprehensive responses
    const messagesWithSystem = [systemMessage, ...openaiMessages];

    // Determine max tokens based on model - use maximum available for unlimited usage
    let maxTokens;
    switch (modelToUse) {
      case 'gpt-4':
        maxTokens = 8192; // GPT-4's maximum output tokens
        break;
      case 'gpt-4o':
        maxTokens = 16384; // GPT-4o's updated maximum output tokens
        break;
      case 'gpt-4-turbo':
        maxTokens = 4096; // GPT-4 Turbo optimal output tokens (can go higher)
        break;
      case 'gpt-3.5-turbo':
        maxTokens = 16384; // GPT-3.5-turbo's updated maximum output tokens
        break;
      default:
        maxTokens = 4096; // Safe default
    }

    // For large requests or code generation, we can omit max_tokens to allow unlimited generation
    const completionConfig = {
      model: modelToUse,
      messages: messagesWithSystem,
      temperature: 0.8, // Slightly higher for more engaging and varied responses
      top_p: 0.95, // Allow more diverse vocabulary and expressions
      frequency_penalty: 0.2, // Reduce repetition while allowing natural flow
      presence_penalty: 0.4, // Encourage comprehensive topic coverage
      stream: false // Ensure complete response generation
    };

    // Only set max_tokens if it's a smaller request - remove limit for comprehensive responses
    const isLargeRequest = openaiMessages.some(msg => 
      msg.content && typeof msg.content === 'string' && 
      (msg.content.length > 500 || 
       msg.content.toLowerCase().includes('create') ||
       msg.content.toLowerCase().includes('generate') ||
       msg.content.toLowerCase().includes('build') ||
       msg.content.toLowerCase().includes('write') ||
       msg.content.toLowerCase().includes('develop'))
    );

    // For large requests like code generation, omit max_tokens for unlimited output
    if (!isLargeRequest) {
      completionConfig.max_tokens = maxTokens;
    }

    console.log(`Processing ${isLargeRequest ? 'large' : 'standard'} request with model: ${modelToUse}${isLargeRequest ? ' (unlimited tokens)' : ` (max ${maxTokens} tokens)`}`);

    const completion = await openai.chat.completions.create(completionConfig);

    const processingTime = Date.now() - startTime;
    const aiResponse = completion.choices[0].message.content;
    const tokensUsed = completion.usage?.total_tokens || 0;

    console.log(`AI Response generated in ${processingTime}ms using ${tokensUsed} tokens with model: ${modelToUse}`);

    // Add AI response to chat
    const aiMessage = {
      id: uuidv4(),
      role: 'assistant',
      content: aiResponse,
      images: [],
      timestamp: new Date(),
      modelUsed: modelToUse,
      tokensUsed: tokensUsed,
      processingTime: processingTime
    };

    chat.messages.push(aiMessage);

    // Save chat
    await chat.save();

    res.json({
      success: true,
      data: {
        chatId: chat.id,
        userMessage: userMessage,
        aiMessage: aiMessage
      }
    });

  } catch (error) {
    console.error('Error processing chat:', error);
    
    // Handle OpenAI specific errors
    if (error.code === 'insufficient_quota') {
      return res.status(402).json({
        success: false,
        error: 'OpenAI API quota exceeded'
      });
    }

    if (error.code === 'invalid_api_key') {
      return res.status(401).json({
        success: false,
        error: 'Invalid OpenAI API key'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to process message'
    });
  }
});

// DELETE /api/chat/:id - Delete chat
router.delete('/:id', async (req, res) => {
  try {
    const chat = await Chat.findOne({ id: req.params.id });
    
    if (!chat) {
      return res.status(404).json({
        success: false,
        error: 'Chat not found'
      });
    }

    chat.isActive = false;
    await chat.save();

    res.json({
      success: true,
      message: 'Chat deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting chat:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete chat'
    });
  }
});

// Rename chat
router.put('/:chatId/rename', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { title } = req.body;

    console.log(`Attempting to rename chat with ID: ${chatId} to title: ${title}`);

    if (!title || title.trim() === '') {
      return res.status(400).json({ error: 'Title is required' });
    }

    // First find the chat to ensure it exists
    const existingChat = await Chat.findOne({ id: chatId });

    if (!existingChat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    // Update the chat manually to avoid any ObjectId casting issues
    existingChat.title = title.trim();
    existingChat.updatedAt = new Date();
    
    const updatedChat = await existingChat.save();

    console.log(`Successfully renamed chat ${chatId} to "${title.trim()}"`);

    res.json({ 
      message: 'Chat renamed successfully',
      chat: {
        id: updatedChat.id,
        title: updatedChat.title,
        updatedAt: updatedChat.updatedAt
      }
    });

  } catch (error) {
    console.error('Error renaming chat:', error);
    res.status(500).json({ error: 'Failed to rename chat' });
  }
});

module.exports = router; 