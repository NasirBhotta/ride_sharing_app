import 'package:flutter/material.dart';

import '../data/onboarding_repository.dart';
import 'widgets/onboarding_field_label.dart';
import 'widgets/onboarding_step_header.dart';

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({super.key});

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final _repo = OnboardingRepository();
  final _pageCtrl = PageController();
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());

  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  String _gender = 'Male';

  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 16, now.month, now.day);
    final earliest = DateTime(now.year - 80, now.month, now.day);
    final preferred = DateTime(now.year - 24, now.month, now.day);
    final initial =
        preferred.isAfter(latest)
            ? latest
            : preferred.isBefore(earliest)
            ? earliest
            : preferred;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: latest,
    );
    if (picked == null) return;
    ctrl.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  void _next() {
    final key = _formKeys[_step];
    if (!key.currentState!.validate()) return;
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
    setState(() => _saving = true);
    try {
      await _repo.saveCustomerProfile({
        'phone': _phoneCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'gender': _gender,
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'emergencyContact': {
          'name': _emergencyNameCtrl.text.trim(),
          'phone': _emergencyPhoneCtrl.text.trim(),
        },
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer onboarding')),
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
                    subtitle: 'Help us tailor your ride experience.',
                    step: 1,
                    total: 3,
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
                          onTap: () => _pickDate(_dobCtrl),
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
                        const OnboardingFieldLabel(label: 'Gender'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _gender = value);
                          },
                          decoration: const InputDecoration(
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(Icons.person_outline, size: 20),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'City'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _cityCtrl,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'San Francisco',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(
                                Icons.location_city_outlined,
                                size: 20,
                              ),
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
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'Address details',
                    subtitle: 'This helps drivers find you faster.',
                    step: 2,
                    total: 3,
                    formKey: _formKeys[1],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(label: 'Emergency contact'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emergencyNameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Contact name',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(
                                Icons.support_agent_outlined,
                                size: 20,
                              ),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Emergency contact name is required'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        const OnboardingFieldLabel(
                          label: 'Emergency phone number',
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emergencyPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: '+1 555 123 4567',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(
                                Icons.phone_in_talk_outlined,
                                size: 20,
                              ),
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                          ),
                          validator:
                              (value) =>
                                  (value ?? '').trim().isEmpty
                                      ? 'Emergency phone number is required'
                                      : null,
                        ),
                      ],
                    ),
                  ),
                  _buildStep(
                    title: 'Review & finish',
                    subtitle: 'Confirm your information before continuing.',
                    step: 3,
                    total: 3,
                    formKey: _formKeys[2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reviewRow('Phone', _phoneCtrl.text),
                        _reviewRow('DOB', _dobCtrl.text),
                        _reviewRow('Gender', _gender),
                        _reviewRow('City', _cityCtrl.text),
                        _reviewRow('Address', _addressCtrl.text),
                        _reviewRow(
                          'Emergency contact',
                          '${_emergencyNameCtrl.text} (${_emergencyPhoneCtrl.text})',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tap Finish to save and start booking rides.',
                          style: theme.textTheme.bodyMedium,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
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
                              : Text(_step == 2 ? 'Finish' : 'Continue'),
                    ),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
