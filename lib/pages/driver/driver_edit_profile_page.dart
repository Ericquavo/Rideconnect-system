import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

class DriverEditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialEmail;

  const DriverEditProfilePage({
    super.key,
    required this.initialName,
    required this.initialEmail,
  });

  @override
  State<DriverEditProfilePage> createState() => _DriverEditProfilePageState();
}

class _DriverEditProfilePageState extends State<DriverEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final DriverLanguageService _lang = DriverLanguageService.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  final List<Color> _avatarColors = const [
    Color(0xFF6C63FF),
    Color(0xFF3B82F6),
    Color(0xFF14B8A6),
    Color(0xFF0EA5E9),
  ];
  int _avatarColorIndex = 0;
  bool _saving = false;
  bool _loading = true;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFEFF4FF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFDCE8FF);
  Color get _surface =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _surfaceBorder =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFC9D6F2);
  Color get _textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDarkMode ? Colors.white54 : const Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _lang.ensureInitialized();
    _lang.languageNotifier.addListener(_onLanguageChanged);
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: '+250 788 123 456');
    _emailController = TextEditingController(text: widget.initialEmail);
    _loadProfile();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _changeAvatarColor() {
    setState(() {
      _avatarColorIndex = (_avatarColorIndex + 1) % _avatarColors.length;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final api = DriverApi.instance;
      final response = await api.getProfile();
      final profile = api.extractDataMap(response);

      if (!mounted) return;
      setState(() {
        _nameController.text = api.readString(profile, const [
          'name',
          'full_name',
        ], fallback: widget.initialName);
        _phoneController.text = api.readString(profile, const [
          'phone',
          'phone_number',
        ], fallback: _phoneController.text);
        _emailController.text = api.readString(profile, const [
          'email',
        ], fallback: widget.initialEmail);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      await DriverApi.instance.updateProfile({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF5E5B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    DriverSyncService.instance.bumpDataVersion();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_lang.t('edit.profileUpdated')),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColors[_avatarColorIndex];

    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgTop,
        title: Text(
          _lang.t('edit.title'),
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child:
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        avatarColor,
                                        const Color(0xFF3B82F6),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: avatarColor.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _nameController.text.trim().isNotEmpty
                                          ? _nameController.text
                                              .trim()[0]
                                              .toUpperCase()
                                          : 'D',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 34,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _changeAvatarColor,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: Text(_lang.t('edit.updatePicture')),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF6C63FF),
                                    textStyle: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _fieldCard(
                            child: _buildTextField(
                              controller: _nameController,
                              label: _lang.t('edit.fullName'),
                              icon: Icons.person_outline_rounded,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return _lang.t('edit.enterName');
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _fieldCard(
                            child: _buildTextField(
                              controller: _phoneController,
                              label: _lang.t('edit.phoneNumber'),
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return _lang.t('edit.enterPhone');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _fieldCard(
                            child: _buildTextField(
                              controller: _emailController,
                              label: _lang.t('edit.emailAddress'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty || !email.contains('@')) {
                                  return _lang.t('edit.validEmail');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child:
                                  _saving
                                      ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                        _lang.t('edit.saveChanges'),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
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

  Widget _fieldCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _surfaceBorder),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.poppins(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        border: InputBorder.none,
        errorStyle: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }
}
