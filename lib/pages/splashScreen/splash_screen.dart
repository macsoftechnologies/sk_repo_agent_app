import 'package:flutter/material.dart';
import 'package:repo_agent_application/utils/my_colors.dart';

import '../../utils/config.dart';
//import 'package:repo_agent_application/screens/auth/login_screen.dart'; // <-- Update path

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // 100 seconds delay then navigate
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        print('Navigate to Home Screens');
        Navigator.pushNamed(
          context,
          Config. loginRouteName, // Navigate to the OnBoardScreen sk//onBoardRouteName
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: h,
        width: w,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MyColors.appThemeDark,
              MyColors.appThemeLight,
              MyColors.appThemeLight1,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: h * 0.32,
              width: w * 0.7,
              child: Image.asset(
                "assets/images/appLogo1.png",
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: h * 0.04),
          ],
        ),
      ),
    );
  }
}
