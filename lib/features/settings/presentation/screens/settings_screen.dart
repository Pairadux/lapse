import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../auth/application/auth_service.dart';

/// Obsidian-inspired settings screen with sectioned layout.
///
/// Desktop: fixed left sidebar nav + scrollable right content.
/// Mobile: scrollable content with bottom section nav.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

// ─── Section definition ─────────────────────────────────────────────────────

class _Section {
  final String label;
  final IconData icon;
  final GlobalKey key;

  _Section({required this.label, required this.icon}) : key = GlobalKey();
}

// ─── Auth display states ────────────────────────────────────────────────────

enum _AuthDisplayState { signInForm, confirmingEmail, accountInfo }

// ─── Main state ─────────────────────────────────────────────────────────────

class _SettingsScreenState extends State<SettingsScreen> {
  static const _sidebarWidth = 220.0;
  static const _contentMaxWidth = 640.0;
  static const _wideBreakpoint = 720.0;

  final _scrollController = ScrollController();
  final _authService = AuthService();

  late final List<_Section> _sections;
  int _activeSectionIndex = 0;

  // Auth form state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthDisplayState _authDisplayState = _AuthDisplayState.signInForm;
  bool _isAuthLoading = false;
  bool _obscurePassword = true;
  String? _pendingEmail;
  Timer? _confirmationTimer;
  int _confirmationElapsed = 0;

  // App info
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _sections = [
      _Section(label: 'Account', icon: Icons.person_outline),
      _Section(label: 'Sync', icon: Icons.cloud_outlined),
      _Section(label: 'Study', icon: Icons.school_outlined),
      _Section(label: 'Appearance', icon: Icons.palette_outlined),
      _Section(label: 'About', icon: Icons.info_outline),
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

  void _onScroll() {
    final pos = _scrollController.position;

    // If at or near the bottom, highlight the last section.
    if (pos.pixels >= pos.maxScrollExtent - 20) {
      if (_activeSectionIndex != _sections.length - 1) {
        setState(() => _activeSectionIndex = _sections.length - 1);
      }
      return;
    }

    int closest = 0;
    double closestDistance = double.infinity;

    for (var i = 0; i < _sections.length; i++) {
      final keyContext = _sections[i].key.currentContext;
      if (keyContext == null) continue;
      final box = keyContext.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero).dy;
      // Account for app bar height (~56) and some padding
      final distance = (position - 80).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = i;
      }
    }

