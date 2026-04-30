import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/otp_service.dart';
import 'passenger/passenger_dashboard.dart';
import 'driver/driver_dashboard.dart';
import '../auth/auth_session.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String requestId;
  final String? userType; // 'passenger' or 'driver'

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.requestId,
    this.userType,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _resendCooldown = false;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showSnack('Please enter the OTP', isError: true);
      return;
    }

    if (otp.length != 6) {
      _showSnack('OTP must be 6 digits', isError: true);
      return;
    }

    setState(() => _isVerifying = true);
    final result = await OtpService.verifyOtp(
      email: widget.email,
      otp: otp,
      requestId: widget.requestId,
    );
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (!result.success) {
      _showSnack(result.message, isError: true);
      return;
    }

    // Save session
    final normalizedRole = (result.role ?? 'passenger').toLowerCase();
    final isPassenger =
        normalizedRole == 'passenger' || normalizedRole == 'rider';
    final isDriver = normalizedRole == 'driver';

    if (isPassenger) {
      await AuthSession.save(
        role: normalizedRole,
        name: result.name ?? 'Passenger',
        email: result.email ?? widget.email,
        token: result.token,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) => PassengerDashboard(
                passengerName: result.name ?? 'Passenger',
                passengerEmail: result.email ?? widget.email,
              ),
        ),
        (_) => false,
      );
    } else if (isDriver) {
      await AuthSession.save(
        role: normalizedRole,
        name: result.name ?? 'Driver',
        email: result.email ?? widget.email,
        token: result.token,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (_) => DriverDashboard(
                driverName: result.name ?? 'Driver',
                driverEmail: result.email ?? widget.email,
              ),
        ),
        (_) => false,
      );
    }
  }

  void _resendOtp() async {
    setState(() {
      _resendCooldown = true;
      _resendCountdown = 60;
    });

    final result = await OtpService.resendOtp(
      email: widget.email,
      userType: widget.userType,
    );

    if (!mounted) return;

    _showSnack(result.message, isError: !result.success);

    // Countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    }).whenComplete(() {
      if (mounted) {
        setState(() => _resendCooldown = false);
      }
    });
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFFF5E5B) : const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient =
        isDark
            ? [const Color(0xFF0A0E1A), const Color(0xFF1A1F3A)]
            : [const Color(0xFFF8FAFF), const Color(0xFFEFF4FF)];
    final cardBg =
        isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.95);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Verify OTP',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle with email
                  Text(
                    'We\'ve sent a 6-digit code to ${widget.email}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // OTP Input Field
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6C63FF),
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 32,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        disabledBackgroundColor: const Color(
                          0xFF6C63FF,
                        ).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _isVerifying
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                'Verify OTP',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resend OTP
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive the code?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _resendCooldown ? null : _resendOtp,
                          child: Text(
                            _resendCooldown
                                ? 'Resend in $_resendCountdown seconds'
                                : 'Resend OTP',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  _resendCooldown
                                      ? Colors.grey
                                      : const Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
