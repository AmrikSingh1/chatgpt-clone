# ChatGPT Clone Mobile App

A full-stack ChatGPT clone mobile application built with Flutter and Node.js, featuring real-time chat, image upload, chat history, and model selection.

## 🚀 Features

- **Chat Interface**: Seamless AI-powered conversations using OpenAI API
- **Chat History**: Persistent conversation storage with MongoDB
- **Image Upload**: Upload and share images in chat with Cloudinary integration
- **Model Selection**: Choose between different OpenAI models (GPT-3.5, GPT-4, etc.)
- **Responsive UI**: Pixel-perfect ChatGPT-like design for mobile devices

## 🛠️ Tech Stack

### Frontend (Mobile)
- **Framework**: Flutter
- **Platform**: iOS & Android
- **State Management**: Provider
- **HTTP Client**: Dio
- **Image Handling**: image_picker

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB Atlas
- **File Storage**: Cloudinary
- **AI Integration**: OpenAI API

## 📁 Project Structure

```
chatgpt-clone/
├── backend/                 # Node.js backend
│   ├── models/             # MongoDB models
│   ├── routes/             # API routes
│   ├── middleware/         # Express middleware
│   ├── config/             # Configuration files
│   └── server.js           # Main server file
├── mobile/                 # Flutter mobile app
│   ├── lib/
│   │   ├── models/         # Data models
│   │   ├── services/       # API services
│   │   ├── screens/        # UI screens
│   │   ├── widgets/        # Reusable widgets
│   │   └── main.dart       # App entry point
│   └── pubspec.yaml        # Flutter dependencies
└── README.md
```

## 🔧 Setup Instructions

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```



4. Start the server:
```bash
npm start
```

### Mobile App Setup

1. Navigate to mobile directory:
```bash
cd mobile
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## 🔑 Environment Variables

The application requires the following environment variables:

- `OPENAI_API_KEY`: Your OpenAI API key
- `MONGODB_URI`: MongoDB connection string
- `CLOUDINARY_CLOUD_NAME`: Cloudinary cloud name
- `CLOUDINARY_API_KEY`: Cloudinary API key
- `CLOUDINARY_API_SECRET`: Cloudinary API secret

## 📱 App Features

### Chat Interface
- Real-time messaging with OpenAI API
- Message history display
- Typing indicators
- Error handling for API failures

### Image Upload
- Camera and gallery image selection
- Image compression and optimization
- Cloudinary integration for storage
- Inline image display in chat

### Model Selection
- Choose between available OpenAI models
- Persistent model preference
- Model-specific configuration

### Chat History
- Save and retrieve past conversations
- Organized by date and time
- Search functionality
- Delete conversations

## 🔒 Security Features

- Environment variable protection for API keys
- Input validation and sanitization
- Error handling and graceful degradation
- HTTPS enforcement for production

## 📝 API Endpoints

- `POST /api/chat` - Send message to AI
- `GET /api/chats` - Get chat history
- `POST /api/upload` - Upload image
- `GET /api/models` - Get available models
- `DELETE /api/chats/:id` - Delete chat

## 🧪 Testing

Run tests for both frontend and backend:

```bash
# Backend tests
cd backend && npm test

# Flutter tests
cd mobile && flutter test
```

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Support

For support and questions, please open an issue in the GitHub repository. 