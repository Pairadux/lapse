import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/routes.dart';
import 'dev_drawer.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showSettingsButton;
  final VoidCallback? onBack;
  final VoidCallback? onDataChanged;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
    this.showBackButton = false,
    this.showSettingsButton = true,
    this.onBack,
    this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.home);
                  }
                },
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: kDebugMode
                      ? () => Scaffold.of(context).openDrawer()
                      : null,
                ),
              ),
        actions: [
          ...?actions,
          if (showSettingsButton)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(Routes.settings),
            ),
        ],
      ),
      drawer: kDebugMode ? DevDrawer(onDataChanged: onDataChanged) : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
