const express = require('express');
const router = express.Router();
const multer = require('multer');
const { v2: cloudinary } = require('cloudinary');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

// Configure multer for memory storage
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Allow images and documents
    const allowedMimeTypes = [
      // Image types
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/bmp',
      'image/webp',
      'image/svg+xml',
      // Document types
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'application/rtf',
      'application/vnd.oasis.opendocument.text'
    ];
    
    const isAllowed = allowedMimeTypes.includes(file.mimetype) || file.mimetype.startsWith('image/');
    
    if (isAllowed) {
      cb(null, true);
    } else {
      console.log(`Rejected file type: ${file.mimetype}`);
      cb(new Error(`Invalid file type: ${file.mimetype}. Only image and document files are allowed`), false);
    }
  }
});

// POST /api/upload - Upload image (base64 or file)
router.post('/', upload.single('image'), async (req, res) => {
  try {
    let imageData = null;
    let filename = 'uploaded_image';
    
    // Handle base64 image from request body
    if (req.body.image && req.body.image.startsWith('data:image/')) {
      const base64Data = req.body.image;
      filename = req.body.filename || `image_${Date.now()}.${base64Data.split(';')[0].split('/')[1]}`;
      
      // Upload to Cloudinary
      const cloudinaryResult = await cloudinary.uploader.upload(base64Data, {
        folder: 'chatgpt-clone',
        resource_type: 'image',
        public_id: `image_${uuidv4()}`,
        overwrite: true,
        transformation: [
          { width: 1024, height: 1024, crop: 'limit' },
          { quality: 'auto' },
          { fetch_format: 'auto' }
        ]
      });
      
      imageData = {
        url: cloudinaryResult.secure_url, // Use Cloudinary URL for storage
        publicId: cloudinaryResult.public_id,
        filename: filename,
        size: cloudinaryResult.bytes,
        format: cloudinaryResult.format,
        width: cloudinaryResult.width,
        height: cloudinaryResult.height
      };
    }
    // Handle multipart file upload
    else if (req.file) {
      filename = req.file.originalname || 'uploaded_image';
      
      // Upload buffer to Cloudinary
      const cloudinaryResult = await cloudinary.uploader.upload(
        `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`,
        {
          folder: 'chatgpt-clone',
          resource_type: 'image',
          public_id: `image_${uuidv4()}`,
          overwrite: true,
          transformation: [
            { width: 1024, height: 1024, crop: 'limit' },
            { quality: 'auto' },
            { fetch_format: 'auto' }
          ]
        }
      );
      
      imageData = {
        url: cloudinaryResult.secure_url, // Use Cloudinary URL for storage
        publicId: cloudinaryResult.public_id,
        filename: filename,
        size: cloudinaryResult.bytes,
        format: cloudinaryResult.format,
        width: cloudinaryResult.width,
        height: cloudinaryResult.height
      };
    }
    
    if (!imageData) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided'
      });
    }

    console.log('Image uploaded to Cloudinary:', imageData.publicId);

    res.json({
      success: true,
      data: imageData
    });

  } catch (error) {
    console.error('Error processing image:', error);
    
    if (error.message === 'Only image and document files are allowed') {
      return res.status(400).json({
        success: false,
        error: 'Only image and document files are allowed'
      });
    }

    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size too large. Maximum size is 10MB'
      });
    }

    if (error.http_code) {
      // Cloudinary error
      return res.status(400).json({
        success: false,
        error: `Cloudinary upload failed: ${error.message}`
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to process image'
    });
  }
});

// POST /api/upload/multiple - Upload multiple images
router.post('/multiple', upload.array('images', 5), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No image files provided'
      });
    }

    const results = await Promise.all(
      req.files.map(async (file) => {
        const filename = file.originalname || 'uploaded_image';
        
        // Upload to Cloudinary
        const cloudinaryResult = await cloudinary.uploader.upload(
          `data:${file.mimetype};base64,${file.buffer.toString('base64')}`,
          {
            folder: 'chatgpt-clone',
            resource_type: 'image',
            public_id: `image_${uuidv4()}`,
            overwrite: true,
            transformation: [
              { width: 1024, height: 1024, crop: 'limit' },
              { quality: 'auto' },
              { fetch_format: 'auto' }
            ]
          }
        );
        
        return {
          url: cloudinaryResult.secure_url,
          publicId: cloudinaryResult.public_id,
          filename: filename,
          size: cloudinaryResult.bytes,
          format: cloudinaryResult.format,
          width: cloudinaryResult.width,
          height: cloudinaryResult.height
        };
      })
    );

    console.log(`Uploaded ${results.length} images to Cloudinary`);

    res.json({
      success: true,
      data: results
    });

  } catch (error) {
    console.error('Error uploading images:', error);
    
    if (error.message === 'Only image and document files are allowed') {
      return res.status(400).json({
        success: false,
        error: 'Only image and document files are allowed',
        message: 'Only image and document files are allowed'
      });
    }

    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size too large. Maximum size is 10MB',
        message: 'File size too large. Maximum size is 10MB'
      });
    }

    if (error.http_code) {
      // Cloudinary error
      return res.status(400).json({
        success: false,
        error: `Cloudinary upload failed: ${error.message}`,
        message: `Cloudinary upload failed: ${error.message}`
      });
    }

    res.status(500).json({
      success: false,
      error: 'Something went wrong!',
      message: 'Only image and document files are allowed'
    });
  }
});

// DELETE /api/upload/:publicId - Delete image from Cloudinary
router.delete('/:publicId', async (req, res) => {
  try {
    const { publicId } = req.params;
    
    if (!publicId) {
      return res.status(400).json({
        success: false,
        error: 'Public ID is required'
      });
    }

    const result = await cloudinary.uploader.destroy(publicId);

    if (result.result === 'ok') {
      res.json({
        success: true,
        message: 'Image deleted successfully'
      });
    } else {
      res.status(404).json({
        success: false,
        error: 'Image not found'
      });
    }

  } catch (error) {
    console.error('Error deleting image:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete image'
    });
  }
});

// POST /api/upload/analyze-document - Analyze document with OpenAI
router.post('/analyze-document', multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB limit for documents
  fileFilter: (req, file, cb) => {
    const allowedTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'application/rtf'
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only document files are allowed'), false);
    }
  }
}).single('document'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No document file provided'
      });
    }

    const { prompt } = req.body;
    
    // For now, return a placeholder response
    // In a real implementation, you would:
    // 1. Extract text from the document using libraries like pdf-parse, mammoth, etc.
    // 2. Send the extracted text to OpenAI for analysis
    // 3. Return the analysis result
    
    const analysis = `Document analysis for ${req.file.originalname}:
    
This is a placeholder response. To implement full document analysis:
1. Install document parsing libraries (pdf-parse, mammoth, etc.)
2. Extract text content from the uploaded document
3. Send the text to OpenAI API for analysis
4. Process and return the structured analysis

Prompt: ${prompt || 'No specific prompt provided'}
File type: ${req.file.mimetype}
File size: ${req.file.size} bytes`;

    res.json({
      success: true,
      data: {
        analysis,
        filename: req.file.originalname,
        fileType: req.file.mimetype,
        fileSize: req.file.size
      }
    });

  } catch (error) {
    console.error('Error analyzing document:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to analyze document'
    });
  }
});

module.exports = router; 