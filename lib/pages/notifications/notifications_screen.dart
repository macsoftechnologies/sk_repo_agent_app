import 'dart:convert';
import 'dart:io' show Platform;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:repo_agent_application/components/custom_app_header.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../data/prefernces.dart';
import '../../models/notification_model.dart';
import '../../services/end_points.dart';
import '../../services/repository.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String userName = "";
  String deviceId = "";
  String userId = "";

  // State variables
  List<NotificationModel> _allNotifications = [];
  List<NotificationModel> _unreadNotifications = [];

  // Loading and error states
  bool _isLoadingAll = false;
  bool _isLoadingUnread = false;
  bool _hasErrorAll = false;
  bool _hasErrorUnread = false;
  String _errorMessageAll = '';
  String _errorMessageUnread = '';

  // Refresh control
  bool _isRefreshing = false;

  // Platform detection helpers
  bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
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

  void _loadAllData() {
    _fetchAllNotifications();
    _fetchUnreadNotifications();
  }

  Future<void> _fetchAllNotifications() async {
    if (_isLoadingAll) return;

    setState(() {
      _isLoadingAll = true;
      _hasErrorAll = false;
    });

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      setState(() {
        _isLoadingAll = false;
        _hasErrorAll = true;
        _errorMessageAll = Config.kNoInternet;
      });
      UtilClass.showAlertDialog(context: context, message: Config.kNoInternet);
      return;
    }

    try {
      final response = await Repository.postApiRawService(
          EndPoints.allNotificationsApi,
          {
            'device_token': deviceId.toString(),
            'admin_id': userId.toString(),
          }
      );

      UtilClass.hideProgress();
      print("All Notifications API Response: ${response}");

      // Handle response
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
          _allNotifications = notifications;
          _isLoadingAll = false;
          _hasErrorAll = false;
        });

        print("✅ Loaded ${notifications.length} all notifications");
      } else {
        setState(() {
          _isLoadingAll = false;
          _hasErrorAll = true;
          _errorMessageAll = parsed["message"] ?? "Failed to load notifications";
        });
      }
    } catch (e, stackTrace) {
      UtilClass.hideProgress();
      print("❌ All Notifications API Error: $e");
      print("Stack trace: $stackTrace");
      setState(() {
        _isLoadingAll = false;
        _hasErrorAll = true;
        _errorMessageAll = e.toString();
      });
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    if (_isLoadingUnread) return;

    setState(() {
      _isLoadingUnread = true;
      _hasErrorUnread = false;
    });

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      setState(() {
        _isLoadingUnread = false;
        _hasErrorUnread = true;
        _errorMessageUnread = Config.kNoInternet;
      });
      return;
    }

    try {
      final response = await Repository.postApiRawService(
          EndPoints.unreadNotificationsApi,
          {
            "device_token": deviceId.toString(),
            'admin_id': userId.toString(),
          }
      );

      UtilClass.hideProgress();
      print("Unread Notifications API Response: ${response}");

      // Handle response
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
          _unreadNotifications = notifications;
          _isLoadingUnread = false;
          _hasErrorUnread = false;
        });

        print("✅ Loaded ${notifications.length} unread notifications");
      } else {
        setState(() {
          _isLoadingUnread = false;
          _hasErrorUnread = true;
          _errorMessageUnread = parsed["message"] ?? "Failed to load unread notifications";
        });
      }
    } catch (e, stackTrace) {
      UtilClass.hideProgress();
      print("❌ Unread Notifications API Error: $e");
      print("Stack trace: $stackTrace");
      setState(() {
        _isLoadingUnread = false;
        _hasErrorUnread = true;
        _errorMessageUnread = e.toString();
      });
    }
  }

  Future<void> _markNotificationsAsRead(List<String> notificationIds) async {
    try {
      final deviceId = await Preferences.getDeviceId();

      // Show loading
      UtilClass.showProgress(context: context);

      final response = await Repository.postApiRawService(
          EndPoints.markAsReadNotificationsApi,
          {
            "device_token": deviceId,
            "ids": notificationIds,
            "admin_id": userId.toString(),
          }
      );

      UtilClass.hideProgress();
      print("Mark as Read API Response: $response");

      // Handle response
      dynamic parsed;
      if (response is String) {
        parsed = json.decode(response);
      } else {
        parsed = response;
      }

      if (parsed["status"] == true) {
        // Show success message
        if (notificationIds.length == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${"notification_marked_as_read".tr()}"),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${notificationIds.length} ${"notifications_marked_as_read".tr()}"),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reload data from API to get updated read status
        _refreshData();

      } else {
        final errorMsg = parsed["message"] ?? "${"failed_to_mark_as_read".tr()}";
        UtilClass.showAlertDialog(context: context, message: errorMsg);
      }

    } catch (e) {
      UtilClass.hideProgress();
      print("Error marking notifications as read: $e");
      UtilClass.showAlertDialog(context: context, message: "${"failed_to_mark_as_read".tr()}");
    }
  }

  Future<void> _markSingleAsRead(String notificationId) async {
    await _markNotificationsAsRead([notificationId]);
  }

  Future<void> _markAllUnreadAsRead() async {
    if (_unreadNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${"no_unread_notifications".tr()}"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final unreadIds = _unreadNotifications.map((n) => n.id).toList();
    await _markNotificationsAsRead(unreadIds);
  }

  void _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    await Future.wait([
      _fetchAllNotifications(),
      _fetchUnreadNotifications(),
    ]);

    setState(() {
      _isRefreshing = false;
    });
  }

  void _retryLoading(int tabIndex) {
    if (tabIndex == 0) {
      _fetchUnreadNotifications();
    } else {
      _fetchAllNotifications();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          CustomAppHeader(
            title:'${"notifications_title".tr()}',
            onBack: () => Navigator.pop(context),
          ),

          SizedBox(height: height * 0.015),

          // Header Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: width * 0.04),
            child: Row(
              children: [
                // Bell Icon with Badge
                Stack(
                  children: [
                    Container(
                      width: width * 0.14,
                      height: width * 0.14,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade200,
                            Colors.red,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(width * 0.03),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: width * 0.07,
                        ),
                      ),
                    ),
                    if (_unreadNotifications.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: width * 0.02,
                            vertical: height * 0.003,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: BoxConstraints(
                            minWidth: width * 0.06,
                          ),
                          child: Text(
                            _unreadNotifications.length > 9 ? '9+' : _unreadNotifications.length.toString(),
                            style: TextStyle(
                              fontSize: width * 0.025,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(width: width * 0.03),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${"notifications_title".tr()}',
                        style: TextStyle(
                          fontSize: width * 0.055,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: height * 0.003),
                      Text(
                        _unreadNotifications.isNotEmpty
                            ? "${_unreadNotifications.length} ${"unread_notifications".tr()}"
                            : "${"youre_all_caught_up".tr()}",
                        style: TextStyle(
                          fontSize: width * 0.035,
                          color: _unreadNotifications.isNotEmpty ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: height * 0.02),

          // Tabs Section
          Container(
            margin: EdgeInsets.symmetric(horizontal: width * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.03),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[600],
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.02),
                color: MyColors.greyTextColor,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(
                  child: SizedBox(
                    width: width * 0.4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("${"unread".tr()}"),
                        if (_unreadNotifications.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(left: width * 0.015),
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.02,
                              vertical: height * 0.002,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _unreadNotifications.length.toString(),
                              style: TextStyle(
                                fontSize: width * 0.028,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Tab(
                  child: SizedBox(
                    width: width * 0.4,
                    child: Center(
                      child: Text("${"all".tr()}"),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: height * 0.02),

          // Tab Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshData();
              },
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Unread Tab
                  _buildMobileUnreadTab(width, height),

                  // All Tab
                  _buildMobileAllTab(width, height),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Windows/Desktop UI
  Widget _buildDesktopUI() {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 1400;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '${"notifications_title".tr()}',
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 24,color: Colors.white,),
            onPressed: _refreshData,
            tooltip: '${"refresh_notifications".tr()}',
          ),
          if (_unreadNotifications.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _markAllUnreadAsRead,
              icon: Icon(Icons.done_all, size: 18),
              label: Text('${"mark_all_as_read".tr()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MyColors.appThemeDark,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel - Summary
          Container(
            width: 300,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Stats
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 48,
                        color: MyColors.appThemeDark,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '${"notification_summary".tr()}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDesktopStatItem(
                            label: '${"total".tr()}',
                            value: _allNotifications.length.toString(),
                            color: Colors.blue,
                          ),
                          _buildDesktopStatItem(
                            label: '${"unread".tr()}',
                            value: _unreadNotifications.length.toString(),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Quick Actions
                Text(
                  '${"quick_actions".tr()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refreshData,
                  icon: Icon(Icons.refresh, size: 20),
                  label: Text('${"refresh".tr()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[800],
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _markAllUnreadAsRead,
                  icon: Icon(Icons.done_all, size: 20),
                  label: Text('${"mark_all_as_read".tr()}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.appThemeDark,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
                SizedBox(height: 24),

                // Filter Options
                Text(
                  '${"filter_by".tr()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text('${"unread".tr()}'),
                      selected: _tabController.index == 0,
                      onSelected: (selected) {
                        _tabController.animateTo(0);
                      },
                      backgroundColor: _tabController.index == 0
                          ? MyColors.appThemeDark
                          : Colors.grey[100],
                      labelStyle: TextStyle(
                        color: _tabController.index == 0 ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    FilterChip(
                      label: Text('${"all".tr()}'),
                      selected: _tabController.index == 1,
                      onSelected: (selected) {
                        _tabController.animateTo(1);
                      },
                      backgroundColor: _tabController.index == 1
                          ? MyColors.appThemeDark
                          : Colors.grey[100],
                      labelStyle: TextStyle(
                        color: _tabController.index == 1 ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Panel - Notifications List
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tabController.index == 0
                            ? '${"unread_notifications".tr()} (${_unreadNotifications.length})'
                            : '${"all_notifications".tr()} (${_allNotifications.length})',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      // Row(
                      //   children: [
                      //     IconButton(
                      //       icon: Icon(Icons.search, size: 24),
                      //       onPressed: () {
                      //         // Add search functionality
                      //       },
                      //       tooltip: '${"search_notifications".tr()}',
                      //     ),
                      //     SizedBox(width: 8),
                      //     DropdownButtonHideUnderline(
                      //       child: DropdownButton<String>(
                      //         value: 'recent',
                      //         items: [
                      //           DropdownMenuItem(
                      //             value: 'recent',
                      //             child: Text('${"most_recent".tr()}'),
                      //           ),
                      //           DropdownMenuItem(
                      //             value: 'oldest',
                      //             child: Text('${"oldest_first".tr()}'),
                      //           ),
                      //         ],
                      //         onChanged: (value) {
                      //           // Add sorting functionality
                      //         },
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: MyColors.appThemeDark,
                      ),
                      tabs: [
                        Tab(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${"unread".tr()}'),
                                if (_unreadNotifications.isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _unreadNotifications.length.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${"all".tr()}'),
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 1 ? Colors.blue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _allNotifications.length.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _tabController.index == 1 ? Colors.white : Colors.transparent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ),
                  SizedBox(height: 24),

                  // Content Area
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Unread Tab
                        _buildDesktopUnreadTab(),

                        // All Tab
                        _buildDesktopAllTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Stat Item
  Widget _buildDesktopStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Mobile Unread Tab
  Widget _buildMobileUnreadTab(double width, double height) {
    return _isLoadingUnread && _unreadNotifications.isEmpty
        ? _buildMobileLoadingState(width, height, "${"loading_unread_notifications".tr()}")
        : _hasErrorUnread && _unreadNotifications.isEmpty
        ? _buildMobileErrorState(
      width,
      height,
      _errorMessageUnread,
          () => _retryLoading(0),
    )
        : _unreadNotifications.isEmpty
        ? _buildMobileEmptyState(
      width: width,
      height: height,
      icon: Icons.notifications_off_rounded,
      title: "${"no_unread_notifications".tr()}",
      message: "${"youre_all_caught_up".tr()}",
    )
        : _buildMobileUnreadContent(width, height);
  }

  // Desktop Unread Tab
  Widget _buildDesktopUnreadTab() {
    return _isLoadingUnread && _unreadNotifications.isEmpty
        ? _buildDesktopLoadingState("${"loading_unread_notifications".tr()}")
        : _hasErrorUnread && _unreadNotifications.isEmpty
        ? _buildDesktopErrorState(
      _errorMessageUnread,
          () => _retryLoading(0),
    )
        : _unreadNotifications.isEmpty
        ? _buildDesktopEmptyState(
      icon: Icons.notifications_off_rounded,
      title: "${"no_unread_notifications".tr()}",
      message: "${"youre_all_caught_up".tr()}",
    )
        : _buildDesktopContent(_unreadNotifications, false);
  }

  // Mobile All Tab
  Widget _buildMobileAllTab(double width, double height) {
    return _isLoadingAll && _allNotifications.isEmpty
        ? _buildMobileLoadingState(width, height, "${"loading_all_notifications".tr()}")
        : _hasErrorAll && _allNotifications.isEmpty
        ? _buildMobileErrorState(
      width,
      height,
      _errorMessageAll,
          () => _retryLoading(1),
    )
        : _allNotifications.isEmpty
        ? _buildMobileEmptyState(
      width: width,
      height: height,
      icon: Icons.notifications_none_rounded,
      title: "${"no_notifications".tr()}",
      message: "${"you_dont_have_any_notifications_yet".tr()}",
    )
        : _buildMobileAllContent(width, height);
  }

  // Desktop All Tab
  Widget _buildDesktopAllTab() {
    return _isLoadingAll && _allNotifications.isEmpty
        ? _buildDesktopLoadingState("${"loading_all_notifications".tr()}")
        : _hasErrorAll && _allNotifications.isEmpty
        ? _buildDesktopErrorState(
      _errorMessageAll,
          () => _retryLoading(1),
    )
        : _allNotifications.isEmpty
        ? _buildDesktopEmptyState(
      icon: Icons.notifications_none_rounded,
      title: "${"no_notifications".tr()}",
      message: "${"you_dont_have_any_notifications_yet".tr()}",
    )
        : _buildDesktopContent(_allNotifications, true);
  }

  // Mobile Unread Content
  Widget _buildMobileUnreadContent(double width, double height) {
    return Column(
      children: [
        // Action Buttons
        Container(
          margin: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: height * 0.01),
          padding: EdgeInsets.all(width * 0.03),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(width * 0.03),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${_unreadNotifications.length} ${"unread_notifications".tr()}",
                  style: TextStyle(
                    fontSize: width * 0.04,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _markAllUnreadAsRead(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyColors.greenBackground,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.04,
                    vertical: height * 0.012,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(width * 0.02),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.done_all, size: width * 0.045),
                label: Text(
                  "${"mark_all_as_read".tr()}",
                  style: TextStyle(
                    fontSize: width * 0.035,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Unread Notifications List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: width * 0.04,
              right: width * 0.04,
              bottom: height * 0.02,
            ),
            itemCount: _unreadNotifications.length,
            itemBuilder: (context, index) {
              final item = _unreadNotifications[index];
              return _buildMobileNotificationCard(item, width, height, showFullDetails: false);
            },
          ),
        ),
      ],
    );
  }

  // Mobile All Content
  Widget _buildMobileAllContent(double width, double height) {
    return Column(
      children: [
        // Action Buttons
        Container(
          margin: EdgeInsets.symmetric(horizontal: width * 0.04, vertical: height * 0.01),
          padding: EdgeInsets.all(width * 0.03),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(width * 0.03),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_allNotifications.length} ${"total_notifications".tr()}",
                style: TextStyle(
                  fontSize: width * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_unreadNotifications.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _markAllUnreadAsRead(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyColors.greenBackground,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.04,
                      vertical: height * 0.012,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(width * 0.02),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    "${"mark_all_as_read".tr()}",
                    style: TextStyle(
                      fontSize: width * 0.035,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // All Notifications List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: width * 0.04,
              right: width * 0.04,
              bottom: height * 0.02,
            ),
            itemCount: _allNotifications.length,
            itemBuilder: (context, index) {
              final item = _allNotifications[index];
              return _buildMobileNotificationCard(item, width, height, showFullDetails: true);
            },
          ),
        ),
      ],
    );
  }

  // Desktop Content
  Widget _buildDesktopContent(List<NotificationModel> notifications, bool showFullDetails) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 24),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final item = notifications[index];
        return _buildDesktopNotificationCard(item, showFullDetails);
      },
    );
  }

  // Mobile Notification Card
  Widget _buildMobileNotificationCard(
      NotificationModel item,
      double width,
      double height, {
        required bool showFullDetails,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: height * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.03),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markSingleAsRead(item.id),
          borderRadius: BorderRadius.circular(width * 0.03),
          child: Padding(
            padding: EdgeInsets.all(width * 0.04),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Indicator
                Container(
                  margin: EdgeInsets.only(top: height * 0.01),
                  width: width * 0.025,
                  height: width * 0.025,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isRead ? Colors.green : Colors.red,
                    boxShadow: item.isRead ? null : [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: width * 0.04),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Batch Number
                      if (item.batchNumber.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: height * 0.008),
                          child: Text(
                            "${"batch".tr()}: ${item.batchNumber}",
                            style: TextStyle(
                              fontSize: width * 0.038,
                              color: MyColors.appThemeDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                      // Message
                      Padding(
                        padding: EdgeInsets.only(bottom: height * 0.012),
                        child: Text(
                          item.message,
                          style: TextStyle(
                            fontSize: width * 0.04,
                            color: item.isRead ? Colors.grey[700] : Colors.black87,
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w600,
                            height: 1.4,
                          ),
                          maxLines: showFullDetails ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Created At
                      Padding(
                        padding: EdgeInsets.only(bottom: height * 0.006),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: width * 0.04,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: width * 0.015),
                            Text(
                              "${"created".tr()}: ${item.formattedCreatedAt}",
                              style: TextStyle(
                                fontSize: width * 0.035,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Read At (only for read notifications in All tab)
                      if (showFullDetails && item.isRead && item.readAt.isNotEmpty && item.readAt.toLowerCase() != 'null')
                        Padding(
                          padding: EdgeInsets.only(bottom: height * 0.006),
                          child: Row(
                            children: [
                              Icon(
                                Icons.done_all_rounded,
                                size: width * 0.04,
                                color: Colors.green,
                              ),
                              SizedBox(width: width * 0.015),
                              Text(
                                "${"read".tr()}: ${item.formattedReadAt}",
                                style: TextStyle(
                                  fontSize: width * 0.035,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: height * 0.01),

                      // Action Button for Unread
                      if (!item.isRead)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () => _markSingleAsRead(item.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(
                                  horizontal: width * 0.04,
                                  vertical: height * 0.008,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(width * 0.02),
                                  side: BorderSide(
                                    color: Colors.green,
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "${"mark_as_read".tr()}",
                                style: TextStyle(
                                  fontSize: width * 0.033,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  // Desktop Notification Card
  Widget _buildDesktopNotificationCard(NotificationModel item, bool showFullDetails) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isRead ? Colors.grey[200]! : Colors.blue[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _markSingleAsRead(item.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Icon
                Container(
                  width: 40,
                  height: 40,
                  margin: EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.isRead ? Icons.check_circle : Icons.circle,
                    color: item.isRead ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (item.batchNumber.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: MyColors.appThemeDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${"batch".tr()}: ${item.batchNumber}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MyColors.appThemeDark,
                                ),
                              ),
                            ),
                          Text(
                            item.formattedCreatedAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Message
                      Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 16,
                          color: item.isRead ? Colors.grey[700] : Colors.grey[800],
                          fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w600,
                        ),
                        maxLines: showFullDetails ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (showFullDetails && item.isRead && item.readAt.isNotEmpty && item.readAt.toLowerCase() != 'null')
                            Row(
                              children: [
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "${"read".tr()}: ${item.formattedReadAt}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          if (!item.isRead)
                            ElevatedButton(
                              onPressed: () => _markSingleAsRead(item.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(color: Colors.green),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                "${"mark_as_read".tr()}",
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
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

  // Mobile Loading State
  Widget _buildMobileLoadingState(double width, double height, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: MyColors.appThemeDark,
          ),
          SizedBox(height: height * 0.02),
          Text(
            message,
            style: TextStyle(
              fontSize: width * 0.04,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Loading State
  Widget _buildDesktopLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(MyColors.appThemeDark),
            ),
          ),
          SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Error State
  Widget _buildMobileErrorState(double width, double height, String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: width * 0.15,
            color: Colors.red,
          ),
          SizedBox(height: height * 0.02),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.1),
            child: Text(
              error,
              style: TextStyle(
                fontSize: width * 0.04,
                color: const Color(0xFF444444),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: height * 0.02),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: MyColors.appThemeDark,
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.06,
                vertical: height * 0.015,
              ),
            ),
            child: Text(
              "${"retry".tr()}",
              style: TextStyle(
                fontSize: width * 0.04,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Error State
  Widget _buildDesktopErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 80),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: MyColors.appThemeDark,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('${"retry".tr()}'),
          ),
        ],
      ),
    );
  }

  // Mobile Empty State
  Widget _buildMobileEmptyState({
    required double width,
    required double height,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: width * 0.25,
            height: width * 0.25,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: width * 0.12,
                color: Colors.grey[400],
              ),
            ),
          ),
          SizedBox(height: height * 0.03),
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.05,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: height * 0.01),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.1),
            child: Text(
              message,
              style: TextStyle(
                fontSize: width * 0.038,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Empty State
  Widget _buildDesktopEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 80),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}