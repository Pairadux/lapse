import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/sync/sync_pull_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_service.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';

/// Obsidian-inspired settings screen with sectioned layout.
///
/// Desktop: fixed left sidebar nav + scrollable right content.
/// Mobile: scrollable content with bottom section nav.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

// ─── Section definition ─────────────────────────────────────────────────────

class _Section {
  final String label;
  final IconData icon;
  final GlobalKey key;

  _Section({required this.label, required this.icon}) : key = GlobalKey();
}

// ─── Nav item (groups one or more sections for nav controls) ───────────────

class _NavItem {
  final String label;
  final IconData icon;
  final List<int> sectionIndices;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.sectionIndices,
  });
}

// ─── Auth display states ────────────────────────────────────────────────────

enum _AuthDisplayState { signInForm, confirmingEmail, accountInfo }

// ─── Main state ─────────────────────────────────────────────────────────────

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _sidebarWidth = 220.0;
  static const _contentMaxWidth = 640.0;
  static const _wideBreakpoint = 720.0;

  final _scrollController = ScrollController();
  final _authService = AuthService();

  late final List<_Section> _sections;
  late final List<_NavItem> _navItems;
  int _activeNavIndex = 0;
  int _activeSectionIndex = 0;
  bool _isScrollingToSection = false;

  // Auth form state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthDisplayState _authDisplayState = _AuthDisplayState.signInForm;
  bool _isAuthLoading = false;
  bool _obscurePassword = true;
  String? _pendingEmail;
  String? _pendingPassword;
  Timer? _confirmationTimer;
  int _confirmationElapsed = 0;

  // App info
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _sections = [
      _Section(label: 'Account', icon: Icons.person_outline),       // 0
      _Section(label: 'Sync', icon: Icons.cloud_outlined),          // 1
      _Section(label: 'Study', icon: Icons.school_outlined),        // 2
      _Section(label: 'Notifications', icon: Icons.notifications_outlined), // 3
      _Section(label: 'Appearance', icon: Icons.palette_outlined),  // 4
      _Section(label: 'Data', icon: Icons.storage_outlined),        // 5
      _Section(label: 'About', icon: Icons.info_outline),           // 6
    ];
    _navItems = const [
      _NavItem(label: 'User', icon: Icons.person_outline, sectionIndices: [0, 1]),
      _NavItem(label: 'Study', icon: Icons.school_outlined, sectionIndices: [2]),
      _NavItem(label: 'App', icon: Icons.apps_outlined, sectionIndices: [3, 4]),
      _NavItem(label: 'Data', icon: Icons.storage_outlined, sectionIndices: [5]),
      _NavItem(label: 'About', icon: Icons.info_outline, sectionIndices: [6]),
    ];
    _scrollController.addListener(_onScroll);
    _updateAuthState();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  void _updateAuthState() {
    final user = _authService.currentUser;
    if (user != null) {
      _authDisplayState = _AuthDisplayState.accountInfo;
    } else if (_pendingEmail != null) {
      _authDisplayState = _AuthDisplayState.confirmingEmail;
    } else {
      _authDisplayState = _AuthDisplayState.signInForm;
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

  // ─── Scroll tracking ───────────────────────────────────────────────────

  /// Maps a content section index to its owning nav item index.
  int _navIndexForSection(int sectionIndex) {
    for (var i = 0; i < _navItems.length; i++) {
      if (_navItems[i].sectionIndices.contains(sectionIndex)) return i;
    }
    return 0;
  }

  void _onScroll() {
    if (_isScrollingToSection) return;

    final pos = _scrollController.position;

    // If at or near the bottom, highlight the last section.
    if (pos.pixels >= pos.maxScrollExtent - 20) {
      final lastSection = _sections.length - 1;
      if (_activeSectionIndex != lastSection) {
        setState(() {
          _activeSectionIndex = lastSection;
          _activeNavIndex = _navIndexForSection(lastSection);
        });
      }
      return;
    }

    // Find the section whose header is closest to the top of the viewport.
    int closest = 0;
    double closestDistance = double.infinity;
    final appBarBottom =
        MediaQuery.of(context).padding.top + kToolbarHeight;

    for (var i = 0; i < _sections.length; i++) {
      final keyContext = _sections[i].key.currentContext;
      if (keyContext == null) continue;
      final box = keyContext.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero).dy;
      final distance = (position - appBarBottom).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = i;
      }
    }

    if (closest != _activeSectionIndex) {
      setState(() {
        _activeSectionIndex = closest;
        _activeNavIndex = _navIndexForSection(closest);
      });
    }
  }

  void _scrollToSection(int sectionIndex) {
    final keyContext = _sections[sectionIndex].key.currentContext;
    if (keyContext == null) return;

    // Lock highlight immediately so _onScroll doesn't override during animation.
    setState(() {
      _isScrollingToSection = true;
      _activeSectionIndex = sectionIndex;
      _activeNavIndex = _navIndexForSection(sectionIndex);
    });

    Scrollable.ensureVisible(
      keyContext,
      alignment: 0.03,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    ).then((_) => _isScrollingToSection = false);
  }

  // ─── Auth actions ─────────────────────────────────────────────────────

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => _isAuthLoading = true);
    try {
      await _authService.signInWithEmail(email, password);
      _emailController.clear();
      _passwordController.clear();
      if (mounted) {
        setState(() {
          _authDisplayState = _AuthDisplayState.accountInfo;
          _isAuthLoading = false;
        });
        _showSuccess('Signed in successfully.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isAuthLoading = false);
        _showError(e.message);
      }
    }
  }

  Future<void> _showSignUpDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final passwordCtrl = TextEditingController(text: _passwordController.text);
    final confirmCtrl = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create an account to sync your study data across devices.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: Spacing.md),
                  Text(
                    errorText!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text;
                      final confirm = confirmCtrl.text;

                      if (email.isEmpty || password.isEmpty) {
                        setDialogState(
                          () => errorText = 'Please fill in all fields.',
                        );
                        return;
                      }
                      final passwordErr = _validatePassword(password);
                      if (passwordErr != null) {
                        setDialogState(() => errorText = passwordErr);
                        return;
                      }
                      if (password != confirm) {
                        setDialogState(
                          () => errorText = 'Passwords do not match.',
                        );
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorText = null;
                      });
                      try {
                        final response = await _authService.signUpWithEmail(
                          email,
                          password,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);

                        if (response.session != null) {
                          // Email confirmation disabled — signed in immediately
                          setState(() {
                            _authDisplayState = _AuthDisplayState.accountInfo;
                          });
                          _showSuccess('Account created and signed in.');
                        } else {
                          // Email confirmation required
                          setState(() {
                            _pendingEmail = email;
                            _pendingPassword = password;
                            _authDisplayState =
                                _AuthDisplayState.confirmingEmail;
                          });
                          _startConfirmationPolling(email);
                        }
                      } on AuthException catch (e) {
                        setDialogState(() {
                          isLoading = false;
                          errorText = e.message;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool isLoading = false;
    bool sent = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(sent ? 'Check your email' : 'Reset password'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 340),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sent)
                    Text(
                      'We sent a password reset link to ${emailCtrl.text.trim()}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  if (errorText != null) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      errorText!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(sent ? 'Done' : 'Cancel'),
            ),
            if (!sent)
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) {
                          setDialogState(
                            () => errorText = 'Please enter your email.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        try {
                          await _authService.resetPassword(email);
                          setDialogState(() {
                            isLoading = false;
                            sent = true;
                          });
                        } on AuthException catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            errorText = e.message;
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send reset link'),
              ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
  }

  void _startConfirmationPolling(String email) {
    _confirmationElapsed = 0;
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _confirmationElapsed++;

      // Phase 1: every 1s for 60s
      // Phase 2: every 5s for 30min (1800s)
      // Phase 3: stop
      if (_confirmationElapsed > 1860) {
        _confirmationTimer?.cancel();
        return;
      }
      if (_confirmationElapsed > 60 && _confirmationElapsed % 5 != 0) return;

      try {
        final response = await _authService.signInWithEmail(
          email,
          _pendingPassword ?? '',
        );
        if (response.session != null && mounted) {
          _confirmationTimer?.cancel();
          _pendingPassword = null;
          setState(() {
            _pendingEmail = null;
            _authDisplayState = _AuthDisplayState.accountInfo;
          });
          _showSuccess('Email confirmed. Signed in.');
        }
      } catch (_) {
        // Not confirmed yet — keep polling
      }
    });
  }

  void _cancelConfirmation() {
    _confirmationTimer?.cancel();
    _pendingPassword = null;
    setState(() {
      _pendingEmail = null;
      _authDisplayState = _AuthDisplayState.signInForm;
    });
  }

  Future<void> _resendConfirmation() async {
    if (_pendingEmail == null) return;
    try {
      await _authService.resendConfirmation(_pendingEmail!);
      if (mounted) _showSuccess('Confirmation email resent.');
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        setState(() {
          _authDisplayState = _AuthDisplayState.signInForm;
        });
        _showSuccess('Signed out.');
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  /// Returns an error message if the password doesn't meet requirements,
  /// or null if valid.
  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.';
    }
    if (!password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      return 'Password must contain at least one special character.';
    }
    return null;
  }

  Future<void> _syncNow() async {
    final result = await ref.read(syncServiceProvider.notifier).syncNow();
    if (!mounted) return;
    if (result.ok) {
      _showSuccess(
        result.message.isNotEmpty ? result.message : 'Sync complete',
      );
    } else {
      _showError(result.error ?? 'Sync failed');
    }
  }

  void _showError(String message) {
    debugPrint('[Settings] ERROR: $message');
    AppSnackBar.show(context, message, backgroundColor: AppColors.error);
  }

  void _showSuccess(String message) {
    AppSnackBar.show(context, message);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          return isWide ? _buildWideLayout() : _buildNarrowLayout();
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideBreakpoint) {
            return const SizedBox.shrink();
          }
          return _buildBottomNav();
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        FocusTraversalGroup(
          child: SizedBox(width: _sidebarWidth, child: _buildSidebar()),
        ),
        const VerticalDivider(width: 1),
        FocusTraversalGroup(child: Expanded(child: _buildScrollableContent())),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildScrollableContent();
  }

  // ─── Sidebar (desktop, tree structure) ─────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.xl,
          horizontal: Spacing.sm,
        ),
        children: [
          for (var i = 0; i < _navItems.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.md),
            ..._buildSidebarNavItem(_navItems[i]),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSidebarNavItem(_NavItem nav) {
    if (nav.sectionIndices.length == 1) {
      // Flat item — single section, clickable
      final sectionIndex = nav.sectionIndices.first;
      final section = _sections[sectionIndex];
      final isActive = _activeSectionIndex == sectionIndex;
      return [_buildSidebarItem(section, sectionIndex, isActive)];
    }

    // Group — clickable parent highlights when any child is active
    final firstIndex = nav.sectionIndices.first;
    final isGroupActive = nav.sectionIndices.contains(_activeSectionIndex);
    return [
      _buildSidebarItem(
        _Section(label: nav.label, icon: nav.icon),
        firstIndex,
        isGroupActive,
      ),
      for (final sectionIndex in nav.sectionIndices)
        Padding(
          padding: const EdgeInsets.only(left: Spacing.xl),
          child: _buildSidebarItem(
            _sections[sectionIndex],
            sectionIndex,
            _activeSectionIndex == sectionIndex,
          ),
        ),
    ];
  }

  Widget _buildSidebarItem(_Section section, int sectionIndex, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Spacing.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Spacing.radiusSm),
          onTap: () => _scrollToSection(sectionIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 18,
                  color:
                      isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom nav (mobile, icon-only) ────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (i) {
              final nav = _navItems[i];
              final isActive = i == _activeNavIndex;
              return Tooltip(
                message: nav.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Spacing.radiusSm),
                  onTap: () => _scrollToSection(nav.sectionIndices.first),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.xs,
                    ),
                    child: Icon(
                      nav.icon,
                      size: 22,
                      color:
                          isActive ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── Scrollable content ───────────────────────────────────────────────

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xl,
        vertical: Spacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAccountSection(),
              const SizedBox(height: Spacing.xxxl),
              _buildSyncSection(),
              const SizedBox(height: Spacing.xxxl),
              _buildStudySection(),
              const SizedBox(height: Spacing.xxxl),
              _buildNotificationsSection(),
              const SizedBox(height: Spacing.xxxl),
              _buildAppearanceSection(),
              const SizedBox(height: Spacing.xxxl),
              _buildDataSection(),
              const SizedBox(height: Spacing.xxxl),
              _buildAboutSection(),
              const SizedBox(height: Spacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, GlobalKey key, {Color? color}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Divider(color: color?.withValues(alpha: 0.4)),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  // ─── Account section ──────────────────────────────────────────────────

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Account', _sections[0].key),
        switch (_authDisplayState) {
          _AuthDisplayState.signInForm => _buildSignInForm(),
          _AuthDisplayState.confirmingEmail => _buildConfirmingEmail(),
          _AuthDisplayState.accountInfo => _buildAccountInfo(),
        },
      ],
    );
  }

  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sign in to sync your study data across devices.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Spacing.xl),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isAuthLoading ? null : _signIn,
            child: _isAuthLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            TextButton(
              onPressed: _showSignUpDialog,
              child: const Text('Create account'),
            ),
            const Spacer(),
            TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        _buildOAuthDivider(),
        const SizedBox(height: Spacing.lg),
        _buildOAuthButtons(),
      ],
    );
  }

  Widget _buildOAuthDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(
            'or',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildOAuthButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _showError('Google sign-in is not yet available.');
            },
            icon: const Text(
              'G',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            label: const Text('Continue with Google'),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _showError('Apple sign-in is not yet available.');
            },
            icon: const Icon(Icons.apple, size: 20),
            label: const Text('Continue with Apple'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmingEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: Spacing.lg),
        Text('Check your email', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Spacing.sm),
        Text(
          'We sent a confirmation link to $_pendingEmail. '
          'Once you confirm, you\'ll be signed in automatically.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Spacing.lg),
        if (_confirmationElapsed < 1860)
          const Padding(
            padding: EdgeInsets.only(bottom: Spacing.lg),
            child: LinearProgressIndicator(),
          ),
        Row(
          children: [
            OutlinedButton(
              onPressed: _resendConfirmation,
              child: const Text('Resend email'),
            ),
            const SizedBox(width: Spacing.md),
            TextButton(
              onPressed: _cancelConfirmation,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountInfo() {
    final user = _authService.currentUser;
    final email = user?.email ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsTile(
          leading: const Icon(Icons.email_outlined, color: AppColors.primary),
          title: 'Email',
          subtitle: email,
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
          ),
          title: 'Status',
          subtitle: 'Signed in',
        ),
        const SizedBox(height: Spacing.xl),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  // ─── Sync section ─────────────────────────────────────────────────────

  Widget _buildSyncSection() {
    final isSignedIn = _authService.currentSession != null;
    final syncState = ref.watch(syncServiceProvider);
    final isSyncing = syncState.isSyncing;

    final statusSubtitle = !isSignedIn
        ? 'Not signed in'
        : syncState.lastError != null
        ? 'Error: ${syncState.lastError}'
        : syncState.lastSyncTime != null
        ? 'Last synced: ${_formatTime(syncState.lastSyncTime!)}'
        : 'Connected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Sync', _sections[1].key),
        _SettingsTile(
          leading: Icon(
            isSignedIn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: isSignedIn ? AppColors.success : AppColors.textTertiary,
          ),
          title: 'Sync status',
          subtitle: statusSubtitle,
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.sync_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Sync now',
          subtitle: 'Manually push and pull changes',
          trailing: OutlinedButton(
            onPressed: isSignedIn && !isSyncing ? _syncNow : null,
            child: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sync'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.history_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Sync activity',
          subtitle: 'View sync history and resolve conflicts',
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  // ─── Study section ────────────────────────────────────────────────────

  Widget _buildStudySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Study', _sections[2].key),
        _SettingsTile(
          leading: const Icon(
            Icons.add_circle_outline,
            color: AppColors.textSecondary,
          ),
          title: 'New cards per day',
          subtitle: 'Maximum number of new cards introduced daily',
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Spacing.radiusSm),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Text(
              '20',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.tune_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'FSRS parameters',
          subtitle: 'Advanced scheduling algorithm settings',
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  // ─── Appearance section ───────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance', _sections[4].key),
        _SettingsTile(
          leading: const Icon(
            Icons.dark_mode_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Theme',
          subtitle: 'Choose between dark and light mode',
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Spacing.radiusSm),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Text(
              'Dark',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.touch_app_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Tooltips',
          subtitle: 'Show helpful hints on hover',
          trailing: Switch(
            value: false,
            onChanged: (_) =>
                _showError('Tooltip settings not yet implemented.'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.animation_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Reduced motion',
          subtitle: 'Minimize animations throughout the app',
          trailing: Switch(
            value: false,
            onChanged: (_) => _showError('Reduced motion not yet implemented.'),
          ),
        ),
      ],
    );
  }

  // ─── Notifications section ───────────────────────────────────────────────

  Widget _buildNotificationsSection() {
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return settingsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Notifications', _sections[3].key),
          const _SettingsTile(
            leading: Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondary,
            ),
            title: 'Loading notification settings...',
            trailing: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Notifications', _sections[3].key),
          _SettingsTile(
            leading: const Icon(Icons.error_outline, color: AppColors.error),
            title: 'Failed to load notification settings',
            subtitle: '$error',
            trailing: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
              onPressed: () => ref.invalidate(notificationSettingsProvider),
            ),
          ),
        ],
      ),
      data: (settings) {
        final reminderTime = TimeOfDay(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
        );
        final reminderTimeLabel = MaterialLocalizations.of(
          context,
        ).formatTimeOfDay(reminderTime);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Notifications', _sections[3].key),
            _SettingsTile(
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
              ),
              title: 'Due card reminders',
              subtitle:
                  'Get alerts for cards due today, tomorrow, and in 1 week',
              trailing: Switch(
                value: settings.enabled,
                onChanged: (value) async {
                  final ok = await notifier.setEnabled(value);
                  if (!ok && mounted) {
                    _showError(
                      'Notification permission denied. Enable it in system settings.',
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: Spacing.md),
            _SettingsTile(
              leading: const Icon(
                Icons.schedule_outlined,
                color: AppColors.textSecondary,
              ),
              title: 'Reminder time',
              subtitle: settings.enabled
                  ? 'When reminders should appear'
                  : 'Enable reminders to set a time',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reminderTimeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: settings.enabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              onTap: settings.enabled
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: reminderTime,
                      );
                      if (picked == null) return;
                      await notifier.setReminderTime(
                        hour: picked.hour,
                        minute: picked.minute,
                      );
                    }
                  : null,
            ),
            const SizedBox(height: Spacing.md),
            _SettingsTile(
              leading: const Icon(
                Icons.today_outlined,
                color: AppColors.textSecondary,
              ),
              title: 'Due today',
              subtitle: 'Notify when cards are due today',
              trailing: Switch(
                value: settings.remindDueToday,
                onChanged: settings.enabled
                    ? (value) => notifier.setRemindDueToday(value)
                    : null,
              ),
            ),
            const SizedBox(height: Spacing.md),
            _SettingsTile(
              leading: const Icon(
                Icons.event_available_outlined,
                color: AppColors.textSecondary,
              ),
              title: '1 day before',
              subtitle: 'Notify one day before cards are due',
              trailing: Switch(
                value: settings.remindOneDayBefore,
                onChanged: settings.enabled
                    ? (value) => notifier.setRemindOneDayBefore(value)
                    : null,
              ),
            ),
            const SizedBox(height: Spacing.md),
            _SettingsTile(
              leading: const Icon(
                Icons.date_range_outlined,
                color: AppColors.textSecondary,
              ),
              title: '1 week before',
              subtitle: 'Notify one week before cards are due',
              trailing: Switch(
                value: settings.remindOneWeekBefore,
                onChanged: settings.enabled
                    ? (value) => notifier.setRemindOneWeekBefore(value)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Data section (danger zone) ───────────────────────────────────────

  Future<void> _deleteAllData() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete all study data?',
      message:
          'This will permanently delete all decks, cards, and reviews '
          'from this device. This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    await DatabaseHelper.instance.clearAllData();
    await SyncPullService.resetLastPullTimestamp();
    if (mounted) {
      AppSnackBar.show(context, 'All study data deleted');
      context.go(Routes.home);
    }
  }

  Widget _buildDataSection() {
    final isSignedIn = _authService.currentSession != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Data', _sections[5].key, color: AppColors.error),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(Spacing.radiusMd),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              _SettingsTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: AppColors.error,
                ),
                title: 'Delete all study data',
                subtitle:
                    'Permanently remove all decks, cards, and reviews from this device',
                trailing: OutlinedButton(
                  onPressed: _deleteAllData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              if (isSignedIn) ...[
                const SizedBox(height: Spacing.md),
                _SettingsTile(
                  leading: const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.error,
                  ),
                  title: 'Delete account',
                  subtitle:
                      'Permanently delete your account and all synced data',
                  trailing: OutlinedButton(
                    onPressed: () {
                      _showError('Account deletion is not yet available.');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── About section ────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('About', _sections[6].key),
        const _SettingsTile(
          leading: Icon(Icons.school_outlined, color: AppColors.primary),
          title: 'Lapse',
          subtitle: 'Spaced repetition flashcards',
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.info_outline,
            color: AppColors.textSecondary,
          ),
          title: 'Version',
          subtitle: _appVersion.isEmpty ? '...' : _appVersion,
        ),
        const SizedBox(height: Spacing.md),
        const _SettingsTile(
          leading: Icon(Icons.group_outlined, color: AppColors.textSecondary),
          title: 'Contributors',
          subtitle: 'Pairadux, GADudley, djanderson26, DevamPatel22',
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.code_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Source code',
          subtitle: 'github.com/Pairadux/lapse',
          trailing: const Icon(
            Icons.open_in_new,
            size: 18,
            color: AppColors.textTertiary,
          ),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/Pairadux/lapse'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.bug_report_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Report an issue',
          subtitle: 'Help us improve Lapse',
          trailing: const Icon(
            Icons.open_in_new,
            size: 18,
            color: AppColors.textTertiary,
          ),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/Pairadux/lapse/issues'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(
            Icons.description_outlined,
            color: AppColors.textSecondary,
          ),
          title: 'Open-source licenses',
          subtitle: 'Third-party software used in this app',
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Lapse',
            applicationVersion: _appVersion,
          ),
        ),
      ],
    );
  }
}

// ─── Reusable settings tile ─────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.sm,
        horizontal: Spacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Spacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(Spacing.radiusSm),
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
