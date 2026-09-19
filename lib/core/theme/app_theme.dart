import 'package:flutter/material.dart';

/// EduNova design language — light, airy system: white/near-white
/// backgrounds, card surfaces with soft hairline borders (not shadows),
/// dark-navy text, and orange stadium (pill) CTAs.
///
/// Screens read from [AppBrand] tokens, so re-theming happens here in one
/// place. [GradientButton] and [GlassCard] in lib/shared/widgets/ui.dart
/// build directly on these tokens.
class AppBrand {
  AppBrand._();

  // ---- Brand (Aditya Globals — navy + orange) ----
  static const purple =
      Color(0xFFF5810C); // primary brand / accent (Aditya orange)
  static const purpleDark = Color(0xFF0F2540);
  static const purpleSoft =
      Color(0xFFFFE9D3); // light peach chip / avatar surface

  static const blue = Color(0xFF000080); // secondary accent (navy blue)
  static const green = Color(0xFF1AA34A); // progress / success accent
  static const greenSoft = Color(0xFFE7F8ED); // light success surface

  // ---- Light surfaces & text ----
  static const bgTop = Color(0xFFFFFFFF); // gradient start (white)
  static const bgBottom = Color(0xFFEEF3FA); // gradient end (soft blue-gray)
  static const bg = Color(0xFFF6F8FC); // solid scaffold base
  static const card = Color(0xFFFFFFFF); // card surface (white)
  static const cardAlt = Color(0xFFF1F5FA); // nested / input-fill surface

  static const ink = Color(0xFF10233F); // primary text (dark navy)
  static const inkSoft = Color(0xFF64748B); // muted slate text
  static const line = Color(0xFFE3E8F0); // hairline borders

  static const amber =
      Color(0xFF29B6F6); // streak / highlight accent (light blue)

  static const subjectColors = [
    Color(0xFFF5810C), // tech - orange
    Color(0xFF000080), // business - navy blue
    Color(0xFF1AA34A), // finance - green
    Color(0xFFFFA84D), // content creation - light orange
  ];

  /// Full-screen background gradient (soft white → pale blue).
  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  /// Orange → amber gradient used on every primary CTA and hero accent.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5810C), Color(0xFFFFA84D)],
  );

  static const radiusCard = 24.0;
  static const radiusPill = 100.0;

  // ---- Aliases used by the Syllabus screens (navy/orange naming) ----
  static const navy = purpleDark; // dark navy accent (icons, gradient start)
  static const navy2 = blue; // lighter navy-blue (gradient end)
  static const orange = purple; // Aditya orange accent
}

/// Backwards-compatible palette used by the older `features/*` prototype
/// screens (unused — nothing imports `features/`, kept only so that dead
/// code still compiles if it's ever revived) and `shared/widgets/ui.dart`.
/// [navy] is a fixed literal rather than aliased to [AppBrand.bgTop] since
/// several live widgets (e.g. StatusPill) use it as an "ink on a light
/// surface" color, not a background.
class AppColors {
  AppColors._();

  static const navy = AppBrand.ink;
  static const heading = AppBrand.ink;
  static const ink = AppBrand.ink;
  static const muted = AppBrand.inkSoft;
  static const line = AppBrand.line;
  static const orange = Color(0xFFFF8A4C);
  static const orangeSoft = Color(0x33FF8A4C);
  static const green = AppBrand.green;
  static const blue = AppBrand.blue;
  static const white = Colors.white;
  static const chipBg = AppBrand.cardAlt;
  static const cream = AppBrand.card;
}

class AppTheme {
  static const seed = AppBrand.purple;

  /// The app's single base theme. Named [dark] for historical reasons
  /// (this used to be a dark theme) but is now light — kept so every
  /// existing call site (main.dart, grade_themes.dart) keeps compiling.
  /// [light] is the same thing under its accurate name.
  static ThemeData get light => dark;

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: AppBrand.purple,
          secondary: AppBrand.blue,
          tertiary: AppBrand.green,
          surface: AppBrand.card,
          onSurface: AppBrand.ink,
        ),
        scaffoldBackgroundColor: AppBrand.bg,
        canvasColor: AppBrand.bg,
        // Web (and desktop) skip page-transition animations by default in
        // Flutter — this forces a consistent fade + slide-in on every
        // platform, including the web build, instead of an instant cut.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeThroughSlideTransitionsBuilder(),
            TargetPlatform.iOS: _FadeThroughSlideTransitionsBuilder(),
            TargetPlatform.macOS: _FadeThroughSlideTransitionsBuilder(),
            TargetPlatform.windows: _FadeThroughSlideTransitionsBuilder(),
            TargetPlatform.linux: _FadeThroughSlideTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppBrand.ink,
              letterSpacing: -.3),
          titleLarge:
              TextStyle(fontWeight: FontWeight.w800, color: AppBrand.ink),
          titleMedium:
              TextStyle(fontWeight: FontWeight.w700, color: AppBrand.ink),
          bodyMedium: TextStyle(color: AppBrand.inkSoft),
          bodyLarge: TextStyle(color: AppBrand.ink),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppBrand.ink,
          titleTextStyle: TextStyle(
            color: AppBrand.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: AppBrand.ink),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppBrand.card,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBrand.radiusCard),
            side: const BorderSide(color: AppBrand.line),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppBrand.purple,
          textColor: AppBrand.ink,
          titleTextStyle: TextStyle(
              fontWeight: FontWeight.w700, color: AppBrand.ink, fontSize: 15),
          subtitleTextStyle: TextStyle(color: AppBrand.inkSoft, fontSize: 12.5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppBrand.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle:
                const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBrand.radiusPill),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppBrand.ink,
            side: const BorderSide(color: AppBrand.line, width: 1.4),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBrand.radiusPill),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppBrand.purple,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppBrand.cardAlt,
          hintStyle: const TextStyle(color: AppBrand.inkSoft),
          labelStyle: const TextStyle(color: AppBrand.inkSoft),
          floatingLabelStyle: const TextStyle(color: AppBrand.purple),
          prefixIconColor: AppBrand.inkSoft,
          suffixIconColor: AppBrand.inkSoft,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppBrand.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppBrand.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppBrand.purple, width: 1.6),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppBrand.cardAlt,
          selectedColor: AppBrand.purple,
          side: const BorderSide(color: AppBrand.line),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, color: AppBrand.ink),
          secondaryLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppBrand.ink,
          unselectedLabelColor: AppBrand.inkSoft,
          indicatorColor: AppBrand.purple,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontWeight: FontWeight.w800),
          dividerColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppBrand.card,
          indicatorColor: AppBrand.purple.withValues(alpha: .22),
          elevation: 0,
          height: 66,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 11,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: states.contains(WidgetState.selected)
                    ? AppBrand.purple
                    : AppBrand.inkSoft,
              )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? AppBrand.purple
                    : AppBrand.inkSoft,
              )),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: AppBrand.card),
        bottomSheetTheme:
            const BottomSheetThemeData(backgroundColor: AppBrand.card),
        dividerTheme:
            const DividerThemeData(color: AppBrand.line, thickness: 1),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppBrand.green,
          linearTrackColor: AppBrand.line,
        ),
      );
}

/// Fade + gentle upward slide used for every screen transition, on every
/// platform. Keeps navigation feeling alive on web/desktop, where Flutter
/// otherwise shows an instant, un-animated screen swap.
class _FadeThroughSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
