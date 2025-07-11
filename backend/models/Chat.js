const mongoose = require('mongoose');

// Image schema for uploaded files
const imageSchema = new mongoose.Schema({
  url: {
    type: String,
    required: true
  },
  publicId: {
    type: String,
    required: true
  },
  filename: {
    type: String,
    required: true
  },
  uploadedAt: {
    type: Date,
    default: Date.now
  },
  size: {
    type: Number,
    required: false
  },
  format: {
    type: String,
    required: false
  },
  width: {
    type: Number,
    required: false
  },
  height: {
    type: Number,
    required: false
  }
});

// Message schema with enhanced metadata
const messageSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true
  },
  role: {
    type: String,
    required: true,
    enum: ['user', 'assistant', 'system']
  },
  content: {
    type: String,
    required: true
  },
  images: [imageSchema],
  timestamp: {
    type: Date,
    default: Date.now
  },
  modelUsed: {
    type: String,
    required: false // Only for assistant messages
  },
  tokensUsed: {
    type: Number,
    required: false // Track API usage
  },
  processingTime: {
    type: Number,
    required: false // Track response time in milliseconds
  }
});

// Chat schema with comprehensive tracking
const chatSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
    unique: true
  },
  title: {
    type: String,
    required: true,
    maxlength: 200
  },
  model: {
    type: String,
    required: true,
    enum: ['gpt-3.5-turbo', 'gpt-4', 'gpt-4o', 'gpt-4-turbo'],
    default: 'gpt-3.5-turbo'
  },
  messages: [messageSchema],
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  },
  // Additional metadata for analytics
  totalMessages: {
    type: Number,
    default: 0
  },
  totalImages: {
    type: Number,
    default: 0
  },
  totalTokensUsed: {
    type: Number,
    default: 0
  },
  lastModelUsed: {
    type: String,
    required: false
  }
});

// Update counters before saving
chatSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  this.totalMessages = this.messages.length;
  this.totalImages = this.messages.reduce((count, msg) => count + (msg.images?.length || 0), 0);
  this.totalTokensUsed = this.messages.reduce((total, msg) => total + (msg.tokensUsed || 0), 0);
  
  // Find last assistant message to get last model used
  const lastAssistantMessage = this.messages
    .filter(msg => msg.role === 'assistant')
    .pop();
  
  if (lastAssistantMessage && lastAssistantMessage.modelUsed) {
    this.lastModelUsed = lastAssistantMessage.modelUsed;
  }
  
  next();
});

// Index for better performance
chatSchema.index({ id: 1 });
chatSchema.index({ createdAt: -1 });
chatSchema.index({ updatedAt: -1 });
chatSchema.index({ isActive: 1 });

module.exports = mongoose.model('Chat', chatSchema); 