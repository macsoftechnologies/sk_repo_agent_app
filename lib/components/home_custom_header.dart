import 'package:flutter/material.dart';
import '../utils/my_colors.dart';

class HomeCustomHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final int? notificationCount;
  final VoidCallback? onNotificationTap;

  const HomeCustomHeader({
    super.key,
    required this.title,
    this.onBack,
    this.notificationCount,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Container(
      color: MyColors.appThemeDark,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back Button
            InkWell(
              onTap: onBack ?? () => {},
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: MyColors.appThemeLight1,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(width: width* 0.2),

            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Notification Bell with Count
            if (notificationCount != null)
              Stack(
                children: [
                  InkWell(
                    onTap: onNotificationTap,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MyColors.appThemeLight.withOpacity(0.2),
                      ),
                      child: Icon(
                        Icons.notifications_none_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  if (notificationCount! > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          notificationCount! > 9 ? '9+' : notificationCount!.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}