import 'dart:convert';
import 'dart:io' show Platform;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../data/prefernces.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AccountScreen({super.key, this.userData});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String userName = "";
  String deviceId = "";
  String userId = "";

  // Platform detection helpers
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  void loadUserData() async {
    final dataStr = await Preferences.getUserDetails();

    if (dataStr != null && dataStr.isNotEmpty) {
      final data = jsonDecode(dataStr);

      setState(() {
        userName = data["name"] ?? "";
        userId = data["admin_id"].toString();
        deviceId = data["device_token"].toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return appropriate UI based on platform
    if (isDesktop) {
      return _buildDesktopUI();
    } else {
      return _buildMobileUI();
    }
  }

  // Mobile UI (existing code)
  Widget _buildMobileUI() {
    final double deviceHeight = MediaQuery.of(context).size.height;
    final double deviceWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: MyColors.lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top Profile Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: deviceHeight * 0.05,
                  bottom: deviceHeight * 0.03,
                ),
                decoration: BoxDecoration(
                  color: MyColors.appThemeDark,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${"account_title".tr()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: deviceHeight * 0.02),
                    // Static User Icon
                    Container(
                      width: deviceWidth * 0.24,
                      height: deviceWidth * 0.24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        Icons.person,
                        size: deviceWidth * 0.15,
                        color: MyColors.appThemeDark,
                      ),
                    ),
                    SizedBox(height: deviceHeight * 0.015),
                    // Dynamic Name
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: deviceHeight * 0.005),
                    // Dynamic Agent Reg ID
                    Text(
                      "User ID: $userId",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Options Menu Card
              Transform.translate(
                offset: Offset(0, -deviceHeight * 0.03),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: deviceWidth * 0.05),
                  child: Card(
                    color: Colors.white,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: deviceWidth * 0.04,
                        vertical: deviceHeight * 0.02,
                      ),
                      child: Column(
                        children: [
                          // Edit Profile
                          _buildMobileMenuItem(
                            icon: Icons.edit,
                            title: '${"edit_profile".tr()}',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                Config.profileRouteName,
                              );
                            },
                          ),
                          _buildDivider(),

                          // Terms
                          _buildMobileMenuItem(
                            icon: Icons.description,
                            title: '${"terms_conditions".tr()}',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                Config.termsRouteName,
                              );
                            },
                          ),
                          _buildDivider(),

                          // Notifications
                          _buildMobileMenuItem(
                            icon: Icons.notifications,
                            title: '${"notifications".tr()}',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                Config.notificationsRouteName,
                              );
                            },
                          ),
                          _buildDivider(),

                          // Logout
                          _buildMobileMenuItem(
                            icon: Icons.logout,
                            title: '${"logout".tr()}',
                            onTap: () {
                              _showLogoutConfirmation();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Windows/Desktop UI
  Widget _buildDesktopUI() {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 1200;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '${"account_title".tr()}',
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
           // Navigator.pop(context);
            _showDesktopLogoutConfirmation();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWideScreen ? 1000 : 800),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel - User Profile
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Profile Avatar
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: MyColors.appThemeDark.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MyColors.appThemeDark,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: MyColors.appThemeDark,
                            ),
                          ),
                          SizedBox(height: 24),
                          // User Name
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          // User ID
                          Text(
                            "User ID: $userId",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),


                          SizedBox(height: 32),

                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 32),
                  // Right Panel - Menu Options
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${"account_settings".tr()}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${"manage_your_account_settings".tr()}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 32),
                          // Menu Items
                          Column(
                            children: [
                              _buildDesktopMenuItem(
                                icon: Icons.edit,
                                title: '${"edit_profile".tr()}',
                                subtitle: '${"update_your_personal_information".tr()}',
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    Config.profileRouteName,
                                  );
                                },
                              ),
                              SizedBox(height: 16),
                              _buildDesktopMenuItem(
                                icon: Icons.description,
                                title: '${"terms_conditions".tr()}',
                                subtitle: '${"read_our_terms_and_conditions".tr()}',
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    Config.termsRouteName,
                                  );
                                },
                              ),
                              SizedBox(height: 16),
                              _buildDesktopMenuItem(
                                icon: Icons.notifications,
                                title: '${"notifications".tr()}',
                                subtitle: '${"manage_notification_settings".tr()}',
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    Config.notificationsRouteName,
                                  );
                                },
                              ),
                              // SizedBox(height: 16),
                              // _buildDesktopMenuItem(
                              //   icon: Icons.help_outline,
                              //   title: '${"help_support".tr()}',
                              //   subtitle: '${"get_help_and_support".tr()}',
                              //   onTap: () {
                              //     _showHelpDialog();
                              //   },
                              // ),
                              SizedBox(height: 32),
                              // Logout Section
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${"secure_logout".tr()}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${"logout_from_all_devices".tr()}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showDesktopLogoutConfirmation();
                                      },
                                      icon: Icon(Icons.logout, size: 20),
                                      label: Text('${"logout".tr()}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mobile Menu Item Widget
  Widget _buildMobileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: MyColors.appThemeDark.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: MyColors.appThemeDark, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: MyColors.appThemeDark,
      ),
      onTap: onTap,
    );
  }

  // Desktop Menu Item Widget
  Widget _buildDesktopMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: MyColors.appThemeDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MyColors.appThemeDark, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 20,
          color: MyColors.appThemeDark,
        ),
        onTap: onTap,
      ),
    );
  }

  // Stat Item for Desktop
  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MyColors.appThemeDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: MyColors.appThemeDark, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Divider Widget
  Widget _buildDivider() {
    return Divider(height: 1, thickness: 0.5, color: Colors.grey[300]);
  }

  void callLogoutAPI() async {
    final internet = await UtilClass.checkInternet();

    if (!internet) {
      UtilClass.showAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    try {
      UtilClass.showProgress(context: context);

      final value = await Repository.postApiRawService(EndPoints.logoutApi, {
        "admin_id": userId,
        "device_token": deviceId,
      });

      UtilClass.hideProgress();
      print("accRes $value");

      // BACKEND returns  { status : true , message : xxx }
      if (value["status"] == true) {
        // clear locally stored user data
        await Preferences.clearPreference();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value["message"] ?? "Logout Successfully!"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // Wait for snackbar
        await Future.delayed(const Duration(seconds: 2));

        // Reset navigation stack & go to Login
        Navigator.pushNamedAndRemoveUntil(
          context,
          Config.loginRouteName,
              (route) => false,
        );
      } else {
        UtilClass.showAlertDialog(
          context: context,
          message: value["message"] ?? "Logout failed",
        );
      }
    } catch (e) {
      UtilClass.hideProgress();
      print(e);
      UtilClass.showAlertDialog(
        context: context,
        message: "Something went wrong !",
      );
    }
  }

  // Desktop Logout Confirmation Dialog
  void _showDesktopLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 12),
              Text(
                "${"logout_confirmation".tr()}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${"logout_confirmation_message".tr()}",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${"logout_warning".tr()}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "${"cancel".tr()}",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                callLogoutAPI();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "${"logout".tr()}",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  // Mobile Logout Confirmation Dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("${"logout".tr()}"),
          content: Text("${"logout_confirmation".tr()}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: MyColors.appThemeDark),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                callLogoutAPI();
              },
              child: Text(
                "${"logout".tr()}",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Help Dialog for Desktop
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                "${"help_support".tr()}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${"need_help".tr()}",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              _buildHelpOption(
                icon: Icons.email,
                title: "${"email_support".tr()}",
                subtitle: "support@repoagent.com",
              ),
              SizedBox(height: 12),
              _buildHelpOption(
                icon: Icons.phone,
                title: "${"phone_support".tr()}",
                subtitle: "+1 (800) 123-4567",
              ),
              SizedBox(height: 12),
              _buildHelpOption(
                icon: Icons.chat,
                title: "${"live_chat".tr()}",
                subtitle: "${"available_24_7".tr()}",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "${"close".tr()}",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Widget _buildHelpOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}