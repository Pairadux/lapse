import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/routing/app_router.dart';
import 'core/routing/page_transitions.dart';
import 'core/services/connectivity_service.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: const Size(1280, 720),
        minimumSize: const Size(400, 500),
        center: true,
        titleBarStyle: Platform.isMacOS ? TitleBarStyle.normal : TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  await SupabaseConfig.initialize();

  // Initialize connectivity service with scaffold messenger key
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  ConnectivityService().setScaffoldMessengerKey(scaffoldMessengerKey);

  runApp(LapseApp(scaffoldMessengerKey: scaffoldMessengerKey));
}

class LapseApp extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const LapseApp({super.key, required this.scaffoldMessengerKey});

  @override
  State<LapseApp> createState() => _LapseAppState();
}

class _LapseAppState extends State<LapseApp> {
  @override
  void initState() {
    super.initState();
    // Show offline snack bar on startup if offline
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityService.showOfflineSnackBar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Lapse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        scaffoldMessengerKey: widget.scaffoldMessengerKey,
        routerConfig: appRouter,
        builder: (context, child) {
          Widget content = child ?? const SizedBox();

          if (isDesktop && !Platform.isMacOS) {
            content = Column(
              children: [
                const WindowTitleBar(),
                Expanded(child: content),
              ],
            );
          }

          return content;
        },
      ),
    );
  }
}
