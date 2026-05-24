import 'package:flutter/material.dart';

import '../widgets/native_text_input.dart';
import 'app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final bool isRequired;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final bool enabled;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.isRequired = false,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                children: [
                  if (isRequired)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        FormField<String>(
          initialValue: controller.text,
          validator: validator,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: field.hasError
                      ? Border.all(color: Colors.red, width: 1)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: NativeTextInput(
                        controller: controller,
                        obscureText: obscureText,
                        enabled: enabled,
                        keyboardType: keyboardType,
                        height: 52,
                        hintText: hintText,
                        onChanged: field.didChange,
                        style: TextStyle(
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        hintColor: AppColors.textPlaceholder,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        fallbackBuilder: (context) => TextFormField(
                          controller: controller,
                          obscureText: obscureText,
                          enabled: enabled,
                          keyboardType: keyboardType,
                          style: TextStyle(
                            color: enabled
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          validator: validator,
                          decoration: _fallbackDecoration(),
                        ),
                      ),
                    ),
                    if (suffixIcon != null) suffixIcon!,
                  ],
                ),
              ),
              if (field.hasError) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fallbackDecoration() {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.textPlaceholder,
        fontSize: 14,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
    );
  }
}
