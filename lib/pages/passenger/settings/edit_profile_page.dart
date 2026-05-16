import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../auth/auth_api.dart';
import '../../../auth/auth_session.dart';
import '../../../services/passenger_language_service.dart';
import '../../../services/passenger_preferences_service.dart';
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
  bool _loading = true;
  Uint8List? _photoBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _photoBytes = PassengerPreferencesService.profilePhoto;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = await AuthSession.load();
    final token = session?.token;
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to update profile.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthApi.updateProfile(
        token: token,
        payload: <String, dynamic>{
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_photoBytes != null) 'avatar_base64': base64Encode(_photoBytes!),
        },
      );
      // Defer updating the shared preferences notifier until after the route
      // pop completes to avoid notifier callbacks running during route
      // disposal which can cause framework assertion failures.
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    });

    // Update profile photo preferences after popping the route so any
    // listeners on other pages (which may rebuild) are notified when it's
    // safe. Do not await; any error here is non-fatal for the UI flow.
    PassengerPreferencesService.setProfilePhotoBytes(_photoBytes).catchError((
      _,
    ) {
      /* ignore */
    });
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _loadProfile() async {
    final session = await AuthSession.load();
    final token = session?.token;
    if (token == null || token.trim().isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final response = await AuthApi.getProfile(token: token);
      final data = response['data'];
      final profile =
          data is Map<String, dynamic>
              ? (data['user'] is Map<String, dynamic>
                  ? data['user'] as Map<String, dynamic>
                  : data)
              : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        final name = (profile['name'] ?? '').toString().trim();
        final email = (profile['email'] ?? '').toString().trim();
        final phone =
            (profile['phone'] ?? profile['phone_number'] ?? '')
                .toString()
                .trim();
        if (name.isNotEmpty) _nameCtrl.text = name;
        if (email.isNotEmpty) _emailCtrl.text = email;
        if (phone.isNotEmpty) _phoneCtrl.text = phone;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);
    final lang = PassengerLanguageService.instance;
    return SettingsPageLayout(
      title: lang.t('settings.editProfile'),
      icon: Icons.edit_rounded,
      child:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    SettingsCard(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: palette.brandGradient,
                                  ),
                                  child: ClipOval(
                                    child:
                                        _photoBytes != null &&
                                                _photoBytes!.isNotEmpty
                                            ? Image.memory(
                                              _photoBytes!,
                                              fit: BoxFit.cover,
                                            )
                                            : Center(
                                              child: Text(
                                                _nameCtrl.text.isNotEmpty
                                                    ? _nameCtrl.text[0]
                                                        .toUpperCase()
                                                    : 'P',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 34,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _pickPhoto,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6C63FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lang.t('edit.tapCamera'),
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
                            lang.t('edit.fullName'),
                            Icons.person_rounded,
                            TextInputType.name,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            context,
                            _emailCtrl,
                            lang.t('edit.email'),
                            Icons.email_rounded,
                            TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          _field(
                            context,
                            _phoneCtrl,
                            lang.t('edit.phone'),
                            Icons.phone_rounded,
                            TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    BrandButton(
                      text:
                          _saving
                              ? lang.t('edit.updating')
                              : lang.t('edit.update'),
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
