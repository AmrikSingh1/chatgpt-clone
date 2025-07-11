const express = require('express');
const router = express.Router();
const OpenAI = require('openai');

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// Available models configuration
const availableModels = [
  {
    id: 'gpt-3.5-turbo',
    name: 'GPT-3.5 Turbo',
    description: 'Fast and efficient for most conversations',
    maxTokens: 16384,
    costPer1kTokens: 0.002,
    isDefault: true
  },
  {
    id: 'gpt-4',
    name: 'GPT-4',
    description: 'More capable but slower, best for complex tasks',
    maxTokens: 8192,
    costPer1kTokens: 0.03,
    isDefault: false
  },
  {
    id: 'gpt-4o',
    name: 'GPT-4o',
    description: 'Multimodal model with vision and text capabilities, unlimited token output',
    maxTokens: 16384,
    costPer1kTokens: 0.03,
    isDefault: false
  },
  {
    id: 'gpt-4-turbo',
    name: 'GPT-4 Turbo',
    description: 'Latest GPT-4 model with improved performance and unlimited output',
    maxTokens: 128000,
    costPer1kTokens: 0.01,
    isDefault: false
  }
];

// GET /api/models - Get available models
router.get('/', async (req, res) => {
  try {
    res.json({
      success: true,
      data: availableModels
    });
  } catch (error) {
    console.error('Error fetching models:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch models'
    });
  }
});

// GET /api/models/openai - Get models from OpenAI API (for verification)
router.get('/openai', async (req, res) => {
  try {
    const models = await openai.models.list();
    
    // Filter to only chat completion models
    const chatModels = models.data.filter(model => 
      model.id.includes('gpt') && 
      !model.id.includes('instruct') && 
      !model.id.includes('edit')
    );

    res.json({
      success: true,
      data: chatModels
    });
  } catch (error) {
    console.error('Error fetching OpenAI models:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch OpenAI models'
    });
  }
});

// POST /api/models/validate - Validate if a model is available
router.post('/validate', async (req, res) => {
  try {
    const { modelId } = req.body;

    if (!modelId) {
      return res.status(400).json({
        success: false,
        error: 'Model ID is required'
      });
    }

    // Check if model exists in our available models
    const model = availableModels.find(m => m.id === modelId);
    
    if (!model) {
      return res.status(404).json({
        success: false,
        error: 'Model not found'
      });
    }

    // Try to make a simple test call to verify the model works
    try {
      await openai.chat.completions.create({
        model: modelId,
        messages: [{ role: 'user', content: 'Hello' }],
        max_tokens: 10
      });

      res.json({
        success: true,
        data: {
          modelId: modelId,
          isAvailable: true,
          model: model
        }
      });
    } catch (openaiError) {
      res.json({
        success: true,
        data: {
          modelId: modelId,
          isAvailable: false,
          error: openaiError.message,
          model: model
        }
      });
    }

  } catch (error) {
    console.error('Error validating model:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to validate model'
    });
  }
});

module.exports = router; 