import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/routing/app_router.dart';
import 'core/routing/page_transitions.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        minimumSize: Size(400, 500),
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  runApp(const ProviderScope(child: LapseApp()));
}

class LapseApp extends StatelessWidget {
  const LapseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lapse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        if (isDesktop) {
          return Column(
            children: [
              const WindowTitleBar(),
              Expanded(child: child ?? const SizedBox()),
            ],
          );
        }
        return child ?? const SizedBox();
      },
    );
  }
}
