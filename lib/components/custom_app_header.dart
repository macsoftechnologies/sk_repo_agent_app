import 'package:flutter/material.dart';

import '../utils/my_colors.dart';
import 'package:repo_agent_application/utils/my_colors.dart';

// 1. Define the parameters the header needs
class CustomAppHeader extends StatelessWidget implements PreferredSizeWidget {
  // We need a title string for the header text.
  final String title;

  // Optional: A custom action for the back button, if you don't want pop(context).
  final VoidCallback? onBack;

  const CustomAppHeader({
    super.key,
    required this.title,
    this.onBack,
  });

  // 2. Implement the build method based on your original code
  @override
  Widget build(BuildContext context) {
    // Note: Replaced MyColors.appThemeLight with a simple Color for example.
    const headerColor = MyColors.appThemeDark; // Replace with MyColors.appThemeLight

    return Container(
      // The height is defined by preferredSize below
      color: headerColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SafeArea( // Use SafeArea to avoid status bar overlap
        bottom: false,
        child: Row(
          children: [
            InkWell(
              // Use the provided onBack function, or default to Navigator.pop(context)
              onTap: onBack ?? () => Navigator.pop(context),
              child: const CircleAvatar(
                radius: 22,
                backgroundColor:MyColors.appThemeLight,
                child: Icon( // Using Icon instead of Image.asset for simplicity/standard
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: Colors.white
                ),
                // OR your original code:
                /*
                child: Image.asset(
                  "assets/images/whiteLeftArrow.png",
                  width: 9,
                ),
                */
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  title, // 👈 Use the passed-in title
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Implement PreferredSizeWidget for use in AppBar/SliverAppBar
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
// kToolbarHeight is usually 56. Add padding/adjustment as needed.
}