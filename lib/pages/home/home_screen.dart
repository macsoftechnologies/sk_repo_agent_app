import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart' as welcome;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:repo_agent_application/pages/account/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../components/home_custom_header.dart';
import '../../data/prefernces.dart';
import '../../helpers/offline_search_sync_service.dart';
import '../../models/notification_model.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/my_colors.dart';
import '../../utils/util_class.dart';
import '../dashboard/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomIndex = 0;

  String userName = "";
  String deviceId = "";
  String userId = "";

  final List<Widget> _screens = [
    const HomeContent(),
    const DashboardScreen(),
    const AccountScreen(),
  ];

  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  //offline search records syncing

  /// 👇 BACK BUTTON HANDLER
  Future<bool> _onWillPop() async {

    if (isDesktop) return true; // ❌ disable logout on window close
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // ✅ only close dialog
              child: const Text(
                "Yes",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await callLogoutAPI(); // ✅ logout AFTER dialog closed
    }

    return false; // prevent back pop
  }


  Future<void> callLogoutAPI() async {
    final internet = await UtilClass.checkInternet();
    // final deviceId = await Preferences.getDeviceId();
    // print("ddID $deviceId");

    if (!internet) {
      UtilClass.showAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    try {
      UtilClass.showProgress(context: context);

      final value = await Repository.postApiRawService(EndPoints.logoutApi, {
        "admin_id": userId.toString(),
        "device_token": deviceId.toString(),
      });

      UtilClass.hideProgress();
      print("hmRes $value");

      // BACKEND returns  { status : true , message : xxx }
      if (value["status"] == true) {
        // clear locally stored user data
        await Preferences.clearPreference();

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(value["message"] ?? "Logout Successfully!"),
        //     duration: Duration(seconds: 2),
        //     backgroundColor: Colors.green,
        //   ),
        // );

        // Wait for snackbar
       // await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

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
  void initState() {
    super.initState();
    loadUserData();



  }

  @override
  void dispose() {

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // 👈 intercept back
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280), // 🟢 desktop fix
            child: _screens[_bottomIndex],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomIndex,
          selectedItemColor: MyColors.appThemeDark,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() => _bottomIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      ),
    );
  }

}

class HomeContent extends StatefulWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {

  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Timer? _notificationTimer;
  String userName = "";
  String userId = "";
  String _isPaid = "";
  bool _isLoading = false;
  bool _isLoadingNotifications = false;
  int _unreadNotificationCount = 0;
  String _selectedLanguage = "English";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    _notificationTimer = Timer.periodic(
      const Duration(minutes: 2),
          (timer) {
        _fetchUnreadNotifications();
      },
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserData();
    await _loadSelectedLanguage();
    await _fetchUnreadNotifications();
  }

  Future<void> changeLanguage(BuildContext context, String langCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', langCode);

    if (context.mounted) {
      context.setLocale(Locale(langCode));
    }
  }

  Future<void> _getSavedLanguage() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? savedLang = prefs.getString('app_lang');

