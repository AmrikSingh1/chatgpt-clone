import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'openai_service.dart';

class FileService {
  final ImagePicker _imagePicker = ImagePicker();
  final OpenAIService _openAI = OpenAIService();

  // Supported file types
  static const List<String> supportedImageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'
  ];
  
  static const List<String> supportedDocumentExtensions = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'pages'
  ];

  static const List<String> supportedAudioExtensions = [
    'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'
  ];

  static const List<String> supportedVideoExtensions = [
    'mp4', 'mov', 'avi', 'mkv', 'webm'
  ];

  /// Pick multiple images from gallery or camera
  Future<List<File>> pickImages({bool allowMultiple = true}) async {
    try {
      if (allowMultiple) {
        final List<XFile>? images = await _imagePicker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        
        if (images != null && images.isNotEmpty) {
          return images.map((xFile) => File(xFile.path)).toList();
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        
        if (image != null) {
          return [File(image.path)];
        }
      }
      
      return [];
    } catch (e) {
      print('Error picking images: $e');
      throw Exception('Failed to pick images: ${e.toString()}');
    }
  }

  /// Take photo with camera
  Future<File?> takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('Error taking photo: $e');
      throw Exception('Failed to take photo: ${e.toString()}');
    }
  }

  /// Pick documents
  Future<List<File>> pickDocuments({bool allowMultiple = true}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedDocumentExtensions,
        allowMultiple: allowMultiple,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error picking documents: $e');
      throw Exception('Failed to pick documents: ${e.toString()}');
    }
  }

  /// Pick any supported file type
  Future<List<File>> pickAnyFile({bool allowMultiple = true}) async {
    try {
      final allExtensions = [
        ...supportedImageExtensions,
        ...supportedDocumentExtensions,
        ...supportedAudioExtensions,
        ...supportedVideoExtensions,
      ];

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allExtensions,
        allowMultiple: allowMultiple,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();
      }

      return [];
    } catch (e) {
      print('Error picking files: $e');
      throw Exception('Failed to pick files: ${e.toString()}');
    }
  }

  /// Validate file type and size
  Future<bool> validateFile(File file, {int maxSizeInMB = 25}) async {
    // Check file size (default 25MB limit)
    final fileSizeInBytes = await file.length();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    
    if (fileSizeInMB > maxSizeInMB) {
      throw Exception('File size exceeds ${maxSizeInMB}MB limit');
    }

    // Check file extension
    final extension = getFileExtension(file.path).toLowerCase();
    final allSupportedExtensions = [
      ...supportedImageExtensions,
      ...supportedDocumentExtensions,
      ...supportedAudioExtensions,
      ...supportedVideoExtensions,
    ];

    if (!allSupportedExtensions.contains(extension)) {
      throw Exception('Unsupported file type: $extension');
    }

    return true;
  }

  /// Get file extension
  String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  /// Get file type category
  FileType getFileType(String filePath) {
    final extension = getFileExtension(filePath);
    
    if (supportedImageExtensions.contains(extension)) {
      return FileType.image;
    } else if (supportedDocumentExtensions.contains(extension)) {
      return FileType.custom; // Documents
    } else if (supportedAudioExtensions.contains(extension)) {
      return FileType.audio;
    } else if (supportedVideoExtensions.contains(extension)) {
      return FileType.video;
    }
    
    return FileType.any;
  }

  /// Get MIME type
  String? getMimeType(String filePath) {
    return lookupMimeType(filePath);
  }

  /// Get file size in human readable format
  String getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Get file name without path
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Process files for ChatGPT-like analysis
  Future<Map<String, dynamic>> processFiles(List<File> files, {String? prompt}) async {
    final List<File> images = [];
    final List<File> documents = [];
    final List<File> audioFiles = [];
    final List<String> analyses = [];

    // Categorize files
    for (final file in files) {
      await validateFile(file);
      
      final fileType = getFileType(file.path);
      switch (fileType) {
        case FileType.image:
          images.add(file);
          break;
        case FileType.custom: // Documents
          documents.add(file);
          break;
        case FileType.audio:
          audioFiles.add(file);
          break;
        default:
          break;
      }
    }

    // Process images with Vision API
    if (images.isNotEmpty) {
      try {
        final imageAnalysis = images.length == 1
            ? await _openAI.analyzeImage(images.first, prompt: prompt)
            : await _openAI.analyzeMultipleImages(images, prompt: prompt);
        analyses.add('Image Analysis: $imageAnalysis');
      } catch (e) {
        analyses.add('Image Analysis Failed: ${e.toString()}');
      }
    }

    // Process documents
    for (final doc in documents) {
      try {
        final docAnalysis = await _openAI.analyzeDocument(doc, prompt: prompt);
        analyses.add('Document Analysis (${getFileName(doc.path)}): $docAnalysis');
      } catch (e) {
        analyses.add('Document Analysis Failed (${getFileName(doc.path)}): ${e.toString()}');
      }
    }

    // Process audio files with Whisper
    for (final audio in audioFiles) {
      try {
        final transcription = await _openAI.speechToText(audio);
        analyses.add('Audio Transcription (${getFileName(audio.path)}): $transcription');
      } catch (e) {
        analyses.add('Audio Transcription Failed (${getFileName(audio.path)}): ${e.toString()}');
      }
    }

    return {
      'totalFiles': files.length,
      'imageCount': images.length,
      'documentCount': documents.length,
      'audioCount': audioFiles.length,
      'analyses': analyses,
      'processedFiles': {
        'images': images.map((f) => f.path).toList(),
        'documents': documents.map((f) => f.path).toList(),
        'audio': audioFiles.map((f) => f.path).toList(),
      }
    };
  }

  /// Create thumbnail for image files
  Future<File?> createThumbnail(File imageFile) async {
    try {
      // For now, return the original file
      // In a production app, you might want to create actual thumbnails
      return imageFile;
    } catch (e) {
      print('Error creating thumbnail: $e');
      return null;
    }
  }

  /// Save file to app directory
  Future<File> saveFileToAppDirectory(File sourceFile, {String? customName}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = customName ?? getFileName(sourceFile.path);
      final destinationPath = '${appDir.path}/$fileName';
      
      return await sourceFile.copy(destinationPath);
    } catch (e) {
      print('Error saving file: $e');
      throw Exception('Failed to save file: ${e.toString()}');
    }
  }

  /// Delete temporary files
  Future<void> cleanupTempFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting temp file ${file.path}: $e');
      }
    }
  }

  /// Check if file is an image
  bool isImageFile(String filePath) {
    final extension = getFileExtension(filePath);
    return supportedImageExtensions.contains(extension);
  }

  /// Check if file is a document
  bool isDocumentFile(String filePath) {
    final extension = getFileExtension(filePath);
    return supportedDocumentExtensions.contains(extension);
  }

  /// Check if file is an audio file
  bool isAudioFile(String filePath) {
    final extension = getFileExtension(filePath);
    return supportedAudioExtensions.contains(extension);
  }

  /// Get file icon based on type
  String getFileIcon(String filePath) {
    final extension = getFileExtension(filePath);
    
    if (supportedImageExtensions.contains(extension)) {
      return '🖼️';
    } else if (supportedDocumentExtensions.contains(extension)) {
      switch (extension) {
        case 'pdf':
          return '📄';
        case 'doc':
        case 'docx':
          return '📝';
        case 'txt':
          return '📃';
        default:
          return '📄';
      }
    } else if (supportedAudioExtensions.contains(extension)) {
      return '🎵';
    } else if (supportedVideoExtensions.contains(extension)) {
      return '🎥';
    }
    
    return '📁';
  }
} 