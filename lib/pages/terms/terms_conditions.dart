import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:window_manager/window_manager.dart';

import '../../components/custom_app_header.dart';
import '../../utils/my_colors.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  final List<Map<String, String>> termsData = [
    {
      "heading": "1. Introduction",
      "description":
      "Welcome to our application. By accessing or using our services, you agree to these terms and conditions.",
    },
    {
      "heading": "2. User Responsibilities",
      "description":
      "You agree to use the app responsibly and avoid any activity that may harm the platform or other users.",
    },
    {
      "heading": "3. Privacy Policy",
      "description":
      "We collect minimal data and ensure that your personal information is protected at all times.",
    },
    {
      "heading": "4. Limitations",
      "description":
      "We are not responsible for any misuse of the application or any consequences arising from it.",
    },
    {
      "heading": "5. Changes to Terms",
      "description":
      "We reserve the right to update the terms at any time. Changes will be reflected in this section.",
    },
  ];

  // Helper method to check if running on Windows desktop
  bool get isWindowsDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  // Helper method to check if running on mobile
  bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    // Use platform-specific UI
    if (isWindowsDesktop) {
      return _buildWindowsUI(context);
    } else {
      return _buildMobileUI(context);
    }
  }

  // ------------------------------------------------------
  // WINDOWS-SPECIFIC UI
  // ------------------------------------------------------
  Widget _buildWindowsUI(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    // Windows-specific sizing constraints
    final double maxContentWidth = 1200.0;
    final bool isWideScreen = width > 800;
    final double horizontalPadding = isWideScreen ? 40.0 : 24.0;
    final double verticalPadding = 24.0;

    return Scaffold(

      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '${"terms_title".tr()}',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white
          ),
        ),
        backgroundColor: MyColors.appThemeDark,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24,color: Colors.white,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

      ),
      body: Container(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxContentWidth,
          ),
          child: Column(
            children: [
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title for Windows
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          '${"terms_conditions".tr()}',
                          style: TextStyle(
                            fontSize: 28.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // Terms content with Windows styling
                      ...termsData.map((item) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 32.0),
                          padding: EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section number in a circle
                                  Container(
                                    width: 32.0,
                                    height: 32.0,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF6C63FF),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      item["heading"]!.split(".").first,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.0,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.0),
                                  // Heading
                                  Expanded(
                                    child: Text(
                                      item["heading"]!.split(".").last.trim(),
                                      style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.0),
                              // Description
                              Padding(
                                padding: EdgeInsets.only(left: 48.0),
                                child: Text(
                                  item["description"]!,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    height: 1.6,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      // Windows-specific footer
                      // if (isWideScreen) _buildWindowsFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  Widget _buildWindowsFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 40.0, bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Divider(
            color: Colors.grey.shade300,
            height: 1.0,
          ),
          SizedBox(height: 20.0),
          Text(
            'Version 1.0.0 • Last updated: ${DateTime.now().year}',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.0),
          Wrap(
            spacing: 20.0,
            children: [
              _buildFooterLink('Privacy Policy'),
              _buildFooterLink('Cookie Policy'),
              _buildFooterLink('Support'),
              _buildFooterLink('Contact'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Handle footer link click
          print('$text clicked');
        },
        child: Text(
          text,
          style: TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 14.0,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }




  // ------------------------------------------------------
  // MOBILE UI (EXISTING CODE - UNCHANGED)
  // ------------------------------------------------------
  Widget _buildMobileUI(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: Column(
        children: [
          CustomAppHeader(
            title: '${"terms_conditions".tr()}',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.06,
                vertical: height * 0.02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: termsData.map((item) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: height * 0.03),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["heading"]!,
                          style: TextStyle(
                            fontSize: width * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: height * 0.01),
                        Text(
                          item["description"]!,
                          style: TextStyle(
                            fontSize: width * 0.043,
                            height: 1.4,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}