import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://utmetuwnmgnterxrwavm.supabase.co',
    publishableKey: 'sb_publishable_h-YJFXDzrx7A12sgEYNk6A_TObw8AHO',
  );

  runApp(const ProviderScope(child: PrecisionPartsApp()));
}

class PrecisionPartsApp extends ConsumerWidget {
  const PrecisionPartsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PartMo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      routerConfig: router,
    );
  }
}
