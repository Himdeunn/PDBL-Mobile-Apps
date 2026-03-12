import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class WudiSearchBar extends StatelessWidget {
  final ValueChanged<String>? onChanged;

  const WudiSearchBar({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: TextField(
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(
              fontSize: 14,
              color: AppColors.textPlaceholder,
            ),
            suffixIcon: Icon(Icons.search, color: AppColors.textPlaceholder),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
}
