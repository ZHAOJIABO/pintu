import 'package:flutter/material.dart';
import 'screens/upload_screen.dart';

void main() {
  runApp(const BobobeadsApp());
}

class BobobeadsApp extends StatelessWidget {
  const BobobeadsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bobobeads',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F2F8),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const UploadScreen(),
    );
  }
}
