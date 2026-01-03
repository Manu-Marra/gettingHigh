
import 'package:flutter/material.dart';
import 'screens/playlist_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121212), elevation: 0),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.green),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Colors.green,
          thumbColor: Colors.green,
          inactiveTrackColor: Colors.grey,
          trackHeight: 4.0,
        ),
      ),
      home: const PlaylistScreen(),
    );
  }
}
