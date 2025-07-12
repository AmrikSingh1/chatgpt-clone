import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/chat_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for ChatGPT-like appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'ChatGPT',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          // Add textSelectionTheme to override cursor color globally
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.black,
            selectionColor: Color(0x3310A37F),
            selectionHandleColor: Color(0xFF10A37F),
          ),
          
          // ChatGPT Color Scheme
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF10A37F), // ChatGPT Green
            secondary: Color(0xFF6B6C7E), // Muted Grey
            surface: Color(0xFFFFFFFF), // Pure White
            background: Color(0xFFFFFFFF), // Pure White
            onPrimary: Colors.white,
            onSecondary: Color(0xFF202123), // Dark Grey
            onSurface: Color(0xFF202123), // Dark Grey
            onBackground: Color(0xFF202123), // Dark Grey
            surfaceVariant: Color(0xFFF7F7F8), // Light Grey for bubbles
            outline: Color(0xFFE5E5E5), // Border Grey
          ),
          
          // Typography - Google Sans / Inter
          textTheme: GoogleFonts.interTextTheme().copyWith(
            displayLarge: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF202123),
            ),
            headlineMedium: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF202123),
            ),
            titleLarge: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF202123),
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF202123),
              height: 1.4,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B6C7E),
            ),
            bodySmall: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          
          // App Bar Theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFF202123),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202123),
            ),
            iconTheme: IconThemeData(
              color: Color(0xFF202123),
              size: 24,
            ),
          ),
          
          // Scaffold Background
          scaffoldBackgroundColor: Colors.white,
          
          // Card Theme
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 0,
            shadowColor: Colors.black.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          
          // Button Themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10A37F),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Icon Button Theme
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF6B6C7E),
              iconSize: 24,
            ),
          ),
          
          // Input Decoration Theme - Pill shape like ChatGPT
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF1F1F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: const BorderSide(
                color: Color(0xFF10A37F),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w400,
            ),
          ),
          
          // Divider Theme
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E5E5),
            thickness: 1,
            space: 1,
          ),
          
          // List Tile Theme
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minLeadingWidth: 40,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
