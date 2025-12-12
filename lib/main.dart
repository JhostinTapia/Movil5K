import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/timer_provider.dart';
import 'screens/login_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/equipos_asignados_screen.dart';
import 'screens/resultados_equipo_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar sqflite_ffi para Windows, Linux y macOS
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Configurar orientación portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Providers que crean su propio AppRepository (NO compartido aún)
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TimerProvider>(
          create: (_) => TimerProvider(),
          update: (context, authProvider, timerProvider) {
            // Compartir el repository del AuthProvider con el TimerProvider
            timerProvider!.setRepository(authProvider.repository);
            return timerProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Carrera 5K UNL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/equipos': (context) => const EquiposAsignadosScreen(),
          '/timer': (context) => const TimerScreen(),
          '/resultados': (context) => const ResultadosEquipoScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadSavedSession();

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      if (authProvider.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/equipos');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.timer,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Carrera 5K',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Universidad Nacional de Loja',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
