import 'dart:async';
import 'package:flutter/material.dart';

class SuccessPopup {
  static void show(
      BuildContext context, {
        required String message,
        int durationSeconds = 4,
      }) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _SuccessPopupWidget(
        message: message,
      ),
    );

    overlay.insert(overlayEntry);

    // Auto close after given duration
    Timer(Duration(seconds: durationSeconds), () {
      overlayEntry.remove();
    });
  }
}

class _SuccessPopupWidget extends StatelessWidget {
  final String message;

  const _SuccessPopupWidget({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
