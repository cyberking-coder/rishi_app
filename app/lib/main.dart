import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';
import 'services/download_service.dart';
import 'services/media_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AnuragRishiApp());
}

class AnuragRishiApp extends StatelessWidget {
  const AnuragRishiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Single ApiService instance shared by everything (carries the auth token).
    final api = ApiService();
    final deviceService = DeviceService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        Provider<DeviceService>.value(value: deviceService),
        Provider<MediaService>(create: (_) => MediaService(api)),
        Provider<DownloadService>(create: (_) => DownloadService(api)),
        ChangeNotifierProvider<AuthService>(
          create: (_) =>
              AuthService(api: api, deviceService: deviceService)..bootstrap(),
        ),
      ],
      child: MaterialApp(
        title: 'Anurag_Rishi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

/// Swaps between login and home based on auth state.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeScreen();
    }
  }
}
