import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  runApp(MedicalReferenceApp(settings: settings));
}
