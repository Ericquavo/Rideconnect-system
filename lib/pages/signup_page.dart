import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';


import '../auth/auth_api.dart';
import '../services/app_theme_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _emailController = TextEditingController();

  final _phoneController = TextEditingController();

  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;

  bool _obscureConfirm = true;

  bool _isLoading = false;

  late AnimationController _animController;

  late Animation<double> _fadeAnim;

  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();

    _nameController.dispose();

    _emailController.dispose();

    _phoneController.dispose();

    _passwordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF131729),

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        content: Text(
          message,

          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }

  void _handleSignup() async {
    final name = _nameController.text.trim();

    final email = _emailController.text.trim();

    final phone = _phoneController.text.trim();

    final password = _passwordController.text.trim();

    final confirmPassword = _confirmPasswordController.text.trim();

    // Validate all fields

    if (name.isEmpty) {
      _showError('Full name is required');

      return;
    }

    if (name.length < 3) {
      _showError('Name must be at least 3 characters');

      return;
    }

    if (email.isEmpty) {
      _showError('Email is required');

      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(email)) {
      _showError('Enter a valid email');

      return;
    }

    if (phone.isEmpty) {
      _showError('Phone number is required');

      return;
    }

    if (phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 7) {
      _showError('Enter a valid phone number');

      return;
    }

    if (password.isEmpty) {
      _showError('Password is required');

      return;
    }

    if (password.length < 8) {
      _showError('Password must be at least 8 characters');

      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      _showError('Password must contain at least one uppercase letter');

      return;
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      _showError('Password must contain at least one lowercase letter');

      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showError('Password must contain at least one number');

      return;
    }

    if (!RegExp(r'[!@#$%^&*()_+=\-\[\]{};:<>?/\\|`~]').hasMatch(password)) {
      _showError('Password must contain a special character (!@#\$%^&*)');

      return;
    }

    if (confirmPassword.isEmpty) {
      _showError('Please confirm your password');

      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');

      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthApi.register(
      fullName: name,
      email: email,
      phoneNumber: phone,
      password: password,
      passwordConfirmation: confirmPassword,
      role: 'passenger',
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (!result.success) {
      _showError(result.message);
      return;
    }

    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: const Color(0xFF131729),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account Created!',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome to RideConnect 🎉\nYour account has been successfully created.\nAwait admin approval to start booking rides.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white54,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          'Continue to Login',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background circles for visual depth
          Positioned(
            left: -50,
            bottom: 0,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            top: -40,
            child: Opacity(
              opacity: 0.09,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6C63FF,
                              ).withValues(alpha: 0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 40,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [_buildThemeToggleButton()],
                              ),
                              const SizedBox(height: 14),
                              _buildHeader(),
                              const SizedBox(height: 20),
                              _buildNameField(),
                              const SizedBox(height: 16),
                              _buildEmailField(),
                              const SizedBox(height: 16),
                              _buildPhoneField(),
                              const SizedBox(height: 16),
                              _buildPasswordField(),
                              const SizedBox(height: 16),
                              _buildConfirmPasswordField(),
                              const SizedBox(height: 24),
                              _buildSignupButton(),
                              const SizedBox(height: 20),
                              _buildDivider(),
                              const SizedBox(height: 20),
                              _buildSocialButtons(),
                              const SizedBox(height: 28),
                              _buildLoginRedirect(context),
                            ],
                          ),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Create Account',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign up to get started with RideConnect',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return _InputField(
      controller: _nameController,
      label: 'Full Name',
      hint: 'Enter your full name',
      prefixIcon: Icons.person_outline,
      keyboardType: TextInputType.name,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Full name is required';
        if (v.trim().length < 3) return 'Name must be at least 3 characters';
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return _InputField(
      controller: _emailController,
      label: 'Email',
      hint: 'Enter your email',
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email is required';
        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(v)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return _InputField(
      controller: _phoneController,
      label: 'Phone Number',
      hint: 'Enter your phone number',
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Phone number is required';
        if (v.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 7) {
          return 'Enter a valid phone number';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _InputField(
      controller: _passwordController,
      label: 'Password',
      hint: 'Enter your password',
      prefixIcon: Icons.lock_outlined,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF999999),
          size: 20,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 8) return 'Minimum 8 characters';
        if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Need uppercase letter';
        if (!RegExp(r'[a-z]').hasMatch(v)) return 'Need lowercase letter';
        if (!RegExp(r'[0-9]').hasMatch(v)) return 'Need a number';
        if (!RegExp(r'[!@#$%^&*]').hasMatch(v)) return 'Need special char (!@#\$%)';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return _InputField(
      controller: _confirmPasswordController,
      label: 'Confirm Password',
      hint: 'Re-enter your password',
      prefixIcon: Icons.lock_outlined,
      obscureText: _obscureConfirm,
      suffixIcon: IconButton(
        icon: Icon(
          _obscureConfirm
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF999999),
          size: 20,
        ),
        onPressed: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please confirm your password';
        if (v != _passwordController.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C57D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _isLoading ? 'Creating Account...' : 'Sign Up',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFECEFF3),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or sign up with',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white38
                      : const Color(0xFF8A8A8A),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFECEFF3),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggleButton() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        return GestureDetector(
          onTap: () => AppThemeService.setDarkMode(!isDark),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset('assets/icon/dark mode.png'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconSocialButton(
          assetPath: 'assets/icon/google.png',
          color: const Color(0xFFEA4335),
          onTap: () {},
        ),
        const SizedBox(width: 18),
        _IconSocialButton(
          assetPath: 'assets/icon/facebook.png',
          color: const Color(0xFF1877F2),
          onTap: () {},
        ),
        const SizedBox(width: 18),
        _IconSocialButton(
          assetPath: 'assets/icon/X.png',
          color: const Color(0xFF000000),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildLoginRedirect(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Text(
            'Already have an account? ',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : const Color(0xFF666666),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Sign In',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,

    required this.label,

    required this.hint,

    required this.prefixIcon,

    this.obscureText = false,

    this.suffixIcon,

    this.keyboardType = TextInputType.text,

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
            color: isDark ? Colors.white70 : const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              prefixIcon,
              color: isDark ? Colors.white54 : const Color(0xFF999999),
              size: 20,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor:
                isDark ? const Color(0xFF111827) : const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4C57D6),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF5E5B), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
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

class _IconSocialButton extends StatelessWidget {
  final String assetPath;
  final Color color;
  final VoidCallback onTap;

  const _IconSocialButton({
    required this.assetPath,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: Center(
          child: Image.asset(
            assetPath,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
