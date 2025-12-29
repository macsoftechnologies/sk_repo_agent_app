import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart' as welcome;
import 'package:flutter/material.dart';
import 'package:repo_agent_application/pages/account/account_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


import '../../components/custom_app_header.dart';
import '../../components/custom_header.dart';
import '../../components/home_custom_header.dart';
import '../../data/prefernces.dart';
import '../../models/notification_model.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/my_colors.dart';
import '../../utils/util_class.dart';
import '../dashboard/dashboard_screen.dart';

// Import your other screens
// Create this file
// Create this file

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomIndex = 0;

  // Screens for each tab
  final List<Widget> _screens = [
    const HomeContent(), // Now this is a stateful widget
    const DashboardScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: _screens[_bottomIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomIndex,
        selectedItemColor: MyColors.appThemeDark,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _bottomIndex = index);
        },
        items:[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

// HomeContent as Stateful Widget for API calls and state management


class HomeContent extends StatefulWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  Timer? _notificationTimer;
  String userName = "";
  String userId = "";
  String _isPaid="";
  bool _isLoading = false;
  bool _isLoadingNotifications = false;
  int _unreadNotificationCount = 0;
  String _selectedLanguage = "English"; // Default language

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    // Call every 2 minutes
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 2),
          (timer) {
        _fetchUnreadNotifications();
      },
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel(); // Prevent memory leaks
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
        // Also set the locale if you have localization set up
        // context.setLocale(Locale(savedLang));
      } else {
        // Set default language
        setState(() {
          _selectedLanguage = 'en'; // or your default language code
        });
      }
    } catch (e) {
      print('Error getting saved language: $e');
      setState(() {
        _selectedLanguage = 'en'; // fallback to default
      });
    }
  }


  Future<void> _loadSelectedLanguage() async {
    final language = await Preferences.getSelectedLanguage();
    if (language != null && language.isNotEmpty && context.locale.languageCode != language) {
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
        setState(() {
          userName = user["name"] ?? "";
          userId = "${user["admin_id"]}" ?? "";
          _isPaid="${user["is_paid"]}" ?? "";
        });
      } else {
        setState(() {
          userName = "";
          userId = "";
          _isPaid="";
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
          {"device_token": deviceId}
      );

      print("Unread Notifications API Response: ${response}");

      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      if (parsed["status"] == true) {
        final List<dynamic> data = parsed["data"] ?? [];
        final List<NotificationModel> notifications = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();

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
    if(_isPaid == "0"){
      UtilClass.showAlertDialog(
        context: context,
        message: "Please activate plan to access this feature.",
        // Or use your translation key if available
        // message: "subscription_required".tr(),
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

    if(_isPaid == "0"){

      UtilClass.showAlertDialog(
        context: context,
        message: "Please activate plan to access this feature.",
        // Or use your translation key if available
        // message: "subscription_required".tr(),
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
    // Refresh notification count after returning from notifications screen
    await Future.delayed(Duration(milliseconds: 500));
    await _fetchUnreadNotifications();
  }

  Future<void> _selectLanguage() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(

          title:  Text("select_language".tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("English"),
                leading: Radio(
                  value: "en",
                  groupValue: _selectedLanguage,
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
                  onChanged: (value) {
                    Navigator.pop(context);
                    //_updateLanguage(value as String);
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

    // Show success message
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return _isLoading && userName.isEmpty
        ? const Center(child: CircularProgressIndicator(color: MyColors.appThemeDark))
        : RefreshIndicator(
      onRefresh: _refreshData,
      color: MyColors.appThemeDark,
      child: Column(
        children: [
          // Updated Header with Notification Count
          HomeCustomHeader(
            title: "${"home".tr()}",
            notificationCount: _unreadNotificationCount,
            onNotificationTap: _handleNotificationTap,
          ),



          SizedBox(height: height * 0.02),

          // Language Selector Card
          _languageCard(width, height),

          SizedBox(height: height * 0.02),

          // Menu Grid
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.04),
                child: Column(
                  children: [
                    _menuGrid(width, height),
                    SizedBox(height: height * 0.02),
                    _singleMenuCard(
                        width,
                        height,
                        Icons.local_shipping_outlined,
                        "matched_cars".tr()
                    ),
                    SizedBox(height: height * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _languageCard(double width, double height) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.04),
      child: Container(
        width: width,
        padding: EdgeInsets.all(width * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color:  MyColors.appThemeDark,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${"welcome".tr()}, $userName!",
              style: TextStyle(
                fontSize: width * 0.06,
                fontWeight: FontWeight.bold,
                color:  MyColors.appThemeDark,
              ),
            ),
            SizedBox(height: height * 0.005),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(width * 0.025),
                  decoration: BoxDecoration(
                    color: MyColors.appThemeDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.language,
                    color: MyColors.appThemeDark,
                    size: width * 0.06,
                  ),
                ),
                SizedBox(width: width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "language".tr(),
                        style: TextStyle(
                          fontSize: width * 0.045,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: height * 0.005),
                      Text(
                        _getLangName(context.locale.languageCode),
                        style: TextStyle(
                          fontSize: width * 0.038,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _selectLanguage,
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    size: width * 0.05,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _menuGrid(double width, double height) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _menuCard(
                width,
                height,
                Icons.inbox_outlined,
                "upload_old_cars".tr(),
                    () => _onMenuTap("Upload Old Cars"),
                backgroundColor: MyColors.cardBackColor1,
                iconColor: MyColors.appThemeDark,
                textColor: MyColors.appThemeDark,
              ),
            ),
            SizedBox(width: width * 0.04),
            Expanded(
              child: _menuCard(
                width,
                height,
                Icons.people_outline,
                "agent_searched_data".tr(),
                    () => _onMenuTap("Agent Searched Data"),
                backgroundColor: MyColors.cardBackColor2,
                iconColor: MyColors.appThemeDark,
                textColor: MyColors.appThemeDark,
              ),
            ),
          ],
        ),
        SizedBox(height: height * 0.02),
        Row(
          children: [
            Expanded(
              child: _menuCard(
                width,
                height,
                Icons.local_shipping_outlined,
                "verified_cars".tr(),
                    () => _onMenuTap("Verified Cars"),
                backgroundColor: MyColors.cardBackColor3,
                iconColor: MyColors.appThemeDark,
                textColor: MyColors.appThemeDark,
              ),
            ),
            SizedBox(width: width * 0.04),
            Expanded(
              child: _menuCard(
                width,
                height,
                Icons.shield_outlined,
                "search_cars".tr(),
                    () => _onMenuTap("Search Cars"),
                backgroundColor: MyColors.cardBackColor4,
                iconColor: MyColors.appThemeDark,
                textColor: MyColors.appThemeDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _singleMenuCard(
      double width,
      double height,
      IconData icon,
      String title
      ) {
    return _menuCard(
      width,
      height,
      icon,
      title,
          () => _onMenuTap("Matched Cars"),
      backgroundColor: MyColors.cardBackColor5,
      iconColor: MyColors.appThemeDark,
      textColor: MyColors.appThemeDark,
    );
  }

  Widget _menuCard(
      double width,
      double height,
      IconData icon,
      String title,
      VoidCallback function, {
        Color backgroundColor = Colors.white,
        Color iconColor = MyColors.appThemeDark,
        Color textColor = MyColors.appThemeDark
      }) {

    double cardHeight = height * 0.2; // <<< SAME HEIGHT FOR ALL CARDS

    return GestureDetector(
      onTap: _isLoading ? null : function,
      child: Opacity(
        opacity: _isLoading ? 0.6 : 1.0,
        child: SizedBox(
          height: cardHeight,        // <<< FIXED HEIGHT
          child: Container(
            padding: EdgeInsets.all(width * 0.04),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // << SMOOTH SPACING
              children: [
                Container(
                  padding: EdgeInsets.all(width * 0.03),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: width * 0.07,
                  ),
                ),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: width * 0.045,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),

                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}