import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_theme.dart';

class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialEmail;

  const EditProfilePage({
    super.key,
    required this.initialName,
    required this.initialEmail,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final TextEditingController _phoneCtrl = TextEditingController(
    text: '+250 788 000 000',
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    return SettingsPageLayout(
      title: 'Edit Profile',
      icon: Icons.edit_rounded,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            SettingsCard(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: palette.brandGradient,
                        ),
                        child: Center(
                          child: Text(
                            _nameCtrl.text.isNotEmpty
                                ? _nameCtrl.text[0].toUpperCase()
                                : 'P',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap camera icon to change photo',
                    style: GoogleFonts.poppins(
                      color: palette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              child: Column(
                children: [
                  _field(
                    context,
                    _nameCtrl,
                    'Full Name',
                    Icons.person_rounded,
                    TextInputType.name,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    _emailCtrl,
                    'Email',
                    Icons.email_rounded,
                    TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    context,
                    _phoneCtrl,
                    'Phone Number',
                    Icons.phone_rounded,
                    TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            BrandButton(
              text: _saving ? 'Updating...' : 'Update Profile',
              icon: Icons.check_circle_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController c,
    String hint,
    IconData icon,
    TextInputType type,
  ) {
    final palette = SettingsPalette.of(context);
    return TextField(
      controller: c,
      keyboardType: type,
      style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        filled: true,
        fillColor: palette.surface,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: palette.textMuted),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.4),
        ),
      ),
    );
  }
}