      if (savedLang != null && savedLang.isNotEmpty) {
        setState(() {
          _selectedLanguage = savedLang;
        });
      } else {
        setState(() {
          _selectedLanguage = 'en';
        });
      }
    } catch (e) {
      print('Error getting saved language: $e');
      setState(() {
        _selectedLanguage = 'en';
      });
    }
  }

  Future<void> _loadSelectedLanguage() async {
    final language = await Preferences.getSelectedLanguage();
    if (language != null &&
        language.isNotEmpty &&
        context.locale.languageCode != language) {
      context.setLocale(Locale(language));
    }
  }

  String _getLangName(String code) {
    switch (code) {
      case 'ms':
        return "Malaysia";
      case 'en':
      default:
        return "English";
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userString = await Preferences.getUserDetails();

      if (userString != null) {
        final user = jsonDecode(userString);
        print("home screen user: $user");
        setState(() {
          userName = user["name"] ?? "";
          userId = "${user["admin_id"]}" ?? "";
          _isPaid = "${user["is_paid"]}" ?? "";
        });
      } else {
        setState(() {
          userName = "";
          userId = "";
          _isPaid = "";
        });
      }
    } catch (error) {
      print('Error loading user data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    if (_isLoadingNotifications) return;

    setState(() {
      _isLoadingNotifications = true;
    });

    final internet = await UtilClass.checkInternet();
    final deviceId = await Preferences.getDeviceId();

    if (!internet) {
      setState(() {
        _isLoadingNotifications = false;
      });
      return;
    }

    try {
      final response = await Repository.postApiRawService(
          EndPoints.unreadNotificationsApi,
          {
            "admin_id": userId,
            "device_token": deviceId});

      print("Unread Notifications API Response: ${response}");

      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      if (parsed["status"] == true) {
        final List<dynamic> data = parsed["data"] ?? [];
        final List<NotificationModel> notifications =
        data.map((json) => NotificationModel.fromJson(json)).toList();

        setState(() {
          _unreadNotificationCount = notifications.length;
          _isLoadingNotifications = false;
        });

        print("✅ Loaded ${notifications.length} unread notifications");
      } else {
        setState(() {
          _isLoadingNotifications = false;
        });
      }
    } catch (e, stackTrace) {
      print("❌ Unread Notifications API Error: $e");
      setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _onMenuTap(String menuTitle) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      switch (menuTitle) {
        case "Upload Old Cars":
          _handleUploadCars();
          break;
        case "Agent Searched Data":
          _handleAgentData();
          break;
        case "Verified Cars":
          _handleVerifiedCars();
          break;
        case "Search Cars":
          _handleSearchCars();
          break;
        case "Matched Cars":
          _handleMatchedCars();
          break;
      }
    } catch (error) {
      print('Error in menu action: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load $menuTitle'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleUploadCars() {
    if (_isPaid == "0") {
      UtilClass.showAlertDialog(
        context: context,
        message: "Please activate plan to access this feature.",
      );
      return;
    }
    Navigator.pushNamed(
      context,
      Config.uploadOldCarsRouteName,
    );
  }

  void _handleAgentData() {
    Navigator.pushNamed(
      context,
      Config.agentSearchedCarsRouteName,
    );
  }

  void _handleVerifiedCars() {
    Navigator.pushNamed(
      context,
      Config.verifiedCarsRouteName,
    );
  }

  void _handleSearchCars() {
    if (_isPaid == "0") {
      UtilClass.showAlertDialog(
        context: context,
        message: "Please activate plan to access this feature.",
      );
      return;
    }
    Navigator.pushNamed(
      context,
      Config.searchCarsRouteName,
    );
  }

  void _handleMatchedCars() {
    Navigator.pushNamed(
      context,
      Config.matchedCarsRouteName,
    );
  }

  Future<void> _handleNotificationTap() async {
    Navigator.pushNamed(
      context,
      Config.notificationsRouteName,
    );
    await Future.delayed(Duration(milliseconds: 500));
    await _fetchUnreadNotifications();
  }

  Future<void> _selectLanguage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "select_language".tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: MyColors.appThemeDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("English"),
                leading: Radio(
                  value: "en",
                  groupValue: _selectedLanguage,
                  activeColor: MyColors.appThemeDark,
                  onChanged: (value) {
                    Navigator.pop(context);
                    changeLanguage(context, 'en');
                  },
                ),
              ),
              ListTile(
                title: Text("Malaysia"),
                leading: Radio(
                  value: "ms",
                  groupValue: _selectedLanguage,
                  activeColor: MyColors.appThemeDark,
                  onChanged: (value) {
                    Navigator.pop(context);
                    changeLanguage(context, 'ms');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateLanguage(String language) async {
    setState(() {
      _selectedLanguage = language;
    });

    await Preferences.setSelectedLanguage(language);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Language changed to $language"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadUserData(),
      _fetchUnreadNotifications(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final contentWidth = isDesktop ? 1100.0 : width;

    return _isLoading && userName.isEmpty
        ? const Center(
      child: CircularProgressIndicator(color: MyColors.appThemeDark),
    )
        : Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth),
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: MyColors.appThemeDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                HomeCustomHeader(
                  title: "home".tr(),
                  notificationCount: _unreadNotificationCount,
                  onNotificationTap: _handleNotificationTap,
                ),
                SizedBox(height: height * 0.02),
                _languageCard(contentWidth, height),
                SizedBox(height: height * 0.025),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : width * 0.04,
                  ),
                  child: Column(
                    children: [
                      _menuGrid(contentWidth, height),
                      SizedBox(height: height * 0.02),
                      _singleMenuCard(
                        contentWidth,
                        height,
                        Icons.local_shipping,
                        "matched_cars".tr(),
                      ),
                      SizedBox(height: height * 0.05),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _languageCard(double width, double height) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04),
      child: Container(
        width: width,
        padding: EdgeInsets.all(width * 0.045),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MyColors.appThemeDark,
              MyColors.appThemeLight1,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MyColors.appThemeDark.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(width * 0.025),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.waving_hand,
                    color: Colors.amber,
                    size: width * 0.065,
                  ),
                ),
                SizedBox(width: width * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${"welcome".tr()}!",
                        style: TextStyle(
                          fontSize: width * 0.04,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: width * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: height * 0.02),
            Container(
              padding: EdgeInsets.all(width * 0.035),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(width * 0.025),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.language,
                      color: MyColors.appThemeDark,
                      size: width * 0.06,
                    ),
                  ),
                  SizedBox(width: width * 0.035),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "language".tr(),
                          style: TextStyle(
                            fontSize: width * 0.038,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: height * 0.002),
                        Text(
                          _getLangName(context.locale.languageCode),
                          style: TextStyle(
                            fontSize: width * 0.045,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _selectLanguage,
                    child: Container(
                      padding: EdgeInsets.all(width * 0.02),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: width * 0.045,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Replace your existing _menuGrid, _singleMenuCard, _menuCardDesktop, and _menuCard methods with these:

  // Replace your existing _menuGrid, _singleMenuCard, _menuCardDesktop, and _menuCard methods with these:

  Widget _menuGrid(double width, double height) {
    if (!isDesktop) {
      return _menuGridMobile(width, height);
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 2.2,
      children: [
        _menuCardDesktop(
          Icons.cloud_upload_outlined,
          "upload_old_cars".tr(),
              () => _onMenuTap("Upload Old Cars"),
          gradientColors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        _menuCardDesktop(
          Icons.people_outline,
          "agent_searched_data".tr(),
              () => _onMenuTap("Agent Searched Data"),
          gradientColors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
        ),
        _menuCardDesktop(
          Icons.verified_user_outlined,
          "verified_cars".tr(),
              () => _onMenuTap("Verified Cars"),
          gradientColors: [Color(0xFFF093FB), Color(0xFFF5576C)],
        ),
        _menuCardDesktop(
          Icons.search,
          "search_cars".tr(),
              () => _onMenuTap("Search Cars"),
          gradientColors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
        ),
      ],
    );
  }

  Widget _singleMenuCard(double width, double height, IconData icon, String title) {
    if (!isDesktop) {
      return _menuCard(
        width,
        height * 0.18,
        Icons.local_shipping_outlined,
        title,
            () => _onMenuTap("Matched Cars"),
        gradientColors: [Color(0xFFFA709A), Color(0xFFFEE140)],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: _menuCardDesktop(
        Icons.local_shipping_outlined,
        title,
            () => _onMenuTap("Matched Cars"),
        isLarge: true,
        gradientColors: [Color(0xFFFA709A), Color(0xFFFEE140)],
      ),
    );
  }

  Widget _menuCardDesktop(
      IconData icon,
      String title,
      VoidCallback onTap, {
        bool isLarge = false,
        required List<Color> gradientColors,
      }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(isLarge ? 28 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: isLarge ? 70 : 56,
                width: isLarge ? 70 : 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(isLarge ? 18 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: isLarge ? 34 : 26,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: isLarge ? 24 : 18),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isLarge ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.all(isLarge ? 12 : 10),
                decoration: BoxDecoration(
                  color: Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: isLarge ? 16 : 14,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard(
      double width,
      double height,
      IconData icon,
      String title,
      VoidCallback function, {
        required List<Color> gradientColors,
      }) {
    final double cardHeight = height;
    final double iconSize = width * 0.075;
    final double titleFontSize = width * 0.04;

    return GestureDetector(
      onTap: _isLoading ? null : function,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle decorative circle - top right
            Positioned(
              right: -15,
              top: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradientColors[0].withOpacity(0.04),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(width * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon container with gradient
                  Container(
                    padding: EdgeInsets.all(width * 0.028),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradientColors,
                        stops: [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                  // Title and button
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A202C),
                          height: 1.2,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: height * 0.015),
                      Row(
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: width * 0.03,
                              color: Color(0xFF718096),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: width * 0.01),
                          Icon(
                            Icons.arrow_forward,
                            color: Color(0xFF718096),
                            size: width * 0.032,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuGridMobile(double width, double height) {
    final double cardSpacing = width * 0.04;
    final double verticalSpacing = height * 0.02;
    final double cardHeight = height * 0.2;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _menuCard(
                width,
                cardHeight,
                Icons.cloud_upload_outlined,
                "upload_old_cars".tr(),
                    () => _onMenuTap("Upload Old Cars"),
                gradientColors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _menuCard(
                width,
                cardHeight,
                Icons.people_outline,
                "agent_searched_data".tr(),
                    () => _onMenuTap("Agent Searched Data"),
                gradientColors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
              ),
            ),
          ],
        ),
        SizedBox(height: verticalSpacing),
        Row(
          children: [
            Expanded(
              child: _menuCard(
                width,
                cardHeight,
                Icons.verified_user_outlined,
                "verified_cars".tr(),
                    () => _onMenuTap("Verified Cars"),
                gradientColors: [Color(0xFFF093FB), Color(0xFFF5576C)],
              ),
            ),
            SizedBox(width: cardSpacing),
            Expanded(
              child: _menuCard(
                width,
                cardHeight,
                Icons.search,
                "search_cars".tr(),
                    () => _onMenuTap("Search Cars"),
                gradientColors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              ),
            ),
          ],
        ),
      ],
    );
  }

}