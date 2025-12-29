import 'dart:io' show Platform;
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:repo_agent_application/components/custom_app_header.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/prefernces.dart';
import '../../models/dashboard_model.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

final String carIcon = "assets/images/sedan.png";
final String checkIcon = "assets/images/checked.png";
final String speedIcon = "assets/images/dashboardImg.png";
final String calendarIcon = "assets/images/calendar.png";
final String warningIcon = "assets/images/warning.png";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardModel? dashboardModel;
  bool isLoading = true;

  String userName = "";
  String deviceId = "";
  String userId = "";

  @override
  void initState() {
    super.initState();
    loadUserData();
    getDashboardDataAPI();
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

  void getDashboardDataAPI() async {
    setState(() {
      isLoading = true;
    });

    final internet = await UtilClass.checkInternet();
    final deviceId = await Preferences.getDeviceId();
    print("deviceID ${deviceId}");

    if (!internet) {
      setState(() {
        isLoading = false;
      });
      UtilClass.showAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    try {
      final value = await Repository.postApiRawService(
        EndPoints.dashboardApi,
        {
          "device_token": deviceId.toString(),
          'admin_id': userId.toString(),
        },
      );

      print("Dashboard Response: $value");

      if (value["success"] == true) {
        setState(() {
          dashboardModel = DashboardModel.fromJson(value["data"]);
          isLoading = false;
        });

      } else {
        // Handle false status

        setState(() {
          isLoading = false;
        });
        UtilClass.showAlertDialog(
            context: context,
            message: value["message"] ?? "Failed to load dashboard data"
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print(e);
      UtilClass.showAlertDialog(context: context, message: e.toString());
    }
  }

  // Platform detection helper
  bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDesktop)
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(MyColors.appThemeDark1),
                  ),
                )
              else
                const CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'loading_data'.tr(),
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2️⃣ Empty / No data state (API not hit / failed)
    if (dashboardModel == null) {
      return Scaffold(
        appBar: isDesktop ? null : PreferredSize(
          preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.085),
          child: CustomAppHeader(
            title: '${"agent_dashboard_title".tr()}',
            onBack: () {
              Navigator.pushNamed(context, Config.homeRegRouteName);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/no-data.png',
                width: isDesktop ? 200 : MediaQuery.of(context).size.width * 0.55,
                height: isDesktop ? 150 : MediaQuery.of(context).size.height * 0.25,
                opacity: const AlwaysStoppedAnimation(0.8),
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                "no_data_available".tr(),
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: getDashboardDataAPI,
                style: isDesktop ? ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ) : null,
                child: Text(
                  "retry".tr(),
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Return appropriate UI based on platform
    if (isDesktop) {
      return _buildDesktopUI();
    } else {
      return _buildMobileUI();
    }
  }

  // Mobile UI (existing code)
  Widget _buildMobileUI() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    bool isPaid = dashboardModel!.isPaid == "1";
    int days = dashboardModel!.daysLeft;

    Color badgeColor;

    if (days >= 15) {
      badgeColor = const Color(0xFF10A5F5); // Blue
    } else if (days < 7) {
      badgeColor = const Color(0xFFE63946); // Red
    } else if (days < 15) {
      badgeColor = const Color(0xFFFFA500); // Orange
    } else {
      badgeColor = const Color(0xFF10A5F5); // default
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(height * 0.085),
        child: CustomAppHeader(
          title: '${"agent_dashboard_title".tr()}',
          onBack: () {
            Navigator.pushNamed(context, Config.homeRegRouteName);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              SizedBox(height: height * 0.02),

              // ---------------------------------------------------
              // TOP STATUS CARD
              // ---------------------------------------------------
              Container(
                width: width * 0.85,
                padding: EdgeInsets.symmetric(
                  vertical: height * 0.03,
                  horizontal: width * 0.05,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPaid
                        ? [MyColors.appThemeLight1, MyColors.appThemeLight]
                        : [MyColors.appThemeLight1, MyColors.appThemeLight],
                  ),
                  borderRadius: BorderRadius.circular(width * 0.06),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(speedIcon,
                            width: width * 0.08, height: width * 0.08),
                        SizedBox(width: width * 0.03),
                        Text(
                          '${"agent_dashboard_title".tr()}',
                          style: TextStyle(
                            fontSize: width * 0.065,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: height * 0.02),

                    if (isPaid)
                      StatusBadge(
                        label: '${"paid_account".tr()}',
                        iconPath: checkIcon,
                        bgColor: const Color(0xFF1DBF73),
                        isDesktop: false,
                      ),

                    if (!isPaid)
                      StatusBadge(
                        label: "${"expired_on".tr()} ${dashboardModel?.formattedExpiry ?? "-"}, ${"renew_now".tr()}",
                        iconPath: warningIcon,
                        bgColor: const Color(0xFFE63946),
                        isDesktop: false,
                      ),

                    StatusBadge(
                      label: isPaid
                          ? "${"valid_until".tr()} ${dashboardModel!.formattedExpiry}"
                          : '${"you_are_in_grace_period_for_14_days".tr()}',
                      iconPath: calendarIcon,
                      bgColor: badgeColor,
                      isDesktop: false,
                    ),
                  ],
                ),
              ),

              SizedBox(height: height * 0.035),

              // SHOW EXPIRY WARNING CARD
              if (days <= 15 && days >= 1)
                Container(
                  width: width * 0.85,
                  padding: EdgeInsets.symmetric(
                    vertical: height * 0.025,
                    horizontal: width * 0.05,
                  ),
                  margin: EdgeInsets.only(bottom: height * 0.02),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width * 0.05),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFC371),
                        Color(0xFFFF5F6D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        padding: EdgeInsets.all(width * 0.03),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: width * 0.08,
                        ),
                      ),

                      SizedBox(width: width * 0.04),

                      // Texts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"plan_message1".tr()} ${dashboardModel!.formattedExpiry}",
                              style: TextStyle(
                                fontSize: width * 0.045,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: height * 0.006),

                            Text(
                              "${"plan_message2".tr()}",
                              style: TextStyle(
                                fontSize: width * 0.038,
                                color: Colors.white.withOpacity(0.95),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ---------------------------------------------------
              // BOTTOM CARDS
              // ---------------------------------------------------
              Container(
                width: width * 0.85,
                child: Column(
                  children: [
                    InfoCard(
                      title: "${"sudhah_tarik".tr()}",
                      count: dashboardModel!.recovered,
                      iconPath: carIcon,
                      bgColor: const Color(0xFF1AA056),
                      isDesktop: false,
                    ),
                    InfoCard(
                      title: "${"got_sticker_others".tr()}",
                      count: dashboardModel!.completed,
                      iconPath: checkIcon,
                      bgColor: const Color(0xFF0A7BFF),
                      isDesktop: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Windows/Desktop UI
  // Windows/Desktop UI
  Widget _buildDesktopUI() {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isWideScreen = width > 1200;

    bool isPaid = dashboardModel!.isPaid == "1";
    int days = dashboardModel!.daysLeft;

    Color badgeColor;
    if (days >= 15) {
      badgeColor = const Color(0xFF10A5F5);
    } else if (days < 7) {
      badgeColor = const Color(0xFFE63946);
    } else if (days < 15) {
      badgeColor = const Color(0xFFFFA500);
    } else {
      badgeColor = const Color(0xFF10A5F5);
    }

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '${"agent_dashboard_title".tr()}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white
          ),
        ),
        backgroundColor: MyColors.appThemeDark,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24,color: Colors.white),
          onPressed: () {
            Navigator.pushNamed(context, Config.homeRegRouteName);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 20, color: Colors.grey[700]),
                SizedBox(width: 8),
                Text(
                  userName.isNotEmpty ? userName : 'User',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWideScreen ? 1400 : 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'welcome_back'.tr(),
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              userName.isNotEmpty ? userName : 'User',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: MyColors.appThemeDark1,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${"last_updated".tr()} ${DateTime.now().toString().substring(0, 16)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [MyColors.appThemeLight, MyColors.appThemeDark1],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: getDashboardDataAPI,
                            child: Row(
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'refresh_data'.tr(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Status Cards Row - Make responsive
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 800) {
                        // Mobile-like layout for small windows
                        return Column(
                          children: [
                            // Main Status Card
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isPaid
                                      ? [MyColors.appThemeLight, MyColors.appThemeDark1]
                                      : [Color(0xFFE63946), Color(0xFFF4A261)],
                                ),
                                borderRadius: BorderRadius.circular(12),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Image.asset(
                                          speedIcon,
                                          width: 28,
                                          height: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        '${"account_status".tr()}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Column(
                                    children: [
                                      if (isPaid)
                                        DesktopStatusBadge(
                                          label: '${"paid_account".tr()}',
                                          icon: Icons.check_circle,
                                          bgColor: Color(0xFF1DBF73),
                                        ),
                                      if (!isPaid)
                                        DesktopStatusBadge(
                                          label: "${"expired_on".tr()} ${dashboardModel?.formattedExpiry ?? "-"}",
                                          icon: Icons.warning,
                                          bgColor: Color(0xFFE63946),
                                        ),
                                      SizedBox(height: 8),
                                      DesktopStatusBadge(
                                        label: isPaid
                                            ? "${"valid_until".tr()} ${dashboardModel!.formattedExpiry}"
                                            : '${"you_are_in_grace_period_for_14_days".tr()}',
                                        icon: Icons.calendar_today,
                                        bgColor: badgeColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Warning Card (if applicable)
                            if (days <= 15 && days >= 1)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(20),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFFC371),
                                      Color(0xFFFF5F6D),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
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
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "${"plan_expiring_soon".tr()}",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      "${"plan_message1".tr()} ${dashboardModel!.formattedExpiry}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      "${"plan_message2".tr()}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      } else {
                        // Desktop layout for wider windows
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Status Card
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isPaid
                                        ? [MyColors.appThemeLight, MyColors.appThemeDark1]
                                        : [Color(0xFFE63946), Color(0xFFF4A261)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
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
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Image.asset(
                                            speedIcon,
                                            width: 32,
                                            height: 32,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          '${"account_status".tr()}',
                                          style: TextStyle(
                                            fontSize: 24,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 24),
                                    // Status badges
                                    Column(
                                      children: [
                                        if (isPaid)
                                          DesktopStatusBadge(
                                            label: '${"paid_account".tr()}',
                                            icon: Icons.check_circle,
                                            bgColor: Color(0xFF1DBF73),
                                          ),
                                        if (!isPaid)
                                          DesktopStatusBadge(
                                            label: "${"expired_on".tr()} ${dashboardModel?.formattedExpiry ?? "-"}",
                                            icon: Icons.warning,
                                            bgColor: Color(0xFFE63946),
                                          ),
                                        SizedBox(height: 8),
                                        DesktopStatusBadge(
                                          label: isPaid
                                              ? "${"valid_until".tr()} ${dashboardModel!.formattedExpiry}"
                                              : '${"you_are_in_grace_period_for_14_days".tr()}',
                                          icon: Icons.calendar_today,
                                          bgColor: badgeColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(width: 24),

                            // Warning Card (if applicable)
                            if (days <= 15 && days >= 1)
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFC371),
                                        Color(0xFFFF5F6D),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
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
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.warning,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "${"plan_expiring_soon".tr()}",
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "${"plan_message1".tr()} ${dashboardModel!.formattedExpiry}",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.95),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "${"plan_message2".tr()}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                    },
                  ),

                  SizedBox(height: 32),

                  // Statistics Section
                  Text(
                    '${"statistics".tr()}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 800) {
                        // Stack cards vertically on small screens
                        return Column(
                          children: [
                            DesktopInfoCard(
                              title: "${"sudhah_tarik".tr()}",
                              count: dashboardModel!.recovered,
                              icon: Icons.directions_car,
                              bgColor: Color(0xFF1AA056),
                              trend: dashboardModel!.recovered > 0 ? '+12%' : '0%',
                            ),
                            SizedBox(height: 16),
                            DesktopInfoCard(
                              title: "${"got_sticker_others".tr()}",
                              count: dashboardModel!.completed,
                              icon: Icons.check_circle_outline,
                              bgColor: Color(0xFF0A7BFF),
                              trend: dashboardModel!.completed > 0 ? '+8%' : '0%',
                            ),
                          ],
                        );
                      } else {
                        // Show cards side by side on larger screens
                        return Row(
                          children: [
                            Expanded(
                              child: DesktopInfoCard(
                                title: "${"sudhah_tarik".tr()}",
                                count: dashboardModel!.recovered,
                                icon: Icons.directions_car,
                                bgColor: Color(0xFF1AA056),
                                trend: dashboardModel!.recovered > 0 ? '+12%' : '0%',
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: DesktopInfoCard(
                                title: "${"got_sticker_others".tr()}",
                                count: dashboardModel!.completed,
                                icon: Icons.check_circle_outline,
                                bgColor: Color(0xFF0A7BFF),
                                trend: dashboardModel!.completed > 0 ? '+8%' : '0%',
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  SizedBox(height: 42),



                   // Add some bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Updated InfoCard with isDesktop parameter
class InfoCard extends StatelessWidget {
  final String title;
  final int count;
  final String iconPath;
  final Color bgColor;
  final bool isDesktop;

  const InfoCard({
    required this.title,
    required this.count,
    required this.iconPath,
    required this.bgColor,
    required this.isDesktop,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopCard(context);
    }

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        vertical: height * 0.035,
      ),
      margin: EdgeInsets.only(bottom: height * 0.02),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(width * 0.05),
      ),
      child: Column(
        children: [
          Image.asset(iconPath,
              width: width * 0.13, height: width * 0.13),
          SizedBox(height: height * 0.015),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: width * 0.08,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.045,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForPath(iconPath),
            size: 48,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 48,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconForPath(String path) {
    if (path.contains('car')) return Icons.directions_car;
    if (path.contains('check')) return Icons.check_circle;
    if (path.contains('calendar')) return Icons.calendar_today;
    if (path.contains('warning')) return Icons.warning;
    return Icons.info;
  }
}

// Updated StatusBadge with isDesktop parameter
class StatusBadge extends StatelessWidget {
  final String label;
  final String iconPath;
  final Color bgColor;
  final bool isDesktop;

  const StatusBadge({
    required this.label,
    required this.iconPath,
    required this.bgColor,
    required this.isDesktop,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopBadge(context);
    }

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.03,
        vertical: height * 0.009,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(width * 0.03),
      ),
      child: Row(
        children: [
          Image.asset(iconPath,
              width: width * 0.045, height: width * 0.045),
          SizedBox(width: width * 0.02),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.038,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBadge(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForPath(iconPath),
            size: 20,
            color: Colors.white,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForPath(String path) {
    if (path.contains('check')) return Icons.check_circle;
    if (path.contains('calendar')) return Icons.calendar_today;
    if (path.contains('warning')) return Icons.warning;
    return Icons.info;
  }
}

// New Desktop-specific components
class DesktopStatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;

  const DesktopStatusBadge({
    required this.label,
    required this.icon,
    required this.bgColor,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopInfoCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color bgColor;
  final String trend;

  const DesktopInfoCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.bgColor,
    required this.trend,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              // Container(
              //   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //   decoration: BoxDecoration(
              //     color: Colors.white.withOpacity(0.2),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Row(
              //     children: [
              //       Icon(Icons.trending_up, color: Colors.white, size: 14),
              //       SizedBox(width: 4),
              //       Text(
              //         trend,
              //         style: TextStyle(
              //           color: Colors.white,
              //           fontWeight: FontWeight.w600,
              //           fontSize: 14,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 36,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),

        ],
      ),
    );
  }

  double _calculateProgress(int count) {
    // You can customize this based on your data
    if (count == 0) return 0.1;
    return (count % 100) / 100.0;
  }
}

