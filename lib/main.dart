import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'screens/auth/login_screen.dart';
// import 'screens/auth/register_screen.dart';
// import 'screens/main/home_screen.dart';
// import 'screens/main/goals_screen.dart';
// import 'screens/main/goal_detail_screen.dart';
// import 'screens/main/create_goal_screen.dart';
// import 'screens/main/profile_screen.dart';
// import 'services/auth_service.dart';
// import 'services/goal_service.dart';

void main() {
  runApp(const KumbaraChildApp());
}

class KumbaraChildApp extends StatelessWidget {
  const KumbaraChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kumbara Çocuk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.orange,
        ),
        useMaterial3: true,
        fontFamily: 'Comic Neue',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple,
              Colors.purple,
              Colors.deepPurpleAccent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.savings,
                  size: 120,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  '🏆 Hedef Kumbaram',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hayallerini gerçekleştirmek için para biriktir!',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to login
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Giriş ekranı yakında hazır!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Giriş Yap'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to register
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Kayıt ekranı yakında hazır!')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Hesap Oluştur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
