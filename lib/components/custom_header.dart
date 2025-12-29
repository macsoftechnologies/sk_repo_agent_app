import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:repo_agent_application/utils/my_colors.dart';

/// Custom Header Widget
class CustomHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const CustomHeader({Key? key, required this.title, required this.onBack})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      width: width,
      height: height * 0.09,
      color: MyColors.appThemeDark,
      padding: EdgeInsets.symmetric(horizontal: width * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          Text(
            title,
            style: TextStyle(
                fontSize: width * 0.055,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const Icon(Icons.grid_view, color: Colors.white, size: 26),
        ],
      ),
    );
  }
}