import 'package:flutter/material.dart';

class WudiLogo extends StatelessWidget {
  const WudiLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/wudi_logo.png',
      width: 180,
      fit: BoxFit.contain,
    );
  }
}