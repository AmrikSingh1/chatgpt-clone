# ChatGPT Clone - Setup Guide

This guide will help you set up and run the ChatGPT Clone mobile application with Flutter frontend and Node.js backend.

## 📋 Prerequisites

### Required Software
- **Node.js** (v16.0.0 or higher)
- **Flutter SDK** (v3.1.0 or higher)
- **Git**
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)

### Required Accounts & API Keys
- **OpenAI API Key** (for ChatGPT functionality)
- **MongoDB Atlas Account** (for database)
- **Cloudinary Account** (for image storage)

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd chatgpt-clone
```

### 2. Backend Setup

#### Install Dependencies
```bash
cd backend
npm install
```



#### Start the Backend Server
```bash
npm start
```

The server will start on `http://localhost:3000`

### 3. Mobile App Setup

#### Install Flutter Dependencies
```bash
cd mobile
flutter pub get
```

#### Run the App
```bash
# For Android
flutter run

# For iOS (macOS only)
flutter run -d ios

# For Web
flutter run -d chrome
```

## 🔧 Configuration Details

### Backend Configuration

#### API Endpoints
- `GET /health` - Health check
- `GET /api/chat` - Get chat history
- `GET /api/chat/:id` - Get specific chat
- `POST /api/chat` - Send message
- `DELETE /api/chat/:id` - Delete chat
- `POST /api/upload` - Upload image
- `GET /api/models` - Get available models

#### Database Schema
The app uses MongoDB with the following collections:
- **chats** - Store chat conversations
- **users** - User information (for future authentication)

### Mobile App Configuration

#### API Base URL
Update the base URL in `mobile/lib/services/api_service.dart`:
- Android Emulator: `http://10.0.2.2:3000`
- iOS Simulator: `http://localhost:3000`
- Physical Device: `http://YOUR_COMPUTER_IP:3000`

#### Permissions
The app requires the following permissions:
- **Internet** - For API communication
- **Camera** - For taking photos
- **Storage** - For selecting images from gallery

## 📱 Features

### ✅ Implemented Features
- **Chat Interface** - Real-time messaging with AI
- **Chat History** - Persistent conversation storage
- **Image Upload** - Camera and gallery integration
- **Model Selection** - Choose between GPT models
- **Responsive UI** - Pixel-perfect ChatGPT-like design

### 🔄 State Management
- Uses **Provider** for state management
- Centralized chat state in `ChatProvider`
- Real-time UI updates

### 🎨 Design System
- **Colors**: ChatGPT green (#10A37F)
- **Typography**: Inter font family
- **Components**: Material 3 design system
- **Theme**: Light theme with custom styling

## 🧪 Testing

### Backend Testing
```bash
cd backend
npm test
```

### Mobile Testing
```bash
cd mobile
flutter test
```

### Manual Testing
1. Start the backend server
2. Run the mobile app
3. Test the following flows:
   - Create new chat
   - Send text messages
   - Upload and send images
   - Switch between models
   - View chat history
   - Delete chats

## 📦 Deployment

### Backend Deployment
1. **Environment Variables**: Set production environment variables
2. **Database**: Ensure MongoDB Atlas is accessible
3. **CORS**: Update CORS settings for production domain
4. **SSL**: Enable HTTPS in production

### Mobile App Deployment

#### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

## 🔍 Troubleshooting

### Common Issues

#### Backend Issues
- **MongoDB Connection**: Check MongoDB URI and network access
- **OpenAI API**: Verify API key and quota
- **Cloudinary**: Check credentials and upload limits

#### Mobile App Issues
- **Network Connection**: Ensure backend is running and accessible
- **Permissions**: Check camera and storage permissions
- **Flutter SDK**: Ensure Flutter is properly installed

### Debug Commands
```bash
# Check Flutter doctor
flutter doctor

# Clean and rebuild
flutter clean && flutter pub get

# Check backend logs
cd backend && npm start

# Test API endpoints
curl http://localhost:3000/health
```

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [OpenAI API Documentation](https://platform.openai.com/docs)
- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)
- [Cloudinary Documentation](https://cloudinary.com/documentation)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 🆘 Support

If you encounter any issues:
1. Check this setup guide
2. Review the troubleshooting section
3. Check the project's issue tracker
4. Create a new issue with detailed information

---

**Happy Coding! 🚀** 