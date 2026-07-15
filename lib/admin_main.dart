import 'package:flutter/widgets.dart';

import 'admin/admin_app.dart';

// This entrypoint is built only for the internal browser portal:
// flutter build web --target lib/admin_main.dart
// The iOS application continues to start from lib/main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BoboBeadsAdminApp());
}
