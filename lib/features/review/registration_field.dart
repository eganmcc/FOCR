import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/extraction/registration_number.dart';

/// Validates free text typed by the salesperson against the same rules as OCR output (FR-010).
/// Input is upper-cased and stripped of spaces, but no look-alike mapping: a human typed it.
ValidationResult validateTyped(String text, DateTime today) =>
    RegistrationNumber.tryParse(text.replaceAll(RegExp(r'\s'), '').toUpperCase(), today: today);

/// Editable, pre-filled registration number field with live validation (FR-009, FR-010).
class RegistrationField extends StatelessWidget {
  const RegistrationField({
    super.key,
    required this.controller,
    required this.validation,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValidationResult validation;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final empty = controller.text.trim().isEmpty;
    return TextField(
      key: const Key('registrationField'),
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 20,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]'))],
      style: const TextStyle(fontFamily: 'monospace', fontSize: 22, letterSpacing: 1.5),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: 'Registration number',
        hintText: 'A03… (16 chars) or A03C… (10 chars)',
        border: const OutlineInputBorder(),
        counterText: '',
        errorText: empty || validation.isValid ? null : describeInvalidReason(validation.reason!),
        suffixIcon: validation.isValid ? const Icon(Icons.check_circle, color: Colors.green) : null,
      ),
    );
  }
}
