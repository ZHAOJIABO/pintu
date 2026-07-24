import 'package:flutter/material.dart';

import 'services/api/api_scope.dart';
import 'screens/upload_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const BobobeadsApp(
      enableBackend: bool.fromEnvironment(
        'BOBOBEADS_ENABLE_BACKEND',
        defaultValue: true,
      ),
    ),
  );
}

class BobobeadsApp extends StatefulWidget {
  final bool enableBackend;
  final BackendServices? backendServices;

  const BobobeadsApp({
    super.key,
    this.enableBackend = false,
    this.backendServices,
  });

  @override
  State<BobobeadsApp> createState() => _BobobeadsAppState();
}

class _BobobeadsAppState extends State<BobobeadsApp> {
  late final BackendServices? _backendServices = widget.enableBackend
      ? widget.backendServices ?? BackendServices()
      : null;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'bobobeads',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F2F8),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const UploadScreen(),
    );

    final services = _backendServices;
    if (services == null) return app;

    return BackendScope(
      services: services,
      child: BackendWarmUp(
        services: services,
        enabled: widget.enableBackend,
        child: app,
      ),
    );
  }
}
