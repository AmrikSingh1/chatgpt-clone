const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const { v2: cloudinary } = require('cloudinary');
const OpenAI = require('openai');
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Load environment variables
require('dotenv').config();

const app = express();

// Security middleware
app.use(helmet({
  crossOriginEmbedderPolicy: false, // Allow HTTPS in development
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// CORS configuration - updated for HTTPS
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ['https://yourdomain.com'] 
    : [
        'http://localhost:3000', 
        'https://localhost:3000',
        'http://10.0.2.2:3000',
        'https://10.0.2.2:3000'
      ],
  credentials: true
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Cloudinary configuration
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'dotfxeybu',
  api_key: process.env.CLOUDINARY_API_KEY || '281669667625763',
  api_secret: process.env.CLOUDINARY_API_SECRET || 'KvB6ZfFMg-KLyQu60plxs8qs7kY'
});

console.log('Cloudinary configured with cloud:', process.env.CLOUDINARY_CLOUD_NAME || 'dotfxeybu');

// Configure OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// MongoDB connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('Connected to MongoDB'))
.catch(err => console.error('MongoDB connection error:', err));

// Import routes
const chatRoutes = require('./routes/chat');
const uploadRoutes = require('./routes/upload');
const modelRoutes = require('./routes/models');

// Use routes
app.use('/api/chat', chatRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/models', modelRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    protocol: req.secure ? 'HTTPS' : 'HTTP'
  });
});

// Multer error handling middleware
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: 'File size too large',
        message: 'File size too large. Maximum size is 10MB'
      });
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        error: 'Too many files',
        message: 'Maximum 5 files allowed'
      });
    }
    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({
        error: 'Unexpected file field',
        message: 'Unexpected file field'
      });
    }
  }
  
  if (err.message === 'Only image and document files are allowed') {
    return res.status(400).json({
      error: 'Invalid file type',
      message: 'Only image and document files are allowed'
    });
  }
  
  next(err);
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    method: req.method,
    url: req.originalUrl
  });
});

// Load SSL certificates for HTTPS
let httpsOptions;
try {
  const sslKeyPath = path.join(__dirname, 'ssl', 'key.pem');
  const sslCertPath = path.join(__dirname, 'ssl', 'cert.pem');
  
  if (fs.existsSync(sslKeyPath) && fs.existsSync(sslCertPath)) {
    httpsOptions = {
      key: fs.readFileSync(sslKeyPath),
      cert: fs.readFileSync(sslCertPath)
    };
    console.log('🔑 SSL certificates loaded successfully');
  } else {
    throw new Error('SSL certificates not found');
  }
} catch (error) {
  console.error('❌ Failed to load SSL certificates:', error.message);
  console.log('⚠️  Run the following to generate certificates:');
  console.log('   mkdir -p ssl && openssl req -x509 -newkey rsa:4096 -keyout ssl/key.pem -out ssl/cert.pem -days 365 -nodes');
  process.exit(1);
}

// Start both HTTP (redirect) and HTTPS servers
const PORT_HTTP = process.env.PORT_HTTP || 3001;
const PORT_HTTPS = process.env.PORT_HTTPS || 3443;

// Store server references for graceful shutdown
let httpsServer;
let httpServer;

// HTTPS Server (primary)
if (process.env.NODE_ENV === 'production') {
  // Production: Only HTTPS
  httpsServer = https.createServer(httpsOptions, app).listen(PORT_HTTPS, () => {
    console.log(`🔒 HTTPS Server running on port ${PORT_HTTPS}`);
    console.log(`🌐 Server running in ${process.env.NODE_ENV} mode`);
  });
  
  // Set timeout for long AI responses (10 minutes)
  httpsServer.timeout = 600000; // 10 minutes
  httpsServer.keepAliveTimeout = 610000; // Slightly longer than timeout
  httpsServer.headersTimeout = 620000; // Slightly longer than keepAliveTimeout
} else {
  // Development: HTTPS + HTTP redirect
  httpsServer = https.createServer(httpsOptions, app).listen(PORT_HTTPS, () => {
    console.log(`🔒 HTTPS Server running on port ${PORT_HTTPS}`);
    console.log(`🌐 Server running in ${process.env.NODE_ENV || 'development'} mode`);
  });

  // Set timeout for long AI responses (10 minutes)
  httpsServer.timeout = 600000; // 10 minutes
  httpsServer.keepAliveTimeout = 610000; // Slightly longer than timeout
  httpsServer.headersTimeout = 620000; // Slightly longer than keepAliveTimeout

  // HTTP Server - Redirect all traffic to HTTPS
  httpServer = http.createServer((req, res) => {
    const redirectUrl = `https://${req.headers.host.replace(`:${PORT_HTTP}`, `:${PORT_HTTPS}`)}${req.url}`;
    console.log(`🔄 Redirecting HTTP to HTTPS: ${req.url} -> ${redirectUrl}`);
    
    res.writeHead(301, { 
      Location: redirectUrl,
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload'
    });
    res.end('Redirecting to HTTPS...');
  }).listen(PORT_HTTP, () => {
    console.log(`🌐 HTTP Server redirects to HTTPS (${PORT_HTTP} -> ${PORT_HTTPS})`);
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  
  const shutdownPromises = [];
  
    if (httpsServer) {
    shutdownPromises.push(new Promise((resolve) => {
      httpsServer.close(() => {
        console.log('HTTPS server closed.');
        resolve();
      });
    }));
  }
  
  if (httpServer) {
    shutdownPromises.push(new Promise((resolve) => {
      httpServer.close(() => {
      console.log('HTTP server closed.');
        resolve();
      });
    }));
  }
  
  Promise.all(shutdownPromises).then(() => {
    console.log('All servers closed.');
      process.exit(0);
  });
});

module.exports = app; 