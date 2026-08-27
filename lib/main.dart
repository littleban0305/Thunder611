import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const Thunder611App());
}

class Thunder611App extends StatelessWidget {
  const Thunder611App({super.key});

  static const background = Color(0xFF0B1115);
  static const surface = Color(0xFF141C21);
  static const surfaceAlt = Color(0xFF1B272C);
  static const primary = Color(0xFFF2B84B);
  static const accent = Color(0xFF5ED6C0);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: surface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '雷霆611',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        fontFamily: 'LXGWWenKaiTC',
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF253238),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentTextStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.w400),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 70,
          backgroundColor: const Color(0xFF0D0D12),
          indicatorColor: primary.withValues(alpha: 0.22),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primary.withValues(alpha: 0.7), width: 1.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}
