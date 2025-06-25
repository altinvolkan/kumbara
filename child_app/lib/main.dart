import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/auth/login_screen.dart';
import 'services/auth_service.dart';
import 'screens/main/home_screen.dart';

void main() {
  // Android animasyon loglarını filtrele
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        !message.contains('onAnimationUpdate') &&
        !message.contains('ViewRootImpl') &&
        !message.contains('ImeTracker') &&
        !message.contains('MIUIInput') &&
        !message.contains('Timeline') &&
        !message.contains('Choreographer')) {
      print(message);
    }
  };

  runApp(const ChildApp());
}

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Hedef Kumbaram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B46C1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Comic Neue',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6B46C1),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      final user = await _authService.getCurrentUser();
      if (user != null && user.role == 'child') {
        Get.offAll(() => const HomeScreen());
      } else {
        Get.offAll(() => const LoginScreen());
      }
    } catch (e) {
      Get.offAll(() => const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6B46C1), // Purple 600
              Color(0xFF9333EA), // Purple 500
              Color(0xFFEC4899), // Pink 500
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 0.5,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.savings_rounded,
                          size: 60,
                          color: Color(0xFF6B46C1),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Text(
                  '🏆 Hedef Kumbaram',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Comic Neue',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Text(
                  'Hayallerini gerçekleştir!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontFamily: 'Comic Neue',
                  ),
                ),
              ),
              const SizedBox(height: 50),
              ScaleTransition(
                scale: _scaleAnimation,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
