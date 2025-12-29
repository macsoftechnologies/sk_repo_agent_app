import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:repo_agent_application/utils/my_colors.dart';
import '../../components/custom_app_header.dart';
import '../../models/matched_car_details.dart';
import '../../services/repository.dart';
import '../../services/end_points.dart';
import '../../utils/config.dart';
import '../../utils/util_class.dart';
import '../../data/prefernces.dart';

class MatchedCarDetailsScreen extends StatefulWidget {
  final String regNo;
  const MatchedCarDetailsScreen({super.key, required this.regNo});

  @override
  State<MatchedCarDetailsScreen> createState() =>
      _MatchedCarDetailsScreenState();
}

class _MatchedCarDetailsScreenState extends State<MatchedCarDetailsScreen> {
  late String regNo;

  MatchedCar? _car;
  List<SearchHistory> _history = [];

  String userName = "";
  String deviceId = "";
  String userId = "";

  // Pagination
  int _perPage = 10;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalPages = 1;

  // Platform detection
  bool get _isDesktop => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map?;
    regNo = args?["regNo"] ?? widget.regNo;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _history = [];
      _hasMore = true;
    });

    await _fetchData();
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

  // Platform-specific alert dialog
  void _showPlatformAlertDialog({required BuildContext context, required String message}) {
    if (_isDesktop) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Information"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    } else {
      UtilClass.showAlertDialog(context: context, message: message);
    }
  }

  Future<void> _fetchData() async {
    if (!_hasMore) return;

    final internet = await UtilClass.checkInternet();

    if (!internet) {
      _showPlatformAlertDialog(
        context: context,
        message: Config.kNoInternet,
      );
      return;
    }

    final value = await Repository.postApiRawService(
      EndPoints.matchedCarsApi,
      {
        "reg_no": regNo,
        "device_token": deviceId.toString(),
        "page": _currentPage,
        'admin_id': userId.toString(),
      },
    );

    dynamic parsed = value is String ? json.decode(value) : value;

    final data = MatchedCarDetailResponse.fromJson(parsed);

    if (data.matchedCars.isNotEmpty) {
      setState(() {
        _car = data.matchedCars.first;

        // update perPage & totalPages from API
        _perPage = data.per_page;
        _totalPages = data.totalPages;

        // append API returned list
        _history.addAll(_car!.searchHistory);

        // update hasMore
        _hasMore = _currentPage < _totalPages;

        _isLoading = false;
        _currentPage += 1;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
    } catch (e) {
      return dateString;
    }
  }

  // Helper function to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'unverified':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isDesktop = _isDesktop;

    return Scaffold(
      backgroundColor: isDesktop ? const Color(0xFFF8F9FA) : const Color(0xFFF1F4FF),
      body: Column(
        children: [
          CustomAppHeader(
            title:'${"matched_car_details_title".tr()}',
            onBack: () => Navigator.pop(context),
          ),

          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: isDesktop ? 3 : 2,
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: isDesktop
                  ? _buildDesktopContent(width, height)
                  : _buildMobileContent(width, height),
            ),
          ),
        ],
      ),
    );
  }

  // =========================== DESKTOP UI ===========================

  Widget _buildDesktopContent(double width, double height) {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.08,
          vertical: height * 0.03,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_car != null) _buildDesktopCarCard(width, height),

            SizedBox(height: 24),

            _buildDesktopSearchHistoryCard(width, height),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopCarCard(double width, double height) {
    final regNo = _car!.regNo.toString() ?? 'N/A';
    final carMake = _car!.carMake.toString() ?? 'N/A';
    final status = _car!.status.toString() ?? 'N/A';
    final searchCount = _car!.searchHistory.length.toString() ?? 'N/A';
    final createdAt = _car!.createdAt.toString() ?? 'N/A';
    final formattedDate = _formatDate(createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MyColors.appThemeDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🚗 ${'car_details'.tr()}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "${'reg_no'.tr()}: $regNo",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Container(
            padding: EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Vehicle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopDetailRow("${'reg_no'.tr()}", regNo),
                      SizedBox(height: 16),
                      _buildDesktopDetailRow("${'car_model'.tr()}", carMake),
                      SizedBox(height: 16),
                      _buildDesktopDetailRow("${'created'.tr()}", formattedDate),
                    ],
                  ),
                ),

                SizedBox(width: 32),

                // Right Column - Stats
                Container(
                  width: 200,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search,
                        size: 32,
                        color: Colors.blue[600],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "${'search_history'.tr()}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "$searchCount searches",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[600],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Last updated: $formattedDate",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSearchHistoryCard(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📋 ${"search_history".tr()}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF333333),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Text(
                    "${_history.length} Records",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                if (_history.isEmpty)
                  Container(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No Search History Found",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF666666),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "This vehicle has no recorded search history yet.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                // DataTable for Desktop
                if (_history.isNotEmpty)
                  DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 0,
                    headingRowHeight: 48,
                    dataRowHeight: 60,
                    columns: [
                      DataColumn(
                        label: Text(
                          "${'s_no'.tr()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "${'registration_no'.tr()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "${'location_details'.tr()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "${'notes'.tr()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "${'searched_at'.tr()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ),
                    ],
                    rows: _history.asMap().entries.map((entry) {
                      final index = entry.key;
                      final h = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[600],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green[100]!),
                              ),
                              child: Text(
                                h.regNo ?? "-",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[600],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                h.locationDetails ?? "No details",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                h.notes ?? "No remarks",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatDateTime(h.searchedAt ?? "-"),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                if (_hasMore && _history.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _fetchData,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, color: Colors.blue[600], size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Load More History",
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================== MOBILE UI (ORIGINAL) ===========================

  Widget _buildMobileContent(double width, double height) {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_car != null) _buildMobileCarCard(width, height),

          SizedBox(height: 12),

          _buildMobileSearchHistoryCard(width, height),
        ],
      ),
    );
  }

  Widget _buildMobileCarCard(double width, double height) {
    final regNo = _car!.regNo.toString() ?? 'N/A';
    final carMake = _car!.carMake.toString() ?? 'N/A';
    final status = _car!.status.toString() ?? 'N/A';
    final searchCount = _car!.searchHistory.length.toString() ?? 'N/A';
    final createdAt = _car!.createdAt.toString() ?? 'N/A';
    final formattedDate = _formatDate(createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          Config.matchedCarDetailsRouteName,
          arguments: {
            'regNo': regNo,
          },
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: width * 0.04,
          vertical: height * 0.0075,
        ),
        padding: EdgeInsets.all(width * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // reg + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  regNo,
                  style: TextStyle(
                    fontSize: width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: height * 0.004,
                    horizontal: width * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: width * 0.033,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: height * 0.008),

            Text(
              carMake,
              style: TextStyle(fontSize: width * 0.038, color: Colors.black54),
            ),

            SizedBox(height: height * 0.008),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.black54),
                    SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: width * 0.04,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Text(
                  "🔍 $searchCount ${"searches".tr()}",
                  style: TextStyle(fontSize: width * 0.04, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSearchHistoryCard(double width, double height) {
    return Container(
      margin: EdgeInsets.all(width * 0.04),
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${"search_history".tr()}",
            style: TextStyle(
              fontSize: width * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 12),

          if (_history.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text("No search history found"),
              ),
            ),

          // 🔥 List of Cards
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _history.length,
            itemBuilder: (context, index) {
              return _buildMobileHistoryItem(
                index: index,
                h: _history[index],
                width: width,
                height: height,
              );
            },
          ),

          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _fetchData,
                child: Text("Load more"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileHistoryItem({
    required int index,
    required SearchHistory h,
    required double width,
    required double height,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: MyColors.appThemeLight,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔥 S. No Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${"s_no".tr()}: ${index + 1}",
                style: TextStyle(
                  fontSize: width * 0.04,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                _formatDate(h.searchedAt ?? "-"),
                style: TextStyle(
                  fontSize: width * 0.036,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          _mobileItemRow("${"reg_num".tr()}", h.regNo ?? "-"),
          _mobileItemRow("${"location".tr()}", h.locationDetails ?? "No details"),
          _mobileItemRow("${"notes".tr()}", h.notes ?? "No remarks"),
        ],
      ),
    );
  }

  Widget _mobileItemRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text("$title:")),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}