import 'package:flutter/material.dart';

class WudiLogo extends StatelessWidget {
  final double width;

  const WudiLogo({super.key, this.width = 180});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/wudi_logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
