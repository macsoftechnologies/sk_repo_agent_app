import 'package:flutter/material.dart';

class NoDataWidget extends StatelessWidget {
  final String message;
  final String imagePath;
  final double imageSize;

  const NoDataWidget({
    super.key,
    this.message = "No data available",
    this.imagePath = "assets/images/no_data.png",
    this.imageSize = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 15),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
