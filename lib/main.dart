import 'package:flutter/material.dart';

import 'navigation/home_navigation.dart';
import 'services/api/api_scope.dart';
import 'screens/onboarding_screen.dart';
import 'screens/upload_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const BobobeadsApp(
      enableBackend: bool.fromEnvironment(
        'BOBOBEADS_ENABLE_BACKEND',
        defaultValue: true,
      ),
      enableOnboarding: true,
    ),
  );
}

class BobobeadsApp extends StatefulWidget {
  final bool enableBackend;
  final bool enableOnboarding;
  final BackendServices? backendServices;

  const BobobeadsApp({
    super.key,
    this.enableBackend = false,
    this.enableOnboarding = false,
    this.backendServices,
  });

  @override
  State<BobobeadsApp> createState() => _BobobeadsAppState();
}

class _BobobeadsAppState extends State<BobobeadsApp> {
  late final BackendServices? _backendServices = widget.enableBackend
      ? widget.backendServices ?? BackendServices()
      : null;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'bobobeads',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F2F8),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
        snackBarTheme: const SnackBarThemeData(
          actionTextColor: Colors.white,
          disabledActionTextColor: Color(0x99FFFFFF),
        ),
      ),
      navigatorObservers: [appNavigatorObserver],
      home: widget.enableOnboarding
          ? const FirstLaunchGate(child: UploadScreen())
          : const UploadScreen(),
    );

    final services = _backendServices;
    if (services == null) return app;

    return BackendScope(
      services: services,
      child: BackendWarmUp(
        services: services,
        enabled: widget.enableBackend,
        navigatorKey: _navigatorKey,
        child: app,
      ),
    );
  }
}
