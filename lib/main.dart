import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/mindkawan_theme.dart';
import 'app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MindKawanApp()));
}

class MindKawanApp extends StatelessWidget {
  const MindKawanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindKawan',
      debugShowCheckedModeBanner: false,
      theme: mindKawanTheme(context),
      // Respect user’s device text scaling for low vision
      builder: (context, child) {
        final media = MediaQuery.of(context);
        // Ensure minimum 1.0 (don’t shrink below) and allow up to 1.6 easily
        final scale = media.textScaleFactor.clamp(1.0, 1.8);
        return MediaQuery(data: media.copyWith(textScaleFactor: scale), child: child!);
      },
      home: const AppShell(),
    );
  }
}
