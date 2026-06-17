import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../services/app_theme_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/error_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Attempt login
    final success = await ref
        .read(authProvider.notifier)
        .login(
          email: email,
          password: password,
          deviceName: 'flutter',
          fcmToken: 'temp-fcm-token', // TODO: Get actual FCM token
        );

    if (!mounted) return;

    if (!success) {
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        _showErrorDialog(authState.error!);
      }
    }
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(message: errorMessage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF0F4FA),
      body: Stack(
        children: [
          // Background blobs for visual interest
          Positioned(
            left: -50,
            bottom: 0,
            child: Opacity(
              opacity: isDark ? 0.08 : 0.15,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4C57D6),
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            top: -50,
            child: Opacity(
              opacity: isDark ? 0.05 : 0.1,
              child: Container(
                width: 400,
                height: 400,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2D8CFF),
                ),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111827) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFF4C57D6).withOpacity(0.08),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildThemeToggleButton(),
                              ],
                            ),
                            _buildLogo(),
                            const SizedBox(height: 12),
                            _buildHeader(),
                            const SizedBox(height: 28),
                            _buildEmailField(authState),
                            const SizedBox(height: 16),
                            _buildPasswordField(authState),
                            const SizedBox(height: 24),
                            _buildLoginButton(authState),
                            const SizedBox(height: 24),
                            _buildDivider(),
                            const SizedBox(height: 20),
                            _buildSocialButtons(authState),
                            const SizedBox(height: 24),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        return GestureDetector(
          onTap: () => AppThemeService.setDarkMode(!isDark),
          child: Icon(
            isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            color: isDark ? Colors.amber : const Color(0xFF1A1A1A),
            size: 24,
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/icon/app_icon.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF4C57D6),
              child: const Center(
                child: Text(
                  'RC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Welcome Back!',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'Login to continue your ride with ',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
            children: [
              TextSpan(
                text: 'RideConnect',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D8CFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(AuthState authState) {
    return _InputField(
      controller: _emailController,
      label: 'Email Address',
      hint: 'e.g., example@email.com',
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      enabled: !authState.isLoading,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email address is required';
        if (!v.contains('@') || !v.contains('.')) {
          return 'Enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(AuthState authState) {
    return _InputField(
      controller: _passwordController,
      label: 'Password',
      hint: 'Enter your password',
      prefixIcon: Icons.lock_outlined,
      obscureText: _obscurePassword,
      enabled: !authState.isLoading,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF999999),
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Widget _buildLoginButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4C57D6), Color(0xFF2D8CFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D8CFF).withOpacity(0.25),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: authState.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: authState.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'LOGIN',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF999999),
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
      ],
    );
  }

  Widget _buildSocialButtons(AuthState authState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          assetPath: 'assets/icon/google.png',
          onTap: authState.isLoading ? () {} : () {},
        ),
        const SizedBox(width: 16),
        _SocialButton(
          assetPath: 'assets/icon/facebook.png',
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _SocialButton(
          assetPath: 'assets/icon/X.png',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "Don't have an account? Contact support",
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          'Beta Version - Testing Only',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Input Field ────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              size: 20,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF2D8CFF),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF5E5B), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFF5E5B),
                width: 1.5,
              ),
            ),
            errorStyle: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFFF5E5B),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Social Login Button ─────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String assetPath;
  final VoidCallback onTap;

  const _SocialButton({
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.login),
          ),
        ),
      ),
    );
  }
}
