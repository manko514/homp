import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'widgets/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const HompApp());
}

class HompApp extends StatelessWidget {
  const HompApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOMP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: ApiService.isLoggedIn ? '/main' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainShell(),
      },
    );
  }
}
