import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../rides/domain/vehicle_type.dart';
import '../data/onboarding_repository.dart';
import 'widgets/onboarding_field_label.dart';
import 'widgets/onboarding_step_header.dart';

class RiderOnboardingPage extends StatefulWidget {
  const RiderOnboardingPage({super.key});

  @override
  State<RiderOnboardingPage> createState() => _RiderOnboardingPageState();
}

class _RiderOnboardingPageState extends State<RiderOnboardingPage> {
  final _repo = OnboardingRepository();
  final _pageCtrl = PageController();
  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());
  final _picker = ImagePicker();

  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _vehicleModelCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  final _licenseNumberCtrl = TextEditingController();
  final _licenseExpiryCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();

  VehicleType _vehicleType = VehicleType.bike;
  File? _licenseImage;
  File? _idImage;
  bool _saving = false;
  int _step = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _plateCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _licenseExpiryCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, int minAge) async {
    final now = DateTime.now();
    final initial = DateTime(now.year - minAge, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - minAge),
    );
    if (picked == null) return;
    ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickExpiryDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final initial = DateTime(now.year + 2, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
    );
    if (picked == null) return;
    ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<File?> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (file == null) return null;
    return File(file.path);
  }

  Future<void> _scanDocument({
    required bool isLicense,
  }) async {
    final file = await _pickImage(ImageSource.camera);
    if (file == null) return;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();

    final text = result.text.replaceAll('\n', ' ').trim();
    if (!mounted) return;
    setState(() {
      if (isLicense) {
        _licenseImage = file;
        if (text.isNotEmpty) _licenseNumberCtrl.text = text;
      } else {
        _idImage = file;
        if (text.isNotEmpty) _idNumberCtrl.text = text;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isEmpty
              ? 'Scan completed. Please fill the details.'
              : 'Scan completed. Please verify the number.',
        ),
      ),
    );
  }

  void _next() {
    final key = _formKeys[_step];
    if (!key.currentState!.validate()) return;

    if (_step == 2 && _licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload your license photo.')),
      );
      return;
    }

    if (_step == 3 && _idImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload your ID card photo.')),
      );
      return;
    }

    if (_step == _formKeys.length - 1) {
      _submit();
      return;
    }

    setState(() => _step += 1);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (_licenseImage == null || _idImage == null) return;
    setState(() => _saving = true);
    try {
      final licenseUrl = await _repo.uploadDocument(
        file: _licenseImage!,
        folder: 'license',
        filename: 'license_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final idUrl = await _repo.uploadDocument(
        file: _idImage!,
        folder: 'id_card',
        filename: 'id_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await _repo.saveRiderProfile({
        'phone': _phoneCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'vehicleType': _vehicleType.id,
        'vehicleModel': _vehicleModelCtrl.text.trim(),
        'vehicleColor': _vehicleColorCtrl.text.trim(),
        'licensePlate': _plateCtrl.text.trim(),
        'licenseNumber': _licenseNumberCtrl.text.trim(),
        'licenseExpiry': _licenseExpiryCtrl.text.trim(),
        'licensePhotoUrl': licenseUrl,
        'idNumber': _idNumberCtrl.text.trim(),
        'idPhotoUrl': idUrl,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rider onboarding')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep(
                    title: 'Personal details',
                    subtitle: 'Tell us about yourself.',
                    step: 1,
                    total: 5,
                    formKey: _formKeys[0],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OnboardingFieldLabel(label: 'Phone number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '+1 555 000 0000',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.call_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Phone number is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'Date of birth'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dobCtrl,
                          readOnly: true,
                          onTap: () => _pickDate(_dobCtrl, 18),
                          decoration: const InputDecoration(
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.cake_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Date of birth is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'City'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            hintText: 'San Francisco',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.location_city_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'City is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'Address'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Street, building, apartment',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.home_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Address is required'
                                      : null,
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'Vehicle details',
                    subtitle: 'Tell us about your ride.',
                    step: 2,
                    total: 5,
                    formKey: _formKeys[1],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OnboardingFieldLabel(label: 'Vehicle type'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<VehicleType>(
                          value: _vehicleType,
                          items:
                              VehicleType.values
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type.label),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _vehicleType = value);
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.directions_bike_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'Vehicle model'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _vehicleModelCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Honda Civic / Yamaha YBR',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.commute_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Vehicle model is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'Vehicle color'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _vehicleColorCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Black / White',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.palette_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Vehicle color is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(
                          label: 'License plate number',
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _plateCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ABC-1234',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.confirmation_number_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'License plate number is required'
                                      : null,
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'License details',
                    subtitle: 'Upload and scan your driver license.',
                    step: 3,
                    total: 5,
                    formKey: _formKeys[2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OnboardingFieldLabel(label: 'License number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _licenseNumberCtrl,
                          decoration: const InputDecoration(
                            hintText: 'License number',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.badge_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'License number is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'License expiry'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _licenseExpiryCtrl,
                          readOnly: true,
                          onTap: () => _pickExpiryDate(_licenseExpiryCtrl),
                          decoration: const InputDecoration(
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.event_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'License expiry is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        _documentUploadRow(
                          label: 'License photo',
                          image: _licenseImage,
                          onCamera: () => _scanDocument(isLicense: true),
                          onGallery: () async {
                            final file = await _pickImage(ImageSource.gallery);
                            if (file == null || !mounted) return;
                            setState(() => _licenseImage = file);
                          },
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'ID card details',
                    subtitle: 'Upload and scan your ID card.',
                    step: 4,
                    total: 5,
                    formKey: _formKeys[3],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OnboardingFieldLabel(label: 'ID number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _idNumberCtrl,
                          decoration: const InputDecoration(
                            hintText: 'ID card number',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.credit_card_outlined, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'ID number is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        _documentUploadRow(
                          label: 'ID card photo',
                          image: _idImage,
                          onCamera: () => _scanDocument(isLicense: false),
                          onGallery: () async {
                            final file = await _pickImage(ImageSource.gallery);
                            if (file == null || !mounted) return;
                            setState(() => _idImage = file);
                          },
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'Review & finish',
                    subtitle: 'Confirm everything looks good.',
                    step: 5,
                    total: 5,
                    formKey: _formKeys[4],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reviewRow('Phone', _phoneCtrl.text),
                        _reviewRow('DOB', _dobCtrl.text),
                        _reviewRow('City', _cityCtrl.text),
                        _reviewRow('Address', _addressCtrl.text),
                        _reviewRow('Vehicle', _vehicleType.label),
                        _reviewRow('Model', _vehicleModelCtrl.text),
                        _reviewRow('Color', _vehicleColorCtrl.text),
                        _reviewRow('Plate', _plateCtrl.text),
                        _reviewRow('License no', _licenseNumberCtrl.text),
                        _reviewRow('License expiry', _licenseExpiryCtrl.text),
                        _reviewRow('ID number', _idNumberCtrl.text),
                        const SizedBox(height: 24),
                        Text(
                          'Tap Finish to submit your rider profile.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _step == 0 || _saving ? null : _back,
                    child: const Text('Back'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    child:
                        _saving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : Text(_step == 4 ? 'Finish' : 'Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String title,
    required String subtitle,
    required int step,
    required int total,
    required GlobalKey<FormState> formKey,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingStepHeader(
              title: title,
              subtitle: subtitle,
              step: step,
              totalSteps: total,
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _documentUploadRow({
    required String label,
    required File? image,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingFieldLabel(label: label),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                theme.brightness == Brightness.dark
                    ? const Color(0xFF1F2333)
                    : const Color(0xFFF2F4FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  theme.brightness == Brightness.dark
                      ? const Color(0xFF2C3246)
                      : const Color(0xFFE4E8F3),
            ),
          ),
          alignment: Alignment.center,
          child:
              image == null
                  ? Text(
                    'No document uploaded yet.',
                    style: theme.textTheme.bodySmall,
                  )
                  : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image, fit: BoxFit.cover, width: double.infinity),
                  ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
