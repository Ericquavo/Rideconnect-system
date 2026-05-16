import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/driver_api.dart';
import '../../services/driver_language_service.dart';
import '../../services/driver_sync_service.dart';

class VehicleInfoPage extends StatefulWidget {
  const VehicleInfoPage({super.key});

  @override
  State<VehicleInfoPage> createState() => _VehicleInfoPageState();
}

class _VehicleInfoPageState extends State<VehicleInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final DriverLanguageService _lang = DriverLanguageService.instance;
  late final TextEditingController _vehicleNameController;
  late final TextEditingController _plateController;
  late final TextEditingController _colorController;
  late final TextEditingController _seatsController;
  late final TextEditingController _detailsController;
  late final TextEditingController _bikeEngineController;
  String _vehicleType = 'car';
  String _category = 'Economy';
  bool _loading = true;
  bool _saving = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgTop =>
      _isDarkMode ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFF);
  Color get _bgBottom =>
      _isDarkMode ? const Color(0xFF1A1F3A) : const Color(0xFFEFF4FF);
  Color get _cardBg =>
      _isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.92);
  Color get _cardBorder =>
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
    _vehicleNameController = TextEditingController();
    _plateController = TextEditingController();
    _colorController = TextEditingController();
    _seatsController = TextEditingController();
    _detailsController = TextEditingController();
    _bikeEngineController = TextEditingController();
    _loadVehicle();
  }

  @override
  void dispose() {
    _lang.languageNotifier.removeListener(_onLanguageChanged);
    _vehicleNameController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _seatsController.dispose();
    _detailsController.dispose();
    _bikeEngineController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadVehicle() async {
    try {
      final api = DriverApi.instance;
      final response = await api.getProfile();
      final profile = api.extractDataMap(response);
      final vehicleRaw = profile['vehicle'];
      final vehicle =
          vehicleRaw is Map<String, dynamic> ? vehicleRaw : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _vehicleNameController.text = api.readString(vehicle, const [
          'name',
          'model',
          'vehicle_name',
        ], fallback: api.readString(profile, const ['vehicle_name']));
        _plateController.text = api.readString(vehicle, const [
          'plate_number',
          'plate',
          'license_plate',
        ], fallback: api.readString(profile, const ['plate_number', 'plate']));
        _colorController.text = api.readString(vehicle, const [
          'color',
          'vehicle_color',
        ], fallback: api.readString(profile, const ['vehicle_color']));
        _seatsController.text = api.readString(vehicle, const [
          'seats',
          'seat_count',
          'number_of_seats',
        ], fallback: api.readString(profile, const ['seats']));
        _detailsController.text = api.readString(vehicle, const [
          'details',
          'description',
          'other_details',
          'notes',
        ], fallback: api.readString(profile, const ['vehicle_details']));
        _bikeEngineController.text = api.readString(vehicle, const [
          'engine_cc',
          'engine',
          'cc',
        ], fallback: api.readString(profile, const ['engine_cc']));
        final inferredType =
            api.readString(
              vehicle,
              const ['vehicle_type', 'type'],
              fallback: api.readString(profile, const ['vehicle_type']),
            ).toLowerCase();
        if (inferredType.contains('motor')) {
          _vehicleType = 'motorcycle';
        } else if (inferredType.contains('car') ||
            inferredType.contains('vehicle')) {
          _vehicleType = 'car';
        }
        _category = api.readString(
          vehicle,
          const ['category', 'type', 'vehicle_category'],
          fallback: api.readString(profile, const [
            'vehicle_category',
          ], fallback: _category),
        );
        if (_category.isEmpty) {
          _category = 'Economy';
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveVehicleDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final vehiclePayload = <String, dynamic>{
        'vehicle_type': _vehicleType,
        'type': _vehicleType,
        'name': _vehicleNameController.text.trim(),
        'plate_number': _plateController.text.trim(),
        'plate': _plateController.text.trim(),
        'color': _colorController.text.trim(),
        'vehicle_color': _colorController.text.trim(),
        'category': _category,
        'vehicle_category': _category,
      };

      if (_vehicleType == 'car') {
        vehiclePayload.addAll(<String, dynamic>{
          'seats': _seatsController.text.trim(),
          'seat_count': _seatsController.text.trim(),
          'number_of_seats': _seatsController.text.trim(),
          'details': _detailsController.text.trim(),
          'description': _detailsController.text.trim(),
          'other_details': _detailsController.text.trim(),
        });
      } else {
        vehiclePayload.addAll(<String, dynamic>{
          'engine_cc': _bikeEngineController.text.trim(),
          'cc': _bikeEngineController.text.trim(),
          'details': _detailsController.text.trim(),
          'description': _detailsController.text.trim(),
          'other_details': _detailsController.text.trim(),
        });
      }

      await DriverApi.instance.updateProfile({'vehicle': vehiclePayload});
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
        content: Text(_lang.t('vehicle.saved')),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgTop,
        title: Text(
          _lang.t('vehicle.title'),
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
                        children: [
                          _infoCard(
                            title: 'Vehicle Type',
                            icon: Icons.directions_car_filled_rounded,
                            useLogo: true,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _VehicleTypeChip(
                                        label: 'Car',
                                        selected: _vehicleType == 'car',
                                        icon: Icons.directions_car_rounded,
                                        onTap: () {
                                          setState(() => _vehicleType = 'car');
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _VehicleTypeChip(
                                        label: 'Motorcycle',
                                        selected: _vehicleType == 'motorcycle',
                                        icon: Icons.two_wheeler_rounded,
                                        onTap: () {
                                          setState(
                                            () => _vehicleType = 'motorcycle',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _buildField(
                                  controller: _vehicleNameController,
                                  label:
                                      _vehicleType == 'car'
                                          ? 'Car model'
                                          : 'Motorcycle model',
                                ),
                                const SizedBox(height: 10),
                                _buildField(
                                  controller: _plateController,
                                  label:
                                      _vehicleType == 'car'
                                          ? 'Car plate number'
                                          : 'Motorcycle plate number',
                                ),
                                const SizedBox(height: 10),
                                _buildField(
                                  controller: _colorController,
                                  label:
                                      _vehicleType == 'car'
                                          ? 'Car color'
                                          : 'Motorcycle color',
                                ),
                                const SizedBox(height: 10),
                                if (_vehicleType == 'car') ...[
                                  _buildField(
                                    controller: _seatsController,
                                    label: 'Number of seats',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 10),
                                ] else ...[
                                  _buildField(
                                    controller: _bikeEngineController,
                                    label: 'Engine size (cc)',
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _buildField(
                                  controller: _detailsController,
                                  label:
                                      _vehicleType == 'car'
                                          ? 'Other car details'
                                          : 'Other motorcycle details',
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value:
                                      const [
                                            'Economy',
                                            'Premium',
                                            'Comfort',
                                            'XL',
                                          ].contains(_category)
                                          ? _category
                                          : 'Economy',
                                  dropdownColor:
                                      _isDarkMode
                                          ? const Color(0xFF1A1F3A)
                                          : Colors.white,
                                  iconEnabledColor: const Color(0xFF6C63FF),
                                  style: GoogleFonts.poppins(
                                    color: _textPrimary,
                                  ),
                                  decoration: _inputDecoration(
                                    _lang.t('vehicle.category'),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Economy',
                                      child: Text(_lang.t('vehicle.economy')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Premium',
                                      child: Text(_lang.t('vehicle.premium')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Comfort',
                                      child: Text(_lang.t('vehicle.comfort')),
                                    ),
                                    DropdownMenuItem(
                                      value: 'XL',
                                      child: Text(_lang.t('vehicle.xl')),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _category = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _saveVehicleDetails,
                              icon: const Icon(Icons.save_outlined),
                              label:
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
                                        _lang.t('vehicle.saveChanges'),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
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

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool useLogo = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              useLogo
                  ? SizedBox(
                    width: 24,
                    height: 24,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/rideconnect_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                  : Icon(icon, color: const Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: _textPrimary),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return _lang.t('common.required');
        }
        return null;
      },
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
      filled: true,
      fillColor:
          _isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 11),
    );
  }
}

class _VehicleTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _VehicleTypeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : const Color(0xFFC9D6F2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF6C63FF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
