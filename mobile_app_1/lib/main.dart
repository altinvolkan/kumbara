import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/child_accounts_screen.dart';
import 'services/auth_service.dart';
import 'services/account_service.dart';

void main() {
  // Sadece önemli logları göster
  if (kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null &&
          !message.contains('onAnimationUpdate') &&
          !message.contains('ViewRootImpl') &&
          !message.contains('ImeTracker') &&
          !message.contains('MIUIInput') &&
          !message.contains('onAnimationStart') &&
          !message.contains('onAnimationEnd') &&
          !message.contains('WindowOnBackDispatcher') &&
          !message.contains('InsetsController') &&
          !message.contains('MotionEvent') &&
          !message.contains('ApkAssets') &&
          !message.contains('HandWritingStubImpl') &&
          !message.contains('InputMethodManager')) {
        // debugPrintThrottled yerine doğrudan print kullan
        print(message);
      }
    };
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kumbara',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.orange,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      initialRoute: '/demo',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/register',
          page: () => const RegisterScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/home',
          page: () => const HomeScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/demo',
          page: () => const DemoScreen(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: '/child_accounts',
          page: () => const ChildAccountsScreen(),
          transition: Transition.fadeIn,
          binding: BindingsBuilder(() {
            Get.put(AuthService());
            Get.put(AccountService());
          }),
        ),
      ],
    );
  }
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.savings_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Kumbara',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Birikimlerinizi akıllıca yönetin',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Get.toNamed('/login'),
                child: const Text('Giriş Yap', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Get.toNamed('/register'),
                child: const Text(
                  'Hesap Oluştur',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
