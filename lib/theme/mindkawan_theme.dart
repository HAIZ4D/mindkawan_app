import 'package:flutter/material.dart';

ThemeData mindKawanTheme(BuildContext context) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF10B981),
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      surface: const Color(0xFF0F172A),
      surfaceContainerHighest: const Color(0xFF111827),
      primary: const Color(0xFF10B981),
      secondary: const Color(0xFF8B5CF6),
      onPrimary: Colors.black,
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1020),
    fontFamily: 'Roboto',
    materialTapTargetSize: MaterialTapTargetSize.padded,

    // ❌ remove the .apply(fontSizeFactor: 1.06)
    textTheme: Typography.whiteMountainView,

    navigationBarTheme: NavigationBarThemeData(
      height: 78,
      backgroundColor: const Color(0xFF0F172A),
      indicatorColor: const Color(0x3310B981),
      // Ensure base size is set to avoid other asserts
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 14.0,
          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: 0.2,
          height: 1.2,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(size: active ? 28 : 26);
      }),
    ),
  );
}
