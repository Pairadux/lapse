import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/database/database_helper.dart';
import 'core/routing/app_router.dart';
import 'core/routing/page_transitions.dart';
import 'core/supabase/supabase_config.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_snack_bar.dart';
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
        titleBarStyle: Platform.isMacOS
            ? TitleBarStyle.normal
            : TitleBarStyle.hidden,
      ),
      () async {
        if (Platform.isLinux || Platform.isWindows) {
          await windowManager.setIcon('assets/icons/icon-other.png');
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  await SupabaseConfig.initialize();

  // Purge stale tombstones on launch (fire-and-forget, non-blocking).
  DatabaseHelper.instance.purgeTombstones();

  runApp(const ProviderScope(child: LapseApp()));
}

class _ConnectivityToast extends ConsumerWidget {
  final Widget child;
  const _ConnectivityToast({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      syncServiceProvider.select((s) => s.isOnline),
      (prev, isOnline) {
        if (prev == null) return;
        if (!isOnline) {
          AppSnackBar.show(context, 'You\'re offline',
              backgroundColor: AppColors.error);
        } else {
          AppSnackBar.show(context, 'Back online',
              duration: const Duration(seconds: 2));
        }
      },
    );
    return child;
  }
}

class LapseApp extends ConsumerWidget {
  const LapseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize sync service so lifecycle listener starts immediately.
    ref.watch(syncServiceProvider);

    return ToastificationWrapper(
      child: MaterialApp.router(
      title: 'Lapse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
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

        return _ConnectivityToast(child: content);
      },
      ),
    );
  }
}
