import 'package:flutter/material.dart';

class GreenButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const GreenButton({super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: Color(0xFF25AC2C), // Green background
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}