    if (closest != _activeSectionIndex) {
      setState(() => _activeSectionIndex = closest);
    }
  }

  void _scrollToSection(int index) {
    final keyContext = _sections[index].key.currentContext;
    if (keyContext == null) return;

    final box = keyContext.findRenderObject() as RenderBox;
    final screenY = box.localToGlobal(Offset.zero).dy;

    // Scroll so the section header lands at the top of the viewport
    // (accounting for AppBar height + padding ≈ 80px).
    final target = _scrollController.offset + screenY - 80;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isLoading = false;

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
                      icon: Icon(obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword),
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
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
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
                        _showError('Please fill in all fields.');
                        return;
                      }
                      if (password.length < 6) {
                        _showError('Password must be at least 6 characters.');
                        return;
                      }
                      if (password != confirm) {
                        _showError('Passwords do not match.');
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final response = await _authService.signUpWithEmail(
                            email, password);
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
                            _authDisplayState =
                                _AuthDisplayState.confirmingEmail;
                          });
                          _startConfirmationPolling(email);
                        }
                      } on AuthException catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) _showError(e.message);
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(sent ? 'Check your email' : 'Reset password'),
          content: sent
              ? Text(
                  'We sent a password reset link to ${emailCtrl.text.trim()}.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
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
                          _showError('Please enter your email.');
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        try {
                          await _authService.resetPassword(email);
                          setDialogState(() {
                            isLoading = false;
                            sent = true;
                          });
                        } on AuthException catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) _showError(e.message);
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
        final response =
            await _authService.signInWithEmail(email, _passwordController.text);
        if (response.session != null && mounted) {
          _confirmationTimer?.cancel();
          _passwordController.clear();
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          child: SizedBox(
            width: _sidebarWidth,
            child: _buildSidebar(),
          ),
        ),
        const VerticalDivider(width: 1),
        FocusTraversalGroup(
          child: Expanded(
            child: _buildScrollableContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildScrollableContent();
  }

  // ─── Sidebar (desktop) ───────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.xl,
          horizontal: Spacing.sm,
        ),
        children: List.generate(_sections.length, (i) {
          final section = _sections[i];
          final isActive = i == _activeSectionIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Material(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Spacing.radiusSm),
              child: InkWell(
                borderRadius: BorderRadius.circular(Spacing.radiusSm),
                onTap: () => _scrollToSection(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        section.icon,
                        size: 20,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: Spacing.md),
                      Text(
                        section.label,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
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
        }),
      ),
    );
  }

  // ─── Bottom nav (mobile) ──────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_sections.length, (i) {
              final section = _sections[i];
              final isActive = i == _activeSectionIndex;
              return InkWell(
                borderRadius: BorderRadius.circular(Spacing.radiusSm),
                onTap: () => _scrollToSection(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section.icon,
                        size: 20,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        section.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
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
              _buildAppearanceSection(),
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

  Widget _buildSectionHeader(String title, GlobalKey key) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Spacing.sm),
        const Divider(),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
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
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
        const Icon(Icons.mark_email_unread_outlined,
            size: 48, color: AppColors.primary),
        const SizedBox(height: Spacing.lg),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'We sent a confirmation link to $_pendingEmail. '
          'Once you confirm, you\'ll be signed in automatically.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
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
          leading: const Icon(Icons.check_circle_outline,
              color: AppColors.success),
          title: 'Status',
          subtitle: 'Signed in',
        ),
        const SizedBox(height: Spacing.xl),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: Spacing.md),
        TextButton.icon(
          onPressed: () {
            _showError('Account deletion is not yet available.');
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          label: const Text(
            'Delete account',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }

  // ─── Sync section ─────────────────────────────────────────────────────

  Widget _buildSyncSection() {
    final isSignedIn = _authService.currentSession != null;

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
          subtitle: isSignedIn ? 'Connected' : 'Not signed in',
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading:
              const Icon(Icons.sync_outlined, color: AppColors.textSecondary),
          title: 'Sync now',
          subtitle: 'Manually push and pull changes',
          trailing: OutlinedButton(
            onPressed: isSignedIn
                ? () => _showError('Sync is not yet implemented.')
                : null,
            child: const Text('Sync'),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(Icons.history_outlined,
              color: AppColors.textSecondary),
          title: 'Sync activity',
          subtitle: 'View sync history and resolve conflicts',
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textTertiary),
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
          leading: const Icon(Icons.add_circle_outline,
              color: AppColors.textSecondary),
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
            child: const Text('20', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(Icons.tune_outlined,
              color: AppColors.textSecondary),
          title: 'FSRS parameters',
          subtitle: 'Advanced scheduling algorithm settings',
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textTertiary),
        ),
      ],
    );
  }

  // ─── Appearance section ───────────────────────────────────────────────

  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appearance', _sections[3].key),
        _SettingsTile(
          leading: const Icon(Icons.dark_mode_outlined,
              color: AppColors.textSecondary),
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
            child: const Text('Dark', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(Icons.touch_app_outlined,
              color: AppColors.textSecondary),
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
          leading: const Icon(Icons.animation_outlined,
              color: AppColors.textSecondary),
          title: 'Reduced motion',
          subtitle: 'Minimize animations throughout the app',
          trailing: Switch(
            value: false,
            onChanged: (_) =>
                _showError('Reduced motion not yet implemented.'),
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
        _buildSectionHeader('About', _sections[4].key),
        _SettingsTile(
          leading:
              const Icon(Icons.info_outline, color: AppColors.textSecondary),
          title: 'Version',
          subtitle: _appVersion.isEmpty ? '…' : _appVersion,
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(Icons.bug_report_outlined,
              color: AppColors.textSecondary),
          title: 'Report an issue',
          subtitle: 'Help us improve Lapse',
          trailing:
              const Icon(Icons.open_in_new, size: 18, color: AppColors.textTertiary),
        ),
        const SizedBox(height: Spacing.md),
        _SettingsTile(
          leading: const Icon(Icons.description_outlined,
              color: AppColors.textSecondary),
          title: 'Open-source licenses',
          subtitle: 'Third-party software used in this app',
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textTertiary),
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

  const _SettingsTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.sm,
        horizontal: Spacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
  }
}

